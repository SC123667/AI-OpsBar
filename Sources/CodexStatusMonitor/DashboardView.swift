import SwiftUI

struct DashboardView: View {
    @ObservedObject var appState: AppState
    @State private var expandedServices = Set<String>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                probesSection
                languageSection
                endpointsSection
                proxySection
                startupSection
                footerSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.98, blue: 1.0), Color(red: 0.92, green: 0.96, blue: 0.97)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(minWidth: 760, minHeight: 640)
        .onAppear {
            syncExpandedServices()
        }
        .onChange(of: appState.snapshot.checkedAt) { _ in
            syncExpandedServices()
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text(.dashboardTitle))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(appState.snapshot.overallState.summary)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(appState.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: appState.refreshNow) {
                if appState.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(L10n.text(.refreshNow))
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var probesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text(.liveStatus))
                    .font(.title2.weight(.bold))
                Spacer()
                Toggle(L10n.text(.onlyShowIssues), isOn: $appState.showOnlyIssues)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Text(L10n.text(.onlyShowIssues))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            let groups = appState.groupedServiceSummaries()

            if appState.snapshot.results.isEmpty {
                Text(L10n.text(.waitingFirstProbe))
                    .foregroundStyle(.secondary)
            } else if groups.isEmpty {
                Text(L10n.text(.allVisibleServicesHealthy))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups, id: \.group) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.group.title)
                            .font(.title3.weight(.bold))

                        ForEach(group.services) { summary in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedServices.contains(summary.id) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedServices.insert(summary.id)
                                        } else {
                                            expandedServices.remove(summary.id)
                                        }
                                    }
                                )
                            ) {
                                VStack(spacing: 10) {
                                    ForEach(summary.probes) { result in
                                        ProbeCardView(result: result)
                                    }
                                }
                                .padding(.top, 10)
                            } label: {
                                ServiceSummaryCard(summary: summary)
                            }
                            .padding(18)
                            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private func syncExpandedServices() {
        for group in appState.groupedServiceSummaries() {
            for summary in group.services where summary.overallState != .pass {
                expandedServices.insert(summary.id)
            }
        }
    }

    private var endpointsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text(.endpoints))
                .font(.title3.weight(.bold))

            labeledField(title: L10n.text(.appSignInURL), text: $appState.settings.appURLString)
            labeledField(title: L10n.text(.codexWebURL), text: $appState.settings.webURLString)
            labeledField(title: L10n.text(.apiURL), text: $appState.settings.apiURLString)

            HStack {
                Button(L10n.text(.saveEndpointSettings)) {
                    appState.saveSettings()
                }
                .buttonStyle(.borderedProminent)

                Text(L10n.text(.endpointHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var proxySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text(.proxyTest))
                .font(.title3.weight(.bold))

            Toggle(L10n.text(.useProxy), isOn: $appState.settings.proxyEnabled)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text(.proxyHost))
                        .font(.subheadline.weight(.semibold))
                    TextField("127.0.0.1", text: $appState.settings.proxyHost)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!appState.settings.proxyEnabled)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text(.proxyPort))
                        .font(.subheadline.weight(.semibold))
                    TextField("7890", text: $appState.settings.proxyPort)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!appState.settings.proxyEnabled)
                }
            }

            HStack {
                Button(L10n.text(.saveProxySettings)) {
                    appState.saveSettings()
                }
                .buttonStyle(.borderedProminent)

                Button(L10n.text(.testProxyNow)) {
                    appState.saveSettings()
                }
                .buttonStyle(.bordered)
            }

            Text(L10n.text(.proxyHint))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text(.languageSection))
                .font(.title3.weight(.bold))

            Picker("", selection: $appState.settings.language) {
                Text(L10n.text(.languageFollowSystem)).tag(AppLanguage.system)
                Text(L10n.text(.languageEnglish)).tag(AppLanguage.english)
                Text(L10n.text(.languageChinese)).tag(AppLanguage.simplifiedChinese)
            }
            .pickerStyle(.segmented)

            Button(L10n.text(.saveLanguage)) {
                appState.saveSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text(.startup))
                .font(.title3.weight(.bold))

            HStack {
                StatusPill(
                    text: appState.launchAtLoginEnabled ? L10n.text(.enabled) : L10n.text(.disabled),
                    color: appState.launchAtLoginEnabled ? .green : .gray
                )

                Text(L10n.text(.startupHint))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(appState.launchAtLoginEnabled ? L10n.text(.disableLaunchAtLogin) : L10n.text(.enableLaunchAtLogin)) {
                    appState.setLaunchAtLoginEnabled(!appState.launchAtLoginEnabled)
                }
                .buttonStyle(.borderedProminent)

                Text(L10n.text(.startupRestrictionHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var footerSection: some View {
        HStack {
            Text(L10n.text(.footerHint))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func labeledField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct ProbeCardView: View {
    let result: ProbeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.serviceName)
                        .font(.headline)
                    Text(result.probeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(text: result.state.label, color: badgeColor)
            }

            Text(result.requestedURL)
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if let code = result.statusCode {
                    metricLabel("HTTP \(code)")
                }

                if let latency = result.latencyMs {
                    metricLabel("\(latency) ms")
                }

                metricLabel(DateFormatter.localizedString(from: result.checkedAt, dateStyle: .none, timeStyle: .medium))
            }

            Text(result.detail)
                .font(.body)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor.opacity(0.7), lineWidth: 1)
        )
    }

    private var badgeColor: Color {
        switch result.state {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        }
    }

    private var cardBackground: LinearGradient {
        switch result.state {
        case .pass:
            return LinearGradient(colors: [Color.green.opacity(0.14), Color.white.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .warning:
            return LinearGradient(colors: [Color.orange.opacity(0.14), Color.white.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fail:
            return LinearGradient(colors: [Color.red.opacity(0.14), Color.white.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var borderColor: Color {
        switch result.state {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        }
    }

    private func metricLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote.monospaced())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.05), in: Capsule())
    }
}

private struct ServiceSummaryCard: View {
    let summary: ServiceStatusSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(summary.serviceName)
                    .font(.headline)
                Spacer()
                StatusPill(text: summary.overallState.label, color: badgeColor)
            }

            HStack(spacing: 10) {
                metricLabel("\(summary.probes.count) probes")
                if summary.issueCount > 0 {
                    metricLabel("\(summary.issueCount) issues")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text(.recentFailureSummary))
                    .font(.subheadline.weight(.semibold))
                Text(summary.lastFailureSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var badgeColor: Color {
        switch summary.overallState {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        }
    }

    private func metricLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote.monospaced())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.05), in: Capsule())
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
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}
