import Foundation

enum ServiceGroup: String, CaseIterable, Identifiable {
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

enum ServiceID: String {
    case codex
    case gemini
    case claude
    case cursor
    case antigravity
    case droid
    case copilot
    case zai
    case minimax
    case deepseek
}

enum ProbeAuthType {
    case bearer
    case anthropic
    case googleAPIKey
    case basicUsername
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
    let webLabel: String
    let webURLString: String
    let apiProbe: ServiceAPIProbe?
}

enum ServiceDefinitions {
    static func group(for serviceName: String) -> ServiceGroup {
        if serviceName == "Codex" {
            return .coding
        }

        return all.first(where: { $0.name == serviceName })?.group ?? .general
    }

    static let all: [ServiceDefinition] = [
        ServiceDefinition(
            id: .gemini,
            name: "Gemini",
            group: .general,
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
            )
        ),
        ServiceDefinition(
            id: .claude,
            name: "Claude",
            group: .general,
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
            )
        ),
        ServiceDefinition(
            id: .cursor,
            name: "Cursor",
            group: .coding,
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
            )
        ),
        ServiceDefinition(
            id: .antigravity,
            name: "AntiGravity",
            group: .agents,
            webLabel: "Web",
            webURLString: "https://antigravity.com/",
            apiProbe: nil
        ),
        ServiceDefinition(
            id: .droid,
            name: "Droid",
            group: .agents,
            webLabel: "Web",
            webURLString: "https://docs.droidrun.ai/",
            apiProbe: nil
        ),
        ServiceDefinition(
            id: .copilot,
            name: "GitHub Copilot",
            group: .coding,
            webLabel: "Web",
            webURLString: "https://github.com/features/copilot",
            apiProbe: nil
        ),
        ServiceDefinition(
            id: .zai,
            name: "Z.ai",
            group: .china,
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
            )
        ),
        ServiceDefinition(
            id: .minimax,
            name: "MiniMax",
            group: .china,
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
            )
        ),
        ServiceDefinition(
            id: .deepseek,
            name: "DeepSeek",
            group: .china,
            webLabel: "Web",
            webURLString: "https://chat.deepseek.com/",
            apiProbe: ServiceAPIProbe(
                label: "API",
                urlString: "https://api.deepseek.com/models",
                method: "GET",
                keychainAccount: "deepseek_api_key",
                authType: .bearer,
                headers: [:],
                body: nil
            )
        ),
    ]
}
