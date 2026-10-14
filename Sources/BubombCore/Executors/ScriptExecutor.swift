import Foundation

/// Executes local scripts safely without mutating file permissions or user scripts.
public final class ScriptExecutor: @unchecked Sendable {
    private let runner = ProcessRunner()

    public init() {}

    public func execute(config: ScriptConfig) async throws -> ExecutionResult {
        let validPath = try PathValidator.validateScript(at: config.scriptPath).get()

        if let workDir = config.workingDirectory {
            _ = try PathValidator.validateWorkingDirectory(workDir).get()
        }

        let isExecutable = FileManager.default.isExecutableFile(atPath: validPath)
        let (interpreterURL, leadingArgs) = resolveInterpreter(forScriptAt: validPath, isExecutable: isExecutable)

        var finalArgs = leadingArgs
        finalArgs.append(validPath)
        finalArgs.append(contentsOf: config.arguments)

        return try await runner.run(
            executableURL: interpreterURL,
            arguments: finalArgs,
            workingDirectory: config.workingDirectory,
            environment: config.environmentVariables,
            timeoutSeconds: config.timeoutSeconds
        )
    }

    public func cancel() {
        runner.cancel()
    }

    /// Determines the appropriate interpreter for a script based on its shebang or file extension.
    private func resolveInterpreter(forScriptAt path: String, isExecutable: Bool) -> (interpreterURL: URL, leadingArgs: [String]) {
        // First check shebang
        if let fileHandle = FileHandle(forReadingAtPath: path) {
            defer { try? fileHandle.close() }
            let headerData = fileHandle.readData(ofLength: 256)
            if let headerString = String(data: headerData, encoding: .utf8), headerString.hasPrefix("#!") {
                let firstLine = headerString.components(separatedBy: .newlines).first ?? ""
                let shebangBody = firstLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
                let tokens = shebangBody.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let interpreter = tokens.first {
                    if interpreter == "/usr/bin/env" && tokens.count > 1 {
                        let actualBin = tokens[1]
                        return (URL(fileURLWithPath: "/usr/bin/env"), [actualBin])
                    } else if FileManager.default.isExecutableFile(atPath: interpreter) {
                        return (URL(fileURLWithPath: interpreter), Array(tokens.dropFirst()))
                    }
                }
            }
        }

        // If file is directly marked executable and no shebang, run directly
        if isExecutable {
            return (URL(fileURLWithPath: path), [])
        }

        // Fallback by extension
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "sh", "zsh", "bash":
            return (URL(fileURLWithPath: "/bin/zsh"), [])
        case "py":
            return (URL(fileURLWithPath: "/usr/bin/python3"), [])
        case "rb":
            return (URL(fileURLWithPath: "/usr/bin/ruby"), [])
        case "pl":
            return (URL(fileURLWithPath: "/usr/bin/perl"), [])
        default:
            return (URL(fileURLWithPath: "/bin/sh"), [])
        }
    }
}
