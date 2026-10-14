import Foundation

public struct TestFailure {
    public let message: String
    public let file: StaticString
    public let line: UInt
}

public final class TestContext: @unchecked Sendable {
    public static let shared = TestContext()
    public var currentTestFailures: [TestFailure] = []
    public var totalPassed = 0
    public var totalFailed = 0
}

open class XCTestCase {
    public init() {}
    open func setUp() {}
    open func tearDown() {}
}

public func XCTAssertEqual<T: Equatable>(
    _ a: @autoclosure () -> T,
    _ b: @autoclosure () -> T,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let valA = a()
    let valB = b()
    if valA != valB {
        let msg = message.isEmpty ? "XCTAssertEqual failed: ('\(valA)') is not equal to ('\(valB)')" : message
        TestContext.shared.currentTestFailures.append(TestFailure(message: msg, file: file, line: line))
    }
}

public func XCTAssertTrue(
    _ condition: @autoclosure () -> Bool,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if !condition() {
        let msg = message.isEmpty ? "XCTAssertTrue failed" : message
        TestContext.shared.currentTestFailures.append(TestFailure(message: msg, file: file, line: line))
    }
}

public func XCTAssertFalse(
    _ condition: @autoclosure () -> Bool,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if condition() {
        let msg = message.isEmpty ? "XCTAssertFalse failed" : message
        TestContext.shared.currentTestFailures.append(TestFailure(message: msg, file: file, line: line))
    }
}

public func XCTAssertNil(
    _ value: @autoclosure () -> Any?,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if value() != nil {
        let msg = message.isEmpty ? "XCTAssertNil failed: value is not nil" : message
        TestContext.shared.currentTestFailures.append(TestFailure(message: msg, file: file, line: line))
    }
}

public func XCTAssertNotNil(
    _ value: @autoclosure () -> Any?,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if value() == nil {
        let msg = message.isEmpty ? "XCTAssertNotNil failed: value is nil" : message
        TestContext.shared.currentTestFailures.append(TestFailure(message: msg, file: file, line: line))
    }
}

public func XCTAssertGreaterThan<T: Comparable>(
    _ a: @autoclosure () -> T,
    _ b: @autoclosure () -> T,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let valA = a()
    let valB = b()
    if !(valA > valB) {
        let msg = message.isEmpty ? "XCTAssertGreaterThan failed: ('\(valA)') is not greater than ('\(valB)')" : message
        TestContext.shared.currentTestFailures.append(TestFailure(message: msg, file: file, line: line))
    }
}

public func XCTFail(
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let msg = message.isEmpty ? "XCTFail called" : message
    TestContext.shared.currentTestFailures.append(TestFailure(message: msg, file: file, line: line))
}

public func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () throws -> T,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) {
    do {
        _ = try expression()
        let msg = message.isEmpty ? "XCTAssertThrowsError failed: did not throw an error" : message
        TestContext.shared.currentTestFailures.append(TestFailure(message: msg, file: file, line: line))
    } catch {
        errorHandler(error)
    }
}

public func XCTAssertNoThrow<T>(
    _ expression: @autoclosure () throws -> T,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        _ = try expression()
    } catch {
        let msg = message.isEmpty ? "XCTAssertNoThrow failed: threw \(error)" : message
        TestContext.shared.currentTestFailures.append(TestFailure(message: msg, file: file, line: line))
    }
}
