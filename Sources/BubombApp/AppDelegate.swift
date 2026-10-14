import AppKit
import BubombCore
import BubombUI

/// Main application delegate coordinating startup, menu bar presence, and menu shortcuts.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore.shared
    private let executor = PayloadExecutor.shared

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce menu bar accessory mode (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Install standard macOS edit and window menus so Cmd+C/V/A/Z/W work in text fields
        setupStandardMenus()

        // Initialize Menu Bar Status Item
        MenuBarController.shared.setup()

        // If no payload is armed or startSilentlyInMenuBar is disabled, show Settings window
        if settingsStore.settings.activePayload == nil || !settingsStore.settings.startSilentlyInMenuBar {
            WindowManager.shared.showSettingsWindow(settingsStore: settingsStore, executor: executor)
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar utility stays active when settings window is closed
        return false
    }

    private func setupStandardMenus() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Bubomb", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Bubomb", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit Menu (Essential for Cmd+C, Cmd+V, Cmd+X, Cmd+A, Cmd+Z in text boxes)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettings() {
        WindowManager.shared.showSettingsWindow(settingsStore: settingsStore, executor: executor)
    }

    @objc private func showAbout() {
        WindowManager.shared.showSettingsWindow(settingsStore: settingsStore, executor: executor)
    }
}
