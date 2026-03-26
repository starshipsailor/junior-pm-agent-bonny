import Foundation

struct AgentStatus: Identifiable {
    let definition: AgentDefinition
    var id: String { definition.id }

    var runState: RunState = .unknown
    var isLoadedInLaunchd: Bool = false
    var lastRunTime: Date?
    var nextRunTime: Date?
    var recentRuns: [AgentRun] = []
    var lastError: String?
    var watermark: WatermarkState?

    enum RunState: String {
        case idle
        case running
        case error
        case paused
        case budgetPaused
        case unknown
    }

    var statusColor: String {
        switch runState {
        case .idle:          return "green"
        case .running:       return "blue"
        case .error:         return "red"
        case .paused:        return "gray"
        case .budgetPaused:  return "orange"
        case .unknown:       return "gray"
        }
    }

    var statusLabel: String {
        switch runState {
        case .idle:          return "Scheduled"
        case .running:       return "Running"
        case .error:         return "Error"
        case .paused:        return "Paused"
        case .budgetPaused:  return "Budget Exceeded"
        case .unknown:       return "Scheduled"
        }
    }

    var lastRunRelative: String {
        guard let lastRunTime else { return "Never" }
        let interval = Date().timeIntervalSince(lastRunTime)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    var nextRunRelative: String {
        guard let nextRunTime else { return "—" }
        let interval = nextRunTime.timeIntervalSince(Date())
        if interval <= 0 { return "Due" }
        if interval < 60 { return "< 1m" }
        if interval < 3600 { return "in \(Int(interval / 60))m" }
        if interval < 86400 {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: nextRunTime)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: nextRunTime)
    }
}

struct AgentRun: Identifiable {
    let id = UUID()
    let agentId: String
    let timestamp: Date
    let duration: TimeInterval?
    let outcome: Outcome
    let logFilePath: String

    enum Outcome {
        case success
        case error(String)
        case unknown
    }

    var outcomeLabel: String {
        switch outcome {
        case .success:       return "OK"
        case .error(let msg): return "Error: \(msg.prefix(40))"
        case .unknown:       return "—"
        }
    }

    var durationLabel: String {
        guard let duration else { return "—" }
        if duration < 60 { return "\(Int(duration))s" }
        return "\(Int(duration / 60))m \(Int(duration.truncatingRemainder(dividingBy: 60)))s"
    }

    var timestampLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}

struct WatermarkState: Codable {
    let lastSuccess: String?
    let itemsFound: Int?
    let itemsWritten: Int?
    let status: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case lastSuccess = "last_success"
        case itemsFound = "items_found"
        case itemsWritten = "items_written"
        case status
        case error
    }
}
