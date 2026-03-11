import AppKit
import Combine
import Foundation
import Security

@MainActor
final class AppState: ObservableObject {
    @Published var settings = SettingsStore.load()
    @Published var snapshot = MonitorSnapshot.checking()
    @Published var serviceSummaries: [ServiceStatusSummary] = []
    @Published var isRefreshing = false
    @Published var launchAtLoginEnabled = false
    @Published var statusMessage = ""
    @Published var searchText = ""
    @Published var selectedFilter: ServiceQuickFilter = .all
    @Published var serviceHistory = ServiceHistoryStore.load()

    private let probeService = CodexProbeService()
    private let launchAgentManager = LaunchAgentManager()
    private let notificationManager = MonitorNotificationManager()
    private var refreshTimer: Timer?
    private var isPanelVisible = false
    private var lastFailureSummaries: [String: String] = [:]
    private var lastQuotaNotificationTokens: [String: String] = [:]

    init() {
        settings.sanitizeCustomServices()
        launchAtLoginEnabled = launchAgentManager.isEnabled()
        notificationManager.requestAuthorizationIfNeeded(enabled: settings.notifications.enabled)
        scheduleRefreshTimer()
        refreshNow()
    }

    func refreshNow() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        statusMessage = L10n.text(.refreshingStatus)

        let currentSettings = settings
        let previousSummaries = serviceSummaries
        let probeService = self.probeService

        Task {
            let latestSnapshot = await probeService.runAllChecks(settings: currentSettings)

            await MainActor.run {
                self.updateLastFailureSummaries(with: latestSnapshot.results)

                var nextHistory = self.serviceHistory
                let initialSummaries = self.makeServiceSummaries(
                    snapshot: latestSnapshot,
                    settings: currentSettings,
                    history: nextHistory
                )
                ServiceHistoryStore.append(
                    summaries: initialSummaries,
                    checkedAt: latestSnapshot.checkedAt,
                    into: &nextHistory
                )

                let finalSummaries = self.makeServiceSummaries(
                    snapshot: latestSnapshot,
                    settings: currentSettings,
                    history: nextHistory
                )

                self.snapshot = latestSnapshot
                self.serviceHistory = nextHistory
                self.serviceSummaries = finalSummaries
                self.sendNotifications(previous: previousSummaries, current: finalSummaries, settings: currentSettings)
                self.isRefreshing = false
                self.statusMessage = "\(L10n.text(.refreshStatusPrefix)) \(Self.timeString(from: latestSnapshot.checkedAt))."
                ServiceHistoryStore.save(nextHistory)
                self.scheduleRefreshTimer()
            }
        }
    }

    func saveSettings() {
        settings.sanitizeCustomServices()
        SettingsStore.save(settings)
        notificationManager.requestAuthorizationIfNeeded(enabled: settings.notifications.enabled)
        statusMessage = L10n.text(.saveSettingsDone)
        refreshNow()
    }

    func addCustomService() {
        settings.customServices.append(CustomServiceDefinition())
    }

    func removeCustomService(_ customService: CustomServiceDefinition) {
        settings.customServices.removeAll { $0.id == customService.id }
        if let account = customService.apiKeyAccount {
            _ = KeychainHelper.deleteAPIKey(account: account)
        }
        serviceHistory.removeValue(forKey: customService.serviceID.rawValue)
        lastFailureSummaries.removeValue(forKey: customService.serviceID.rawValue)
        lastQuotaNotificationTokens.removeValue(forKey: customService.serviceID.rawValue)
    }

    func hasAPIKey(for definition: ServiceDefinition) -> Bool {
        guard let account = definition.apiProbe?.keychainAccount else {
            return false
        }

        return KeychainHelper.loadAPIKey(account: account) != nil
    }

    func promptForAPIKey(for definition: ServiceDefinition) {
        guard let account = definition.apiProbe?.keychainAccount else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "\(definition.name) API Key"
        alert.informativeText = L10n.text(.apiKeyDialogMessage)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.text(.save))
        alert.addButton(withTitle: L10n.text(.cancel))

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.placeholderString = hasAPIKey(for: definition) ? L10n.text(.apiKeyReplacePlaceholder) : L10n.text(.apiKeyPlaceholder)
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let value = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            statusMessage = L10n.text(.apiKeyNotSaved)
            return
        }

        let status = KeychainHelper.saveAPIKey(value, account: account)
        guard status == errSecSuccess else {
            statusMessage = "\(L10n.text(.failedSaveAPIKey)): \(status)"
            return
        }

        statusMessage = L10n.text(.apiKeySaved)
        refreshNow()
    }

    func clearAPIKey(for definition: ServiceDefinition) {
        guard let account = definition.apiProbe?.keychainAccount else {
            return
        }

        let status = KeychainHelper.deleteAPIKey(account: account)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            statusMessage = "\(L10n.text(.failedClearAPIKey)): \(status)"
            return
        }

        statusMessage = L10n.text(.apiKeyRemoved)
        refreshNow()
    }

    func setDashboardVisible(_ visible: Bool) {
        guard isPanelVisible != visible else {
            return
        }

        isPanelVisible = visible
        scheduleRefreshTimer()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try launchAgentManager.setEnabled(enabled)
            launchAtLoginEnabled = launchAgentManager.isEnabled()
            statusMessage = enabled ? L10n.text(.launchEnabledStatus) : L10n.text(.launchDisabledStatus)
        } catch {
            launchAtLoginEnabled = launchAgentManager.isEnabled()
            statusMessage = error.localizedDescription
        }
    }

    func displayedGroupedServiceSummaries() -> [(group: ServiceGroup, services: [ServiceStatusSummary])] {
        groupedSummaries(from: filteredServiceSummaries())
    }

    func menuGroupedServiceSummaries() -> [(group: ServiceGroup, services: [ServiceStatusSummary])] {
        groupedSummaries(from: serviceSummaries)
    }

    func topIssueSummaries(limit: Int) -> [ServiceStatusSummary] {
        serviceSummaries
            .filter { $0.issueCount > 0 }
            .sorted {
                if $0.issueCount == $1.issueCount {
                    return $0.serviceName < $1.serviceName
                }

                return $0.issueCount > $1.issueCount
            }
            .prefix(limit)
            .map { $0 }
    }

    func serviceDefinitionsByGroup() -> [(group: ServiceGroup, services: [ServiceDefinition])] {
        let definitions = ServiceDefinitions.all(settings: settings)
        return ServiceGroup.allCases.compactMap { group in
            let grouped = definitions.filter { $0.group == group }
            return grouped.isEmpty ? nil : (group, grouped)
        }
    }

    func definition(for serviceID: ServiceID) -> ServiceDefinition? {
        ServiceDefinitions.definition(for: serviceID, settings: settings)
    }

    func isServiceEnabled(_ id: ServiceID) -> Bool {
        settings.isServiceEnabled(id)
    }

    func setService(_ id: ServiceID, enabled: Bool) {
        settings.setService(id, enabled: enabled)
        SettingsStore.save(settings)
        statusMessage = enabled ? L10n.text(.serviceEnabledStatus) : L10n.text(.serviceDisabledStatus)
        refreshNow()
    }

    var enabledServiceCount: Int {
        ServiceDefinitions.all(settings: settings).filter { settings.isServiceEnabled($0.id) }.count
    }

    var issueServiceCount: Int {
        serviceSummaries.filter { $0.issueCount > 0 }.count
    }

    var quotaSignalCount: Int {
        serviceSummaries.filter(\.hasQuotaSignal).count
    }

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        let interval = currentRefreshInterval()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow()
            }
        }
        timer.tolerance = interval * AppConfig.timerToleranceRatio
        refreshTimer = timer
    }

    private func currentRefreshInterval() -> TimeInterval {
        if isPanelVisible {
            return AppConfig.visibleRefreshInterval
        }

        switch snapshot.overallState {
        case .checking, .degraded, .blocked:
            return AppConfig.degradedRefreshInterval
        case .healthy:
            return AppConfig.idleRefreshInterval
        }
    }

    private func filteredServiceSummaries() -> [ServiceStatusSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return serviceSummaries.filter { summary in
            guard matchesFilter(summary, filter: selectedFilter) else {
                return false
            }

            guard !query.isEmpty else {
                return true
            }

            let haystacks = [
                summary.serviceName.lowercased(),
                summary.group.title.lowercased(),
                summary.lastFailureSummary.lowercased(),
                summary.quotaSummary.lowercased(),
                summary.spendSummary.lowercased(),
                summary.spendDetail.lowercased(),
                summary.probes.map(\.detail).joined(separator: " ").lowercased(),
            ]

            return haystacks.contains { $0.contains(query) }
        }
    }

    private func makeServiceSummaries(
        snapshot: MonitorSnapshot,
        settings: MonitorSettings,
        history: [String: [ServiceHistorySample]]
    ) -> [ServiceStatusSummary] {
        let definitions = ServiceDefinitions.all(settings: settings)
        let resultsByService = Dictionary(grouping: snapshot.results, by: \.serviceID)

        return definitions.compactMap { definition in
            guard settings.isServiceEnabled(definition.id) else {
                return nil
            }

            let probes = (resultsByService[definition.id] ?? []).sorted {
                if $0.kind == $1.kind {
                    return $0.probeLabel < $1.probeLabel
                }

                return $0.kind.sortIndex < $1.kind.sortIndex
            }

            guard !probes.isEmpty else {
                return nil
            }

            let overallState: ProbeState
            if probes.contains(where: { $0.state == .fail }) {
                overallState = .fail
            } else if probes.contains(where: { $0.state == .warning }) {
                overallState = .warning
            } else {
                overallState = .pass
            }

            let quotaProbe = probes.first(where: { $0.kind == .api && $0.quota != nil })
            let quotaSnapshot = quotaProbe?.quota
            let quotaSummary: String
            let quotaDetail: String
            let hasQuotaSignal = quotaSnapshot != nil

            if let quota = quotaSnapshot {
                quotaSummary = quota.compactText
                quotaDetail = quota.detail
            } else if probes.contains(where: { $0.kind == .api && $0.statusCode == 429 }) {
                quotaSummary = L10n.text(.quotaRateLimited)
                quotaDetail = L10n.text(.quotaRateLimitedDetail)
            } else {
                switch definition.quotaSupport {
                case .codexAppServer:
                    quotaSummary = L10n.text(.quotaCodexWaitingSummary)
                    quotaDetail = L10n.text(.quotaCodexWaitingHint)
                case .responseHeaders:
                    quotaSummary = L10n.text(.quotaAwaitingSignal)
                    quotaDetail = L10n.text(.quotaAwaitingSignalDetail)
                case .responseBodyUsage:
                    quotaSummary = L10n.text(.quotaAwaitingSignal)
                    quotaDetail = L10n.text(.quotaUsageDetail)
                case .openAIUsageAPI:
                    quotaSummary = L10n.text(.quotaOpenAIAdminSummary)
                    quotaDetail = L10n.text(.quotaOpenAIAdminHint)
                case .anthropicUsageAPI:
                    quotaSummary = L10n.text(.quotaAnthropicAdminSummary)
                    quotaDetail = L10n.text(.quotaAnthropicAdminHint)
                case .consoleOnly, .none:
                    quotaSummary = L10n.text(.quotaUnsupported)
                    quotaDetail = L10n.text(.quotaUnsupportedDetail)
                }
            }

            let spendProbe = probes.first(where: { $0.kind == .api && $0.spend != nil })
            let spendSnapshot = spendProbe?.spend
            let spendSummary: String
            let spendDetail: String
            let hasSpendSignal = spendSnapshot != nil

            if let spend = spendSnapshot {
                spendSummary = spend.compactText
                spendDetail = spend.detail
            } else {
                switch definition.spendSupport {
                case .codexLocalLogs:
                    spendSummary = L10n.text(.spendNoDataSummary)
                    spendDetail = L10n.text(.spendCodexLocalHint)
                case .openAIOrganizationCosts:
                    spendSummary = L10n.text(.spendOpenAIAdminSummary)
                    spendDetail = L10n.text(.spendOpenAIAdminHint)
                case .none:
                    spendSummary = L10n.text(.spendUnsupported)
                    spendDetail = L10n.text(.spendUnsupportedDetail)
                }
            }

            return ServiceStatusSummary(
                definition: definition,
                serviceID: definition.id,
                serviceName: definition.name,
                group: definition.group,
                overallState: overallState,
                probes: probes,
                quotaSnapshot: quotaSnapshot,
                spendSnapshot: spendSnapshot,
                lastFailureSummary: lastFailureSummaries[definition.id.rawValue] ?? L10n.text(.noRecentFailures),
                quotaSummary: quotaSummary,
                quotaDetail: quotaDetail,
                spendSummary: spendSummary,
                spendDetail: spendDetail,
                hasQuotaSignal: hasQuotaSignal,
                hasSpendSignal: hasSpendSignal,
                quotaSupported: definition.quotaSupport != .none,
                spendSupported: definition.spendSupport != .none,
                primaryLatencyMs: probes.first(where: { $0.kind == .api })?.latencyMs ?? probes.first?.latencyMs,
                recentHistory: history[definition.id.rawValue] ?? []
            )
        }
    }

    private func groupedSummaries(from services: [ServiceStatusSummary]) -> [(group: ServiceGroup, services: [ServiceStatusSummary])] {
        let grouped = Dictionary(grouping: services, by: \.group)

        return ServiceGroup.allCases.compactMap { group in
            guard let services = grouped[group], !services.isEmpty else {
                return nil
            }

            return (group: group, services: services)
        }
    }

    private func matchesFilter(_ summary: ServiceStatusSummary, filter: ServiceQuickFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .issues:
            return summary.issueCount > 0
        case .quota:
            return summary.hasQuotaSignal || summary.quotaSupported
        case .coding:
            return summary.group == .coding
        case .general:
            return summary.group == .general
        case .china:
            return summary.group == .china
        case .agents:
            return summary.group == .agents
        }
    }

    private func updateLastFailureSummaries(with results: [ProbeResult]) {
        let grouped = Dictionary(grouping: results, by: \.serviceID)

        for (serviceID, probes) in grouped {
            let problems = probes.filter { $0.state != .pass }
            guard !problems.isEmpty else {
                continue
            }

            let summary = problems
                .prefix(2)
                .map { "\($0.probeLabel): \($0.detail)" }
                .joined(separator: " | ")
            lastFailureSummaries[serviceID.rawValue] = summary
        }
    }

    private func sendNotifications(
        previous: [ServiceStatusSummary],
        current: [ServiceStatusSummary],
        settings: MonitorSettings
    ) {
        notificationManager.requestAuthorizationIfNeeded(enabled: settings.notifications.enabled)

        let previousByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.serviceID.rawValue, $0) })
        for summary in current {
            let previousState = previousByID[summary.serviceID.rawValue]?.overallState
            let detail = summary.issueCount > 0 ? summary.lastFailureSummary : summary.quotaSummary
            notificationManager.notifyServiceTransition(
                serviceName: summary.serviceName,
                previous: previousState,
                current: summary.overallState,
                detail: detail,
                settings: settings.notifications
            )

            if let quota = summary.quotaSnapshot,
               shouldNotifyQuota(for: summary.serviceID, quota: quota) {
                notificationManager.notifyQuotaWarning(
                    serviceName: summary.serviceName,
                    quota: quota,
                    settings: settings.notifications
                )
                lastQuotaNotificationTokens[summary.serviceID.rawValue] = quota.compactText
            }
        }
    }

    private func shouldNotifyQuota(for serviceID: ServiceID, quota: QuotaSnapshot) -> Bool {
        let token = quota.compactText
        guard lastQuotaNotificationTokens[serviceID.rawValue] != token else {
            return false
        }

        if let remaining = quota.remaining, let limit = quota.limit, limit > 0 {
            return Double(remaining) / Double(limit) <= 0.10
        }

        return token.localizedCaseInsensitiveContains("rate") || token.localizedCaseInsensitiveContains("限流")
    }

    private static func timeString(from date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
    }
}
