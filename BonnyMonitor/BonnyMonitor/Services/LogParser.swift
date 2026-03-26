import Foundation

struct LogParser {
    let logDir: String

    /// Get the last N runs for an agent by scanning the logs/ directory
    func recentRuns(for agent: AgentDefinition, count: Int = 5) -> [AgentRun] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: logDir) else { return [] }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        dateFormatter.timeZone = TimeZone.current

        var runs: [AgentRun] = []

        for file in files {
            guard file.hasSuffix(".log") else { continue }

            // Skip stdout/stderr redirect logs
            if file.hasSuffix("-stdout.log") || file.hasSuffix("-stderr.log") ||
               file == "launchd-stdout.log" || file == "launchd-stderr.log" { continue }

            let prefix = agent.logPrefix
            if agent == .orchestrator {
                // Orchestrator logs have no prefix: just YYYY-MM-DD_HHMMSS.log
                // Skip files with any known prefix
                let knownPrefixes = AgentDefinition.allCases.compactMap { $0 == .orchestrator ? nil : $0.rawValue + "-" }
                if knownPrefixes.contains(where: { file.hasPrefix($0) }) { continue }

                let baseName = file.replacingOccurrences(of: ".log", with: "")
                guard let timestamp = dateFormatter.date(from: baseName) else { continue }

                let filePath = (logDir as NSString).appendingPathComponent(file)
                let duration = fileDuration(path: filePath, startTime: timestamp)
                let outcome = fileOutcome(path: filePath)

                runs.append(AgentRun(
                    agentId: agent.id,
                    timestamp: timestamp,
                    duration: duration,
                    outcome: outcome,
                    logFilePath: filePath
                ))
            } else {
                guard file.hasPrefix(prefix) else { continue }
                let baseName = file
                    .replacingOccurrences(of: prefix, with: "")
                    .replacingOccurrences(of: ".log", with: "")
                guard let timestamp = dateFormatter.date(from: baseName) else { continue }

                let filePath = (logDir as NSString).appendingPathComponent(file)
                let duration = fileDuration(path: filePath, startTime: timestamp)
                let outcome = fileOutcome(path: filePath)

                runs.append(AgentRun(
                    agentId: agent.id,
                    timestamp: timestamp,
                    duration: duration,
                    outcome: outcome,
                    logFilePath: filePath
                ))
            }
        }

        runs.sort { $0.timestamp > $1.timestamp }
        return Array(runs.prefix(count))
    }

    private func fileDuration(path: String, startTime: Date) -> TimeInterval? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attrs[.modificationDate] as? Date else { return nil }
        let duration = modDate.timeIntervalSince(startTime)
        return duration > 0 ? duration : nil
    }

    private func fileOutcome(path: String) -> AgentRun.Outcome {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return .unknown
        }

        // Check last 20 lines for exit status
        let lines = content.components(separatedBy: .newlines).suffix(20)
        for line in lines.reversed() {
            let lower = line.lowercased()
            if lower.contains("completed (exit code: 0)") || lower.contains("completed successfully") {
                return .success
            }
            if lower.contains("exit code:") && !lower.contains("exit code: 0") {
                return .error(String(line.prefix(80)))
            }
            if lower.contains("error") && (lower.contains("budget") || lower.contains("failed") || lower.contains("exit")) {
                return .error(String(line.prefix(80)))
            }
        }

        // If the file is non-empty and no explicit error, assume success
        if content.count > 50 {
            return .success
        }
        return .unknown
    }
}
