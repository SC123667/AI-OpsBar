import AppKit
import Combine

@MainActor
final class StatusMenuController: NSObject {
    private let appState: AppState
    private let openDashboard: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let contextMenu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState, openDashboard: @escaping () -> Void) {
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
        statusItem.menu = contextMenu
        observeState()
        rebuildMenu()
    }

    @objc
    func refreshNow(_ sender: Any?) {
        appState.refreshNow()
    }

    @objc
    func showDashboard(_ sender: Any?) {
        openDashboard()
    }

    @objc
    func configureAPIKey(_ sender: Any?) {
        let account = (sender as? NSMenuItem)?.representedObject as? String ?? AppConfig.keychainAccount
        let serviceName = (sender as? NSMenuItem)?.title.replacingOccurrences(of: "Set ", with: "").replacingOccurrences(of: " API Key", with: "") ?? "OpenAI"

        let alert = NSAlert()
        alert.messageText = "\(serviceName) API Key"
        alert.informativeText = L10n.text(.apiKeyDialogMessage)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.text(.save))
        alert.addButton(withTitle: L10n.text(.cancel))

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.placeholderString = KeychainHelper.loadAPIKey(account: account) == nil ? L10n.text(.apiKeyPlaceholder) : L10n.text(.apiKeyReplacePlaceholder)
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let value = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else {
            showInfoAlert(title: L10n.text(.apiKeyNotSaved), message: L10n.text(.emptyField))
            return
        }

        let status = KeychainHelper.saveAPIKey(value, account: account)

        guard status == errSecSuccess else {
            showInfoAlert(title: L10n.text(.failedSaveAPIKey), message: "Keychain returned status \(status).")
            return
        }

        appState.statusMessage = L10n.text(.apiKeySaved)
        appState.refreshNow()
    }

    @objc
    func clearAPIKey(_ sender: Any?) {
        let account = (sender as? NSMenuItem)?.representedObject as? String ?? AppConfig.keychainAccount
        let status = KeychainHelper.deleteAPIKey(account: account)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            showInfoAlert(title: L10n.text(.failedClearAPIKey), message: "Keychain returned status \(status).")
            return
        }

        appState.statusMessage = L10n.text(.apiKeyRemoved)
        appState.refreshNow()
    }

    @objc
    func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
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

        if appState.snapshot.results.isEmpty {
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
        let groups = appState.groupedServiceSummaries()

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

        let summaryItem = NSMenuItem(title: summary.lastFailureSummary, action: nil, keyEquivalent: "")
        summaryItem.isEnabled = false
        submenu.addItem(summaryItem)
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

    private func showInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text(.ok))
        alert.runModal()
    }

    private func apiKeysMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "API Keys", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let codexSet = NSMenuItem(title: "Set OpenAI API Key", action: #selector(configureAPIKey(_:)), keyEquivalent: "")
        codexSet.representedObject = AppConfig.keychainAccount
        codexSet.target = self
        submenu.addItem(codexSet)

        let codexClear = NSMenuItem(title: "Clear OpenAI API Key", action: #selector(clearAPIKey(_:)), keyEquivalent: "")
        codexClear.representedObject = AppConfig.keychainAccount
        codexClear.target = self
        submenu.addItem(codexClear)

        for definition in ServiceDefinitions.all {
            guard let account = definition.apiProbe?.keychainAccount else {
                continue
            }

            submenu.addItem(.separator())

            let setItem = NSMenuItem(title: "Set \(definition.name) API Key", action: #selector(configureAPIKey(_:)), keyEquivalent: "")
            setItem.representedObject = account
            setItem.target = self
            submenu.addItem(setItem)

            let clearItem = NSMenuItem(title: "Clear \(definition.name) API Key", action: #selector(clearAPIKey(_:)), keyEquivalent: "")
            clearItem.representedObject = account
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
