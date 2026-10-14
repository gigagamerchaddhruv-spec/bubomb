import Foundation

/// Individual step within a Multi-step Sequence payload.
public struct SequenceStep: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var action: StepAction

    public init(id: UUID = UUID(), name: String, action: StepAction) {
        self.id = id
        self.name = name
        self.action = action
    }

    public enum StepAction: Codable, Equatable, Hashable, Sendable {
        case openApplication(applicationPath: String)
        case openURL(urlString: String)
        case runCommand(command: String, workingDirectory: String?, timeoutSeconds: TimeInterval?)
        case runScript(scriptPath: String, arguments: [String], workingDirectory: String?, timeoutSeconds: TimeInterval?)
    }

    public var actionTypeTitle: String {
        switch action {
        case .openApplication: return "Open App"
        case .openURL: return "Open URL"
        case .runCommand: return "Shell Command"
        case .runScript: return "Run Script"
        }
    }

    public var summary: String {
        switch action {
        case .openApplication(let path):
            return (path as NSString).lastPathComponent
        case .openURL(let url):
            return url
        case .runCommand(let cmd, _, _):
            return cmd
        case .runScript(let path, _, _, _):
            return (path as NSString).lastPathComponent
        }
    }
}
