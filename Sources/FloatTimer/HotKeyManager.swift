import AppKit
import Carbon.HIToolbox

class HotKeyManager {
    private let timerEngine: TimerEngine
    private weak var overlayPanel: TimerOverlayPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // Default shortcuts:
    //   Ctrl+Shift+S = Start / Pause / Resume
    //   Ctrl+Shift+R = Reset (stop)
    //   Ctrl+Shift+T = Toggle show / hide

    init(timerEngine: TimerEngine, overlayPanel: TimerOverlayPanel) {
        self.timerEngine = timerEngine
        self.overlayPanel = overlayPanel
        registerShortcuts()
    }

    private func registerShortcuts() {
        // Global monitor: fires when OTHER apps have focus
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor: fires when OUR app has focus
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let prefs = Preferences.shared

        let startPause = prefs.hotkeyStartPause
        let reset = prefs.hotkeyReset
        let toggle = prefs.hotkeyToggle

        if flags.rawValue == startPause.modifiers && event.keyCode == startPause.keyCode {
            if timerEngine.state == .idle {
                let duration = prefs.lastDuration ?? 300
                timerEngine.start(duration: duration)
            } else {
                timerEngine.togglePauseResume()
            }
        } else if flags.rawValue == reset.modifiers && event.keyCode == reset.keyCode {
            timerEngine.reset()
        } else if flags.rawValue == toggle.modifiers && event.keyCode == toggle.keyCode {
            if let panel = overlayPanel {
                if panel.isVisible {
                    panel.hideOverlay()
                } else {
                    panel.showOverlay()
                }
            }
        }
    }

    func unregisterAll() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    /// Prompt user to grant Accessibility permission (required for global hotkeys)
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    deinit {
        unregisterAll()
    }
}
