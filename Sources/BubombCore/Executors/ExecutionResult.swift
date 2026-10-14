import Foundation

/// Output result from any single executor.
public struct ExecutionResult: Sendable {
    public var exitCode: Int?
    public var stdout: String
    public var stderr: String
    public var duration: TimeInterval

    public init(
        exitCode: Int? = 0,
        stdout: String = "",
        stderr: String = "",
        duration: TimeInterval = 0
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
    }
}
