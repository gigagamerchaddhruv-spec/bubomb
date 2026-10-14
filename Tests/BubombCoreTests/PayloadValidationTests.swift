#if canImport(XCTest)
import XCTest
#endif
import Foundation
import BubombCore

final class PayloadValidationTests: XCTestCase {
    func testEmptyPayloadNameThrows() {
        let payload = Payload(name: "   ", type: .shellCommand(ShellConfig(command: "echo hi")))
        XCTAssertThrowsError(try payload.validate()) { error in
            guard case ExecutionError.invalidConfiguration(let reason) = error else {
                XCTFail("Expected invalidConfiguration, got \(error)")
                return
            }
            XCTAssertTrue(reason.contains("name"))
        }
    }

    func testEmptyCommandThrows() {
        let payload = Payload(name: "Test", type: .shellCommand(ShellConfig(command: "")))
        XCTAssertThrowsError(try payload.validate()) { error in
            guard case ExecutionError.invalidConfiguration(let reason) = error else {
                XCTFail("Expected invalidConfiguration, got \(error)")
                return
            }
            XCTAssertTrue(reason.contains("Command cannot be empty"))
        }
    }

    func testValidShellCommandPasses() throws {
        let payload = Payload(
            name: "Valid Shell",
            type: .shellCommand(ShellConfig(command: "echo 'Detonate!'", shellPath: "/bin/zsh"))
        )
        XCTAssertNoThrow(try payload.validate())
    }

    func testNonExistentShellThrows() {
        let payload = Payload(
            name: "Bad Shell",
            type: .shellCommand(ShellConfig(command: "echo hi", shellPath: "/bin/non_existent_shell_12345"))
        )
        XCTAssertThrowsError(try payload.validate()) { error in
            guard case ExecutionError.executableNotFound = error else {
                XCTFail("Expected executableNotFound, got \(error)")
                return
            }
        }
    }

    func testNonExistentWorkingDirectoryThrows() {
        let payload = Payload(
            name: "Bad WorkDir",
            type: .shellCommand(ShellConfig(command: "echo hi", workingDirectory: "/path/that/does/not/exist_12345"))
        )
        XCTAssertThrowsError(try payload.validate()) { error in
            guard case ExecutionError.workingDirectoryNotFound = error else {
                XCTFail("Expected workingDirectoryNotFound, got \(error)")
                return
            }
        }
    }

    func testInvalidURLThrows() {
        let payload = Payload(name: "Bad URL", type: .openURL(URLConfig(urlString: "ftp://example.com")))
        XCTAssertThrowsError(try payload.validate()) { error in
            guard case ExecutionError.invalidURL = error else {
                XCTFail("Expected invalidURL, got \(error)")
                return
            }
        }

        let payload2 = Payload(name: "Malformed URL", type: .openURL(URLConfig(urlString: "not-a-url")))
        XCTAssertThrowsError(try payload2.validate())
    }

    func testValidURLPasses() throws {
        let payload = Payload(name: "Good URL", type: .openURL(URLConfig(urlString: "https://apple.com")))
        XCTAssertNoThrow(try payload.validate())
    }

    func testNonExistentScriptThrows() {
        let payload = Payload(name: "Bad Script", type: .runScript(ScriptConfig(scriptPath: "/tmp/non_existent_script_9876.sh")))
        XCTAssertThrowsError(try payload.validate()) { error in
            guard case ExecutionError.scriptNotFound = error else {
                XCTFail("Expected scriptNotFound, got \(error)")
                return
            }
        }
    }

    func testEmptySequenceThrows() {
        let payload = Payload(name: "Empty Seq", type: .sequence(SequenceConfig(steps: [])))
        XCTAssertThrowsError(try payload.validate()) { error in
            guard case ExecutionError.invalidConfiguration = error else {
                XCTFail("Expected invalidConfiguration, got \(error)")
                return
            }
        }
    }
}
