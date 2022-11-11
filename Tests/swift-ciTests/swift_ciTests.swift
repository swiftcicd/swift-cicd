import XCTest
@testable import swift_ci

final class swift_ciTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(swift_ci().text, "Hello, World!")
    }
}
