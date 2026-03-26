import Foundation

struct FileSystemService {
    let projectRoot: String

    func fullPath(_ relative: String) -> String {
        (projectRoot as NSString).appendingPathComponent(relative)
    }

    // MARK: - Watermark

    func readWatermark(relativePath: String) -> WatermarkState? {
        let path = fullPath(relativePath)
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(WatermarkState.self, from: data)
    }

    // MARK: - Budget

    func readBudget() -> BudgetState {
        let path = fullPath("state/daily-spend.json")
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONDecoder().decode(DailySpendJSON.self, from: data) else {
            return .empty
        }

        let configPath = fullPath("config/bonny.json")
        var baseCap: Double = 50
        if let configData = FileManager.default.contents(atPath: configPath),
           let configDict = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
           let budgetCap = configDict["daily_budget_cap_usd"] as? Double {
            baseCap = budgetCap
        }

        let today = Self.todayDateString()

        // Check for temporary daily override
        var effectiveCap = baseCap
        var isOverride = false
        let overridePath = fullPath("state/budget-override.json")
        if let overrideData = FileManager.default.contents(atPath: overridePath),
           let override = try? JSONDecoder().decode(BudgetOverrideJSON.self, from: overrideData),
           override.date == today {
            effectiveCap = override.cap
            isOverride = true
        }

        guard json.date == today else {
            return BudgetState(date: today, totalSpent: 0, dailyCap: effectiveCap, baseCap: baseCap, isOverrideActive: isOverride, runs: [])
        }

        return BudgetState(
            date: json.date,
            totalSpent: json.totalUsd,
            dailyCap: effectiveCap,
            baseCap: baseCap,
            isOverrideActive: isOverride,
            runs: json.runs
        )
    }

    // MARK: - Lock file

    func isLockActive(relativePath: String) -> Bool {
        let path = fullPath(relativePath)
        guard let content = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(content) else {
            return false
        }
        return kill(pid, 0) == 0
    }

    // MARK: - Inbox counts

    func countPendingItems(relativePath: String) -> Int {
        let path = fullPath(relativePath)
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return 0 }
        var count = 0
        content.enumerateLines { line, _ in
            if line.lowercased().contains("status: pending") ||
               line.lowercased().contains("status:pending") {
                count += 1
            }
        }
        return count
    }

    func readInboxCounts() -> InboxCounts {
        InboxCounts(
            slack: countPendingItems(relativePath: "Mission_Control/inbox-slack.md"),
            confluence: countPendingItems(relativePath: "Mission_Control/inbox-confluence.md"),
            meetings: countPendingItems(relativePath: "Mission_Control/inbox-meetings.md")
        )
    }

    // MARK: - Auth status (heuristic from logs)

    func checkAuthErrors() -> [String: String?] {
        var results: [String: String?] = [
            "Slack": nil,
            "Notion": nil,
            "Atlassian": nil
        ]

        // Check recent stderr logs for auth errors
        let stderrFiles = [
            ("Slack", "logs/slack-monitor-stderr.log"),
            ("Notion", "logs/meeting-monitor-stderr.log"),
            ("Atlassian", "logs/confluence-monitor-stderr.log")
        ]

        for (plugin, logFile) in stderrFiles {
            let path = fullPath(logFile)
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines).suffix(20)
            for line in lines {
                if line.contains("apiKeyHelper failed") ||
                   line.contains("Invalid MCP configuration") ||
                   line.contains("OAuth") && line.contains("error") ||
                   line.contains("401") ||
                   line.contains("authentication") {
                    results[plugin] = String(line.prefix(100))
                }
            }
        }

        return results
    }

    // MARK: - Budget override

    /// Set a temporary budget override for today only.
    /// Writes state/budget-override.json with today's date. Shell scripts check this file
    /// and use its cap if the date matches. Automatically ignored on the next day.
    /// Does NOT modify config/bonny.json.
    func setTemporaryBudgetOverride(newCap: Double) -> Double? {
        let overridePath = fullPath("state/budget-override.json")
        let today = Self.todayDateString()
        let override = BudgetOverrideJSON(date: today, cap: newCap)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(override) else { return nil }

        do {
            try data.write(to: URL(fileURLWithPath: overridePath))
            return newCap
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
