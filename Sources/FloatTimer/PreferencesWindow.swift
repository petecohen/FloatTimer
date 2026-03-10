import AppKit

// MARK: - ShortcutField — captures key combos

class ShortcutField: NSTextField {
    var onShortcutCaptured: ((HotkeyBinding) -> Void)?
    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isEditable = false
        isSelectable = true
        alignment = .center
        font = NSFont.systemFont(ofSize: 14, weight: .medium)
        bezelStyle = .roundedBezel
        placeholderString = "Click to record"
    }

    func setBinding(_ binding: HotkeyBinding) {
        stringValue = binding.displayString
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        stringValue = "Type shortcut\u{2026}"
        textColor = .systemOrange
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Require at least one modifier key
        let hasModifier = flags.contains(.control) || flags.contains(.option)
            || flags.contains(.shift) || flags.contains(.command)

        guard hasModifier else {
            NSSound.beep()
            return
        }

        // Ignore bare modifier-only presses (keyCode for modifier keys themselves)
        let modKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        guard !modKeyCodes.contains(event.keyCode) else { return }

        let binding = HotkeyBinding(modifiers: flags.rawValue, keyCode: event.keyCode)
        isRecording = false
        textColor = .labelColor
        stringValue = binding.displayString
        onShortcutCaptured?(binding)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            textColor = .labelColor
            // Restore current value if user clicked away without recording
        }
        return super.resignFirstResponder()
    }
}

// MARK: - PreferencesWindow

class PreferencesWindow: NSWindow {

    private let bgColorWell: NSColorWell
    private let textColorWell: NSColorWell
    private let cornerRadiusSlider: NSSlider
    private let cornerRadiusValueLabel: NSTextField
    private let startPauseField: ShortcutField
    private let resetField: ShortcutField
    private let toggleField: ShortcutField

    init() {
        bgColorWell = NSColorWell(frame: .zero)
        textColorWell = NSColorWell(frame: .zero)
        cornerRadiusSlider = NSSlider(frame: .zero)
        cornerRadiusValueLabel = NSTextField(labelWithString: "")
        startPauseField = ShortcutField(frame: .zero)
        resetField = ShortcutField(frame: .zero)
        toggleField = ShortcutField(frame: .zero)

        let contentRect = NSRect(x: 0, y: 0, width: 400, height: 380)

        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "FloatTimer Preferences"
        self.isReleasedWhenClosed = false
        self.center()

        buildUI()
        loadCurrentValues()
        wireCallbacks()
    }

    // MARK: - Build UI

    private func buildUI() {
        let container = NSView(frame: self.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        self.contentView = container

        let padding: CGFloat = 20
        var y: CGFloat = container.bounds.height - padding

        // === Colours section ===
        y -= 22
        let colorsHeader = makeLabel("Colours", bold: true)
        colorsHeader.frame = NSRect(x: padding, y: y, width: 360, height: 20)
        container.addSubview(colorsHeader)

        y -= 8
        let colorsSep = makeSeparator()
        colorsSep.frame = NSRect(x: padding, y: y, width: 360, height: 1)
        container.addSubview(colorsSep)

        y -= 36
        let bgLabel = makeLabel("Background:")
        bgLabel.frame = NSRect(x: padding, y: y, width: 120, height: 24)
        container.addSubview(bgLabel)

        bgColorWell.frame = NSRect(x: 140, y: y, width: 44, height: 28)
        if #available(macOS 13.0, *) {
            bgColorWell.colorWellStyle = .expanded
        }
        container.addSubview(bgColorWell)

        y -= 36
        let textLabel = makeLabel("Text:")
        textLabel.frame = NSRect(x: padding, y: y, width: 120, height: 24)
        container.addSubview(textLabel)

        textColorWell.frame = NSRect(x: 140, y: y, width: 44, height: 28)
        if #available(macOS 13.0, *) {
            textColorWell.colorWellStyle = .expanded
        }
        container.addSubview(textColorWell)

        // Corner radius
        y -= 36
        let crLabel = makeLabel("Corner Radius:")
        crLabel.frame = NSRect(x: padding, y: y, width: 120, height: 24)
        container.addSubview(crLabel)

        cornerRadiusSlider.frame = NSRect(x: 140, y: y, width: 160, height: 24)
        cornerRadiusSlider.minValue = 0
        cornerRadiusSlider.maxValue = 44
        cornerRadiusSlider.isContinuous = true
        container.addSubview(cornerRadiusSlider)

        cornerRadiusValueLabel.frame = NSRect(x: 310, y: y, width: 60, height: 24)
        cornerRadiusValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        container.addSubview(cornerRadiusValueLabel)

        // === Shortcuts section ===
        y -= 36
        let shortcutsHeader = makeLabel("Keyboard Shortcuts", bold: true)
        shortcutsHeader.frame = NSRect(x: padding, y: y, width: 360, height: 20)
        container.addSubview(shortcutsHeader)

        y -= 8
        let shortcutsSep = makeSeparator()
        shortcutsSep.frame = NSRect(x: padding, y: y, width: 360, height: 1)
        container.addSubview(shortcutsSep)

        // Start / Pause
        y -= 36
        let spLabel = makeLabel("Start / Pause:")
        spLabel.frame = NSRect(x: padding, y: y, width: 140, height: 24)
        container.addSubview(spLabel)

        startPauseField.frame = NSRect(x: 170, y: y, width: 120, height: 26)
        container.addSubview(startPauseField)

        // Reset
        y -= 36
        let resetLabel = makeLabel("Reset:")
        resetLabel.frame = NSRect(x: padding, y: y, width: 140, height: 24)
        container.addSubview(resetLabel)

        resetField.frame = NSRect(x: 170, y: y, width: 120, height: 26)
        container.addSubview(resetField)

        // Toggle show/hide
        y -= 36
        let toggleLabel = makeLabel("Show / Hide:")
        toggleLabel.frame = NSRect(x: padding, y: y, width: 140, height: 24)
        container.addSubview(toggleLabel)

        toggleField.frame = NSRect(x: 170, y: y, width: 120, height: 26)
        container.addSubview(toggleField)

        // === Reset button ===
        y -= 44
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetToDefaults(_:)))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: padding, y: y, width: 150, height: 30)
        container.addSubview(resetButton)
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold
            ? NSFont.systemFont(ofSize: 13, weight: .semibold)
            : NSFont.systemFont(ofSize: 13)
        return label
    }

    private func makeSeparator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    // MARK: - Load / wire

    private func loadCurrentValues() {
        let prefs = Preferences.shared
        bgColorWell.color = prefs.pillBackgroundColor
        textColorWell.color = prefs.textColor
        cornerRadiusSlider.doubleValue = Double(prefs.cornerRadius)
        updateCornerRadiusLabel()
        startPauseField.setBinding(prefs.hotkeyStartPause)
        resetField.setBinding(prefs.hotkeyReset)
        toggleField.setBinding(prefs.hotkeyToggle)
    }

    private func updateCornerRadiusLabel() {
        let val = Int(cornerRadiusSlider.doubleValue)
        cornerRadiusValueLabel.stringValue = val == 0 ? "Square" : val == 44 ? "Pill" : "\(val)"
    }

    private func wireCallbacks() {
        bgColorWell.target = self
        bgColorWell.action = #selector(bgColorChanged(_:))

        textColorWell.target = self
        textColorWell.action = #selector(textColorChanged(_:))

        cornerRadiusSlider.target = self
        cornerRadiusSlider.action = #selector(cornerRadiusChanged(_:))

        startPauseField.onShortcutCaptured = { binding in
            Preferences.shared.hotkeyStartPause = binding
        }
        resetField.onShortcutCaptured = { binding in
            Preferences.shared.hotkeyReset = binding
        }
        toggleField.onShortcutCaptured = { binding in
            Preferences.shared.hotkeyToggle = binding
        }
    }

    // MARK: - Actions

    @objc private func bgColorChanged(_ sender: NSColorWell) {
        Preferences.shared.pillBackgroundColor = sender.color
    }

    @objc private func textColorChanged(_ sender: NSColorWell) {
        Preferences.shared.textColor = sender.color
    }

    @objc private func cornerRadiusChanged(_ sender: NSSlider) {
        updateCornerRadiusLabel()
        Preferences.shared.cornerRadius = CGFloat(sender.doubleValue)
    }

    @objc private func resetToDefaults(_ sender: NSButton) {
        Preferences.shared.resetAllToDefaults()
        loadCurrentValues()
    }

    // MARK: - Show

    func showWindow() {
        loadCurrentValues()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
    }
}

// Go back to accessory mode when preferences window closes
extension PreferencesWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
