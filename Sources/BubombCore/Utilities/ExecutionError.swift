import Foundation

/// Errors that can occur during Bubomb payload validation, execution, and persistence.
public enum ExecutionError: LocalizedError, Equatable, Sendable {
    case noPayloadConfigured
    case invalidConfiguration(String)
    case executableNotFound(String)
    case scriptNotFound(String)
    case workingDirectoryNotFound(String)
    case invalidURL(String)
    case permissionDenied(String)
    case nonZeroExitStatus(Int, output: String)
    case timeout(TimeInterval)
    case cancelled
    case processLaunchFailed(String)
    case duplicateExecution
    case destructiveActionRejected
    case stepFailed(stepIndex: Int, stepName: String, reason: String)
    case applicationNotFound(String)
    case applicationLaunchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noPayloadConfigured:
            return "No payload configured. Open Settings to set up an action."
        case .invalidConfiguration(let details):
            return "Invalid configuration: \(details)"
        case .executableNotFound(let path):
            return "Executable not found at path: \(path)"
        case .scriptNotFound(let path):
            return "Script file not found at path: \(path)"
        case .workingDirectoryNotFound(let path):
            return "Working directory does not exist: \(path)"
        case .invalidURL(let url):
            return "Invalid URL: \(url). Only valid http:// and https:// URLs are supported."
        case .permissionDenied(let path):
            return "Permission denied accessing: \(path)"
        case .nonZeroExitStatus(let code, let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Command failed with exit status \(code)."
            } else {
                let firstLine = trimmed.components(separatedBy: .newlines).first ?? ""
                return "Command failed with exit status \(code): \(firstLine)"
            }
        case .timeout(let duration):
            return "Execution timed out after \(String(format: "%.1f", duration)) seconds."
        case .cancelled:
            return "Execution was cancelled by the user."
        case .processLaunchFailed(let details):
            return "Failed to launch process: \(details)"
        case .duplicateExecution:
            return "A payload is already running. Wait for it to finish or cancel it."
        case .destructiveActionRejected:
            return "Destructive action was rejected by the user."
        case .stepFailed(let index, let name, let reason):
            return "Step \(index + 1) ('\(name)') failed: \(reason)"
        case .applicationNotFound(let path):
            return "Application not found at path: \(path)"
        case .applicationLaunchFailed(let details):
            return "Failed to open application: \(details)"
        }
    }
}
