import AppKit
import SwiftUI

@MainActor
final class DashboardWindowController: NSObject, NSPopoverDelegate {
    private let appState: AppState
    private let popover: NSPopover

    init(appState: AppState) {
        self.appState = appState
        self.popover = NSPopover()
        super.init()

        popover.contentViewController = NSHostingController(rootView: DashboardView(appState: appState))
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 460, height: 760)
    }

    func showAndActivate(relativeTo positioningView: NSView?) {
        guard let positioningView else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        if let hostingController = popover.contentViewController as? NSHostingController<DashboardView> {
            hostingController.rootView = DashboardView(appState: appState)
        }

        popover.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .minY)
        appState.setDashboardVisible(true)
        NSApp.activate(ignoringOtherApps: true)
    }

    func popoverDidClose(_ notification: Notification) {
        appState.setDashboardVisible(false)
    }
}
