import SwiftUI
import BubombCore
#if canImport(AppKit)
import AppKit

/// Controls creation, display, and lifecycle of native macOS windows for Bubomb.
@MainActor
public final class WindowManager: NSObject, NSWindowDelegate {
    public static let shared = WindowManager()

    private var settingsWindow: NSWindow?

    override private init() {
        super.init()
    }

    /// Opens or brings the Settings window to the front.
    public func showSettingsWindow(settingsStore: SettingsStore = .shared, executor: PayloadExecutor? = nil) {
        let exec = executor ?? PayloadExecutor.shared
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView(settingsStore: settingsStore, executor: exec)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Bubomb Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        window.setContentSize(NSSize(width: 680, height: 580))
        window.center()

        self.settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func closeSettingsWindow() {
        settingsWindow?.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        // Keep window reference around for fast reopening
    }
}
#endif
