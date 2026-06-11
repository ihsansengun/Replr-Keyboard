import Foundation

/// Pure display rules for the Home tab. No UI, fully unit-tested.
enum HomeLogic {
    /// Whole replies the balance affords at the current tier price.
    static func approxReplies(balance: Int, costPerReply: Int) -> Int {
        guard costPerReply > 0, balance > 0 else { return 0 }
        return balance / costPerReply
    }

    /// Low state: can't afford a single reply (dev mode is never low).
    static func isLowBalance(balance: Int, costPerReply: Int, devMode: Bool) -> Bool {
        !devMode && balance < max(costPerReply, 1)
    }
}
