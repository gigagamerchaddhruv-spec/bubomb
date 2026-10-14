#if canImport(XCTest)
import XCTest
#endif
import Foundation
import BubombCore

final class URLLauncherTests: XCTestCase {
    func testValidURLs() {
        let validURLs = [
            "https://apple.com",
            "http://localhost:8080/detonate",
            "https://github.com/apple/swift?tab=readme-ov-file#swift",
            "http://127.0.0.1:3000"
        ]

        for u in validURLs {
            switch PathValidator.validateURL(u) {
            case .success(let url):
                XCTAssertNotNil(url.scheme)
            case .failure(let error):
                XCTFail("Expected \(u) to be valid, failed with \(error)")
            }
        }
    }

    func testInvalidURLs() {
        let invalid = [
            "ftp://files.example.com",
            "file:///Users/macbook",
            "not-a-valid-url",
            "",
            "   ",
            "http://"
        ]

        for u in invalid {
            switch PathValidator.validateURL(u) {
            case .success:
                XCTFail("Expected \(u) to be invalid")
            case .failure(let error):
                XCTAssertEqual(error, .invalidURL(u))
            }
        }
    }
}
