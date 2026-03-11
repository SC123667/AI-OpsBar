import Foundation

enum AppConfig {
    static let idleRefreshInterval: TimeInterval = 120
    static let visibleRefreshInterval: TimeInterval = 20
    static let degradedRefreshInterval: TimeInterval = 45
    static let timerToleranceRatio: Double = 0.25
    static let requestTimeout: TimeInterval = 4
    static let userAgent = "AIOpsBar/0.5.0"
    static let bundleIdentifier = "com.sc123667.aiopsbar"
    static let keychainService = "com.sc123667.aiopsbar"
    static let keychainAccount = "openai_api_key"
    static let launchAgentLabel = "com.sc123667.aiopsbar.launch"
    static let settingsKey = "ai_opsbar.settings"
    static let historyKey = "ai_opsbar.history"
    static let historySampleLimit = 72

    static let appSignInURL = URL(string: "https://chatgpt.com")!
    static let codexWebURL = URL(string: "https://chatgpt.com/codex")!
    static let apiURL = URL(string: "https://api.openai.com/v1/models")!
}
