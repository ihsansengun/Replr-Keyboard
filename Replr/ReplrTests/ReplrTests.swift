//
//  ReplrTests.swift
//  ReplrTests
//
//  Created by FF on 12/05/2026.
//

import Testing
@testable import Replr

struct ReplrTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func lastConsumedScreenshotIDRoundTrip() {
        let svc = AppGroupService.shared
        defer { svc.lastConsumedScreenshotID = nil }   // cleanup — prevent state leak between runs
        // Save and read back
        svc.lastConsumedScreenshotID = "test-asset-abc-123"
        #expect(svc.lastConsumedScreenshotID == "test-asset-abc-123")
        // Clear and verify nil
        svc.lastConsumedScreenshotID = nil
        #expect(svc.lastConsumedScreenshotID == nil)
    }

    @Test func keychainRoundTrip() throws {
        let key = "test.keychain.key.\(Int.random(in: 1...999999))"
        defer { Keychain.delete(forKey: key) }
        try Keychain.save("hello-world", forKey: key)
        #expect(Keychain.load(forKey: key) == "hello-world")
        Keychain.delete(forKey: key)
        #expect(Keychain.load(forKey: key) == nil)
    }
}
