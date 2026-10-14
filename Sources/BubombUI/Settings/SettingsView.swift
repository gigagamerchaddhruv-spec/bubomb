import SwiftUI
import BubombCore

/// Main Settings Window for Bubomb.
@MainActor
public struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var executor: PayloadExecutor

    @State private var selectedTab: Int = 0

    public init(settingsStore: SettingsStore = .shared, executor: PayloadExecutor? = nil) {
        self.settingsStore = settingsStore
        self.executor = executor ?? PayloadExecutor.shared
    }

    public var body: some View {
        VStack(spacing: 0) {
            topTabBar

            Divider().background(BubombTheme.borderSubtle)

            Group {
                switch selectedTab {
                case 0:
                    PayloadEditorView(settingsStore: settingsStore, executor: executor)
                case 1:
                    ExecutionStatusView(settingsStore: settingsStore, executor: executor)
                case 2:
                    GeneralSettingsView(settingsStore: settingsStore)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 520, idealHeight: 580)
        .background(BubombTheme.windowBackground)
    }

    // MARK: - Top Tab Bar

    private var topTabBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                AnimatedBombView(size: 28, isDetonating: executor.currentState.isRunning)
                Text("Bubomb")
                    .font(.headline.bold())
                    .foregroundColor(BubombTheme.textPrimary)
            }
            .padding(.leading, 8)

            Spacer()

            Picker("", selection: $selectedTab) {
                Label("Payload", systemImage: "flame.fill").tag(0)
                Label("Execution", systemImage: "clock.arrow.circlepath").tag(1)
                Label("General", systemImage: "gearshape.fill").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            .labelsHidden()

            Spacer()

            // Armed Status Pill
            if settingsStore.settings.activePayload != nil {
                HStack(spacing: 5) {
                    Circle().fill(BubombTheme.successGreen).frame(width: 6, height: 6)
                    Text("Armed")
                        .font(.caption2.bold())
                        .foregroundColor(BubombTheme.successGreen)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(BubombTheme.successGreen.opacity(0.12))
                .cornerRadius(12)
            } else {
                HStack(spacing: 5) {
                    Circle().fill(BubombTheme.accentAmber).frame(width: 6, height: 6)
                    Text("Unarmed")
                        .font(.caption2.bold())
                        .foregroundColor(BubombTheme.accentAmber)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(BubombTheme.accentAmber.opacity(0.12))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(BubombTheme.surface)
    }
}
