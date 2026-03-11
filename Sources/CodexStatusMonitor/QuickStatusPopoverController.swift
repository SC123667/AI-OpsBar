import AppKit
import SwiftUI

@MainActor
final class QuickStatusPopoverController: NSObject, NSPopoverDelegate {
    private let appState: AppState
    private let openDashboard: () -> Void
    private let popover: NSPopover

    init(appState: AppState, openDashboard: @escaping () -> Void) {
        self.appState = appState
        self.openDashboard = openDashboard
        self.popover = NSPopover()
        super.init()

        popover.contentViewController = NSHostingController(
            rootView: QuickStatusView(
                appState: appState,
                openDashboard: openDashboard,
                closePopover: { [weak self] in self?.close() }
            )
        )
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 360, height: 420)
    }

    var isShown: Bool {
        popover.isShown
    }

    func toggle(relativeTo positioningView: NSView?) {
        guard let positioningView else {
            return
        }

        if popover.isShown {
            close()
            return
        }

        if let hostingController = popover.contentViewController as? NSHostingController<QuickStatusView> {
            hostingController.rootView = QuickStatusView(
                appState: appState,
                openDashboard: openDashboard,
                closePopover: { [weak self] in self?.close() }
            )
        }

        popover.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .minY)
        appState.setDashboardVisible(true)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        appState.setDashboardVisible(false)
    }
}

private struct QuickStatusView: View {
    @ObservedObject var appState: AppState
    let openDashboard: () -> Void
    let closePopover: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text(.appTitle))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Text(appState.snapshot.overallState.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                QuickStatusPill(
                    text: appState.snapshot.overallState.menuBarTitle,
                    color: stateColor(appState.snapshot.overallState)
                )
            }

            HStack(spacing: 8) {
                actionButton(L10n.text(.menuRefreshNow), systemImage: "arrow.clockwise") {
                    appState.refreshNow()
                }
                actionButton(L10n.text(.menuOpenDashboard), systemImage: "rectangle.stack") {
                    closePopover()
                    openDashboard()
                }
            }

            sectionTitle(L10n.text(.quickPanelTopIssues))

            if appState.issueServiceCount == 0 {
                emptyCard(L10n.text(.quickPanelNoIssues))
            } else {
                VStack(spacing: 8) {
                    ForEach(appState.topIssueSummaries(limit: 3)) { summary in
                        QuickIssueRow(summary: summary)
                    }
                }
            }

            sectionTitle(L10n.text(.quickPanelRecentHealth))

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(appState.serviceSummaries.prefix(5)) { summary in
                        QuickHealthRow(summary: summary)
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .padding(16)
        .frame(width: 360, height: 420)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 0.99),
                    Color(red: 0.93, green: 0.96, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
}

private struct QuickIssueRow: View {
    let summary: ServiceStatusSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.serviceName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                QuickStatusPill(text: summary.overallState.label, color: tint)
            }

            Text(summary.lastFailureSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var tint: Color {
        switch summary.overallState {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        }
    }
}

private struct QuickStatusPill: View {
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

private struct QuickHealthRow: View {
    let summary: ServiceStatusSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(summary.serviceName)
                    .font(.footnote.weight(.semibold))

                Spacer()

                HistorySparkline(samples: summary.recentHistory, tint: tint)
                    .frame(width: 84, height: 18)
            }

            if let spend = summary.spendSnapshot, spend.hasWindowBreakdown {
                SpendBreakdownView(snapshot: spend, accent: .green, compact: true)
            } else {
                Text(summary.spendSupported || summary.hasSpendSignal ? summary.spendSummary : summary.quotaSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var tint: Color {
        switch summary.overallState {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        }
    }
}
