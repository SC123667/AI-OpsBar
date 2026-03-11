import AppKit
import Combine

@MainActor
final class StatusMenuController: NSObject {
    private let appState: AppState
    private let openDashboard: (NSStatusBarButton?) -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let contextMenu = NSMenu()
    private lazy var quickPopoverController = QuickStatusPopoverController(
        appState: appState,
        openDashboard: { [weak self] in
            self?.openDashboard(self?.statusItem.button)
        }
    )
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState, openDashboard: @escaping (NSStatusBarButton?) -> Void) {
        self.appState = appState
        self.openDashboard = openDashboard
    }

    func start() {
        guard let button = statusItem.button else {
            return
        }

        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = appState.snapshot.overallState.summary
        button.image = statusImage(for: appState.snapshot.overallState)
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        observeState()
        rebuildMenu()
    }

    @objc
    func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            return
        }

        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            quickPopoverController.toggle(relativeTo: statusItem.button)
        }
    }

    @objc
    func refreshNow(_ sender: Any?) {
        appState.refreshNow()
    }

    @objc
    func showDashboard(_ sender: Any?) {
        quickPopoverController.close()
        DispatchQueue.main.async { [weak self] in
            self?.openDashboard(self?.statusItem.button)
        }
    }

    @objc
    func configureAPIKey(_ sender: Any?) {
        guard let definition = representedDefinition(from: sender) else {
            return
        }

        appState.promptForAPIKey(for: definition)
    }

    @objc
    func clearAPIKey(_ sender: Any?) {
        guard let definition = representedDefinition(from: sender) else {
            return
        }

        appState.clearAPIKey(for: definition)
    }

    @objc
    func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    private func representedDefinition(from sender: Any?) -> ServiceDefinition? {
        guard let rawValue = (sender as? NSMenuItem)?.representedObject as? String else {
            return nil
        }

        return appState.definition(for: ServiceID(rawValue: rawValue))
    }

    private func observeState() {
        appState.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.statusItem.button?.image = self?.statusImage(for: snapshot.overallState)
                self?.statusItem.button?.toolTip = snapshot.overallState.summary
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        appState.$statusMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        appState.$launchAtLoginEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        appState.$serviceSummaries
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    private func showContextMenu() {
        rebuildMenu()
        guard let button = statusItem.button else {
            return
        }

        statusItem.menu = contextMenu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func rebuildMenu() {
        contextMenu.removeAllItems()

        let summaryItem = NSMenuItem(title: appState.snapshot.overallState.summary, action: nil, keyEquivalent: "")
        summaryItem.isEnabled = false
        contextMenu.addItem(summaryItem)

        if !appState.statusMessage.isEmpty {
            let messageItem = NSMenuItem(title: appState.statusMessage, action: nil, keyEquivalent: "")
            messageItem.isEnabled = false
            contextMenu.addItem(messageItem)
        }

        contextMenu.addItem(.separator())

        if appState.serviceSummaries.isEmpty {
            let checkingItem = NSMenuItem(title: L10n.text(.waitingFirstProbeMenu), action: nil, keyEquivalent: "")
            checkingItem.isEnabled = false
            contextMenu.addItem(checkingItem)
        } else {
            addGroupedServiceSections()
        }

        contextMenu.addItem(.separator())
        contextMenu.addItem(NSMenuItem(title: L10n.text(.menuOpenDashboard), action: #selector(showDashboard(_:)), keyEquivalent: "d"))
        contextMenu.addItem(NSMenuItem(title: L10n.text(.menuRefreshNow), action: #selector(refreshNow(_:)), keyEquivalent: "r"))
        contextMenu.addItem(apiKeysMenuItem())
        contextMenu.addItem(.separator())

        let autoStartText = appState.launchAtLoginEnabled ? L10n.text(.menuLaunchAtLoginEnabled) : L10n.text(.menuLaunchAtLoginDisabled)
        let autoStartItem = NSMenuItem(title: autoStartText, action: nil, keyEquivalent: "")
        autoStartItem.isEnabled = false
        contextMenu.addItem(autoStartItem)

        contextMenu.addItem(.separator())
        contextMenu.addItem(NSMenuItem(title: L10n.text(.menuQuit), action: #selector(quit(_:)), keyEquivalent: "q"))

        for item in contextMenu.items where item.action != nil {
            item.target = self
        }
    }

    private func addGroupedServiceSections() {
        let groups = appState.menuGroupedServiceSummaries()

        for (index, group) in groups.enumerated() {
            let groupHeader = NSMenuItem(title: group.group.title, action: nil, keyEquivalent: "")
            groupHeader.isEnabled = false
            contextMenu.addItem(groupHeader)

            for service in group.services {
                contextMenu.addItem(serviceMenuItem(for: service))
            }

            if index < groups.count - 1 {
                contextMenu.addItem(.separator())
            }
        }
    }

    private func serviceMenuItem(for summary: ServiceStatusSummary) -> NSMenuItem {
        let issueSuffix = summary.issueCount > 0 ? " • \(summary.issueCount)" : ""
        let item = NSMenuItem(
            title: "\(summary.serviceName)  \(summary.overallState.label)\(issueSuffix)",
            action: nil,
            keyEquivalent: ""
        )

        let submenu = NSMenu()

        let summaryItem = NSMenuItem(title: summary.issueCount > 0 ? summary.lastFailureSummary : summary.quotaSummary, action: nil, keyEquivalent: "")
        summaryItem.isEnabled = false
        submenu.addItem(summaryItem)

        if !summary.recentHistory.isEmpty {
            let historyItem = NSMenuItem(title: "\(L10n.text(.historyTitle)): \(historyGlyphs(from: summary.recentHistory.suffix(10)))", action: nil, keyEquivalent: "")
            historyItem.isEnabled = false
            submenu.addItem(historyItem)
        }

        submenu.addItem(.separator())

        for probe in summary.probes {
            let probeItem = NSMenuItem(title: probe.menuTitle, action: nil, keyEquivalent: "")
            probeItem.isEnabled = false
            submenu.addItem(probeItem)

            let detailItem = NSMenuItem(title: "  \(probe.detail)", action: nil, keyEquivalent: "")
            detailItem.isEnabled = false
            submenu.addItem(detailItem)
        }

        item.submenu = submenu
        return item
    }

    private func historyGlyphs(from samples: ArraySlice<ServiceHistorySample>) -> String {
        samples.map { sample in
            switch sample.state {
            case .pass:
                return "●"
            case .warning:
                return "◐"
            case .fail:
                return "○"
            }
        }.joined()
    }

    private func apiKeysMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.text(.menuAPIKeys), action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let definitions = ServiceDefinitions.all(settings: appState.settings)
            .filter { $0.apiProbe?.keychainAccount != nil }
            .sorted { $0.name < $1.name }

        for (index, definition) in definitions.enumerated() {
            if index > 0 {
                submenu.addItem(.separator())
            }

            let setItem = NSMenuItem(title: "\(L10n.text(.manageAPIKey)) \(definition.name)", action: #selector(configureAPIKey(_:)), keyEquivalent: "")
            setItem.representedObject = definition.id.rawValue
            setItem.target = self
            submenu.addItem(setItem)

            let clearItem = NSMenuItem(title: "\(L10n.text(.clearSavedAPIKey)) \(definition.name)", action: #selector(clearAPIKey(_:)), keyEquivalent: "")
            clearItem.representedObject = definition.id.rawValue
            clearItem.target = self
            submenu.addItem(clearItem)
        }

        item.submenu = submenu
        return item
    }

    private func statusImage(for state: OverallState) -> NSImage? {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.labelColor.setStroke()
            NSColor.labelColor.setFill()

            switch state {
            case .checking:
                self.drawCheckingIcon(in: rect)
            case .healthy:
                self.drawHealthyIcon(in: rect)
            case .degraded:
                self.drawDegradedIcon(in: rect)
            case .blocked:
                self.drawBlockedIcon(in: rect)
            }

            return true
        }

        image.accessibilityDescription = state.summary
        image.isTemplate = true
        return image
    }

    private func drawHealthyIcon(in rect: NSRect) {
        let circleRect = rect.insetBy(dx: 4.6, dy: 4.6)
        let path = NSBezierPath(ovalIn: circleRect)
        path.lineWidth = 1.7
        path.stroke()
        path.fill()
    }

    private func drawDegradedIcon(in rect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.midX, y: rect.maxY - 3.4))
        path.line(to: NSPoint(x: rect.maxX - 4.0, y: rect.minY + 4.2))
        path.line(to: NSPoint(x: rect.minX + 4.0, y: rect.minY + 4.2))
        path.close()
        path.lineWidth = 1.6
        path.stroke()
    }

    private func drawBlockedIcon(in rect: NSRect) {
        let insetRect = rect.insetBy(dx: 4.8, dy: 4.8)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: insetRect.minX, y: insetRect.minY))
        path.line(to: NSPoint(x: insetRect.maxX, y: insetRect.maxY))
        path.move(to: NSPoint(x: insetRect.minX, y: insetRect.maxY))
        path.line(to: NSPoint(x: insetRect.maxX, y: insetRect.minY))
        path.lineWidth = 1.8
        path.stroke()
    }

    private func drawCheckingIcon(in rect: NSRect) {
        let dotRadius: CGFloat = 1.45
        let centers = [
            NSPoint(x: rect.midX - 4.5, y: rect.midY),
            NSPoint(x: rect.midX, y: rect.midY),
            NSPoint(x: rect.midX + 4.5, y: rect.midY),
        ]

        for center in centers {
            let dotRect = NSRect(
                x: center.x - dotRadius,
                y: center.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            NSBezierPath(ovalIn: dotRect).fill()
        }
    }
}
