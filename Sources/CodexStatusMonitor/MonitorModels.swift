import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: Self { self }

    var displayName: String {
        switch self {
        case .system:
            return "Follow System"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}

enum ProbeKind: CaseIterable, Identifiable {
    case app
    case web
    case api

    var id: Self { self }

    var title: String {
        switch self {
        case .app:
            return "App"
        case .web:
            return "Web"
        case .api:
            return "API"
        }
    }

    var defaultURL: URL {
        switch self {
        case .app:
            return AppConfig.appSignInURL
        case .web:
            return AppConfig.codexWebURL
        case .api:
            return AppConfig.apiURL
        }
    }
}

enum ProbeState: String, Codable {
    case pass
    case warning
    case fail

    var label: String {
        switch self {
        case .pass:
            return L10n.text(.statusOK)
        case .warning:
            return L10n.text(.statusWarn)
        case .fail:
            return L10n.text(.statusFail)
        }
    }
}

struct ProbeResult: Identifiable {
    let id = UUID()
    let serviceName: String
    let probeLabel: String
    let kind: ProbeKind
    let requestedURL: String
    let state: ProbeState
    let detail: String
    let statusCode: Int?
    let latencyMs: Int?
    let checkedAt: Date

    var menuTitle: String {
        var segments = ["\(serviceName) \(probeLabel): \(state.label)"]

        if let statusCode {
            segments.append("HTTP \(statusCode)")
        }

        if let latencyMs {
            segments.append("\(latencyMs) ms")
        }

        return segments.joined(separator: " | ")
    }
}

enum OverallState {
    case checking
    case healthy
    case degraded
    case blocked

    var menuBarTitle: String {
        switch self {
        case .checking:
            return L10n.text(.menuChecking)
        case .healthy:
            return L10n.text(.menuHealthy)
        case .degraded:
            return L10n.text(.menuDegraded)
        case .blocked:
            return L10n.text(.menuBlocked)
        }
    }

    var summary: String {
        switch self {
        case .checking:
            return L10n.text(.summaryChecking)
        case .healthy:
            return L10n.text(.summaryHealthy)
        case .degraded:
            return L10n.text(.summaryDegraded)
        case .blocked:
            return L10n.text(.summaryBlocked)
        }
    }
}

struct MonitorSnapshot {
    let results: [ProbeResult]
    let checkedAt: Date
    let overallState: OverallState

    static func checking() -> MonitorSnapshot {
        MonitorSnapshot(results: [], checkedAt: Date(), overallState: .checking)
    }
}

struct ServiceStatusSummary: Identifiable {
    let serviceName: String
    let group: ServiceGroup
    let overallState: ProbeState
    let probes: [ProbeResult]
    let lastFailureSummary: String

    var id: String { serviceName }
    var issueCount: Int { probes.filter { $0.state != .pass }.count }
}

struct MonitorSettings: Codable {
    var appURLString: String = AppConfig.appSignInURL.absoluteString
    var webURLString: String = AppConfig.codexWebURL.absoluteString
    var apiURLString: String = AppConfig.apiURL.absoluteString
    var language: AppLanguage = .system
    var proxyEnabled = false
    var proxyHost = ""
    var proxyPort = "7890"

    func configuredURLString(for kind: ProbeKind) -> String {
        let rawValue: String

        switch kind {
        case .app:
            rawValue = appURLString
        case .web:
            rawValue = webURLString
        case .api:
            rawValue = apiURLString
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.defaultURL.absoluteString : trimmed
    }

    func resolvedURL(for kind: ProbeKind) -> URL? {
        URL(string: configuredURLString(for: kind))
    }

    var proxyPortValue: Int? {
        Int(proxyPort.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
