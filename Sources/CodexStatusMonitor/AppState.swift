import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var settings = SettingsStore.load()
    @Published var snapshot = MonitorSnapshot.checking()
    @Published var isRefreshing = false
    @Published var launchAtLoginEnabled = false
    @Published var statusMessage = ""
    @Published var showOnlyIssues = false

    private let probeService = CodexProbeService()
    private let launchAgentManager = LaunchAgentManager()
    private var refreshTimer: Timer?
    private var isDashboardVisible = false
    private var lastFailureSummaries: [String: String] = [:]

    init() {
        launchAtLoginEnabled = launchAgentManager.isEnabled()
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

        Task {
            let latestSnapshot = await probeService.runAllChecks(settings: currentSettings)

            await MainActor.run {
                self.snapshot = latestSnapshot
                self.updateLastFailureSummaries(with: latestSnapshot.results)
                self.isRefreshing = false
                self.statusMessage = "\(L10n.text(.refreshStatusPrefix)) \(Self.timeString(from: latestSnapshot.checkedAt))."
                self.scheduleRefreshTimer()
            }
        }
    }

    func saveSettings() {
        SettingsStore.save(settings)
        statusMessage = L10n.text(.saveSettingsDone)
        refreshNow()
    }

    func setDashboardVisible(_ visible: Bool) {
        guard isDashboardVisible != visible else {
            return
        }

        isDashboardVisible = visible
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
        if isDashboardVisible {
            return AppConfig.visibleRefreshInterval
        }

        switch snapshot.overallState {
        case .checking, .degraded, .blocked:
            return AppConfig.degradedRefreshInterval
        case .healthy:
            return AppConfig.idleRefreshInterval
        }
    }

    func groupedServiceSummaries() -> [(group: ServiceGroup, services: [ServiceStatusSummary])] {
        let groupedResults = Dictionary(grouping: snapshot.results, by: \.serviceName)
        var groupedSummaries: [ServiceGroup: [ServiceStatusSummary]] = [:]

        for (serviceName, probes) in groupedResults {
            let sortedProbes = probes.sorted {
                if $0.kind == $1.kind {
                    return $0.probeLabel < $1.probeLabel
                }

                return probeSortIndex($0.kind) < probeSortIndex($1.kind)
            }

            let overallState: ProbeState
            if sortedProbes.contains(where: { $0.state == .fail }) {
                overallState = .fail
            } else if sortedProbes.contains(where: { $0.state == .warning }) {
                overallState = .warning
            } else {
                overallState = .pass
            }

            let failureSummary = lastFailureSummaries[serviceName] ?? L10n.text(.noRecentFailures)
            let summary = ServiceStatusSummary(
                serviceName: serviceName,
                group: ServiceDefinitions.group(for: serviceName),
                overallState: overallState,
                probes: sortedProbes,
                lastFailureSummary: failureSummary
            )

            if !showOnlyIssues || overallState != .pass {
                groupedSummaries[summary.group, default: []].append(summary)
            }
        }

        return ServiceGroup.allCases.compactMap { group in
            guard let services = groupedSummaries[group]?.sorted(by: { $0.serviceName < $1.serviceName }), !services.isEmpty else {
                return nil
            }

            return (group: group, services: services)
        }
    }

    private func updateLastFailureSummaries(with results: [ProbeResult]) {
        let grouped = Dictionary(grouping: results, by: \.serviceName)

        for (serviceName, probes) in grouped {
            let problems = probes.filter { $0.state != .pass }
            guard !problems.isEmpty else {
                continue
            }

            let summary = problems
                .prefix(2)
                .map { "\($0.probeLabel): \($0.detail)" }
                .joined(separator: " | ")
            lastFailureSummaries[serviceName] = summary
        }
    }

    private func probeSortIndex(_ kind: ProbeKind) -> Int {
        switch kind {
        case .app:
            return 0
        case .web:
            return 1
        case .api:
            return 2
        }
    }

    private static func timeString(from date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
    }
}
