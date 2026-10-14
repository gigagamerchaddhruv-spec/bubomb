import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Validates and opens URLs in the user's default web browser.
public final class URLLauncher: Sendable {
    public init() {}

    public func open(urlString: String) async throws -> ExecutionResult {
        let startTime = Date()
        let validatedURL = try PathValidator.validateURL(urlString).get()

        var success = false

        #if canImport(AppKit)
        success = await MainActor.run {
            NSWorkspace.shared.open(validatedURL)
        }
        #endif

        if !success {
            // Fallback to /usr/bin/open if NSWorkspace is not available or failed
            let runner = ProcessRunner()
            let result = try await runner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/open"),
                arguments: [validatedURL.absoluteString]
            )
            return ExecutionResult(
                exitCode: result.exitCode,
                stdout: "Opened \(validatedURL.absoluteString) via open tool",
                stderr: result.stderr,
                duration: Date().timeIntervalSince(startTime)
            )
        }

        let duration = Date().timeIntervalSince(startTime)
        return ExecutionResult(
            exitCode: 0,
            stdout: "Successfully opened URL: \(validatedURL.absoluteString)",
            stderr: "",
            duration: duration
        )
    }
}
