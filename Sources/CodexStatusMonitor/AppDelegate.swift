import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private lazy var dashboardWindowController = DashboardWindowController(appState: appState)
    private lazy var statusMenuController = StatusMenuController(
        appState: appState,
        openDashboard: { [weak self] in
            self?.dashboardWindowController.showAndActivate()
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenuController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Nothing to tear down beyond normal ARC cleanup.
    }
}
