import Foundation

enum L10nKey {
    case appTitle
    case dashboardTitle
    case dashboardSummary
    case refreshNow
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
    case menuQuit
    case menuLaunchAtLoginEnabled
    case menuLaunchAtLoginDisabled
    case menuAPIKeys
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
    case panelOverview
    case panelSettings
    case searchPlaceholder
    case filterAll
    case filterIssues
    case filterQuota
    case metricEnabledServices
    case metricIssues
    case metricQuotaSignals
    case metricLastCheck
    case metricProbes
    case noEnabledServices
    case noMatchingServices
    case noRecentFailures
    case servicesSection
    case servicesSectionHint
    case serviceEnabled
    case serviceDisabled
    case serviceEnabledStatus
    case serviceDisabledStatus
    case quotaMonitoring
    case quotaHeaderSource
    case quotaHeaderDetail
    case quotaTokenSource
    case quotaTokenDetail
    case quotaUsageSource
    case quotaUsageDetail
    case quotaCodexLocalSource
    case quotaCodexLocalHint
    case quotaCodexLocalFallbackHint
    case quotaCodexWaitingSummary
    case quotaCodexWaitingHint
    case quotaCodexUnavailableSummary
    case quotaCodexSignedOutSummary
    case quotaCodexSignedOutHint
    case quotaAwaitingSignal
    case quotaAwaitingSignalDetail
    case quotaUnsupported
    case quotaUnsupportedDetail
    case quotaRateLimited
    case quotaRateLimitedDetail
    case quotaRemainingPrefix
    case quotaResetPrefix
    case quotaTag
    case quotaInputShort
    case quotaOutputShort
    case quotaTotalShort
    case quotaCachedShort
    case quotaPlanPrefix
    case quotaCreditsPrefix
    case quotaOpenAIAdminSummary
    case quotaOpenAIAdminHint
    case quotaAnthropicAdminSummary
    case quotaAnthropicAdminHint
    case quotaAnthropicAdminRequiredSummary
    case quotaAnthropicAdminRequiredHint
    case spendMonitoring
    case spendTag
    case spendUnsupported
    case spendUnsupportedDetail
    case spendOpenAIAdminSummary
    case spendOpenAIAdminHint
    case spendAdminRequiredSummary
    case spendNoDataSummary
    case spendOpenAIWindowHint
    case spendCodexLocalHint
    case spendWindow5h
    case spendWindow1d
    case spendWindow7d
    case spendWindow30d
    case spendWindowAll
    case customServicesSection
    case customServicesHint
    case addCustomService
    case removeCustomService
    case customServiceName
    case customServiceWebURL
    case customServiceAPIURL
    case customServiceGroup
    case customServiceAuth
    case customServiceUntitled
    case customAuthNone
    case customAuthBearer
    case notificationsSection
    case notificationsHint
    case notificationsEnabled
    case notificationsOnRecovery
    case notificationsOnQuota
    case historyTitle
    case quickPanelTopIssues
    case quickPanelRecentHealth
    case quickPanelNoIssues
    case notificationRecovered
    case notificationWarning
    case notificationFailed
    case notificationQuotaTitleSuffix
    case apiKeyConfigured
    case apiKeyMissing
    case manageAPIKey
    case clearSavedAPIKey
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
        case .dashboardSummary: return "Reachability, API health, quota signals, and future billing visibility for your AI stack."
        case .refreshNow: return "Refresh Now"
        case .waitingFirstProbe: return "Waiting for the first probe cycle."
        case .endpoints: return "Endpoints"
        case .appSignInURL: return "App Sign-in URL"
        case .codexWebURL: return "Codex Web URL"
        case .apiURL: return "API URL"
        case .saveEndpointSettings: return "Save Endpoint Settings"
        case .endpointHint: return "Leave a field empty to fall back to the default OpenAI endpoint."
        case .proxyTest: return "Proxy"
        case .useProxy: return "Use HTTP/HTTPS proxy for all probes"
        case .proxyHost: return "Proxy Host"
        case .proxyPort: return "Proxy Port"
        case .saveProxySettings: return "Save Proxy Settings"
        case .testProxyNow: return "Test Proxy Now"
        case .proxyHint: return "Applied to every probe through URLSession proxy configuration."
        case .startup: return "Launch at Login"
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        case .startupHint: return "Manual launch-at-login is managed through a user LaunchAgent."
        case .enableLaunchAtLogin: return "Enable Launch at Login"
        case .disableLaunchAtLogin: return "Disable Launch at Login"
        case .startupRestrictionHint: return "This only works after launching the packaged .app bundle, not `swift run`."
        case .footerHint: return "API keys are stored in Keychain. Endpoints and proxy settings are stored in UserDefaults."
        case .menuOpenDashboard: return "Open Panel"
        case .menuRefreshNow: return "Refresh Now"
        case .menuQuit: return "Quit"
        case .menuLaunchAtLoginEnabled: return "Launch at Login: Enabled"
        case .menuLaunchAtLoginDisabled: return "Launch at Login: Disabled"
        case .menuAPIKeys: return "API Keys"
        case .menuChecking: return "Checking"
        case .menuHealthy: return "Healthy"
        case .menuDegraded: return "Degraded"
        case .menuBlocked: return "Blocked"
        case .statusOK: return "OK"
        case .statusWarn: return "WARN"
        case .statusFail: return "FAIL"
        case .summaryChecking: return "Checking enabled AI services..."
        case .summaryHealthy: return "Enabled services look reachable from this network."
        case .summaryDegraded: return "Some enabled services are degraded or partially unavailable."
        case .summaryBlocked: return "The current network looks blocked for the enabled services."
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
        case .panelOverview: return "Overview"
        case .panelSettings: return "Settings"
        case .searchPlaceholder: return "Search services, failures, quota..."
        case .filterAll: return "All"
        case .filterIssues: return "Issues"
        case .filterQuota: return "Quota"
        case .metricEnabledServices: return "Enabled Services"
        case .metricIssues: return "Issues"
        case .metricQuotaSignals: return "Quota Signals"
        case .metricLastCheck: return "Last Check"
        case .metricProbes: return "probes"
        case .noEnabledServices: return "All services are disabled. Re-enable them in Settings."
        case .noMatchingServices: return "No services match the current search or quick filter."
        case .noRecentFailures: return "No recent failures recorded."
        case .servicesSection: return "Services"
        case .servicesSectionHint: return "Turn individual services on or off without affecting the others."
        case .serviceEnabled: return "Enabled"
        case .serviceDisabled: return "Disabled"
        case .serviceEnabledStatus: return "Service enabled."
        case .serviceDisabledStatus: return "Service disabled."
        case .quotaMonitoring: return "Quota & Balance"
        case .quotaHeaderSource: return "Header quota"
        case .quotaHeaderDetail: return "Derived from provider rate-limit response headers."
        case .quotaTokenSource: return "Token quota"
        case .quotaTokenDetail: return "Derived from provider token rate-limit headers."
        case .quotaUsageSource: return "Usage"
        case .quotaUsageDetail: return "Derived from the provider's API response body."
        case .quotaCodexLocalSource: return "Local Codex"
        case .quotaCodexLocalHint: return "Read from the local `codex app-server` without spending tokens."
        case .quotaCodexLocalFallbackHint: return "Recovered from local Codex session logs when the app-server is unavailable."
        case .quotaCodexWaitingSummary: return "Waiting for local Codex account"
        case .quotaCodexWaitingHint: return "AI OpsBar will read Codex plan and rate limits from the local app-server."
        case .quotaCodexUnavailableSummary: return "Local Codex data unavailable"
        case .quotaCodexSignedOutSummary: return "Codex account not signed in"
        case .quotaCodexSignedOutHint: return "The local Codex app-server is reachable, but no active ChatGPT/Codex account was returned."
        case .quotaAwaitingSignal: return "No live quota header yet"
        case .quotaAwaitingSignalDetail: return "The provider supports header-based quota signals, but this response did not expose one."
        case .quotaUnsupported: return "No public quota endpoint"
        case .quotaUnsupportedDetail: return "This service currently exposes reachability only in AI OpsBar."
        case .quotaRateLimited: return "Rate limited"
        case .quotaRateLimitedDetail: return "The provider returned HTTP 429 during the latest API probe."
        case .quotaRemainingPrefix: return "Remaining"
        case .quotaResetPrefix: return "Reset"
        case .quotaTag: return "Quota"
        case .quotaInputShort: return "in"
        case .quotaOutputShort: return "out"
        case .quotaTotalShort: return "total"
        case .quotaCachedShort: return "cached"
        case .quotaPlanPrefix: return "Plan"
        case .quotaCreditsPrefix: return "Credits"
        case .quotaOpenAIAdminSummary: return "Usage API available"
        case .quotaOpenAIAdminHint: return "OpenAI exposes organization usage endpoints, but this key may still need usage-reader or admin permission."
        case .quotaAnthropicAdminSummary: return "Admin usage API available"
        case .quotaAnthropicAdminHint: return "Anthropic usage reports require an admin API key and organization-level access."
        case .quotaAnthropicAdminRequiredSummary: return "Admin key required"
        case .quotaAnthropicAdminRequiredHint: return "Anthropic usage reports require an `sk-ant-admin...` key."
        case .spendMonitoring: return "Spend & Usage"
        case .spendTag: return "Usage"
        case .spendUnsupported: return "No public spend signal"
        case .spendUnsupportedDetail: return "This service does not expose a supported billing or cost endpoint in AI OpsBar yet."
        case .spendOpenAIAdminSummary: return "OpenAI cost API available"
        case .spendOpenAIAdminHint: return "Uses the saved OpenAI key to read organization costs. Admin or usage-reader access is typically required, and 5h is prorated from daily buckets."
        case .spendAdminRequiredSummary: return "Admin key required"
        case .spendNoDataSummary: return "No spend data yet"
        case .spendOpenAIWindowHint: return "Spend is aggregated from OpenAI organization cost buckets. The 5h window is estimated from overlapping daily buckets."
        case .spendCodexLocalHint: return "Derived from local Codex session logs. Your machine currently exposes token usage, not USD cost, so AI OpsBar shows token windows like CodexBar."
        case .spendWindow5h: return "5h"
        case .spendWindow1d: return "1d"
        case .spendWindow7d: return "7d"
        case .spendWindow30d: return "30d"
        case .spendWindowAll: return "All"
        case .customServicesSection: return "Custom Services"
        case .customServicesHint: return "Add your own web or API checks. API keys for bearer auth are stored in Keychain."
        case .addCustomService: return "Add Custom Service"
        case .removeCustomService: return "Remove"
        case .customServiceName: return "Display Name"
        case .customServiceWebURL: return "Web URL"
        case .customServiceAPIURL: return "API URL"
        case .customServiceGroup: return "Group"
        case .customServiceAuth: return "API Auth"
        case .customServiceUntitled: return "Custom Service"
        case .customAuthNone: return "No Auth"
        case .customAuthBearer: return "Bearer Token"
        case .notificationsSection: return "Notifications"
        case .notificationsHint: return "macOS notifications for outages, recoveries, and low quota signals."
        case .notificationsEnabled: return "Enable notifications"
        case .notificationsOnRecovery: return "Notify when a service recovers"
        case .notificationsOnQuota: return "Notify on low quota or rate limiting"
        case .historyTitle: return "Recent Health"
        case .quickPanelTopIssues: return "Top Issues"
        case .quickPanelRecentHealth: return "Recent Health"
        case .quickPanelNoIssues: return "No active issues across enabled services."
        case .notificationRecovered: return "recovered"
        case .notificationWarning: return "needs attention"
        case .notificationFailed: return "is unavailable"
        case .notificationQuotaTitleSuffix: return "quota warning"
        case .apiKeyConfigured: return "API Key configured"
        case .apiKeyMissing: return "No API Key saved"
        case .manageAPIKey: return "Set API Key"
        case .clearSavedAPIKey: return "Clear API Key"
        }
    }

    private static func chinese(_ key: L10nKey) -> String {
        switch key {
        case .appTitle: return "AI OpsBar"
        case .dashboardTitle: return "AI OpsBar"
        case .dashboardSummary: return "一个把连通性、API 可用性、配额信号和后续账单监控收进菜单栏的 AI 运维浮层。"
        case .refreshNow: return "立即刷新"
        case .waitingFirstProbe: return "等待首次探测结果。"
        case .endpoints: return "检测地址"
        case .appSignInURL: return "App 登录地址"
        case .codexWebURL: return "Codex 网页地址"
        case .apiURL: return "API 地址"
        case .saveEndpointSettings: return "保存检测地址"
        case .endpointHint: return "留空时将回退到默认的 OpenAI 地址。"
        case .proxyTest: return "代理"
        case .useProxy: return "所有探测都使用 HTTP/HTTPS 代理"
        case .proxyHost: return "代理主机"
        case .proxyPort: return "代理端口"
        case .saveProxySettings: return "保存代理设置"
        case .testProxyNow: return "立即测试代理"
        case .proxyHint: return "会通过 URLSession 代理配置应用到全部探测。"
        case .startup: return "开机启动"
        case .enabled: return "已开启"
        case .disabled: return "已关闭"
        case .startupHint: return "手动开机启动通过用户级 LaunchAgent 管理。"
        case .enableLaunchAtLogin: return "开启开机启动"
        case .disableLaunchAtLogin: return "关闭开机启动"
        case .startupRestrictionHint: return "只有运行打包后的 .app 时才可用，`swift run` 下不可用。"
        case .footerHint: return "API Key 存储在 Keychain，检测地址和代理设置存储在 UserDefaults。"
        case .menuOpenDashboard: return "打开浮层"
        case .menuRefreshNow: return "立即刷新"
        case .menuQuit: return "退出"
        case .menuLaunchAtLoginEnabled: return "开机启动：已开启"
        case .menuLaunchAtLoginDisabled: return "开机启动：已关闭"
        case .menuAPIKeys: return "API Keys"
        case .menuChecking: return "检测中"
        case .menuHealthy: return "正常"
        case .menuDegraded: return "部分异常"
        case .menuBlocked: return "阻断"
        case .statusOK: return "正常"
        case .statusWarn: return "警告"
        case .statusFail: return "失败"
        case .summaryChecking: return "正在检测已启用的 AI 服务..."
        case .summaryHealthy: return "已启用服务在当前网络下看起来都可访问。"
        case .summaryDegraded: return "部分已启用服务处于降级或部分不可用状态。"
        case .summaryBlocked: return "当前网络对已启用服务看起来存在阻断。"
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
        case .panelOverview: return "概览"
        case .panelSettings: return "设置"
        case .searchPlaceholder: return "搜索服务、失败原因、配额..."
        case .filterAll: return "全部"
        case .filterIssues: return "异常"
        case .filterQuota: return "配额"
        case .metricEnabledServices: return "已启用服务"
        case .metricIssues: return "异常项"
        case .metricQuotaSignals: return "配额信号"
        case .metricLastCheck: return "最近检测"
        case .metricProbes: return "探测"
        case .noEnabledServices: return "当前所有服务都已禁用，请到设置里重新开启。"
        case .noMatchingServices: return "没有服务匹配当前搜索或快速筛选。"
        case .noRecentFailures: return "最近没有失败记录。"
        case .servicesSection: return "服务开关"
        case .servicesSectionHint: return "可以按服务单独开启或关闭，不影响其他服务。"
        case .serviceEnabled: return "已开启"
        case .serviceDisabled: return "已关闭"
        case .serviceEnabledStatus: return "服务已开启。"
        case .serviceDisabledStatus: return "服务已关闭。"
        case .quotaMonitoring: return "额度 / 余额 / 配额"
        case .quotaHeaderSource: return "请求配额"
        case .quotaHeaderDetail: return "来自服务端返回的限流响应头。"
        case .quotaTokenSource: return "Token 配额"
        case .quotaTokenDetail: return "来自服务端返回的 Token 限流响应头。"
        case .quotaUsageSource: return "本次用量"
        case .quotaUsageDetail: return "来自 API 响应体里的 usage 字段。"
        case .quotaCodexLocalSource: return "本地 Codex"
        case .quotaCodexLocalHint: return "直接从本地 `codex app-server` 读取，不消耗对话额度。"
        case .quotaCodexLocalFallbackHint: return "当 app-server 暂时不可用时，从本地 Codex 会话日志恢复配额信息。"
        case .quotaCodexWaitingSummary: return "等待本地 Codex 账户信号"
        case .quotaCodexWaitingHint: return "AI OpsBar 会从本地 app-server 读取 Codex 套餐和限额状态。"
        case .quotaCodexUnavailableSummary: return "本地 Codex 数据暂不可用"
        case .quotaCodexSignedOutSummary: return "Codex 账户未登录"
        case .quotaCodexSignedOutHint: return "本地 Codex app-server 可访问，但没有返回有效的 ChatGPT / Codex 登录账户。"
        case .quotaAwaitingSignal: return "暂未看到实时配额头"
        case .quotaAwaitingSignalDetail: return "该服务支持响应头配额信号，但本次响应没有暴露可用字段。"
        case .quotaUnsupported: return "暂无公开配额接口"
        case .quotaUnsupportedDetail: return "AI OpsBar 当前只能显示该服务的连通性。"
        case .quotaRateLimited: return "已触发限流"
        case .quotaRateLimitedDetail: return "最近一次 API 探测返回了 HTTP 429。"
        case .quotaRemainingPrefix: return "剩余"
        case .quotaResetPrefix: return "重置"
        case .quotaTag: return "配额"
        case .quotaInputShort: return "输入"
        case .quotaOutputShort: return "输出"
        case .quotaTotalShort: return "总计"
        case .quotaCachedShort: return "缓存"
        case .quotaPlanPrefix: return "套餐"
        case .quotaCreditsPrefix: return "余额"
        case .quotaOpenAIAdminSummary: return "可尝试组织用量接口"
        case .quotaOpenAIAdminHint: return "OpenAI 提供组织级 usage 接口，但当前 key 可能还需要 usage-reader 或 admin 权限。"
        case .quotaAnthropicAdminSummary: return "可尝试 Admin 用量接口"
        case .quotaAnthropicAdminHint: return "Anthropic 的 usage report 需要 admin API key 和组织级权限。"
        case .quotaAnthropicAdminRequiredSummary: return "需要 Admin Key"
        case .quotaAnthropicAdminRequiredHint: return "Anthropic 的 usage report 需要 `sk-ant-admin...` 这类管理员密钥。"
        case .spendMonitoring: return "金额 / 用量"
        case .spendTag: return "用量"
        case .spendUnsupported: return "暂无公开金额接口"
        case .spendUnsupportedDetail: return "这个服务在 AI OpsBar 里暂时还没有可用的账单 / 成本接口。"
        case .spendOpenAIAdminSummary: return "可尝试 OpenAI 成本接口"
        case .spendOpenAIAdminHint: return "使用当前保存的 OpenAI Key 拉取组织级成本数据。通常需要 admin 或 usage-reader 权限，5 小时窗口会按天桶重叠比例估算。"
        case .spendAdminRequiredSummary: return "需要 Admin Key"
        case .spendNoDataSummary: return "暂未看到金额数据"
        case .spendOpenAIWindowHint: return "金额来自 OpenAI 组织级 cost bucket 聚合。5 小时窗口会根据按天 bucket 的重叠比例估算。"
        case .spendCodexLocalHint: return "来自本地 Codex 会话日志。你这台机器当前暴露的是 token 用量而不是 USD 成本，所以 AI OpsBar 会像 CodexBar 一样显示各时间窗口的 token。"
        case .spendWindow5h: return "5小时"
        case .spendWindow1d: return "1天"
        case .spendWindow7d: return "7天"
        case .spendWindow30d: return "1个月"
        case .spendWindowAll: return "全部"
        case .customServicesSection: return "自定义服务"
        case .customServicesHint: return "可添加你自己的网页或 API 检测项。Bearer 类型 API Key 会保存在 Keychain。"
        case .addCustomService: return "新增自定义服务"
        case .removeCustomService: return "删除"
        case .customServiceName: return "显示名称"
        case .customServiceWebURL: return "网页地址"
        case .customServiceAPIURL: return "API 地址"
        case .customServiceGroup: return "分组"
        case .customServiceAuth: return "API 认证"
        case .customServiceUntitled: return "自定义服务"
        case .customAuthNone: return "无需认证"
        case .customAuthBearer: return "Bearer Token"
        case .notificationsSection: return "通知"
        case .notificationsHint: return "为故障、恢复和低配额信号发送 macOS 通知。"
        case .notificationsEnabled: return "启用通知"
        case .notificationsOnRecovery: return "服务恢复时通知"
        case .notificationsOnQuota: return "低配额或限流时通知"
        case .historyTitle: return "最近健康状态"
        case .quickPanelTopIssues: return "当前重点异常"
        case .quickPanelRecentHealth: return "最近健康状态"
        case .quickPanelNoIssues: return "当前已启用服务没有活动异常。"
        case .notificationRecovered: return "已恢复"
        case .notificationWarning: return "需要关注"
        case .notificationFailed: return "不可用"
        case .notificationQuotaTitleSuffix: return "配额告警"
        case .apiKeyConfigured: return "已配置 API Key"
        case .apiKeyMissing: return "未保存 API Key"
        case .manageAPIKey: return "设置 API Key"
        case .clearSavedAPIKey: return "清除 API Key"
        }
    }
}
