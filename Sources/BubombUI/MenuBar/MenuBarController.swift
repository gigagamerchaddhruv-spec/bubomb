import SwiftUI
import BubombCore
#if canImport(AppKit)
import AppKit

/// Manages the native macOS NSStatusItem, click routing (left=detonate, right=menu),
/// and dynamic menu bar icon animations.
@MainActor
public final class MenuBarController: NSObject {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private let settingsStore: SettingsStore
    private let executor: PayloadExecutor
    private var animationTimer: Timer?
    private var currentFrame: Int = 0

    public init(settingsStore: SettingsStore = .shared, executor: PayloadExecutor? = nil) {
        self.settingsStore = settingsStore
        self.executor = executor ?? PayloadExecutor.shared
        super.init()
    }

    /// Configures the NSStatusItem in the macOS menu bar.
    public func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
        }

        self.statusItem = item
        updateIcon()

        // Observe state changes on executor
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStateChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        // Observe executor currentState directly via a polling/timer or binding
        startStateObservation()
    }

    // MARK: - Click Handling

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            handlePrimaryClick()
            return
        }

        let isRightClick = event.type == .rightMouseUp
        let isControlLeftClick = event.type == .leftMouseUp && event.modifierFlags.contains(.control)

        if isRightClick || isControlLeftClick {
            showContextMenu()
        } else {
            handlePrimaryClick()
        }
    }

    /// Left-click interaction: Detonates configured action instantly, or opens settings if unconfigured.
    public func handlePrimaryClick() {
        guard let payload = settingsStore.settings.activePayload else {
            // Unconfigured: Open settings immediately
            WindowManager.shared.showSettingsWindow(settingsStore: settingsStore, executor: executor)
            return
        }

        // If already running, prevent duplicate or show notice
        if executor.currentState.isRunning {
            return
        }

        // Check if confirmation is required
        let alwaysConfirm = settingsStore.settings.confirmDestructiveActions
        let (requiresConfirm, _) = SafetyPolicy.requiresConfirmation(
            command: commandStringForPayload(payload),
            userSettingAlwaysConfirmDestructive: alwaysConfirm || payload.requiresConfirmation
        )

        if requiresConfirm {
            // Show alert or open settings to confirm
            WindowManager.shared.showSettingsWindow(settingsStore: settingsStore, executor: executor)
            return
        }

        // Detonate directly!
        Task {
            do {
                _ = try await executor.detonate(payload: payload, ignoreSafetyConfirmation: false)
            } catch {
                print("Detonation finished with notice: \(error.localizedDescription)")
            }
        }
    }

    /// Right-click menu with configuration and power options.
    public func showContextMenu() {
        guard let item = statusItem, let button = item.button else { return }

        let menu = NSMenu()

        // App title & Armed status
        let titleItem = NSMenuItem(title: "Bubomb", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "💣 Bubomb — Configure the boom",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        menu.addItem(titleItem)

        if let active = settingsStore.settings.activePayload {
            let armedItem = NSMenuItem(title: "Armed: \(active.name)", action: nil, keyEquivalent: "")
            armedItem.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
            menu.addItem(armedItem)
        } else {
            let unarmedItem = NSMenuItem(title: "No Payload Armed", action: nil, keyEquivalent: "")
            unarmedItem.image = NSImage(systemSymbolName: "exclamationmark.circle", accessibilityDescription: nil)
            menu.addItem(unarmedItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Detonate action
        let detonateItem = NSMenuItem(title: "Detonate Payload", action: #selector(menuDetonateClicked), keyEquivalent: "\r")
        detonateItem.target = self
        detonateItem.isEnabled = (settingsStore.settings.activePayload != nil) && !executor.currentState.isRunning
        detonateItem.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)
        menu.addItem(detonateItem)

        if executor.currentState.isRunning {
            let cancelItem = NSMenuItem(title: "Cancel Detonation", action: #selector(menuCancelClicked), keyEquivalent: ".")
            cancelItem.target = self
            cancelItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
            menu.addItem(cancelItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsMenuItem = NSMenuItem(title: "Settings...", action: #selector(menuSettingsClicked), keyEquivalent: ",")
        settingsMenuItem.target = self
        settingsMenuItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Bubomb", action: #selector(menuQuitClicked), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)

        item.menu = menu
        button.performClick(nil)
        item.menu = nil
    }

    // MARK: - Menu Actions

    @objc private func menuDetonateClicked() {
        handlePrimaryClick()
    }

    @objc private func menuCancelClicked() {
        executor.cancel()
    }

    @objc private func menuSettingsClicked() {
        WindowManager.shared.showSettingsWindow(settingsStore: settingsStore, executor: executor)
    }

    @objc private func menuQuitClicked() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func handleStateChanged() {
        updateIcon()
    }

    // MARK: - Animation & State Updates

    private func startStateObservation() {
        // Lightweight polling timer (60ms) to sync menu bar icon with executor state
        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncStateWithExecutor()
            }
        }
    }

    private var previousState: DetonationState = .idle

    private func syncStateWithExecutor() {
        let state = executor.currentState
        if state != previousState {
            previousState = state
            onStateTransition(to: state)
        }
    }

    private func onStateTransition(to state: DetonationState) {
        animationTimer?.invalidate()
        animationTimer = nil
        currentFrame = 0

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ||
            (settingsStore.settings.animationPreference == .none)

        switch state {
        case .idle:
            updateIcon()

        case .burning:
            if reduceMotion {
                statusItem?.button?.image = BombIconRenderer.menuBarImage(state: .burning(frame: 0))
            } else {
                animationTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.currentFrame = (self.currentFrame + 1) % 4
                        self.statusItem?.button?.image = BombIconRenderer.menuBarImage(state: .burning(frame: self.currentFrame))
                    }
                }
            }

        case .exploded:
            if settingsStore.settings.playCompletionFeedback {
                NSSound.beep()
            }
            if reduceMotion {
                statusItem?.button?.image = BombIconRenderer.menuBarImage(state: .exploded(frame: 2))
            } else {
                // 3 quick frames for explosion burst
                var burstFrame = 0
                animationTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] timer in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        burstFrame += 1
                        if burstFrame < 4 {
                            self.statusItem?.button?.image = BombIconRenderer.menuBarImage(state: .exploded(frame: burstFrame))
                        } else {
                            timer.invalidate()
                            self.updateIcon()
                        }
                    }
                }
            }

        case .failed:
            statusItem?.button?.image = BombIconRenderer.menuBarImage(state: .failed)
        }
    }

    private func updateIcon() {
        if settingsStore.settings.activePayload == nil {
            statusItem?.button?.image = BombIconRenderer.menuBarImage(state: .unconfigured)
            statusItem?.button?.toolTip = "Bubomb (Unconfigured) — Click to setup payload"
        } else {
            statusItem?.button?.image = BombIconRenderer.menuBarImage(state: .idle)
            statusItem?.button?.toolTip = "Bubomb: Detonate '\(settingsStore.settings.activePayload?.name ?? "")'"
        }
    }

    private func commandStringForPayload(_ payload: Payload) -> String {
        switch payload.type {
        case .shellCommand(let config):
            return config.command
        case .runScript(let config):
            return config.scriptPath
        default:
            return ""
        }
    }
}
#endif
