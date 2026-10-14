import Foundation

public enum ExecutionStatus: String, Codable, Equatable, Hashable, Sendable {
    case succeeded = "Succeeded"
    case failed = "Failed"
    case cancelled = "Cancelled"
    case timedOut = "Timed Out"

    public var badgeColorName: String {
        switch self {
        case .succeeded: return "green"
        case .failed: return "red"
        case .cancelled: return "orange"
        case .timedOut: return "purple"
        }
    }
}

/// Metadata and logs from a payload detonation.
public struct ExecutionRecord: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var payloadId: UUID
    public var payloadName: String
    public var payloadTypeDescription: String
    public var startedAt: Date
    public var finishedAt: Date
    public var duration: TimeInterval
    public var status: ExecutionStatus
    public var exitCode: Int?
    public var standardOutput: String
    public var standardError: String
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        payloadId: UUID,
        payloadName: String,
        payloadTypeDescription: String,
        startedAt: Date,
        finishedAt: Date = Date(),
        duration: TimeInterval = 0,
        status: ExecutionStatus,
        exitCode: Int? = nil,
        standardOutput: String = "",
        standardError: String = "",
        errorMessage: String? = nil
    ) {
        self.id = id
        self.payloadId = payloadId
        self.payloadName = payloadName
        self.payloadTypeDescription = payloadTypeDescription
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.duration = duration
        self.status = status
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.errorMessage = errorMessage
    }

    public var formattedDuration: String {
        if duration < 1.0 {
            return String(format: "%.0f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }

    public var combinedOutput: String {
        var out = ""
        if !standardOutput.isEmpty {
            out += standardOutput
        }
        if !standardError.isEmpty {
            if !out.isEmpty && !out.hasSuffix("\n") {
                out += "\n"
            }
            out += standardError
        }
        return out
    }
}
