import SwiftUI
import BubombCore
#if canImport(AppKit)
import AppKit
#endif

/// Displays execution results, live console output, status badges, and history.
@MainActor
public struct ExecutionStatusView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var executor: PayloadExecutor

    @State private var selectedRecordId: UUID? = nil
    @State private var copiedNotice: Bool = false

    public init(settingsStore: SettingsStore = .shared, executor: PayloadExecutor? = nil) {
        self.settingsStore = settingsStore
        self.executor = executor ?? PayloadExecutor.shared
    }

    private var activeRecord: ExecutionRecord? {
        if let id = selectedRecordId {
            return settingsStore.settings.recentExecutions.first(where: { $0.id == id })
        }
        return settingsStore.settings.recentExecutions.first
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                liveStatusSection
                currentRecordDetailsSection
                outputConsoleSection
                historySection
            }
            .padding(18)
        }
        .background(BubombTheme.windowBackground)
    }

    // MARK: - Live Status Section

    private var liveStatusSection: some View {
        HStack(spacing: 12) {
            switch executor.currentState {
            case .idle:
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundColor(BubombTheme.accentOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bubomb Armed & Ready")
                        .font(.headline)
                        .foregroundColor(BubombTheme.textPrimary)
                    Text("Click the bomb in your menu bar to detonate.")
                        .font(.caption)
                        .foregroundColor(BubombTheme.textSecondary)
                }

            case .burning(let name, let info):
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Detonating: \(name)")
                        .font(.headline)
                        .foregroundColor(BubombTheme.accentOrange)
                    Text(info ?? "Executing action...")
                        .font(.caption)
                        .foregroundColor(BubombTheme.textSecondary)
                }

            case .exploded(let record):
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(BubombTheme.successGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Detonation Succeeded!")
                        .font(.headline)
                        .foregroundColor(BubombTheme.successGreen)
                    Text("Finished in \(record.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(BubombTheme.textSecondary)
                }

            case .failed(let record):
                Image(systemName: "xmark.octagon.fill")
                    .font(.title2)
                    .foregroundColor(BubombTheme.failureRed)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Detonation Failed")
                        .font(.headline)
                        .foregroundColor(BubombTheme.failureRed)
                    Text(record.errorMessage ?? "An error occurred during execution.")
                        .font(.caption)
                        .foregroundColor(BubombTheme.failureRed)
                }
            }

            Spacer()

            if executor.currentState.isRunning {
                Button("Cancel") {
                    executor.cancel()
                }
                .buttonStyle(.bordered)
                .tint(BubombTheme.failureRed)
            }
        }
        .bubombCard()
    }

    // MARK: - Current Record Details

    @ViewBuilder
    private var currentRecordDetailsSection: some View {
        if let record = activeRecord {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Execution Details: \(record.payloadName)")
                        .font(.subheadline.bold())
                        .foregroundColor(BubombTheme.textPrimary)
                    Spacer()
                    statusBadge(for: record.status)
                }

                Divider().background(BubombTheme.borderSubtle)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text("Payload Type:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                        Text(record.payloadTypeDescription).font(.caption.bold()).foregroundColor(BubombTheme.textPrimary)
                    }
                    GridRow {
                        Text("Timestamp:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                        Text(record.startedAt.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundColor(BubombTheme.textPrimary)
                    }
                    GridRow {
                        Text("Duration:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                        Text(record.formattedDuration).font(.caption.monospaced()).foregroundColor(BubombTheme.accentOrange)
                    }
                    if let code = record.exitCode {
                        GridRow {
                            Text("Exit Status:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                            Text("\(code)").font(.caption.monospaced().bold()).foregroundColor(code == 0 ? BubombTheme.successGreen : BubombTheme.failureRed)
                        }
                    }
                    if let err = record.errorMessage {
                        GridRow {
                            Text("Error Details:").font(.caption).foregroundColor(BubombTheme.failureRed)
                            Text(err).font(.caption).foregroundColor(BubombTheme.failureRed)
                        }
                    }
                }
            }
            .bubombCard()
        }
    }

    // MARK: - Output Console

    private var outputConsoleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Detonation Log Output")
                    .font(.caption.bold())
                    .foregroundColor(BubombTheme.textSecondary)

                Spacer()

                if copiedNotice {
                    Text("Copied!").font(.caption).foregroundColor(BubombTheme.successGreen)
                }

                Button(action: {
                    copyOutputToClipboard()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc").font(.caption)
                        Text("Copy").font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(BubombTheme.accentAmber)
            }

            let log = activeRecord?.combinedOutput ?? "No logs recorded yet. Detonate a payload to see captured stdout/stderr here."

            ScrollView(.vertical) {
                Text(log)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color.green.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 140)
            .background(Color.black.opacity(0.6))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(BubombTheme.borderSubtle, lineWidth: 1))
        }
        .bubombCard()
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Detonations (\(settingsStore.settings.recentExecutions.count))")
                    .font(.subheadline.bold())
                    .foregroundColor(BubombTheme.textPrimary)

                Spacer()

                if !settingsStore.settings.recentExecutions.isEmpty {
                    Button("Clear History") {
                        settingsStore.clearHistory()
                        selectedRecordId = nil
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(BubombTheme.failureRed)
                }
            }

            if settingsStore.settings.recentExecutions.isEmpty {
                Text("No detonations recorded yet.")
                    .font(.caption)
                    .foregroundColor(BubombTheme.textMuted)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(settingsStore.settings.recentExecutions) { item in
                        Button(action: {
                            selectedRecordId = item.id
                        }) {
                            HStack {
                                Circle()
                                    .fill(statusColor(for: item.status))
                                    .frame(width: 8, height: 8)

                                Text(item.payloadName)
                                    .font(.caption.bold())
                                    .foregroundColor(BubombTheme.textPrimary)

                                Text("(\(item.payloadTypeDescription))")
                                    .font(.caption2)
                                    .foregroundColor(BubombTheme.textMuted)

                                Spacer()

                                Text(item.formattedDuration)
                                    .font(.caption2.monospaced())
                                    .foregroundColor(BubombTheme.textSecondary)

                                Text(item.startedAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(BubombTheme.textSecondary)
                            }
                            .padding(8)
                            .background(
                                (selectedRecordId == item.id || (selectedRecordId == nil && settingsStore.settings.recentExecutions.first?.id == item.id))
                                ? BubombTheme.accentOrange.opacity(0.15)
                                : Color.black.opacity(0.2)
                            )
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .bubombCard()
    }

    // MARK: - Helpers

    private func statusBadge(for status: ExecutionStatus) -> some View {
        Text(status.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor(for: status).opacity(0.2))
            .foregroundColor(statusColor(for: status))
            .cornerRadius(4)
    }

    private func statusColor(for status: ExecutionStatus) -> Color {
        switch status {
        case .succeeded: return BubombTheme.successGreen
        case .failed: return BubombTheme.failureRed
        case .cancelled: return BubombTheme.accentAmber
        case .timedOut: return BubombTheme.accentPurple
        }
    }

    private func copyOutputToClipboard() {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let content = activeRecord?.combinedOutput ?? ""
        pasteboard.setString(content, forType: .string)
        copiedNotice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedNotice = false
        }
        #endif
    }
}
