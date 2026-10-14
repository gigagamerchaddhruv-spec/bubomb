import Foundation

public struct ShellConfig: Codable, Equatable, Hashable, Sendable {
    public var command: String
    public var shellPath: String
    public var arguments: [String]
    public var workingDirectory: String?
    public var environmentVariables: [String: String]
    public var timeoutSeconds: TimeInterval?

    public init(
        command: String = "",
        shellPath: String = "/bin/zsh",
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environmentVariables: [String: String] = [:],
        timeoutSeconds: TimeInterval? = 30
    ) {
        self.command = command
        self.shellPath = shellPath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environmentVariables = environmentVariables
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct AppConfig: Codable, Equatable, Hashable, Sendable {
    public var applicationPath: String
    public var arguments: [String]

    public init(applicationPath: String = "", arguments: [String] = []) {
        self.applicationPath = applicationPath
        self.arguments = arguments
    }
}

public struct URLConfig: Codable, Equatable, Hashable, Sendable {
    public var urlString: String

    public init(urlString: String = "https://") {
        self.urlString = urlString
    }
}

public struct ScriptConfig: Codable, Equatable, Hashable, Sendable {
    public var scriptPath: String
    public var arguments: [String]
    public var workingDirectory: String?
    public var environmentVariables: [String: String]
    public var timeoutSeconds: TimeInterval?

    public init(
        scriptPath: String = "",
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environmentVariables: [String: String] = [:],
        timeoutSeconds: TimeInterval? = 60
    ) {
        self.scriptPath = scriptPath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environmentVariables = environmentVariables
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct SequenceConfig: Codable, Equatable, Hashable, Sendable {
    public var steps: [SequenceStep]
    public var stopOnError: Bool

    public init(steps: [SequenceStep] = [], stopOnError: Bool = true) {
        self.steps = steps
        self.stopOnError = stopOnError
    }
}

/// The specific payload types supported by Bubomb.
public enum PayloadType: Codable, Equatable, Hashable, Sendable {
    case shellCommand(ShellConfig)
    case openApplication(AppConfig)
    case openURL(URLConfig)
    case runScript(ScriptConfig)
    case sequence(SequenceConfig)

    public var typeDisplayName: String {
        switch self {
        case .shellCommand: return "Shell Command"
        case .openApplication: return "Open Application"
        case .openURL: return "Open URL"
        case .runScript: return "Run Script"
        case .sequence: return "Multi-step Sequence"
        }
    }

    public var iconName: String {
        switch self {
        case .shellCommand: return "terminal.fill"
        case .openApplication: return "app.badge.fill"
        case .openURL: return "link"
        case .runScript: return "doc.text.fill"
        case .sequence: return "list.bullet.rectangle.fill"
        }
    }
}
