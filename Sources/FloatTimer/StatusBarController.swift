import AppKit

class StatusBarController {
    private let statusItem: NSStatusItem
    private let timerEngine: TimerEngine
    private let overlayPanel: TimerOverlayPanel
    var preferencesWindow: PreferencesWindow?

    init(timerEngine: TimerEngine, overlayPanel: TimerOverlayPanel) {
        self.timerEngine = timerEngine
        self.overlayPanel = overlayPanel

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "timer",
                accessibilityDescription: "FloatTimer"
            )
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        // Presets
        let headerItem = NSMenuItem(title: "Start Timer", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let presets: [(String, TimeInterval)] = [
            ("1 minute", 1 * 60),
            ("2 minutes", 2 * 60),
            ("3 minutes", 3 * 60),
            ("4 minutes", 4 * 60),
            ("5 minutes", 5 * 60),
            ("10 minutes", 10 * 60),
            ("15 minutes", 15 * 60),
            ("30 minutes", 30 * 60),
        ]

        for (title, duration) in presets {
            let item = NSMenuItem(
                title: title,
                action: #selector(presetSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = duration
            menu.addItem(item)
        }

        let customItem = NSMenuItem(
            title: "Custom\u{2026}",
            action: #selector(customSelected(_:)),
            keyEquivalent: ""
        )
        customItem.target = self
        menu.addItem(customItem)

        menu.addItem(NSMenuItem.separator())

        // Controls
        let pauseItem = NSMenuItem(
            title: "Pause / Resume",
            action: #selector(togglePause(_:)),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        let stopItem = NSMenuItem(
            title: "Stop",
            action: #selector(stopTimer(_:)),
            keyEquivalent: ""
        )
        stopItem.target = self
        menu.addItem(stopItem)

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(
            title: "Show / Hide Timer",
            action: #selector(toggleOverlay(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences\u{2026}",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit FloatTimer",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func presetSelected(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? TimeInterval else { return }
        timerEngine.start(duration: duration)
    }

    @objc private func customSelected(_ sender: NSMenuItem) {
        showCustomDurationAlert()
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        timerEngine.togglePauseResume()
    }

    @objc private func stopTimer(_ sender: NSMenuItem) {
        timerEngine.stop()
        overlayPanel.hideOverlay()
    }

    @objc private func openPreferences(_ sender: NSMenuItem) {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
            preferencesWindow?.delegate = preferencesWindow
        }
        preferencesWindow?.showWindow()
    }

    @objc private func toggleOverlay(_ sender: NSMenuItem) {
        if overlayPanel.isVisible {
            overlayPanel.hideOverlay()
        } else {
            overlayPanel.showOverlay()
        }
    }

    private func showCustomDurationAlert() {
        // Temporarily become regular app so the alert can receive focus
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Custom Timer"
        alert.informativeText = "Enter duration in minutes:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        input.placeholderString = "e.g. 25"
        input.stringValue = ""
        alert.accessoryView = input

        let response = alert.runModal()

        // Go back to accessory (hide dock icon)
        NSApp.setActivationPolicy(.accessory)

        if response == .alertFirstButtonReturn {
            if let minutes = Double(input.stringValue), minutes > 0 {
                timerEngine.start(duration: minutes * 60)
            }
        }
    }
}
