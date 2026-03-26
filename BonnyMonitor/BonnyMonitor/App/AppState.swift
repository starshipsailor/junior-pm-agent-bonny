import Foundation
import SwiftUI
import AppKit

@Observable
final class AppState {
    static let projectRoot = "/Users/rohan.vadgaonkar/workspace/junior-pm-agent-bonny"

    var agents: [AgentStatus] = AgentDefinition.allCases.map { AgentStatus(definition: $0) }
    var budget: BudgetState = .empty
    var inboxCounts: InboxCounts = .zero
    var authStatus: [String: AuthState] = [
        "slack": .unknown,
        "notion": .unknown,
        "atlassian": .unknown
    ]
    var lastRefresh: Date = .distantPast
    var isRefreshing: Bool = false
    var isCheckingAuth: Bool = false

    enum AuthState: Equatable {
        case unknown        // Not yet checked
        case checking       // Probe running
        case ok             // Auth is valid
        case failed         // Auth is stale/expired
    }

    private let fileSystem = FileSystemService(projectRoot: AppState.projectRoot)
    private let launchd = LaunchdService()
    private let logParser = LogParser(logDir: "\(AppState.projectRoot)/logs")
    let processRunner = ProcessRunner(projectRoot: AppState.projectRoot)

    private var refreshTimer: Timer?

    func startAutoRefresh() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() {
        isRefreshing = true

        // 1. Get launchd state
        let jobs = launchd.listBonnyJobs()

        // 2. Read budget
        budget = fileSystem.readBudget()

        // 3. Read inbox counts
        inboxCounts = fileSystem.readInboxCounts()

        // 4. Auth status is checked separately via checkAllAuth() — not on every refresh

        // 5. Update each agent
        for i in agents.indices {
            let def = agents[i].definition

            // Launchd state
            let job = jobs[def.launchdLabel]
            agents[i].isLoadedInLaunchd = job != nil

            // Lock file (running?)
            let lockActive = fileSystem.isLockActive(relativePath: def.lockFile)

            // Watermark
            if let wmPath = def.watermarkFile {
                agents[i].watermark = fileSystem.readWatermark(relativePath: wmPath)
            }

            // Recent runs from logs
            agents[i].recentRuns = logParser.recentRuns(for: def)

            // Last run time: prefer watermark, fall back to most recent log
            if let wmTime = agents[i].watermark?.lastSuccess,
               let date = ISO8601DateFormatter().date(from: wmTime) {
                agents[i].lastRunTime = date
            } else if let firstRun = agents[i].recentRuns.first {
                agents[i].lastRunTime = firstRun.timestamp
            }

            // Last error
            if let wmError = agents[i].watermark?.error, agents[i].watermark?.status == "error" {
                agents[i].lastError = wmError
            } else if let lastRun = agents[i].recentRuns.first,
                      case .error(let msg) = lastRun.outcome {
                agents[i].lastError = msg
            } else {
                agents[i].lastError = nil
            }

            // Next run time
            if let interval = def.scheduleIntervalSeconds, let lastRun = agents[i].lastRunTime {
                agents[i].nextRunTime = lastRun.addingTimeInterval(TimeInterval(interval))
            } else {
                agents[i].nextRunTime = computeNextCalendarRun(for: def)
            }

            // Run state
            if !agents[i].isLoadedInLaunchd {
                agents[i].runState = .paused
            } else if lockActive || (job?.pid != nil) {
                agents[i].runState = .running
            } else if budget.isExhausted {
                agents[i].runState = .budgetPaused
            } else if agents[i].watermark?.status == "error" {
                agents[i].runState = .error
            } else if job != nil {
                agents[i].runState = .idle
            } else {
                agents[i].runState = .unknown
            }
        }

        lastRefresh = Date()
        isRefreshing = false
    }

    // MARK: - Actions

    func triggerRun(_ agent: AgentDefinition) {
        processRunner.runAgent(agent)
        // Immediately show as running
        if let idx = agents.firstIndex(where: { $0.definition == agent }) {
            agents[idx].runState = .running
        }
        // Refresh after a short delay to pick up lock file
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.refresh()
        }
    }

    func overrideBudget() {
        let newCap = budget.dailyCap * 2
        if let confirmedCap = fileSystem.setTemporaryBudgetOverride(newCap: newCap) {
            budget.dailyCap = confirmedCap
            budget.isOverrideActive = true
            refresh()
        }
    }

    func togglePause(_ agent: AgentDefinition) {
        if launchd.isJobLoaded(label: agent.launchdLabel) {
            launchd.unloadJob(label: agent.launchdLabel)
        } else {
            launchd.loadJob(label: agent.launchdLabel)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refresh()
        }
    }

    func openSkill(_ agent: AgentDefinition) {
        if let path = agent.skillFilePath {
            processRunner.openInEditor(path)
        }
    }

    func openLog(_ agent: AgentDefinition) {
        if let firstRun = agents.first(where: { $0.definition == agent })?.recentRuns.first {
            NSWorkspace.shared.open(URL(fileURLWithPath: firstRun.logFilePath))
        } else {
            // Open the stdout log
            let path = (Self.projectRoot as NSString).appendingPathComponent(agent.stdoutLogFile)
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    // MARK: - Auth

    /// Check auth for all plugins (runs probes in background)
    func checkAllAuth() {
        guard !isCheckingAuth else { return }
        isCheckingAuth = true

        let plugins = ["slack", "notion", "atlassian"]
        for plugin in plugins {
            authStatus[plugin] = .checking
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            for plugin in plugins {
                let result = self.processRunner.checkPluginAuth(plugin)
                DispatchQueue.main.async {
                    if result == "OK" {
                        self.authStatus[plugin] = .ok
                    } else {
                        self.authStatus[plugin] = .failed
                    }
                }
            }
            DispatchQueue.main.async {
                self.isCheckingAuth = false
            }
        }
    }

    /// Check auth for a single plugin
    func checkAuth(plugin: String) {
        authStatus[plugin] = .checking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.processRunner.checkPluginAuth(plugin)
            DispatchQueue.main.async {
                self.authStatus[plugin] = result == "OK" ? .ok : .failed
            }
        }
    }

    /// Re-auth a plugin — opens interactive Terminal session
    func reAuth(plugin: String) {
        processRunner.reAuthPlugin(plugin)
    }

    // MARK: - Calendar scheduling

    private func computeNextCalendarRun(for agent: AgentDefinition) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()

        switch agent {
        case .contextDigest:
            components.hour = 6
            components.minute = 0
        case .selfImprovement:
            components.hour = 7
            components.minute = 0
        case .cleanup:
            components.weekday = 1 // Sunday
            components.hour = 0
            components.minute = 0
        default:
            return nil
        }

        return calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)
    }
}
