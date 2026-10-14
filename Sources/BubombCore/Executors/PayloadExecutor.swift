import Foundation
import Combine

/// Lifecycle state during payload detonation.
public enum DetonationState: Equatable, Sendable {
    case idle
    case burning(payloadName: String, progressInfo: String?)
    case exploded(record: ExecutionRecord)
    case failed(record: ExecutionRecord)

    public var isRunning: Bool {
        if case .burning = self { return true }
        return false
    }
}

/// Central coordinator for executing payloads safely, preventing duplicates,
/// broadcasting state changes, and recording history.
@MainActor
public final class PayloadExecutor: ObservableObject {
    public static let shared = PayloadExecutor()

    @Published public private(set) var currentState: DetonationState = .idle

    private let settingsStore: SettingsStore
    private var currentShellExecutor: ShellCommandExecutor?
    private var currentScriptExecutor: ScriptExecutor?
    private var currentSequenceExecutor: SequenceExecutor?

    public init(settingsStore: SettingsStore = .shared) {
        self.settingsStore = settingsStore
    }

    /// Detonates a payload immediately.
    /// - Parameters:
    ///   - payload: The payload to execute. If nil, uses the store's activePayload.
    ///   - ignoreSafetyConfirmation: Set to true only after the user explicitly confirmed a destructive action dialog.
    /// - Returns: The resulting ExecutionRecord.
    @discardableResult
    public func detonate(
        payload: Payload? = nil,
        ignoreSafetyConfirmation: Bool = false
    ) async throws -> ExecutionRecord {
        let targetPayload: Payload
        if let p = payload {
            targetPayload = p
        } else if let active = settingsStore.settings.activePayload {
            targetPayload = active
        } else {
            let error = ExecutionError.noPayloadConfigured
            let dummyRecord = ExecutionRecord(
                payloadId: UUID(),
                payloadName: "None",
                payloadTypeDescription: "None",
                startedAt: Date(),
                finishedAt: Date(),
                duration: 0,
                status: .failed,
                errorMessage: error.localizedDescription
            )
            self.currentState = .failed(record: dummyRecord)
            throw error
        }

        // Validate payload before launching
        do {
            try targetPayload.validate()
        } catch let err as ExecutionError {
            let record = ExecutionRecord(
                payloadId: targetPayload.id,
                payloadName: targetPayload.name,
                payloadTypeDescription: targetPayload.type.typeDisplayName,
                startedAt: Date(),
                finishedAt: Date(),
                duration: 0,
                status: .failed,
                errorMessage: err.localizedDescription
            )
            settingsStore.addExecutionRecord(record)
            self.currentState = .failed(record: record)
            throw err
        }

        // Safety check
        if !ignoreSafetyConfirmation {
            let alwaysConfirm = settingsStore.settings.confirmDestructiveActions
            let (requiresConfirm, _) = SafetyPolicy.requiresConfirmation(
                command: commandStringForPayload(targetPayload),
                userSettingAlwaysConfirmDestructive: alwaysConfirm || targetPayload.requiresConfirmation
            )
            if requiresConfirm {
                throw ExecutionError.destructiveActionRejected
            }
        }

        // Check duplicate execution
        if currentState.isRunning {
            throw ExecutionError.duplicateExecution
        }
        self.currentState = .burning(payloadName: targetPayload.name, progressInfo: "Detonating...")

        let startTime = Date()

        do {
            let result = try await executeInternal(payload: targetPayload)
            let finishedAt = Date()
            let duration = finishedAt.timeIntervalSince(startTime)

            let record = ExecutionRecord(
                payloadId: targetPayload.id,
                payloadName: targetPayload.name,
                payloadTypeDescription: targetPayload.type.typeDisplayName,
                startedAt: startTime,
                finishedAt: finishedAt,
                duration: duration,
                status: .succeeded,
                exitCode: result.exitCode,
                standardOutput: result.stdout,
                standardError: result.stderr,
                errorMessage: nil
            )

            settingsStore.addExecutionRecord(record)
            self.currentState = .exploded(record: record)

            // Reset back to idle after short delay to let animations complete
            scheduleIdleReset(delay: 1.2)
            return record

        } catch {
            let finishedAt = Date()
            let duration = finishedAt.timeIntervalSince(startTime)
            let errString = error.localizedDescription
            let exitCode: Int?

            if case .nonZeroExitStatus(let code, _) = (error as? ExecutionError) {
                exitCode = code
            } else {
                exitCode = nil
            }

            let status: ExecutionStatus
            if case .timeout = (error as? ExecutionError) {
                status = .timedOut
            } else if case .cancelled = (error as? ExecutionError) {
                status = .cancelled
            } else {
                status = .failed
            }

            let record = ExecutionRecord(
                payloadId: targetPayload.id,
                payloadName: targetPayload.name,
                payloadTypeDescription: targetPayload.type.typeDisplayName,
                startedAt: startTime,
                finishedAt: finishedAt,
                duration: duration,
                status: status,
                exitCode: exitCode,
                standardOutput: "",
                standardError: "",
                errorMessage: errString
            )

            settingsStore.addExecutionRecord(record)
            self.currentState = .failed(record: record)

            scheduleIdleReset(delay: 2.0)
            throw error
        }
    }

    /// Cancels any currently running payload execution.
    public func cancel() {
        currentShellExecutor?.cancel()
        currentScriptExecutor?.cancel()
        currentSequenceExecutor?.cancel()

        self.currentState = .idle
    }

    // MARK: - Private Helpers

    private func executeInternal(payload: Payload) async throws -> ExecutionResult {
        switch payload.type {
        case .shellCommand(let config):
            let executor = ShellCommandExecutor()
            self.currentShellExecutor = executor
            defer { self.currentShellExecutor = nil }
            return try await executor.execute(config: config)

        case .openApplication(let config):
            let launcher = ApplicationLauncher()
            return try await launcher.launch(appPath: config.applicationPath, arguments: config.arguments)

        case .openURL(let config):
            let launcher = URLLauncher()
            return try await launcher.open(urlString: config.urlString)

        case .runScript(let config):
            let executor = ScriptExecutor()
            self.currentScriptExecutor = executor
            defer { self.currentScriptExecutor = nil }
            return try await executor.execute(config: config)

        case .sequence(let config):
            let executor = SequenceExecutor()
            self.currentSequenceExecutor = executor
            defer { self.currentSequenceExecutor = nil }
            return try await executor.execute(config: config) { [weak self] stepIndex, totalSteps, stepName in
                Task { @MainActor [weak self] in
                    self?.currentState = .burning(
                        payloadName: payload.name,
                        progressInfo: "Step \(stepIndex)/\(totalSteps): \(stepName)"
                    )
                }
            }
        }
    }

    private func commandStringForPayload(_ payload: Payload) -> String {
        switch payload.type {
        case .shellCommand(let config):
            return config.command
        case .runScript(let config):
            return config.scriptPath
        case .sequence(let config):
            return config.steps.map { $0.summary }.joined(separator: " && ")
        default:
            return ""
        }
    }

    private func scheduleIdleReset(delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            if !self.currentState.isRunning {
                self.currentState = .idle
            }
        }
    }
}
