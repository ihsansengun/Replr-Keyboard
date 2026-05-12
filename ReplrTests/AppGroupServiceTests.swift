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
}
