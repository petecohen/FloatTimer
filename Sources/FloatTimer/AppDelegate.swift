import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var timerEngine: TimerEngine!
    private var overlayPanel: TimerOverlayPanel!
    private var hotKeyManager: HotKeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        timerEngine = TimerEngine()
        overlayPanel = TimerOverlayPanel(timerEngine: timerEngine)
        statusBarController = StatusBarController(
            timerEngine: timerEngine,
            overlayPanel: overlayPanel
        )
        hotKeyManager = HotKeyManager(timerEngine: timerEngine, overlayPanel: overlayPanel)

        overlayPanel.restoreSavedPosition()

        // Prompt for Accessibility permission (needed for global hotkeys)
        HotKeyManager.requestAccessibilityPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlayPanel.savePosition()
        hotKeyManager.unregisterAll()
    }
}
