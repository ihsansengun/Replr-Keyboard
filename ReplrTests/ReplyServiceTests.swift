import XCTest
@testable import ReplrKeyboard

final class ReplyServiceTests: XCTestCase {
    func testParseResponseExtractsReplies() throws {
        let json = """
        {"replies": ["Hey there", "What's up", "Sounds good"]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ReplyResponse.self, from: json)
        XCTAssertEqual(response.replies, ["Hey there", "What's up", "Sounds good"])
    }

    func testReplyRequestEncodesCorrectly() throws {
        let req = ReplyRequest(
            screenshotBase64: "abc123",
            tone: "casual",
            summary: nil,
            previousContext: nil,
            model: "gpt-4.1-mini",
            userId: "user-1"
        )
        let data = try JSONEncoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(dict["tone"] as? String, "casual")
        XCTAssertEqual(dict["model"] as? String, "gpt-4.1-mini")
    }
}
