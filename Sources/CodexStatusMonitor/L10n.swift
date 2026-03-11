import Foundation

enum L10nKey {
    case appTitle
    case dashboardTitle
    case dashboardSummary
    case dashboardStatusMessage
    case refreshNow
    case refreshing
    case liveStatus
    case onlyShowIssues
    case allVisibleServicesHealthy
    case recentFailureSummary
    case noRecentFailures
    case waitingFirstProbe
    case endpoints
    case appSignInURL
    case codexWebURL
    case apiURL
    case saveEndpointSettings
    case endpointHint
    case proxyTest
    case useProxy
    case proxyHost
    case proxyPort
    case saveProxySettings
    case testProxyNow
    case proxyHint
    case startup
    case enabled
    case disabled
    case startupHint
    case enableLaunchAtLogin
    case disableLaunchAtLogin
    case startupRestrictionHint
    case footerHint
    case menuOpenDashboard
    case menuRefreshNow
    case menuSetAPIKey
    case menuClearAPIKey
    case menuQuit
    case menuLaunchAtLoginEnabled
    case menuLaunchAtLoginDisabled
    case menuChecking
    case menuHealthy
    case menuDegraded
    case menuBlocked
    case statusOK
    case statusWarn
    case statusFail
    case summaryChecking
    case summaryHealthy
    case summaryDegraded
    case summaryBlocked
    case probeAppTitle
    case probeWebTitle
    case probeAPITitle
    case detailReachable
    case detailAPIAuthenticated
    case detailAPIReachableNoKey
    case detailAPIKeyRejected
    case detailAPIRateLimited
    case detailInvalidURL
    case detailInvalidProxy
    case detailUnexpectedHTTPPrefix
    case errorNoInternet
    case errorTimedOut
    case errorDNSLookupFailed
    case errorConnectionRefused
    case errorConnectionLost
    case errorTLSHandshakeFailed
    case saveSettingsDone
    case refreshStatusPrefix
    case refreshingStatus
    case launchEnabledStatus
    case launchDisabledStatus
    case apiKeySaved
    case apiKeyRemoved
    case waitingFirstProbeMenu
    case languageSection
    case languageFollowSystem
    case languageEnglish
    case languageChinese
    case saveLanguage
    case apiKeyDialogTitle
    case apiKeyDialogMessage
    case save
    case cancel
    case apiKeyPlaceholder
    case apiKeyReplacePlaceholder
    case apiKeyNotSaved
    case emptyField
    case failedSaveAPIKey
    case failedClearAPIKey
    case ok
    case groupCoding
    case groupGeneral
    case groupChina
    case groupAgents
}

enum L10n {
    static func text(_ key: L10nKey) -> String {
        switch resolvedLanguage(from: SettingsStore.load().language) {
        case .system:
            return english(key)
        case .english:
            return english(key)
        case .simplifiedChinese:
            return chinese(key)
        }
    }

    static func resolvedLanguage(from configured: AppLanguage) -> AppLanguage {
        switch configured {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""

            if preferred.hasPrefix("zh-hans") || preferred.hasPrefix("zh-cn") || preferred.hasPrefix("zh-sg") || preferred.hasPrefix("zh") {
                return .simplifiedChinese
            }

            return .english
        case .english, .simplifiedChinese:
            return configured
        }
    }

    private static func english(_ key: L10nKey) -> String {
        switch key {
        case .appTitle: return "AI OpsBar"
        case .dashboardTitle: return "AI OpsBar"
        case .dashboardSummary: return "Unified menu bar operations for AI service reachability, API health, and future quota monitoring."
        case .dashboardStatusMessage: return "Current Status"
        case .refreshNow: return "Refresh Now"
        case .refreshing: return "Refreshing..."
        case .liveStatus: return "Live Status"
        case .onlyShowIssues: return "Only Show Issues"
        case .allVisibleServicesHealthy: return "No abnormal services are currently visible."
        case .recentFailureSummary: return "Recent Failure Summary"
        case .noRecentFailures: return "No recent failures recorded."
        case .waitingFirstProbe: return "Waiting for the first probe cycle."
        case .endpoints: return "Endpoints"
        case .appSignInURL: return "App Sign-in URL"
        case .codexWebURL: return "Codex Web URL"
        case .apiURL: return "API URL"
        case .saveEndpointSettings: return "Save Endpoint Settings"
        case .endpointHint: return "Leave a field empty to fall back to the default OpenAI endpoint."
        case .proxyTest: return "Proxy Test"
        case .useProxy: return "Use HTTP/HTTPS proxy for all probes"
        case .proxyHost: return "Proxy Host"
        case .proxyPort: return "Proxy Port"
        case .saveProxySettings: return "Save Proxy Settings"
        case .testProxyNow: return "Test Proxy Now"
        case .proxyHint: return "The proxy settings are applied to all three probes through URLSession proxy configuration."
        case .startup: return "Startup"
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        case .startupHint: return "Manual launch-at-login is managed through a user LaunchAgent."
        case .enableLaunchAtLogin: return "Enable Launch at Login"
        case .disableLaunchAtLogin: return "Disable Launch at Login"
        case .startupRestrictionHint: return "This only works after launching the packaged .app bundle, not `swift run`."
        case .footerHint: return "API keys are stored in Keychain. Endpoint and proxy preferences are stored in UserDefaults."
        case .menuOpenDashboard: return "Open Dashboard"
        case .menuRefreshNow: return "Refresh Now"
        case .menuSetAPIKey: return "Set API Key..."
        case .menuClearAPIKey: return "Clear Stored API Key"
        case .menuQuit: return "Quit"
        case .menuLaunchAtLoginEnabled: return "Launch at Login: Enabled"
        case .menuLaunchAtLoginDisabled: return "Launch at Login: Disabled"
        case .menuChecking: return "Cx ..."
        case .menuHealthy: return "Cx OK"
        case .menuDegraded: return "Cx DEG"
        case .menuBlocked: return "Cx ERR"
        case .statusOK: return "OK"
        case .statusWarn: return "WARN"
        case .statusFail: return "FAIL"
        case .summaryChecking: return "Checking Codex connectivity..."
        case .summaryHealthy: return "Codex web and API look reachable."
        case .summaryDegraded: return "Codex is partially reachable. Check the failing surface."
        case .summaryBlocked: return "Codex looks blocked from this network."
        case .probeAppTitle: return "Codex App Sign-in"
        case .probeWebTitle: return "Codex Web"
        case .probeAPITitle: return "OpenAI API"
        case .detailReachable: return "Reachable"
        case .detailAPIAuthenticated: return "Authenticated API access is working"
        case .detailAPIReachableNoKey: return "Network path is reachable, but no API key is configured"
        case .detailAPIKeyRejected: return "API key was rejected"
        case .detailAPIRateLimited: return "API is reachable but rate-limited"
        case .detailInvalidURL: return "Invalid URL"
        case .detailInvalidProxy: return "Invalid proxy configuration. Check host and port."
        case .detailUnexpectedHTTPPrefix: return "Unexpected HTTP status"
        case .errorNoInternet: return "No internet connection"
        case .errorTimedOut: return "Timed out"
        case .errorDNSLookupFailed: return "DNS lookup failed"
        case .errorConnectionRefused: return "Connection refused"
        case .errorConnectionLost: return "Connection lost"
        case .errorTLSHandshakeFailed: return "TLS handshake failed"
        case .saveSettingsDone: return "Settings saved."
        case .refreshStatusPrefix: return "Last updated at"
        case .refreshingStatus: return "Refreshing probe results..."
        case .launchEnabledStatus: return "Launch at login enabled."
        case .launchDisabledStatus: return "Launch at login disabled."
        case .apiKeySaved: return "API key saved to Keychain."
        case .apiKeyRemoved: return "Stored API key removed."
        case .waitingFirstProbeMenu: return "Waiting for first probe result..."
        case .languageSection: return "Language"
        case .languageFollowSystem: return "Follow System"
        case .languageEnglish: return "English"
        case .languageChinese: return "简体中文"
        case .saveLanguage: return "Save Language"
        case .apiKeyDialogTitle: return "Set OpenAI API Key"
        case .apiKeyDialogMessage: return "The key is stored in your macOS Keychain and is used only to verify API access."
        case .save: return "Save"
        case .cancel: return "Cancel"
        case .apiKeyPlaceholder: return "sk-..."
        case .apiKeyReplacePlaceholder: return "Replace existing key"
        case .apiKeyNotSaved: return "API key not saved"
        case .emptyField: return "The field was empty."
        case .failedSaveAPIKey: return "Failed to save API key"
        case .failedClearAPIKey: return "Failed to clear API key"
        case .ok: return "OK"
        case .groupCoding: return "Coding Tools"
        case .groupGeneral: return "Global AI"
        case .groupChina: return "China Models"
        case .groupAgents: return "Agents & Automation"
        }
    }

    private static func chinese(_ key: L10nKey) -> String {
        switch key {
        case .appTitle: return "AI OpsBar"
        case .dashboardTitle: return "AI OpsBar"
        case .dashboardSummary: return "统一管理 AI 服务连通性、API 可用性，以及后续额度监控的菜单栏工具。"
        case .dashboardStatusMessage: return "当前状态"
        case .refreshNow: return "立即刷新"
        case .refreshing: return "刷新中..."
        case .liveStatus: return "实时状态"
        case .onlyShowIssues: return "仅显示异常项"
        case .allVisibleServicesHealthy: return "当前可见服务中没有异常项。"
        case .recentFailureSummary: return "最近一次失败原因摘要"
        case .noRecentFailures: return "最近没有失败记录。"
        case .waitingFirstProbe: return "等待首次探测结果。"
        case .endpoints: return "检测地址"
        case .appSignInURL: return "App 登录地址"
        case .codexWebURL: return "Codex 网页地址"
        case .apiURL: return "API 地址"
        case .saveEndpointSettings: return "保存检测地址"
        case .endpointHint: return "留空时将回退到默认的 OpenAI 地址。"
        case .proxyTest: return "代理测试"
        case .useProxy: return "所有探测都使用 HTTP/HTTPS 代理"
        case .proxyHost: return "代理主机"
        case .proxyPort: return "代理端口"
        case .saveProxySettings: return "保存代理设置"
        case .testProxyNow: return "立即测试代理"
        case .proxyHint: return "代理设置会通过 URLSession 代理配置应用到全部三路探测。"
        case .startup: return "开机启动"
        case .enabled: return "已开启"
        case .disabled: return "已关闭"
        case .startupHint: return "手动开机启动通过用户级 LaunchAgent 管理。"
        case .enableLaunchAtLogin: return "开启开机启动"
        case .disableLaunchAtLogin: return "关闭开机启动"
        case .startupRestrictionHint: return "只有运行打包后的 .app 时才可用，`swift run` 下不可用。"
        case .footerHint: return "API Key 存储在 Keychain，检测地址和代理设置存储在 UserDefaults。"
        case .menuOpenDashboard: return "打开面板"
        case .menuRefreshNow: return "立即刷新"
        case .menuSetAPIKey: return "设置 API Key..."
        case .menuClearAPIKey: return "清除已保存的 API Key"
        case .menuQuit: return "退出"
        case .menuLaunchAtLoginEnabled: return "开机启动：已开启"
        case .menuLaunchAtLoginDisabled: return "开机启动：已关闭"
        case .menuChecking: return "Cx 检测中"
        case .menuHealthy: return "Cx 正常"
        case .menuDegraded: return "Cx 异常"
        case .menuBlocked: return "Cx 失败"
        case .statusOK: return "正常"
        case .statusWarn: return "警告"
        case .statusFail: return "失败"
        case .summaryChecking: return "正在检测 Codex 连通性..."
        case .summaryHealthy: return "Codex 网页端和 API 当前可访问。"
        case .summaryDegraded: return "Codex 部分可达，请检查失败的检测项。"
        case .summaryBlocked: return "当前网络下 Codex 看起来被阻断。"
        case .probeAppTitle: return "Codex App 登录"
        case .probeWebTitle: return "Codex 网页端"
        case .probeAPITitle: return "OpenAI API"
        case .detailReachable: return "可访问"
        case .detailAPIAuthenticated: return "API 鉴权访问正常"
        case .detailAPIReachableNoKey: return "网络路径可达，但还没有配置 API Key"
        case .detailAPIKeyRejected: return "API Key 被拒绝"
        case .detailAPIRateLimited: return "API 可达，但触发了限流"
        case .detailInvalidURL: return "URL 无效"
        case .detailInvalidProxy: return "代理配置无效，请检查主机和端口。"
        case .detailUnexpectedHTTPPrefix: return "异常的 HTTP 状态码"
        case .errorNoInternet: return "当前没有网络连接"
        case .errorTimedOut: return "请求超时"
        case .errorDNSLookupFailed: return "DNS 解析失败"
        case .errorConnectionRefused: return "连接被拒绝"
        case .errorConnectionLost: return "连接中断"
        case .errorTLSHandshakeFailed: return "TLS 握手失败"
        case .saveSettingsDone: return "设置已保存。"
        case .refreshStatusPrefix: return "最近刷新时间"
        case .refreshingStatus: return "正在刷新探测结果..."
        case .launchEnabledStatus: return "已开启开机启动。"
        case .launchDisabledStatus: return "已关闭开机启动。"
        case .apiKeySaved: return "API Key 已保存到 Keychain。"
        case .apiKeyRemoved: return "已移除保存的 API Key。"
        case .waitingFirstProbeMenu: return "等待首次检测结果..."
        case .languageSection: return "语言"
        case .languageFollowSystem: return "跟随系统"
        case .languageEnglish: return "English"
        case .languageChinese: return "简体中文"
        case .saveLanguage: return "保存语言"
        case .apiKeyDialogTitle: return "设置 OpenAI API Key"
        case .apiKeyDialogMessage: return "该 Key 会保存到 macOS Keychain，仅用于验证 API 是否可用。"
        case .save: return "保存"
        case .cancel: return "取消"
        case .apiKeyPlaceholder: return "sk-..."
        case .apiKeyReplacePlaceholder: return "替换现有 Key"
        case .apiKeyNotSaved: return "未保存 API Key"
        case .emptyField: return "输入内容为空。"
        case .failedSaveAPIKey: return "保存 API Key 失败"
        case .failedClearAPIKey: return "清除 API Key 失败"
        case .ok: return "确定"
        case .groupCoding: return "编程工具"
        case .groupGeneral: return "国际 AI"
        case .groupChina: return "国产模型"
        case .groupAgents: return "代理与自动化"
        }
    }
}
