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

}

struct BackTapCarouselTests {

    // nextSubstep: 1→2, 4→5, 5→1 (wrap)
    @Test func nextSubstepAdvances() {
        #expect(BackTapStep.nextSubstep(from: 1) == 2)
        #expect(BackTapStep.nextSubstep(from: 4) == 5)
    }

    @Test func nextSubstepWrapsAtFive() {
        #expect(BackTapStep.nextSubstep(from: 5) == 1)
    }

    // prevSubstep: 3→2, 5→4, 1→5 (wrap)
    @Test func prevSubstepGoesBack() {
        #expect(BackTapStep.prevSubstep(from: 3) == 2)
        #expect(BackTapStep.prevSubstep(from: 5) == 4)
    }

    @Test func prevSubstepWrapsAtOne() {
        #expect(BackTapStep.prevSubstep(from: 1) == 5)
    }
}
