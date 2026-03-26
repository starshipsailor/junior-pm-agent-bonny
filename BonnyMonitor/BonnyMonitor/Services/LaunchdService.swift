import Foundation

struct LaunchdJob {
    let label: String
    let pid: Int?
    let lastExitStatus: Int?
}

struct LaunchdService {
    /// Parse `launchctl list` output to find all com.bonny.* jobs
    func listBonnyJobs() -> [String: LaunchdJob] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return [:]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        var jobs: [String: LaunchdJob] = [:]
        for line in output.components(separatedBy: .newlines) {
            guard line.contains("com.bonny.") else { continue }
            let parts = line.split(separator: "\t", maxSplits: 2)
            guard parts.count == 3 else { continue }

            let label = String(parts[2]).trimmingCharacters(in: .whitespaces)
            let pidStr = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let exitStr = String(parts[1]).trimmingCharacters(in: .whitespaces)

            let pid = pidStr == "-" ? nil : Int(pidStr)
            let exitStatus = Int(exitStr)

            jobs[label] = LaunchdJob(label: label, pid: pid, lastExitStatus: exitStatus)
        }
        return jobs
    }

    func isJobLoaded(label: String) -> Bool {
        listBonnyJobs()[label] != nil
    }

    func loadJob(label: String) {
        let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/\(label).plist"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    func unloadJob(label: String) {
        let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/\(label).plist"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
