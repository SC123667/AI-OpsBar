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

enum ServiceQuickFilter: String, CaseIterable, Identifiable {
    case all
    case issues
    case quota
    case coding
    case general
    case china
    case agents

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return L10n.text(.filterAll)
        case .issues:
            return L10n.text(.filterIssues)
        case .quota:
            return L10n.text(.filterQuota)
        case .coding:
            return L10n.text(.groupCoding)
        case .general:
            return L10n.text(.groupGeneral)
        case .china:
            return L10n.text(.groupChina)
        case .agents:
            return L10n.text(.groupAgents)
        }
    }
}

enum ProbeKind: CaseIterable, Identifiable {
    case app
    case web
    case api

    var id: Self { self }

    var sortIndex: Int {
        switch self {
        case .app:
            return 0
        case .web:
            return 1
        case .api:
            return 2
        }
    }

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

enum SpendWindow: String, CaseIterable, Codable, Identifiable {
    case fiveHours
    case oneDay
    case sevenDays
    case thirtyDays
    case all

    var id: Self { self }

    var title: String {
        switch self {
        case .fiveHours:
            return L10n.text(.spendWindow5h)
        case .oneDay:
            return L10n.text(.spendWindow1d)
        case .sevenDays:
            return L10n.text(.spendWindow7d)
        case .thirtyDays:
            return L10n.text(.spendWindow30d)
        case .all:
            return L10n.text(.spendWindowAll)
        }
    }
}

struct QuotaSnapshot: Codable {
    let label: String
    let remaining: Int?
    let limit: Int?
    let resetAt: Date?
    let detail: String
    let summaryText: String?

    var compactText: String {
        if let summaryText, !summaryText.isEmpty {
            return summaryText
        }

        var parts: [String] = []

        if let remaining, let limit {
            parts.append("\(remaining)/\(limit)")
        } else if let remaining {
            parts.append("\(L10n.text(.quotaRemainingPrefix)) \(remaining)")
        } else if let limit {
            parts.append("limit \(limit)")
        }

        if let resetAt {
            parts.append("\(L10n.text(.quotaResetPrefix)) \(DateFormatter.localizedString(from: resetAt, dateStyle: .none, timeStyle: .short))")
        }

        return parts.isEmpty ? detail : parts.joined(separator: " · ")
    }
}

struct SpendSnapshot: Codable {
    let label: String
    let currencyCode: String
    let amounts: [String: Double]
    let tokenCounts: [String: Int]
    let detail: String
    let summaryText: String?
    let isEstimated: Bool

    init(
        label: String,
        currencyCode: String,
        amounts: [String: Double],
        tokenCounts: [String: Int] = [:],
        detail: String,
        summaryText: String?,
        isEstimated: Bool
    ) {
        self.label = label
        self.currencyCode = currencyCode
        self.amounts = amounts
        self.tokenCounts = tokenCounts
        self.detail = detail
        self.summaryText = summaryText
        self.isEstimated = isEstimated
    }

    func amount(for window: SpendWindow) -> Double? {
        amounts[window.rawValue]
    }

    func tokenCount(for window: SpendWindow) -> Int? {
        tokenCounts[window.rawValue]
    }

    var availableWindows: [SpendWindow] {
        SpendWindow.allCases.filter { amount(for: $0) != nil || tokenCount(for: $0) != nil }
    }

    var hasWindowBreakdown: Bool {
        !availableWindows.isEmpty
    }

    func formattedValue(for window: SpendWindow) -> String? {
        if let amount = amount(for: window) {
            return formattedAmount(amount, for: window)
        }

        if let tokens = tokenCount(for: window) {
            return Self.formattedTokens(tokens)
        }

        return nil
    }

    var compactText: String {
        if hasWindowBreakdown {
            return availableWindows.compactMap { window in
                guard let value = formattedValue(for: window) else {
                    return nil
                }

                return "\(window.title) \(value)"
            }.joined(separator: " · ")
        }

        if let summaryText, !summaryText.isEmpty {
            return summaryText
        }

        return SpendWindow.allCases.map { window in
            "\(window.title) \(formattedValue(for: window) ?? "--")"
        }.joined(separator: " · ")
    }

    private func formattedAmount(_ amount: Double, for window: SpendWindow) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        let rendered = formatter.string(from: NSNumber(value: amount))
            ?? "\(currencyCode) \(String(format: "%.2f", amount))"

        if isEstimated && window == .fiveHours {
            return "~\(rendered)"
        }

        return rendered
    }

    private static func formattedTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM tok", Double(tokens) / 1_000_000)
        }

        if tokens >= 1_000 {
            return String(format: "%.1fK tok", Double(tokens) / 1_000)
        }

        return "\(tokens) tok"
    }
}

struct ProbeResult: Identifiable {
    let id = UUID()
    let serviceID: ServiceID
    let serviceName: String
    let probeLabel: String
    let kind: ProbeKind
    let requestedURL: String
    let state: ProbeState
    let detail: String
    let statusCode: Int?
    let latencyMs: Int?
    let checkedAt: Date
    let quota: QuotaSnapshot?
    let spend: SpendSnapshot?

    var menuTitle: String {
        var segments = ["\(serviceName) \(probeLabel): \(state.label)"]

        if let statusCode {
            segments.append("HTTP \(statusCode)")
        }

        if let latencyMs {
            segments.append("\(latencyMs) ms")
        }

        if let quota {
            segments.append(quota.compactText)
        }

        if let spend {
            segments.append(spend.compactText)
        }

        return segments.joined(separator: " | ")
    }
}

enum CustomServiceAuthMode: String, Codable, CaseIterable, Identifiable {
    case none
    case bearer

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            return L10n.text(.customAuthNone)
        case .bearer:
            return L10n.text(.customAuthBearer)
        }
    }
}

struct CustomServiceDefinition: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String = ""
    var group: ServiceGroup = .general
    var webURLString: String = ""
    var apiURLString: String = ""
    var apiAuthMode: CustomServiceAuthMode = .none

    var serviceID: ServiceID {
        ServiceID(rawValue: "custom.\(id)")
    }

    var apiKeyAccount: String? {
        apiAuthMode == .none ? nil : "custom_api_key_\(id)"
    }

    var serviceDefinition: ServiceDefinition {
        ServiceDefinition(
            id: serviceID,
            name: trimmedName.isEmpty ? L10n.text(.customServiceUntitled) : trimmedName,
            group: group,
            isCustom: true,
            appLabel: nil,
            appURLString: nil,
            webLabel: "Web",
            webURLString: trimmedWebURL,
            apiProbe: trimmedAPIURL.isEmpty ? nil : ServiceAPIProbe(
                label: "API",
                urlString: trimmedAPIURL,
                method: "GET",
                keychainAccount: apiKeyAccount,
                authType: apiAuthMode == .bearer ? .bearer : nil,
                headers: [:],
                body: nil
            ),
            quotaSupport: trimmedAPIURL.isEmpty ? .none : .responseHeaders,
            spendSupport: .none
        )
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedWebURL: String {
        webURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAPIURL: String {
        apiURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isMeaningful: Bool {
        !trimmedName.isEmpty || !trimmedWebURL.isEmpty || !trimmedAPIURL.isEmpty
    }
}

struct ServiceHistorySample: Codable, Identifiable {
    let checkedAt: Date
    let state: ProbeState
    let issueCount: Int
    let latencyMs: Int?
    let quotaSummary: String

    var id: Date { checkedAt }
}

struct NotificationSettings: Codable {
    var enabled = true
    var notifyOnRecovery = true
    var notifyOnQuotaWarning = true
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
    let definition: ServiceDefinition
    let serviceID: ServiceID
    let serviceName: String
    let group: ServiceGroup
    let overallState: ProbeState
    let probes: [ProbeResult]
    let quotaSnapshot: QuotaSnapshot?
    let spendSnapshot: SpendSnapshot?
    let lastFailureSummary: String
    let quotaSummary: String
    let quotaDetail: String
    let spendSummary: String
    let spendDetail: String
    let hasQuotaSignal: Bool
    let hasSpendSignal: Bool
    let quotaSupported: Bool
    let spendSupported: Bool
    let primaryLatencyMs: Int?
    let recentHistory: [ServiceHistorySample]

    var id: String { serviceID.rawValue }
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
    var disabledServiceIDs: [String] = []
    var customServices: [CustomServiceDefinition] = []
    var notifications = NotificationSettings()

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

    func isServiceEnabled(_ id: ServiceID) -> Bool {
        !disabledServiceIDs.contains(id.rawValue)
    }

    mutating func setService(_ id: ServiceID, enabled: Bool) {
        if enabled {
            disabledServiceIDs.removeAll { $0 == id.rawValue }
        } else if !disabledServiceIDs.contains(id.rawValue) {
            disabledServiceIDs.append(id.rawValue)
        }
    }

    mutating func sanitizeCustomServices() {
        customServices = customServices
            .filter(\.isMeaningful)
            .map { service in
                var sanitized = service
                sanitized.name = service.trimmedName
                sanitized.webURLString = service.trimmedWebURL
                sanitized.apiURLString = service.trimmedAPIURL
                return sanitized
            }
    }
}
