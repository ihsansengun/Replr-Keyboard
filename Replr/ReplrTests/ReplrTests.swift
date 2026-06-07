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
        // Save and read back
        svc.lastConsumedScreenshotID = "test-asset-abc-123"
        #expect(svc.lastConsumedScreenshotID == "test-asset-abc-123")
        // Clear and verify nil
        svc.lastConsumedScreenshotID = nil
        #expect(svc.lastConsumedScreenshotID == nil)
    }
}
