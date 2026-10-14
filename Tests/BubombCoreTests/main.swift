import Foundation
import BubombCore

func runTest(suiteName: String, testName: String, block: () async throws -> Void) async {
    TestContext.shared.currentTestFailures = []
    let start = Date()
    var threw = false
    var errorDesc = ""

    do {
        try await block()
    } catch {
        threw = true
        errorDesc = "\(error)"
    }

    let elapsed = Date().timeIntervalSince(start)
    let failures = TestContext.shared.currentTestFailures

    if !threw && failures.isEmpty {
        TestContext.shared.totalPassed += 1
        print("  \u{001B}[32m✓\u{001B}[0m \(testName) (\(String(format: "%.3f", elapsed))s)")
    } else {
        TestContext.shared.totalFailed += 1
        print("  \u{001B}[31m✗\u{001B}[0m \(testName) (\(String(format: "%.3f", elapsed))s)")
        if threw {
            print("    \u{001B}[31mThrew unexpected error: \(errorDesc)\u{001B}[0m")
        }
        for f in failures {
            print("    \u{001B}[31m[\(f.file):\(f.line)] \(f.message)\u{001B}[0m")
        }
    }
}

print("\u{001B}[1m💣 Running Bubomb Test Suite...\u{001B}[0m\n")
let suiteStartTime = Date()

// Suite 1: PayloadValidationTests
print("\u{001B}[33m• PayloadValidationTests\u{001B}[0m")
let val = PayloadValidationTests()
await runTest(suiteName: "PayloadValidationTests", testName: "testEmptyPayloadNameThrows") { val.testEmptyPayloadNameThrows() }
await runTest(suiteName: "PayloadValidationTests", testName: "testEmptyCommandThrows") { val.testEmptyCommandThrows() }
await runTest(suiteName: "PayloadValidationTests", testName: "testValidShellCommandPasses") { try val.testValidShellCommandPasses() }
await runTest(suiteName: "PayloadValidationTests", testName: "testNonExistentShellThrows") { val.testNonExistentShellThrows() }
await runTest(suiteName: "PayloadValidationTests", testName: "testNonExistentWorkingDirectoryThrows") { val.testNonExistentWorkingDirectoryThrows() }
await runTest(suiteName: "PayloadValidationTests", testName: "testInvalidURLThrows") { val.testInvalidURLThrows() }
await runTest(suiteName: "PayloadValidationTests", testName: "testValidURLPasses") { try val.testValidURLPasses() }
await runTest(suiteName: "PayloadValidationTests", testName: "testNonExistentScriptThrows") { val.testNonExistentScriptThrows() }
await runTest(suiteName: "PayloadValidationTests", testName: "testEmptySequenceThrows") { val.testEmptySequenceThrows() }

// Suite 2: SettingsStoreTests
print("\n\u{001B}[33m• SettingsStoreTests\u{001B}[0m")
let storeTests = SettingsStoreTests()
await runTest(suiteName: "SettingsStoreTests", testName: "testInitialSettings") {
    storeTests.setUp()
    storeTests.testInitialSettings()
    storeTests.tearDown()
}
await runTest(suiteName: "SettingsStoreTests", testName: "testSaveAndRetrieveActivePayload") {
    storeTests.setUp()
    storeTests.testSaveAndRetrieveActivePayload()
    storeTests.tearDown()
}
await runTest(suiteName: "SettingsStoreTests", testName: "testExecutionHistoryCap") {
    storeTests.setUp()
    storeTests.testExecutionHistoryCap()
    storeTests.tearDown()
}
await runTest(suiteName: "SettingsStoreTests", testName: "testClearHistory") {
    storeTests.setUp()
    storeTests.testClearHistory()
    storeTests.tearDown()
}
await runTest(suiteName: "SettingsStoreTests", testName: "testResetToDefaults") {
    storeTests.setUp()
    storeTests.testResetToDefaults()
    storeTests.tearDown()
}

// Suite 3: ProcessRunnerTests
print("\n\u{001B}[33m• ProcessRunnerTests\u{001B}[0m")
let procTests = ProcessRunnerTests()
await runTest(suiteName: "ProcessRunnerTests", testName: "testSuccessfulCommandExecution") { try await procTests.testSuccessfulCommandExecution() }
await runTest(suiteName: "ProcessRunnerTests", testName: "testShellCommandExecutorWithArguments") { try await procTests.testShellCommandExecutorWithArguments() }
await runTest(suiteName: "ProcessRunnerTests", testName: "testNonZeroExitStatusThrows") { await procTests.testNonZeroExitStatusThrows() }
await runTest(suiteName: "ProcessRunnerTests", testName: "testEnvironmentVariablesPassedToProcess") { try await procTests.testEnvironmentVariablesPassedToProcess() }
await runTest(suiteName: "ProcessRunnerTests", testName: "testWorkingDirectory") { try await procTests.testWorkingDirectory() }
await runTest(suiteName: "ProcessRunnerTests", testName: "testProcessTimeout") { await procTests.testProcessTimeout() }
await runTest(suiteName: "ProcessRunnerTests", testName: "testProcessCancellation") { await procTests.testProcessCancellation() }

// Suite 4: URLLauncherTests
print("\n\u{001B}[33m• URLLauncherTests\u{001B}[0m")
let urlTests = URLLauncherTests()
await runTest(suiteName: "URLLauncherTests", testName: "testValidURLs") { urlTests.testValidURLs() }
await runTest(suiteName: "URLLauncherTests", testName: "testInvalidURLs") { urlTests.testInvalidURLs() }

// Suite 5: SafetyPolicyTests
print("\n\u{001B}[33m• SafetyPolicyTests\u{001B}[0m")
let safetyTests = SafetyPolicyTests()
await runTest(suiteName: "SafetyPolicyTests", testName: "testDestructiveCommandsDetected") { safetyTests.testDestructiveCommandsDetected() }
await runTest(suiteName: "SafetyPolicyTests", testName: "testSuspiciousCommandsDetected") { safetyTests.testSuspiciousCommandsDetected() }
await runTest(suiteName: "SafetyPolicyTests", testName: "testSafeCommandsPass") { safetyTests.testSafeCommandsPass() }

// Suite 6: SequenceExecutorTests
print("\n\u{001B}[33m• SequenceExecutorTests\u{001B}[0m")
let seqTests = SequenceExecutorTests()
await runTest(suiteName: "SequenceExecutorTests", testName: "testSuccessfulSequentialExecution") { try await seqTests.testSuccessfulSequentialExecution() }
await runTest(suiteName: "SequenceExecutorTests", testName: "testSequenceStopsOnErrorWhenConfigured") { await seqTests.testSequenceStopsOnErrorWhenConfigured() }
await runTest(suiteName: "SequenceExecutorTests", testName: "testSequenceContinuesOnErrorWhenConfigured") { try await seqTests.testSequenceContinuesOnErrorWhenConfigured() }

let totalTime = Date().timeIntervalSince(suiteStartTime)
let passed = TestContext.shared.totalPassed
let failed = TestContext.shared.totalFailed
let total = passed + failed

print("\n" + String(repeating: "-", count: 50))
if failed == 0 {
    print("\u{001B}[32;1m💥 All \(total) tests passed in \(String(format: "%.2f", totalTime))s! BOOM!\u{001B}[0m\n")
    exit(0)
} else {
    print("\u{001B}[31;1m❌ \(failed) of \(total) tests failed in \(String(format: "%.2f", totalTime))s.\u{001B}[0m\n")
    exit(1)
}
