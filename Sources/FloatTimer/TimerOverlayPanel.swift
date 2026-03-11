import AppKit

class TimerOverlayPanel: NSPanel, TimerEngineDelegate {
    private let timerEngine: TimerEngine
    private let timeLabel: NSTextField
    private let pillView: NSView
    var preferencesWindow: PreferencesWindow?

    init(timerEngine: TimerEngine) {
        self.timerEngine = timerEngine

        // Time label with monospaced digits to prevent jiggle
        timeLabel = NSTextField(labelWithString: "0:00")
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 56, weight: .medium)
        timeLabel.textColor = Preferences.shared.textColor
        timeLabel.alignment = .center
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Dark pill background (colour from preferences)
        pillView = NSView()
        pillView.wantsLayer = true
        pillView.layer?.backgroundColor = Preferences.shared.pillBackgroundColor.cgColor
        pillView.layer?.cornerRadius = Preferences.shared.cornerRadius
        pillView.layer?.masksToBounds = true
        pillView.translatesAutoresizingMaskIntoConstraints = false

        let contentRect = NSRect(x: 0, y: 0, width: 260, height: 88)

        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        // --- Float above everything including full-screen apps ---
        self.level = .screenSaver
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]

        // Transparency
        self.isOpaque = false
        self.backgroundColor = .clear
        self.alphaValue = 0.85
        self.hasShadow = true

        // Never steal focus
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true

        // Drag anywhere on the pill
        self.isMovableByWindowBackground = true

        // Hide titlebar
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        // Layout
        let container = NSView(frame: contentRect)
        container.wantsLayer = true
        self.contentView = container

        container.addSubview(pillView)
        pillView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            pillView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pillView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pillView.topAnchor.constraint(equalTo: container.topAnchor),
            pillView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            timeLabel.centerXAnchor.constraint(equalTo: pillView.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
        ])

        // Right-click context menu on the pill
        container.menu = buildContextMenu()

        // Wire up delegate
        timerEngine.delegate = self

        // Save position on drag
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: self
        )

        // Listen for colour changes from preferences
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyColors),
            name: .preferencesColorsDidChange,
            object: nil
        )
    }

    /// Re-apply colours from Preferences (called on notification or startup)
    @objc func applyColors() {
        let prefs = Preferences.shared
        pillView.layer?.backgroundColor = prefs.pillBackgroundColor.cgColor
        pillView.layer?.cornerRadius = prefs.cornerRadius
        timeLabel.textColor = prefs.textColor
    }

    // --- Never become key/main (don't steal focus) ---

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // --- Context menu (right-click on pill) ---

    private func buildContextMenu() -> NSMenu {
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

        // Pause / Resume
        let pauseItem = NSMenuItem(
            title: "Pause / Resume",
            action: #selector(togglePause(_:)),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        // Reset
        let resetItem = NSMenuItem(
            title: "Reset",
            action: #selector(resetTimer(_:)),
            keyEquivalent: ""
        )
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        // Hide
        let hideItem = NSMenuItem(
            title: "Hide Timer",
            action: #selector(hideTimerClicked(_:)),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(
            title: "Preferences\u{2026}",
            action: #selector(openPreferencesFromMenu(_:)),
            keyEquivalent: ""
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        // Update labels dynamically before showing
        menu.delegate = self

        return menu
    }

    @objc private func presetSelected(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? TimeInterval else { return }
        timerEngine.start(duration: duration)
    }

    @objc private func customSelected(_ sender: NSMenuItem) {
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
        NSApp.setActivationPolicy(.accessory)

        if response == .alertFirstButtonReturn {
            if let minutes = Double(input.stringValue), minutes > 0 {
                timerEngine.start(duration: minutes * 60)
            }
        }
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        timerEngine.togglePauseResume()
    }

    @objc private func resetTimer(_ sender: NSMenuItem) {
        timerEngine.reset()
    }

    @objc private func openPreferencesFromMenu(_ sender: NSMenuItem) {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
            preferencesWindow?.delegate = preferencesWindow
        }
        preferencesWindow?.showWindow()
    }

    @objc private func hideTimerClicked(_ sender: NSMenuItem) {
        hideOverlay()
    }

    // --- Position persistence ---

    func restoreSavedPosition() {
        if let savedFrame = Preferences.shared.overlayPosition {
            self.setFrameOrigin(savedFrame.origin)
        } else {
            // Default: top-right corner
            if let screen = NSScreen.main {
                let x = screen.visibleFrame.maxX - self.frame.width - 20
                let y = screen.visibleFrame.maxY - self.frame.height - 80
                self.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }

    func savePosition() {
        Preferences.shared.overlayPosition = self.frame
    }

    @objc private func windowDidMove(_ notification: Notification) {
        savePosition()
    }

    // --- Show / hide ---

    func showOverlay() {
        self.orderFrontRegardless()
    }

    func hideOverlay() {
        self.orderOut(nil)
    }

    // --- TimerEngineDelegate ---

    func timerDidTick(remaining: TimeInterval) {
        timeLabel.stringValue = timerEngine.formattedTime
    }

    func timerDidFinish() {
        timeLabel.stringValue = "0:00"
        // Flash red briefly then back to saved text colour
        let savedTextColor = Preferences.shared.textColor
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            timeLabel.animator().textColor = .systemRed
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    self?.timeLabel.animator().textColor = savedTextColor
                })
            }
        }
        NSSound.beep()
    }

    func timerDidChangeState(_ state: TimerEngine.State) {
        let textCol = Preferences.shared.textColor
        switch state {
        case .running:
            showOverlay()
            timeLabel.textColor = textCol
        case .paused:
            timeLabel.textColor = textCol.withAlphaComponent(0.5)
        case .idle:
            timeLabel.textColor = textCol
        }
    }
}

// MARK: - NSMenuDelegate (dynamic label updates before menu shows)

extension TimerOverlayPanel: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Update Pause/Resume label based on current state
        for item in menu.items {
            if item.action == #selector(togglePause(_:)) {
                switch timerEngine.state {
                case .running:
                    item.title = "Pause"
                case .paused:
                    item.title = "Resume"
                case .idle:
                    item.title = "Pause / Resume"
                    item.isEnabled = false
                }
            }
            if item.action == #selector(resetTimer(_:)) {
                item.isEnabled = timerEngine.state != .idle
            }
        }
    }
}
