import AppKit
import SwiftUI

@MainActor
final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        let rootView = DashboardView(appState: appState)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = L10n.text(.appTitle)
        window.setContentSize(NSSize(width: 820, height: 700))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = nil

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func showAndActivate() {
        window?.title = L10n.text(.appTitle)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        appState.setDashboardVisible(true)
    }

    func windowWillClose(_ notification: Notification) {
        appState.setDashboardVisible(false)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        appState.setDashboardVisible(false)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        appState.setDashboardVisible(true)
    }
}
