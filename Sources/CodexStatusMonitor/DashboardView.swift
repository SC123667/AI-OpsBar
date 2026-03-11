import SwiftUI

private enum PanelTab: String, CaseIterable, Identifiable {
    case overview
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .overview:
            return L10n.text(.panelOverview)
        case .settings:
            return L10n.text(.panelSettings)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var appState: AppState
    @State private var expandedServices = Set<ServiceID>()
    @State private var selectedTab: PanelTab = .overview

    private let metricColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            tabSection

            Group {
                if selectedTab == .overview {
                    overviewSection
                } else {
                    settingsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 460, height: 760)
        .background(panelBackground)
        .onAppear {
            syncExpandedServices()
        }
        .onChange(of: appState.snapshot.checkedAt) { _ in
            syncExpandedServices()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text(.dashboardTitle))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(appState.snapshot.overallState.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button(action: appState.refreshNow) {
                    Group {
                        if appState.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .help(L10n.text(.refreshNow))
            }

            HStack(spacing: 8) {
                StatusPill(text: appState.snapshot.overallState.menuBarTitle, color: stateColor(appState.snapshot.overallState))
                Text(appState.statusMessage.isEmpty ? L10n.text(.waitingFirstProbe) : appState.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 0.98),
                    Color(red: 0.92, green: 0.96, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .padding(16)
        .padding(.bottom, 6)
    }

    private var tabSection: some View {
        Picker("", selection: $selectedTab) {
            ForEach(PanelTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var overviewSection: some View {
        VStack(spacing: 12) {
            searchRow
            filterRow
            metricsGrid
            serviceGroupsScroll
        }
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(L10n.text(.searchPlaceholder), text: $appState.searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ServiceQuickFilter.allCases) { filter in
                    Button(action: { appState.selectedFilter = filter }) {
                        FilterChipView(title: filter.title, isSelected: appState.selectedFilter == filter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: metricColumns, spacing: 10) {
            MetricTile(title: L10n.text(.metricEnabledServices), value: "\(appState.enabledServiceCount)", tint: Color(red: 0.11, green: 0.52, blue: 0.58))
            MetricTile(title: L10n.text(.metricIssues), value: "\(appState.issueServiceCount)", tint: .orange)
            MetricTile(title: L10n.text(.metricQuotaSignals), value: "\(appState.quotaSignalCount)", tint: .blue)
            MetricTile(
                title: L10n.text(.metricLastCheck),
                value: DateFormatter.localizedString(from: appState.snapshot.checkedAt, dateStyle: .none, timeStyle: .short),
                tint: .gray
            )
        }
    }

    private var serviceGroupsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                let groups = appState.displayedGroupedServiceSummaries()

                if appState.snapshot.results.isEmpty {
                    emptyState(L10n.text(.waitingFirstProbe))
                } else if appState.enabledServiceCount == 0 {
                    emptyState(L10n.text(.noEnabledServices))
                } else if groups.isEmpty {
                    emptyState(L10n.text(.noMatchingServices))
                } else {
                    ForEach(groups, id: \.group) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(group.group.title)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(group.services.count)")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(group.services) { summary in
                                ServiceCardView(
                                    summary: summary,
                                    isExpanded: expandedServices.contains(summary.serviceID)
                                ) {
                                    toggleExpanded(summary.serviceID)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var settingsSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                settingsCard(title: L10n.text(.servicesSection), subtitle: L10n.text(.servicesSectionHint)) {
                    VStack(spacing: 12) {
                        ForEach(appState.serviceDefinitionsByGroup(), id: \.group) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.group.title)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.secondary)

                                ForEach(group.services, id: \.id) { definition in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(definition.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text(appState.isServiceEnabled(definition.id) ? L10n.text(.serviceEnabled) : L10n.text(.serviceDisabled))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Toggle("", isOn: Binding(
                                            get: { appState.isServiceEnabled(definition.id) },
                                            set: { appState.setService(definition.id, enabled: $0) }
                                        ))
                                        .labelsHidden()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }

                settingsCard(title: L10n.text(.languageSection), subtitle: L10n.text(.dashboardSummary)) {
                    Picker("", selection: $appState.settings.language) {
                        Text(L10n.text(.languageFollowSystem)).tag(AppLanguage.system)
                        Text(L10n.text(.languageEnglish)).tag(AppLanguage.english)
                        Text(L10n.text(.languageChinese)).tag(AppLanguage.simplifiedChinese)
                    }
                    .pickerStyle(.segmented)

                    saveButton(L10n.text(.saveLanguage))
                }

                settingsCard(title: L10n.text(.endpoints), subtitle: L10n.text(.endpointHint)) {
                    labeledField(title: L10n.text(.appSignInURL), text: $appState.settings.appURLString)
                    labeledField(title: L10n.text(.codexWebURL), text: $appState.settings.webURLString)
                    labeledField(title: L10n.text(.apiURL), text: $appState.settings.apiURLString)
                    saveButton(L10n.text(.saveEndpointSettings))
                }

                settingsCard(title: L10n.text(.proxyTest), subtitle: L10n.text(.proxyHint)) {
                    Toggle(L10n.text(.useProxy), isOn: $appState.settings.proxyEnabled)

                    HStack(spacing: 10) {
                        labeledField(title: L10n.text(.proxyHost), text: $appState.settings.proxyHost)
                        labeledField(title: L10n.text(.proxyPort), text: $appState.settings.proxyPort)
                    }

                    HStack(spacing: 8) {
                        saveButton(L10n.text(.saveProxySettings))
                        secondaryButton(L10n.text(.testProxyNow), action: appState.saveSettings)
                    }
                }

                settingsCard(title: L10n.text(.startup), subtitle: L10n.text(.startupHint)) {
                    HStack {
                        StatusPill(
                            text: appState.launchAtLoginEnabled ? L10n.text(.enabled) : L10n.text(.disabled),
                            color: appState.launchAtLoginEnabled ? .green : .gray
                        )
                        Text(L10n.text(.startupRestrictionHint))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    secondaryButton(
                        appState.launchAtLoginEnabled ? L10n.text(.disableLaunchAtLogin) : L10n.text(.enableLaunchAtLogin),
                        action: { appState.setLaunchAtLoginEnabled(!appState.launchAtLoginEnabled) }
                    )
                }

                settingsCard(title: L10n.text(.notificationsSection), subtitle: L10n.text(.notificationsHint)) {
                    Toggle(L10n.text(.notificationsEnabled), isOn: $appState.settings.notifications.enabled)
                    Toggle(L10n.text(.notificationsOnRecovery), isOn: $appState.settings.notifications.notifyOnRecovery)
                    Toggle(L10n.text(.notificationsOnQuota), isOn: $appState.settings.notifications.notifyOnQuotaWarning)
                    saveButton(L10n.text(.saveSettingsDone))
                }

                settingsCard(title: L10n.text(.customServicesSection), subtitle: L10n.text(.customServicesHint)) {
                    VStack(spacing: 12) {
                        if appState.settings.customServices.isEmpty {
                            Text(L10n.text(.customServicesHint))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach($appState.settings.customServices) { $service in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(service.trimmedName.isEmpty ? L10n.text(.customServiceUntitled) : service.trimmedName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    secondaryButton(L10n.text(.removeCustomService)) {
                                        appState.removeCustomService(service)
                                    }
                                }

                                labeledField(title: L10n.text(.customServiceName), text: $service.name)

                                Picker(L10n.text(.customServiceGroup), selection: $service.group) {
                                    ForEach(ServiceGroup.allCases) { group in
                                        Text(group.title).tag(group)
                                    }
                                }
                                .pickerStyle(.segmented)

                                labeledField(title: L10n.text(.customServiceWebURL), text: $service.webURLString)
                                labeledField(title: L10n.text(.customServiceAPIURL), text: $service.apiURLString)

                                Picker(L10n.text(.customServiceAuth), selection: $service.apiAuthMode) {
                                    ForEach(CustomServiceAuthMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if !service.trimmedAPIURL.isEmpty {
                                    let definition = service.serviceDefinition
                                    HStack(spacing: 8) {
                                        MiniTag(
                                            text: appState.hasAPIKey(for: definition) ? L10n.text(.apiKeyConfigured) : L10n.text(.apiKeyMissing),
                                            tint: appState.hasAPIKey(for: definition) ? .green : .gray
                                        )
                                        Spacer()
                                        secondaryButton(L10n.text(.manageAPIKey)) {
                                            appState.promptForAPIKey(for: definition)
                                        }
                                        secondaryButton(L10n.text(.clearSavedAPIKey)) {
                                            appState.clearAPIKey(for: definition)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        HStack(spacing: 8) {
                            secondaryButton(L10n.text(.addCustomService), action: appState.addCustomService)
                            saveButton(L10n.text(.saveSettingsDone))
                        }
                    }
                }

                Text(L10n.text(.footerHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func labeledField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func saveButton(_ title: String) -> some View {
        Button(title, action: appState.saveSettings)
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.regular)
    }

    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.person.crop")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func toggleExpanded(_ serviceID: ServiceID) {
        if expandedServices.contains(serviceID) {
            expandedServices.remove(serviceID)
        } else {
            expandedServices.insert(serviceID)
        }
    }

    private func syncExpandedServices() {
        for group in appState.displayedGroupedServiceSummaries() {
            for summary in group.services where summary.issueCount > 0 {
                expandedServices.insert(summary.serviceID)
            }
        }
    }

    private func stateColor(_ state: OverallState) -> Color {
        switch state {
        case .checking:
            return .blue
        case .healthy:
            return .green
        case .degraded:
            return .orange
        case .blocked:
            return .red
        }
    }

    private var panelBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 0.98),
                    Color(red: 0.93, green: 0.96, blue: 0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.31, green: 0.79, blue: 0.70).opacity(0.10))
                .frame(width: 260, height: 260)
                .offset(x: 140, y: -220)

            Circle()
                .fill(Color(red: 0.18, green: 0.44, blue: 0.96).opacity(0.08))
                .frame(width: 220, height: 220)
                .offset(x: -140, y: 260)
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct FilterChipView: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(background, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(isSelected ? 0.0 : 0.08), lineWidth: 1)
            )
    }

    private var background: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.11, green: 0.52, blue: 0.58), Color(red: 0.17, green: 0.64, blue: 0.71)],
                startPoint: .leading,
                endPoint: .trailing
            ))
        } else {
            return AnyShapeStyle(Color.white.opacity(0.88))
        }
    }
}

private struct ServiceCardView: View {
    let summary: ServiceStatusSummary
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(summary.serviceName)
                                    .font(.headline)
                                if summary.hasQuotaSignal {
                                    MiniTag(text: L10n.text(.quotaTag), tint: .blue)
                                }
                                if summary.hasSpendSignal {
                                    MiniTag(text: L10n.text(.spendTag), tint: .green)
                                }
                            }

                            Text(summary.issueCount > 0 ? summary.lastFailureSummary : summary.quotaDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            StatusPill(text: summary.overallState.label, color: stateColor)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        MiniTag(text: "\(summary.probes.count) \(L10n.text(.metricProbes))", tint: .gray)
                        if summary.issueCount > 0 {
                            MiniTag(text: "\(summary.issueCount) \(L10n.text(.metricIssues))", tint: .orange)
                        }
                        if let latency = summary.primaryLatencyMs {
                            MiniTag(text: "\(latency) ms", tint: .teal)
                        }
                    }

                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "gauge.with.dots.needle.50percent")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.text(.quotaMonitoring))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(summary.quotaSummary)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                    }

                    if summary.spendSupported || summary.hasSpendSignal {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.text(.spendMonitoring))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                if let spend = summary.spendSnapshot, spend.hasWindowBreakdown {
                                    SpendBreakdownView(snapshot: spend, accent: .green, compact: true)
                                } else {
                                    Text(summary.spendSummary)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(3)
                                }
                            }
                        }
                    }

                    if !summary.recentHistory.isEmpty {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.text(.historyTitle))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                HistorySparkline(samples: summary.recentHistory, tint: stateColor)
                                    .frame(height: 18)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(summary.probes) { probe in
                        ProbeCompactRow(result: probe)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(stateColor.opacity(0.22), lineWidth: 1)
        )
    }

    private var stateColor: Color {
        switch summary.overallState {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        }
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [
                stateColor.opacity(0.11),
                Color.white.opacity(0.94),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ProbeCompactRow: View {
    let result: ProbeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                MiniTag(text: result.probeLabel, tint: tint)
                Text(result.state.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer()
                if let code = result.statusCode {
                    Text("HTTP \(code)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let latency = result.latencyMs {
                    Text("\(latency) ms")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Text(result.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let quota = result.quota {
                Text("\(quota.label): \(quota.compactText)")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            if let spend = result.spend {
                VStack(alignment: .leading, spacing: 6) {
                    Text(spend.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)

                    SpendBreakdownView(snapshot: spend, accent: .green, compact: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tint: Color {
        switch result.state {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        }
    }
}

private struct MiniTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.footnote.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}
