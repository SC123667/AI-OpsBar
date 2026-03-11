import Foundation

enum ServiceGroup: String, CaseIterable, Identifiable, Codable {
    case coding
    case general
    case china
    case agents

    var id: Self { self }

    var title: String {
        switch self {
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

struct ServiceID: RawRepresentable, Codable, Hashable, Identifiable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    var id: String { rawValue }

    static let codex: ServiceID = "codex"
    static let gemini: ServiceID = "gemini"
    static let claude: ServiceID = "claude"
    static let cursor: ServiceID = "cursor"
    static let antigravity: ServiceID = "antigravity"
    static let droid: ServiceID = "droid"
    static let copilot: ServiceID = "copilot"
    static let zai: ServiceID = "zai"
    static let minimax: ServiceID = "minimax"
    static let deepseek: ServiceID = "deepseek"
}

enum ProbeAuthType {
    case bearer
    case anthropic
    case googleAPIKey
    case basicUsername
}

enum ServiceQuotaSupport {
    case none
    case responseHeaders
    case responseBodyUsage
    case codexAppServer
    case openAIUsageAPI
    case anthropicUsageAPI
    case consoleOnly
}

enum ServiceSpendSupport {
    case none
    case codexLocalLogs
    case openAIOrganizationCosts
}

struct ServiceAPIProbe {
    let label: String
    let urlString: String
    let method: String
    let keychainAccount: String?
    let authType: ProbeAuthType?
    let headers: [String: String]
    let body: Data?
}

struct ServiceDefinition {
    let id: ServiceID
    let name: String
    let group: ServiceGroup
    let isCustom: Bool
    let appLabel: String?
    let appURLString: String?
    let webLabel: String
    let webURLString: String
    let apiProbe: ServiceAPIProbe?
    let quotaSupport: ServiceQuotaSupport
    let spendSupport: ServiceSpendSupport
}

enum ServiceDefinitions {
    static func all(settings: MonitorSettings) -> [ServiceDefinition] {
        builtIn + settings.customServices.map(\.serviceDefinition)
    }

    static func definition(for id: ServiceID, settings: MonitorSettings) -> ServiceDefinition? {
        all(settings: settings).first(where: { $0.id == id })
    }

    static func definition(for serviceName: String, settings: MonitorSettings) -> ServiceDefinition? {
        all(settings: settings).first(where: { $0.name == serviceName })
    }

    static func group(for serviceName: String, settings: MonitorSettings) -> ServiceGroup {
        definition(for: serviceName, settings: settings)?.group ?? .general
    }

    static let builtIn: [ServiceDefinition] = [
        ServiceDefinition(
            id: .codex,
            name: "Codex",
            group: .coding,
            isCustom: false,
            appLabel: "App Sign-in",
            appURLString: AppConfig.appSignInURL.absoluteString,
            webLabel: "Web",
            webURLString: AppConfig.codexWebURL.absoluteString,
            apiProbe: ServiceAPIProbe(
                label: "API",
                urlString: AppConfig.apiURL.absoluteString,
                method: "GET",
                keychainAccount: AppConfig.keychainAccount,
                authType: .bearer,
                headers: [:],
                body: nil
            ),
            quotaSupport: .codexAppServer,
            spendSupport: .codexLocalLogs
        ),
        ServiceDefinition(
            id: .gemini,
            name: "Gemini",
            group: .general,
            isCustom: false,
            appLabel: nil,
            appURLString: nil,
            webLabel: "Web",
            webURLString: "https://gemini.google.com/",
            apiProbe: ServiceAPIProbe(
                label: "API",
                urlString: "https://generativelanguage.googleapis.com/v1beta/models",
                method: "GET",
                keychainAccount: "google_gemini_api_key",
                authType: .googleAPIKey,
                headers: [:],
                body: nil
            ),
            quotaSupport: .consoleOnly,
            spendSupport: .none
        ),
        ServiceDefinition(
            id: .claude,
            name: "Claude",
            group: .general,
            isCustom: false,
            appLabel: nil,
            appURLString: nil,
            webLabel: "Web",
            webURLString: "https://claude.ai/",
            apiProbe: ServiceAPIProbe(
                label: "API",
                urlString: "https://api.anthropic.com/v1/models",
                method: "GET",
                keychainAccount: "anthropic_api_key",
                authType: .anthropic,
                headers: [
                    "anthropic-version": "2023-06-01",
                ],
                body: nil
            ),
            quotaSupport: .anthropicUsageAPI,
            spendSupport: .none
        ),
        ServiceDefinition(
            id: .cursor,
            name: "Cursor",
            group: .coding,
            isCustom: false,
            appLabel: nil,
            appURLString: nil,
            webLabel: "Web",
            webURLString: "https://cursor.com/",
            apiProbe: ServiceAPIProbe(
                label: "API",
                urlString: "https://api.cursor.com/teams/members",
                method: "GET",
                keychainAccount: "cursor_api_key",
                authType: .basicUsername,
                headers: [:],
                body: nil
            ),
            quotaSupport: .none,
            spendSupport: .none
        ),
        ServiceDefinition(
            id: .antigravity,
            name: "AntiGravity",
            group: .agents,
            isCustom: false,
            appLabel: nil,
            appURLString: nil,
            webLabel: "Web",
            webURLString: "https://antigravity.com/",
            apiProbe: nil,
            quotaSupport: .none,
            spendSupport: .none
        ),
        ServiceDefinition(
            id: .droid,
            name: "Droid",
            group: .agents,
            isCustom: false,
            appLabel: nil,
            appURLString: nil,
            webLabel: "Web",
            webURLString: "https://docs.droidrun.ai/",
            apiProbe: nil,
            quotaSupport: .none,
            spendSupport: .none
        ),
        ServiceDefinition(
            id: .copilot,
            name: "GitHub Copilot",
            group: .coding,
            isCustom: false,
            appLabel: nil,
            appURLString: nil,
            webLabel: "Web",
            webURLString: "https://github.com/features/copilot",
            apiProbe: nil,
            quotaSupport: .none,
            spendSupport: .none
        ),
        ServiceDefinition(
            id: .zai,
            name: "Z.ai",
            group: .china,
            isCustom: false,
            appLabel: nil,
            appURLString: nil,
            webLabel: "Web",
            webURLString: "https://z.ai/",
            apiProbe: ServiceAPIProbe(
                label: "API",
                urlString: "https://api.z.ai/api/paas/v4/chat/completions",
                method: "POST",
                keychainAccount: "zai_api_key",
                authType: .bearer,
                headers: [:],
                body: Data("""
                {"model":"glm-4.5-air","messages":[{"role":"user","content":"ping"}],"max_tokens":1}
                """.utf8)
            ),
            quotaSupport: .responseBodyUsage,
            spendSupport: .none
        ),
        ServiceDefinition(
            id: .minimax,
            name: "MiniMax",
            group: .china,
            isCustom: false,
            appLabel: nil,
            appURLString: nil,
            webLabel: "Web",
            webURLString: "https://www.minimax.io/",
            apiProbe: ServiceAPIProbe(
                label: "API",
                urlString: "https://api.minimax.io/v1/text/chatcompletion_v2",
                method: "POST",
                keychainAccount: "minimax_api_key",
                authType: .bearer,
                headers: [:],
                body: Data("""
                {"model":"MiniMax-Text-01","messages":[{"role":"user","content":"ping"}],"max_tokens":1}
                """.utf8)
            ),
            quotaSupport: .responseBodyUsage,
            spendSupport: .none
        ),
        ServiceDefinition(
            id: .deepseek,
            name: "DeepSeek",
            group: .china,
            isCustom: false,
            appLabel: nil,
            appURLString: nil,
            webLabel: "Web",
            webURLString: "https://chat.deepseek.com/",
            apiProbe: ServiceAPIProbe(
                label: "API",
                urlString: "https://api.deepseek.com/chat/completions",
                method: "POST",
                keychainAccount: "deepseek_api_key",
                authType: .bearer,
                headers: [:],
                body: Data("""
                {"model":"deepseek-chat","messages":[{"role":"user","content":"ping"}],"max_tokens":1}
                """.utf8)
            ),
            quotaSupport: .responseBodyUsage,
            spendSupport: .none
        ),
    ]
}
