import Foundation

enum LaunchAgentError: LocalizedError {
    case appBundleRequired
    case executableMissing
    case launchctlFailed(String)

    var errorDescription: String? {
        switch self {
        case .appBundleRequired:
            return "Launch at login is only available when running from a packaged .app bundle."
        case .executableMissing:
            return "The app executable could not be located inside the bundle."
        case .launchctlFailed(let message):
            return message
        }
    }
}

struct LaunchAgentManager {
    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(AppConfig.launchAgentLabel).plist")
    }

    func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }

    private func enable() throws {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            throw LaunchAgentError.appBundleRequired
        }

        guard let executableURL = Bundle.main.executableURL else {
            throw LaunchAgentError.executableMissing
        }

        let launchAgentsDirectory = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": AppConfig.launchAgentLabel,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
            "KeepAlive": false,
            "WorkingDirectory": executableURL.deletingLastPathComponent().path,
            "ProcessType": "Interactive",
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)

        _ = try runLaunchctl(arguments: ["bootout", "gui/\(getuid())", plistURL.path], allowFailure: true)
        _ = try runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", plistURL.path], allowFailure: false)
    }

    private func disable() throws {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            _ = try runLaunchctl(arguments: ["bootout", "gui/\(getuid())", plistURL.path], allowFailure: true)
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    @discardableResult
    private func runLaunchctl(arguments: [String], allowFailure: Bool) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let message = [output.trimmingCharacters(in: .whitespacesAndNewlines), error.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if process.terminationStatus != 0, !allowFailure {
            throw LaunchAgentError.launchctlFailed(message.isEmpty ? "launchctl returned exit code \(process.terminationStatus)." : message)
        }

        return message
    }
}
