#if canImport(XCTest)
import XCTest
#endif
import Foundation
import BubombCore

final class SettingsStoreTests: XCTestCase {
    var userDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.bubomb.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testInitialSettings() {
        let store = SettingsStore(userDefaults: userDefaults)
        XCTAssertNil(store.settings.activePayload)
        XCTAssertTrue(store.settings.savedPayloads.isEmpty)
        XCTAssertTrue(store.settings.confirmDestructiveActions)
    }

    func testSaveAndRetrieveActivePayload() {
        let store = SettingsStore(userDefaults: userDefaults)
        let payload = Payload(
            name: "Deploy Script",
            type: .shellCommand(ShellConfig(command: "echo deploy", shellPath: "/bin/zsh"))
        )
        store.setActivePayload(payload)

        XCTAssertEqual(store.settings.activePayload?.id, payload.id)
        XCTAssertEqual(store.settings.activePayload?.name, "Deploy Script")
        XCTAssertEqual(store.settings.savedPayloads.count, 1)

        // Verify fresh store instance loads saved settings
        let restoredStore = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(restoredStore.settings.activePayload?.id, payload.id)
        XCTAssertEqual(restoredStore.settings.activePayload?.name, "Deploy Script")
    }

    func testExecutionHistoryCap() {
        let store = SettingsStore(userDefaults: userDefaults)
        for i in 1...35 {
            let record = ExecutionRecord(
                payloadId: UUID(),
                payloadName: "Run \(i)",
                payloadTypeDescription: "Shell Command",
                startedAt: Date(),
                status: .succeeded
            )
            store.addExecutionRecord(record)
        }

        XCTAssertEqual(store.settings.recentExecutions.count, 30)
        XCTAssertEqual(store.settings.recentExecutions.first?.payloadName, "Run 35")
    }

    func testClearHistory() {
        let store = SettingsStore(userDefaults: userDefaults)
        let record = ExecutionRecord(
            payloadId: UUID(),
            payloadName: "Test Run",
            payloadTypeDescription: "Shell Command",
            startedAt: Date(),
            status: .succeeded
        )
        store.addExecutionRecord(record)
        XCTAssertFalse(store.settings.recentExecutions.isEmpty)

        store.clearHistory()
        XCTAssertTrue(store.settings.recentExecutions.isEmpty)
    }

    func testResetToDefaults() {
        let store = SettingsStore(userDefaults: userDefaults)
        let payload = Payload(name: "Temporary", type: .openURL(URLConfig(urlString: "https://example.com")))
        store.setActivePayload(payload)
        XCTAssertNotNil(store.settings.activePayload)

        store.resetToDefaults()
        XCTAssertNil(store.settings.activePayload)
        XCTAssertTrue(store.settings.savedPayloads.isEmpty)
    }
}
