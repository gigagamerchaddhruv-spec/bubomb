import Foundation

/// A complete configured payload in Bubomb.
public struct Payload: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var type: PayloadType
    public var requiresConfirmation: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "My Action",
        type: PayloadType = .shellCommand(ShellConfig()),
        requiresConfirmation: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.requiresConfirmation = requiresConfirmation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Validates this payload against system requirements and filesystem paths.
    public func validate() throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw ExecutionError.invalidConfiguration("Payload name cannot be empty.")
        }

        switch type {
        case .shellCommand(let config):
            let trimmedCmd = config.command.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedCmd.isEmpty {
                throw ExecutionError.invalidConfiguration("Command cannot be empty.")
            }
            if !config.shellPath.isEmpty {
                _ = try PathValidator.validateExecutable(at: config.shellPath).get()
            }
            if let workDir = config.workingDirectory {
                _ = try PathValidator.validateWorkingDirectory(workDir).get()
            }

        case .openApplication(let config):
            let trimmedApp = config.applicationPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedApp.isEmpty {
                throw ExecutionError.invalidConfiguration("Application path cannot be empty.")
            }
            _ = try PathValidator.validateApplication(at: trimmedApp).get()

        case .openURL(let config):
            _ = try PathValidator.validateURL(config.urlString).get()

        case .runScript(let config):
            let trimmedScript = config.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedScript.isEmpty {
                throw ExecutionError.invalidConfiguration("Script path cannot be empty.")
            }
            _ = try PathValidator.validateScript(at: trimmedScript).get()
            if let workDir = config.workingDirectory {
                _ = try PathValidator.validateWorkingDirectory(workDir).get()
            }

        case .sequence(let config):
            if config.steps.isEmpty {
                throw ExecutionError.invalidConfiguration("Multi-step sequence must have at least one step.")
            }
            for (index, step) in config.steps.enumerated() {
                switch step.action {
                case .openApplication(let path):
                    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        throw ExecutionError.invalidConfiguration("Step \(index + 1): Application path is empty.")
                    }
                    _ = try PathValidator.validateApplication(at: trimmed).get()
                case .openURL(let url):
                    _ = try PathValidator.validateURL(url).get()
                case .runCommand(let cmd, let workDir, _):
                    let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        throw ExecutionError.invalidConfiguration("Step \(index + 1): Command is empty.")
                    }
                    if let dir = workDir {
                        _ = try PathValidator.validateWorkingDirectory(dir).get()
                    }
                case .runScript(let path, _, let workDir, _):
                    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        throw ExecutionError.invalidConfiguration("Step \(index + 1): Script path is empty.")
                    }
                    _ = try PathValidator.validateScript(at: trimmed).get()
                    if let dir = workDir {
                        _ = try PathValidator.validateWorkingDirectory(dir).get()
                    }
                }
            }
        }
    }

    /// Evaluates if safety policy flags this payload as destructive.
    public var safetyRisk: SafetyPolicy.RiskLevel {
        switch type {
        case .shellCommand(let config):
            return SafetyPolicy.evaluate(command: config.command)
        case .runScript(let config):
            return SafetyPolicy.evaluate(command: config.scriptPath)
        case .sequence(let config):
            for step in config.steps {
                switch step.action {
                case .runCommand(let cmd, _, _):
                    let risk = SafetyPolicy.evaluate(command: cmd)
                    if risk.isDestructive { return risk }
                case .runScript(let script, _, _, _):
                    let risk = SafetyPolicy.evaluate(command: script)
                    if risk.isDestructive { return risk }
                default:
                    break
                }
            }
            return .safe
        default:
            return .safe
        }
    }
}
