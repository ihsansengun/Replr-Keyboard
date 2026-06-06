import Testing
@testable import Replr

struct KeyboardTipCoordinatorTests {

    private func tip(capture: Int = 0, regen: Int = 0,
                     steerDismissed: Bool = false, steerShows: Int = 0,
                     backTapDismissed: Bool = false, backTapShows: Int = 0,
                     chat: Bool = true) -> KeyboardTip {
        KeyboardTipCoordinator.currentTip(
            captureCount: capture, sessionRegenerateCount: regen,
            steerDismissed: steerDismissed, steerShowCount: steerShows,
            backTapDismissed: backTapDismissed, backTapShowCount: backTapShows,
            isChatMode: chat)
    }

    @Test func notChatModeAlwaysNone() {
        #expect(tip(capture: 5, chat: false) == .none)
    }

    @Test func coldStartShowsNothing() {
        #expect(tip(capture: 0, regen: 0) == .none)
        #expect(tip(capture: 1, regen: 1) == .none)
    }

    @Test func steerUnlocksAtTwoCaptures() {
        #expect(tip(capture: 2) == .steer)
    }

    @Test func steerUnlocksAtTwoRegenerates() {
        #expect(tip(capture: 1, regen: 2) == .steer)
    }

    @Test func steerSuppressedWhenDismissedAndBackTapNotYetEligible() {
        #expect(tip(capture: 2, steerDismissed: true) == .none)
    }

    @Test func steerComesBeforeBackTapEvenWhenBackTapEligible() {
        #expect(tip(capture: 5) == .steer)
    }

    @Test func backTapUnlocksWhenSteerRetiredByShowCount() {
        #expect(tip(capture: 5, steerShows: 3) == .backTap)
    }

    @Test func backTapUnlocksWhenSteerDismissed() {
        #expect(tip(capture: 5, steerDismissed: true) == .backTap)
    }

    @Test func backTapNotEligibleBeforeFiveCaptures() {
        #expect(tip(capture: 4, steerDismissed: true) == .none)
    }

    @Test func allRetiredShowsNothing() {
        #expect(tip(capture: 5, steerDismissed: true, backTapDismissed: true) == .none)
        #expect(tip(capture: 5, steerDismissed: true, backTapShows: 3) == .none)
    }
}
