import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Launches macOS applications safely using native APIs.
public final class ApplicationLauncher: Sendable {
    public init() {}

    public func launch(appPath: String, arguments: [String] = []) async throws -> ExecutionResult {
        let startTime = Date()
        let validatedPath = try PathValidator.validateApplication(at: appPath).get()
        let appURL = URL(fileURLWithPath: validatedPath)

        #if canImport(AppKit)
        let config = NSWorkspace.OpenConfiguration()
        if !arguments.isEmpty {
            config.arguments = arguments
        }

        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NSRunningApplication, Error>) in
                NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let app = app {
                        continuation.resume(returning: app)
                    } else {
                        continuation.resume(throwing: ExecutionError.applicationLaunchFailed("Application launch failed without error info."))
                    }
                }
            }
            let duration = Date().timeIntervalSince(startTime)
            return ExecutionResult(
                exitCode: 0,
                stdout: "Successfully launched application: \(appURL.lastPathComponent)",
                stderr: "",
                duration: duration
            )
        } catch {
            // If native NSWorkspace openApplication threw, try /usr/bin/open as fallback
            let runner = ProcessRunner()
            var args = ["-a", validatedPath]
            if !arguments.isEmpty {
                args.append("--args")
                args.append(contentsOf: arguments)
            }
            let res = try await runner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/open"),
                arguments: args
            )
            return ExecutionResult(
                exitCode: res.exitCode,
                stdout: "Launched via open tool: \(appURL.lastPathComponent)",
                stderr: res.stderr,
                duration: Date().timeIntervalSince(startTime)
            )
        }
        #else
        let runner = ProcessRunner()
        var args = ["-a", validatedPath]
        if !arguments.isEmpty {
            args.append("--args")
            args.append(contentsOf: arguments)
        }
        let res = try await runner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/open"),
            arguments: args
        )
        return ExecutionResult(
            exitCode: res.exitCode,
            stdout: "Launched via open tool: \(appURL.lastPathComponent)",
            stderr: res.stderr,
            duration: Date().timeIntervalSince(startTime)
        )
        #endif
    }
}
