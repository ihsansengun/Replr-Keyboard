import Testing
@testable import Replr

/// The steer/intent text is one-shot: it applies to the generation it was typed
/// for and must never season a later one (Regenerate re-reads it from the saved
/// session's contextHint instead).
/// `.serialized`: both tests mutate the SAME App Group key — parallel runs race.
@Suite(.serialized)
struct PendingContextTests {
    @Test func consumeIsOneShot() {
        let svc = AppGroupService.shared
        defer { svc.savePendingContext("") }   // cleanup — no state leak between runs
        svc.savePendingContext("make it flirty but short")
        #expect(svc.consumePendingContext() == "make it flirty but short")
        #expect(svc.consumePendingContext() == nil)   // second consumer gets nothing
        #expect(svc.readPendingContext() == nil)      // and nothing is left behind
    }

    @Test func emptySaveRemoves() {
        let svc = AppGroupService.shared
        defer { svc.savePendingContext("") }
        svc.savePendingContext("steer")
        svc.savePendingContext("")
        #expect(svc.readPendingContext() == nil)
        #expect(svc.consumePendingContext() == nil)
    }
}
