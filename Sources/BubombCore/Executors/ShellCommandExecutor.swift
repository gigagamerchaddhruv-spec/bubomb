import Foundation

/// Executes shell commands using an explicit shell or direct binary invocation.
public final class ShellCommandExecutor: @unchecked Sendable {
    private let runner = ProcessRunner()

    public init() {}

    public func execute(config: ShellConfig) async throws -> ExecutionResult {
        // Validate working directory if specified
        if let workDir = config.workingDirectory {
            _ = try PathValidator.validateWorkingDirectory(workDir).get()
        }

        let trimmedCommand = config.command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else {
            throw ExecutionError.invalidConfiguration("Command cannot be empty.")
        }

        let executableURL: URL
        let arguments: [String]

        let shell = config.shellPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !shell.isEmpty {
            // Validate shell executable exists
            let validShell = try PathValidator.validateExecutable(at: shell).get()
            executableURL = URL(fileURLWithPath: validShell)

            var fullCommand = trimmedCommand
            if !config.arguments.isEmpty {
                let appended = config.arguments.map { arg -> String in
                    if arg.contains(" ") || arg.contains("\"") {
                        return "\"\(arg.replacingOccurrences(of: "\"", with: "\\\""))\""
                    }
                    return arg
                }.joined(separator: " ")
                fullCommand += " " + appended
            }
            arguments = ["-c", fullCommand]
        } else {
            // Direct binary invocation
            let components = trimmedCommand.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let binaryName = components.first else {
                throw ExecutionError.invalidConfiguration("No binary specified.")
            }
            let validBinary = try PathValidator.validateExecutable(at: binaryName).get()
            executableURL = URL(fileURLWithPath: validBinary)
            arguments = Array(components.dropFirst()) + config.arguments
        }

        return try await runner.run(
            executableURL: executableURL,
            arguments: arguments,
            workingDirectory: config.workingDirectory,
            environment: config.environmentVariables,
            timeoutSeconds: config.timeoutSeconds
        )
    }

    public func cancel() {
        runner.cancel()
    }
}
