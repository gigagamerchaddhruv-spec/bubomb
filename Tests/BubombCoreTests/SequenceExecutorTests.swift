#if canImport(XCTest)
import XCTest
#endif
import Foundation
import BubombCore

final class SequenceExecutorTests: XCTestCase {
    func testSuccessfulSequentialExecution() async throws {
        let step1 = SequenceStep(
            name: "Step 1",
            action: .runCommand(command: "echo 'first'", workingDirectory: nil, timeoutSeconds: 5)
        )
        let step2 = SequenceStep(
            name: "Step 2",
            action: .runCommand(command: "echo 'second'", workingDirectory: nil, timeoutSeconds: 5)
        )

        let config = SequenceConfig(steps: [step1, step2], stopOnError: true)
        let executor = SequenceExecutor()

        let tracker = StepTracker()
        let result = try await executor.execute(config: config) { step, total, name in
            tracker.record(step: step, total: total, name: name)
        }

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("first"))
        XCTAssertTrue(result.stdout.contains("second"))
        let calls = tracker.getCalls()
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].0, 1)
        XCTAssertEqual(calls[1].0, 2)
    }

    func testSequenceStopsOnErrorWhenConfigured() async {
        let step1 = SequenceStep(
            name: "Failing Step",
            action: .runCommand(command: "exit 12", workingDirectory: nil, timeoutSeconds: 5)
        )
        let step2 = SequenceStep(
            name: "Should Not Run",
            action: .runCommand(command: "echo 'unreachable'", workingDirectory: nil, timeoutSeconds: 5)
        )

        let config = SequenceConfig(steps: [step1, step2], stopOnError: true)
        let executor = SequenceExecutor()

        do {
            _ = try await executor.execute(config: config)
            XCTFail("Should have thrown stepFailed error")
        } catch let error as ExecutionError {
            if case .stepFailed(let index, let name, _) = error {
                XCTAssertEqual(index, 0)
                XCTAssertEqual(name, "Failing Step")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected non-ExecutionError: \(error)")
        }
    }

    func testSequenceContinuesOnErrorWhenConfigured() async throws {
        let step1 = SequenceStep(
            name: "Ignored Failure",
            action: .runCommand(command: "exit 5", workingDirectory: nil, timeoutSeconds: 5)
        )
        let step2 = SequenceStep(
            name: "Subsequent Step",
            action: .runCommand(command: "echo 'recovered'", workingDirectory: nil, timeoutSeconds: 5)
        )

        let config = SequenceConfig(steps: [step1, step2], stopOnError: false)
        let executor = SequenceExecutor()

        let result = try await executor.execute(config: config)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("recovered"))
        XCTAssertTrue(result.stderr.contains("Step 1 failed"))
    }
}

private final class StepTracker: @unchecked Sendable {
    private var calls: [(Int, Int, String)] = []
    private let lock = NSLock()

    func record(step: Int, total: Int, name: String) {
        lock.lock()
        calls.append((step, total, name))
        lock.unlock()
    }

    func getCalls() -> [(Int, Int, String)] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}
