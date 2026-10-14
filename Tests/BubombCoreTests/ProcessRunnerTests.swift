#if canImport(XCTest)
import XCTest
#endif
import Foundation
import BubombCore

final class ProcessRunnerTests: XCTestCase {
    func testSuccessfulCommandExecution() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["Hello", "Bubomb!"]
        )

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "Hello Bubomb!")
        XCTAssertTrue(result.stderr.isEmpty)
        XCTAssertGreaterThan(result.duration, 0)
    }

    func testShellCommandExecutorWithArguments() async throws {
        let executor = ShellCommandExecutor()
        let config = ShellConfig(
            command: "echo",
            shellPath: "/bin/zsh",
            arguments: ["arg1", "arg2"]
        )
        let result = try await executor.execute(config: config)
        XCTAssertEqual(result.exitCode, 0)
        let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(trimmed.contains("arg1 arg2"))
    }

    func testNonZeroExitStatusThrows() async {
        let runner = ProcessRunner()
        do {
            _ = try await runner.run(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "exit 42"]
            )
            XCTFail("Should have thrown nonZeroExitStatus")
        } catch let error as ExecutionError {
            if case .nonZeroExitStatus(let code, _) = error {
                XCTAssertEqual(code, 42)
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected non-ExecutionError: \(error)")
        }
    }

    func testEnvironmentVariablesPassedToProcess() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "echo $BUBOMB_MAGIC_TOKEN"],
            environment: ["BUBOMB_MAGIC_TOKEN": "BOOM_42"]
        )
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "BOOM_42")
    }

    func testWorkingDirectory() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/pwd"),
            arguments: [],
            workingDirectory: "/tmp"
        )
        XCTAssertEqual(result.exitCode, 0)
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        // On macOS /tmp is a symlink to /private/tmp
        XCTAssertTrue(output == "/tmp" || output == "/private/tmp")
    }

    func testProcessTimeout() async {
        let runner = ProcessRunner()
        do {
            _ = try await runner.run(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["5"],
                timeoutSeconds: 0.3
            )
            XCTFail("Should have timed out")
        } catch let error as ExecutionError {
            if case .timeout(let duration) = error {
                XCTAssertEqual(duration, 0.3)
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProcessCancellation() async {
        let runner = ProcessRunner()
        let task = Task {
            try await runner.run(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["5"]
            )
        }

        // Cancel after 100ms
        try? await Task.sleep(nanoseconds: 100_000_000)
        runner.cancel()

        do {
            _ = try await task.value
            XCTFail("Should have thrown cancelled")
        } catch let error as ExecutionError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            // Task cancellation or ExecutionError.cancelled is expected
        }
    }
}
