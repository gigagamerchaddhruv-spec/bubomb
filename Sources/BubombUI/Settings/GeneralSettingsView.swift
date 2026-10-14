import SwiftUI
import BubombCore
#if canImport(ServiceManagement)
import ServiceManagement
#endif

/// General application preferences including login item, animations, and safety toggles.
@MainActor
public struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var showResetConfirmation: Bool = false

    public init(settingsStore: SettingsStore = .shared) {
        self.settingsStore = settingsStore
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                appIdentitySection
                systemIntegrationSection
                animationPreferenceSection
                safetySection
                dangerZoneSection
            }
            .padding(18)
        }
        .background(BubombTheme.windowBackground)
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                settingsStore.resetToDefaults()
            }
        } message: {
            Text("This will remove your configured payload, execution history, and restore factory defaults.")
        }
    }

    // MARK: - Sections

    private var appIdentitySection: some View {
        HStack(spacing: 16) {
            AnimatedBombView(size: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text("Bubomb")
                    .font(.title2.bold())
                    .foregroundColor(BubombTheme.textPrimary)

                Text("Configure the boom.")
                    .font(.subheadline)
                    .foregroundColor(BubombTheme.accentOrange)

                Text("Version \(AppSettings.currentVersion) (Build \(AppSettings.buildNumber)) • Native macOS")
                    .font(.caption2)
                    .foregroundColor(BubombTheme.textMuted)
            }
            Spacer()
        }
        .bubombCard()
    }

    private var systemIntegrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System & Startup")
                .font(.subheadline.bold())
                .foregroundColor(BubombTheme.accentOrange)

            Toggle("Launch Bubomb at Login", isOn: Binding(
                get: { settingsStore.settings.launchAtLogin },
                set: { newValue in
                    var s = settingsStore.settings
                    s.launchAtLogin = newValue
                    settingsStore.update(s)
                    toggleLaunchAtLogin(newValue)
                }
            ))
            .font(.subheadline)
            .foregroundColor(BubombTheme.textPrimary)

            Text("Automatically arms your menu bar bomb when your Mac starts.")
                .font(.caption)
                .foregroundColor(BubombTheme.textSecondary)

            Divider().background(BubombTheme.borderSubtle)

            Toggle("Start Silently in Menu Bar", isOn: Binding(
                get: { settingsStore.settings.startSilentlyInMenuBar },
                set: { newValue in
                    var s = settingsStore.settings
                    s.startSilentlyInMenuBar = newValue
                    settingsStore.update(s)
                }
            ))
            .font(.subheadline)
            .foregroundColor(BubombTheme.textPrimary)

            Text("When enabled, Bubomb starts without opening the Settings window.")
                .font(.caption)
                .foregroundColor(BubombTheme.textSecondary)
        }
        .bubombCard()
    }

    private var animationPreferenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visuals & Feedback")
                .font(.subheadline.bold())
                .foregroundColor(BubombTheme.accentOrange)

            Text("Menu Bar Animation Style:")
                .font(.caption)
                .foregroundColor(BubombTheme.textSecondary)

            Picker("", selection: Binding(
                get: { settingsStore.settings.animationPreference },
                set: { newValue in
                    var s = settingsStore.settings
                    s.animationPreference = newValue
                    settingsStore.update(s)
                }
            )) {
                ForEach(AnimationPreference.allCases, id: \.self) { pref in
                    Text(pref.rawValue).tag(pref)
                }
            }
            .labelsHidden()

            Divider().background(BubombTheme.borderSubtle)

            Toggle("Play subtle completion sound / haptic feedback", isOn: Binding(
                get: { settingsStore.settings.playCompletionFeedback },
                set: { newValue in
                    var s = settingsStore.settings
                    s.playCompletionFeedback = newValue
                    settingsStore.update(s)
                }
            ))
            .font(.subheadline)
            .foregroundColor(BubombTheme.textPrimary)
        }
        .bubombCard()
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety & Protection")
                .font(.subheadline.bold())
                .foregroundColor(BubombTheme.accentOrange)

            Toggle("Require explicit confirmation for destructive actions", isOn: Binding(
                get: { settingsStore.settings.confirmDestructiveActions },
                set: { newValue in
                    var s = settingsStore.settings
                    s.confirmDestructiveActions = newValue
                    settingsStore.update(s)
                }
            ))
            .font(.subheadline)
            .foregroundColor(BubombTheme.textPrimary)

            Text("Guards against accidental execution of destructive patterns (e.g. recursive removals, raw disk writes).")
                .font(.caption)
                .foregroundColor(BubombTheme.textSecondary)
        }
        .bubombCard()
    }

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reset")
                .font(.subheadline.bold())
                .foregroundColor(BubombTheme.failureRed)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset Bubomb Settings")
                        .font(.subheadline)
                        .foregroundColor(BubombTheme.textPrimary)
                    Text("Restores all settings, clears history, and unarms active payload.")
                        .font(.caption)
                        .foregroundColor(BubombTheme.textSecondary)
                }
                Spacer()
                Button("Reset Defaults...") {
                    showResetConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(BubombTheme.failureRed)
            }
        }
        .bubombCard()
    }

    // MARK: - Helper

    private func toggleLaunchAtLogin(_ enable: Bool) {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                // If service management registration fails in dev mode, non-fatal
                print("Launch at login registration notice: \(error)")
            }
        }
        #endif
    }
}
