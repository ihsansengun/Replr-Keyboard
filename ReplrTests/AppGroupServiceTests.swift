import XCTest
@testable import Replr

final class AppGroupServiceTests: XCTestCase {
    let service = AppGroupService.shared

    func testUserIDIsPersistent() {
        let id1 = service.userID()
        let id2 = service.userID()
        XCTAssertEqual(id1, id2)
    }

    func testCaptureReadyFlag() {
        service.isCaptureReady = true
        XCTAssertTrue(service.isCaptureReady)
        service.isCaptureReady = false
        XCTAssertFalse(service.isCaptureReady)
    }

    func testTonesRoundtrip() throws {
        let tones = Tone.presets
        try service.writeTones(tones)
        let read = service.readTones()
        XCTAssertEqual(tones.map(\.name), read.map(\.name))
    }

    // MARK: - Contact tests

    func testCreateContactPersistsAndReturns() {
        service.saveContacts([])
        let c = service.createContact(displayName: "Alice")
        XCTAssertEqual(c.displayName, "Alice")
        let loaded = service.loadContacts()
        XCTAssertTrue(loaded.contains(where: { $0.id == c.id }))
    }

    func testUpdateContactChangesDisplayName() {
        service.saveContacts([])
        var c = service.createContact(displayName: "Bob")
        c.displayName = "Bobby"
        service.updateContact(c)
        let loaded = service.loadContacts()
        let found = loaded.first(where: { $0.id == c.id })
        XCTAssertEqual(found?.displayName, "Bobby")
    }

    func testFindContactsCaseInsensitive() {
        service.saveContacts([])
        _ = service.createContact(displayName: "Alexis")
        _ = service.createContact(displayName: "alexis")
        _ = service.createContact(displayName: "ALEXIS")
        let results = service.findContacts(named: "alexis")
        XCTAssertEqual(results.count, 3)
    }

    func testFindContactsTrimsWhitespace() {
        service.saveContacts([])
        _ = service.createContact(displayName: "  Sam  ")
        let results = service.findContacts(named: " sam ")
        XCTAssertEqual(results.count, 1)
    }

    func testRecentSummariesReturnsCorrectContactSummaries() {
        service.saveContacts([])
        service.clearCaptureSessions()
        let contact = service.createContact(displayName: "Carol")
        let s1 = CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                                contextHint: nil, generatedReplies: [], selectedReply: nil,
                                llmSummary: "First summary", contactID: contact.id, contactName: "Carol")
        let s2 = CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                                contextHint: nil, generatedReplies: [], selectedReply: nil,
                                llmSummary: "Second summary", contactID: contact.id, contactName: "Carol")
        let other = CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                                   contextHint: nil, generatedReplies: [], selectedReply: nil,
                                   llmSummary: "Other person", contactID: UUID(), contactName: "Dan")
        service.saveCaptureSessions([s1, s2, other])
        let summaries = service.recentSummaries(forContactID: contact.id, limit: 10)
        XCTAssertEqual(summaries, ["First summary", "Second summary"])
    }

    func testRecentSummariesHonorsLimit() {
        service.saveContacts([])
        service.clearCaptureSessions()
        let id = UUID()
        let sessions = (1...5).map { i in
            CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                           contextHint: nil, generatedReplies: [], selectedReply: nil,
                           llmSummary: "Summary \(i)", contactID: id, contactName: "Test")
        }
        service.saveCaptureSessions(sessions)
        let result = service.recentSummaries(forContactID: id, limit: 3)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result, ["Summary 3", "Summary 4", "Summary 5"])
    }

    func testClearMemoryZeroesOutSummaries() {
        service.saveContacts([])
        service.clearCaptureSessions()
        let id = UUID()
        let s = CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                               contextHint: nil, generatedReplies: [], selectedReply: nil,
                               llmSummary: "Something happened", contactID: id, contactName: "Eve")
        service.saveCaptureSessions([s])
        service.clearMemory(forContactID: id)
        let after = service.loadCaptureSessions().first(where: { $0.contactID == id })
        XCTAssertNil(after?.llmSummary)
    }

    func testSessionsForContactIDFiltersCorrectly() {
        service.saveContacts([])
        service.clearCaptureSessions()
        let id = UUID()
        let match = CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                                   contextHint: nil, generatedReplies: [], selectedReply: nil,
                                   llmSummary: nil, contactID: id, contactName: "Test")
        let other = CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                                   contextHint: nil, generatedReplies: [], selectedReply: nil,
                                   llmSummary: nil, contactID: UUID(), contactName: "Other")
        service.saveCaptureSessions([match, other])
        let result = service.sessions(forContactID: id)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, match.id)
    }

    func testCurrentContactIDRoundtrip() {
        let uuid = UUID()
        service.currentContactID = uuid
        XCTAssertEqual(service.currentContactID, uuid)
        service.currentContactID = nil
        XCTAssertNil(service.currentContactID)
    }
}
