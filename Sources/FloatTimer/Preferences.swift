import Foundation
import AppKit

/// Notification posted when colours change so the overlay can update live.
extension Notification.Name {
    static let preferencesColorsDidChange = Notification.Name("preferencesColorsDidChange")
    static let preferencesShortcutsDidChange = Notification.Name("preferencesShortcutsDidChange")
}

/// A hotkey binding: modifier flags + virtual key code.
struct HotkeyBinding: Equatable {
    var modifiers: UInt   // NSEvent.ModifierFlags.rawValue (device-independent)
    var keyCode: UInt16

    /// Default shortcuts
    static let defaultStartPause = HotkeyBinding(modifiers: NSEvent.ModifierFlags([.control, .shift]).rawValue, keyCode: 1)   // Ctrl+Shift+S
    static let defaultReset      = HotkeyBinding(modifiers: NSEvent.ModifierFlags([.control, .shift]).rawValue, keyCode: 15)  // Ctrl+Shift+R
    static let defaultToggle     = HotkeyBinding(modifiers: NSEvent.ModifierFlags([.control, .shift]).rawValue, keyCode: 17)  // Ctrl+Shift+T

    /// Human-readable string like "⌃⇧S"
    var displayString: String {
        var parts = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { parts += "\u{2303}" }
        if flags.contains(.option)  { parts += "\u{2325}" }
        if flags.contains(.shift)   { parts += "\u{21E7}" }
        if flags.contains(.command) { parts += "\u{2318}" }
        parts += keyCodeToString(keyCode)
        return parts
    }

    private func keyCodeToString(_ code: UInt16) -> String {
        // Map common key codes to readable characters
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`",
            36: "\u{21A9}", // Return
            48: "\u{21E5}", // Tab
            51: "\u{232B}", // Delete
            53: "\u{238B}", // Escape
            76: "\u{21A9}", // Numpad Enter
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 109: "F10",
            111: "F12", 113: "F14", 115: "F15",
            118: "F4", 120: "F2", 122: "F1",
            123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
        ]
        return map[code] ?? "?"
    }
}

class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let overlayX = "overlayPositionX"
        static let overlayY = "overlayPositionY"
        static let overlayW = "overlayPositionW"
        static let overlayH = "overlayPositionH"
        static let lastDuration = "lastDuration"

        // Appearance
        static let pillBackgroundColor = "pillBackgroundColor"
        static let textColor = "textColor"
        static let cornerRadius = "cornerRadius"

        // Hotkeys (stored as modifier UInt + keyCode UInt16)
        static let hotkeyStartPauseMod = "hotkeyStartPauseMod"
        static let hotkeyStartPauseKey = "hotkeyStartPauseKey"
        static let hotkeyResetMod = "hotkeyResetMod"
        static let hotkeyResetKey = "hotkeyResetKey"
        static let hotkeyToggleMod = "hotkeyToggleMod"
        static let hotkeyToggleKey = "hotkeyToggleKey"
    }

    // MARK: - Overlay position

    var overlayPosition: NSRect? {
        get {
            guard defaults.object(forKey: Keys.overlayX) != nil else { return nil }
            return NSRect(
                x: defaults.double(forKey: Keys.overlayX),
                y: defaults.double(forKey: Keys.overlayY),
                width: defaults.double(forKey: Keys.overlayW),
                height: defaults.double(forKey: Keys.overlayH)
            )
        }
        set {
            if let rect = newValue {
                defaults.set(rect.origin.x, forKey: Keys.overlayX)
                defaults.set(rect.origin.y, forKey: Keys.overlayY)
                defaults.set(rect.size.width, forKey: Keys.overlayW)
                defaults.set(rect.size.height, forKey: Keys.overlayH)
            } else {
                defaults.removeObject(forKey: Keys.overlayX)
                defaults.removeObject(forKey: Keys.overlayY)
                defaults.removeObject(forKey: Keys.overlayW)
                defaults.removeObject(forKey: Keys.overlayH)
            }
        }
    }

    // MARK: - Last duration

    var lastDuration: TimeInterval? {
        get {
            let val = defaults.double(forKey: Keys.lastDuration)
            return val > 0 ? val : nil
        }
        set {
            if let duration = newValue {
                defaults.set(duration, forKey: Keys.lastDuration)
            } else {
                defaults.removeObject(forKey: Keys.lastDuration)
            }
        }
    }

    // MARK: - Colours

    /// Default pill background: black at 70% opacity
    static let defaultPillBackground = NSColor.black.withAlphaComponent(0.7)
    /// Default text colour: white
    static let defaultTextColor = NSColor.white

    var pillBackgroundColor: NSColor {
        get {
            guard let data = defaults.data(forKey: Keys.pillBackgroundColor),
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            else { return Self.defaultPillBackground }
            return color
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                defaults.set(data, forKey: Keys.pillBackgroundColor)
            }
            NotificationCenter.default.post(name: .preferencesColorsDidChange, object: nil)
        }
    }

    var textColor: NSColor {
        get {
            guard let data = defaults.data(forKey: Keys.textColor),
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            else { return Self.defaultTextColor }
            return color
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                defaults.set(data, forKey: Keys.textColor)
            }
            NotificationCenter.default.post(name: .preferencesColorsDidChange, object: nil)
        }
    }

    // MARK: - Corner radius

    /// Default corner radius (fully rounded pill)
    static let defaultCornerRadius: CGFloat = 44

    var cornerRadius: CGFloat {
        get {
            guard defaults.object(forKey: Keys.cornerRadius) != nil else { return Self.defaultCornerRadius }
            return CGFloat(defaults.double(forKey: Keys.cornerRadius))
        }
        set {
            defaults.set(Double(newValue), forKey: Keys.cornerRadius)
            NotificationCenter.default.post(name: .preferencesColorsDidChange, object: nil)
        }
    }

    // MARK: - Hotkey bindings

    var hotkeyStartPause: HotkeyBinding {
        get { loadBinding(modKey: Keys.hotkeyStartPauseMod, codeKey: Keys.hotkeyStartPauseKey, fallback: .defaultStartPause) }
        set { saveBinding(newValue, modKey: Keys.hotkeyStartPauseMod, codeKey: Keys.hotkeyStartPauseKey) }
    }

    var hotkeyReset: HotkeyBinding {
        get { loadBinding(modKey: Keys.hotkeyResetMod, codeKey: Keys.hotkeyResetKey, fallback: .defaultReset) }
        set { saveBinding(newValue, modKey: Keys.hotkeyResetMod, codeKey: Keys.hotkeyResetKey) }
    }

    var hotkeyToggle: HotkeyBinding {
        get { loadBinding(modKey: Keys.hotkeyToggleMod, codeKey: Keys.hotkeyToggleKey, fallback: .defaultToggle) }
        set { saveBinding(newValue, modKey: Keys.hotkeyToggleMod, codeKey: Keys.hotkeyToggleKey) }
    }

    private func loadBinding(modKey: String, codeKey: String, fallback: HotkeyBinding) -> HotkeyBinding {
        guard defaults.object(forKey: modKey) != nil else { return fallback }
        let mod = UInt(defaults.integer(forKey: modKey))
        let code = UInt16(defaults.integer(forKey: codeKey))
        return HotkeyBinding(modifiers: mod, keyCode: code)
    }

    private func saveBinding(_ binding: HotkeyBinding, modKey: String, codeKey: String) {
        defaults.set(Int(binding.modifiers), forKey: modKey)
        defaults.set(Int(binding.keyCode), forKey: codeKey)
        NotificationCenter.default.post(name: .preferencesShortcutsDidChange, object: nil)
    }

    // MARK: - Reset to defaults

    func resetColorsToDefaults() {
        defaults.removeObject(forKey: Keys.pillBackgroundColor)
        defaults.removeObject(forKey: Keys.textColor)
        defaults.removeObject(forKey: Keys.cornerRadius)
        NotificationCenter.default.post(name: .preferencesColorsDidChange, object: nil)
    }

    func resetShortcutsToDefaults() {
        defaults.removeObject(forKey: Keys.hotkeyStartPauseMod)
        defaults.removeObject(forKey: Keys.hotkeyStartPauseKey)
        defaults.removeObject(forKey: Keys.hotkeyResetMod)
        defaults.removeObject(forKey: Keys.hotkeyResetKey)
        defaults.removeObject(forKey: Keys.hotkeyToggleMod)
        defaults.removeObject(forKey: Keys.hotkeyToggleKey)
        NotificationCenter.default.post(name: .preferencesShortcutsDidChange, object: nil)
    }

    func resetAllToDefaults() {
        resetColorsToDefaults()
        resetShortcutsToDefaults()
    }
}
