import Foundation
import AppKit

struct ProcessRunner {
    let projectRoot: String

    /// Run an agent script in the background (non-blocking)
    func runAgent(_ agent: AgentDefinition) {
        let scriptPath = (projectRoot as NSString).appendingPathComponent(agent.scriptPath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        process.currentDirectoryURL = URL(fileURLWithPath: projectRoot)
        process.environment = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
            "HOME": NSHomeDirectory()
        ]
        // Detach output so we don't block
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            print("Failed to launch \(agent.displayName): \(error)")
        }
    }

    /// Open a file in the default editor
    func openInEditor(_ relativePath: String) {
        let fullPath = (projectRoot as NSString).appendingPathComponent(relativePath)
        let url = URL(fileURLWithPath: fullPath)
        NSWorkspace.shared.open(url)
    }

    /// Check auth status for a plugin by running a minimal headless probe.
    /// Returns "OK" if auth is valid, "FAIL" if stale, nil if check couldn't run.
    func checkPluginAuth(_ plugin: String) -> String? {
        let scriptPath = (projectRoot as NSString).appendingPathComponent("scripts/auth-check.sh")

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath, plugin, "--check"]
        process.currentDirectoryURL = URL(fileURLWithPath: projectRoot)
        process.environment = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
            "HOME": NSHomeDirectory()
        ]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if output.hasPrefix("OK:") { return "OK" }
        if output.hasPrefix("FAIL:") { return "FAIL" }
        return process.terminationStatus == 0 ? "OK" : "FAIL"
    }

    /// Re-auth a plugin by running auth-check.sh interactively in Terminal.
    /// This triggers Claude Code which will pop the browser OAuth flow.
    func reAuthPlugin(_ plugin: String) {
        let escapedRoot = projectRoot.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(escapedRoot)' && bash scripts/auth-check.sh \(plugin) --reauth"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    /// Open project folder in Finder
    func openProjectInFinder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: projectRoot))
    }
}
