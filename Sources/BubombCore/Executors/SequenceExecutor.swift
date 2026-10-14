import Foundation

/// Executes a sequence of payload steps in defined order with progress updates and failure policies.
public final class SequenceExecutor: @unchecked Sendable {
    public typealias ProgressHandler = @Sendable (Int, Int, String) -> Void

    private let state = SequenceState()

    public init() {}

    public func execute(
        config: SequenceConfig,
        progress: ProgressHandler? = nil
    ) async throws -> ExecutionResult {
        let startTime = Date()
        let totalSteps = config.steps.count
        guard totalSteps > 0 else {
            throw ExecutionError.invalidConfiguration("Sequence has no steps configured.")
        }

        var fullStdout = ""
        var fullStderr = ""

        for (index, step) in config.steps.enumerated() {
            if await state.checkCancelled() {
                throw ExecutionError.cancelled
            }

            progress?(index + 1, totalSteps, step.name)

            let stepHeader = "--- [Step \(index + 1)/\(totalSteps): \(step.name)] ---\n"
            fullStdout += stepHeader

            do {
                let result = try await executeStep(step)
                if !result.stdout.isEmpty {
                    fullStdout += result.stdout + (result.stdout.hasSuffix("\n") ? "" : "\n")
                }
                if !result.stderr.isEmpty {
                    fullStderr += "[\(step.name) stderr]: " + result.stderr + (result.stderr.hasSuffix("\n") ? "" : "\n")
                }
            } catch {
                let errString = error.localizedDescription
                let failureLog = "❌ Step \(index + 1) failed: \(errString)\n"
                fullStderr += failureLog

                if config.stopOnError {
                    throw ExecutionError.stepFailed(stepIndex: index, stepName: step.name, reason: errString)
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return ExecutionResult(
            exitCode: 0,
            stdout: fullStdout,
            stderr: fullStderr,
            duration: duration
        )
    }

    private func executeStep(_ step: SequenceStep) async throws -> ExecutionResult {
        switch step.action {
        case .openApplication(let appPath):
            let launcher = ApplicationLauncher()
            return try await launcher.launch(appPath: appPath)

        case .openURL(let urlString):
            let launcher = URLLauncher()
            return try await launcher.open(urlString: urlString)

        case .runCommand(let cmd, let workDir, let timeout):
            let executor = ShellCommandExecutor()
            await state.setShell(executor)
            defer {
                Task { await self.state.setShell(nil) }
            }
            let shellConfig = ShellConfig(
                command: cmd,
                shellPath: "/bin/zsh",
                workingDirectory: workDir,
                timeoutSeconds: timeout
            )
            return try await executor.execute(config: shellConfig)

        case .runScript(let scriptPath, let args, let workDir, let timeout):
            let executor = ScriptExecutor()
            await state.setScript(executor)
            defer {
                Task { await self.state.setScript(nil) }
            }
            let scriptConfig = ScriptConfig(
                scriptPath: scriptPath,
                arguments: args,
                workingDirectory: workDir,
                timeoutSeconds: timeout
            )
            return try await executor.execute(config: scriptConfig)
        }
    }

    public func cancel() {
        Task {
            await state.cancel()
        }
    }
}

private actor SequenceState {
    private var isCancelled = false
    private var shellExecutor: ShellCommandExecutor?
    private var scriptExecutor: ScriptExecutor?

    func setShell(_ executor: ShellCommandExecutor?) {
        self.shellExecutor = executor
    }

    func setScript(_ executor: ScriptExecutor?) {
        self.scriptExecutor = executor
    }

    func cancel() {
        self.isCancelled = true
        shellExecutor?.cancel()
        scriptExecutor?.cancel()
    }

    func checkCancelled() -> Bool {
        return isCancelled
    }
}
