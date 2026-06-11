import Testing
import Foundation
@testable import Replr

struct HistoryLogicTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }
    private let en = Locale(identifier: "en_US")
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(timeZone: cal.timeZone, year: y, month: m, day: d, hour: h))!
    }

    @Test func dayLabels() {
        let now = date(2026, 6, 11)
        #expect(HistoryLogic.dayLabel(for: date(2026, 6, 11, 9), now: now, calendar: cal, locale: en) == "Today")
        #expect(HistoryLogic.dayLabel(for: date(2026, 6, 10, 23), now: now, calendar: cal, locale: en) == "Yesterday")
        #expect(HistoryLogic.dayLabel(for: date(2026, 6, 9), now: now, calendar: cal, locale: en) == "Jun 9")
    }

    @Test func dayGroupsNewestDayFirstAndStableWithinDay() {
        let now = date(2026, 6, 11)
        // Input is newest-first, as HistoryView receives it.
        let items: [Date] = [date(2026, 6, 11, 15), date(2026, 6, 11, 9), date(2026, 6, 10, 22), date(2026, 6, 9, 8)]
        let groups = HistoryLogic.dayGroups(items, date: { $0 }, now: now, calendar: cal, locale: en)
        #expect(groups.map(\.label) == ["Today", "Yesterday", "Jun 9"])
        #expect(groups[0].items == [date(2026, 6, 11, 15), date(2026, 6, 11, 9)])
        #expect(groups[1].items == [date(2026, 6, 10, 22)])
        #expect(groups.map(\.day) == [cal.startOfDay(for: date(2026, 6, 11)),
                                      cal.startOfDay(for: date(2026, 6, 10)),
                                      cal.startOfDay(for: date(2026, 6, 9))])
    }

    @Test func dayLabelAppendsYearForOtherYears() {
        let now = date(2026, 6, 11)
        #expect(HistoryLogic.dayLabel(for: date(2025, 6, 9), now: now, calendar: cal, locale: en) == "Jun 9, 2025")
        #expect(HistoryLogic.dayLabel(for: date(2026, 6, 9), now: now, calendar: cal, locale: en) == "Jun 9")
    }

    @Test func dayLabelAcrossDSTBoundary() {
        // Europe/London springs forward on 29 Mar 2026.
        let now = date(2026, 3, 29)
        #expect(HistoryLogic.dayLabel(for: date(2026, 3, 28), now: now, calendar: cal, locale: en) == "Yesterday")
    }

    @Test func personSubtitles() {
        #expect(HistoryLogic.personSubtitle(replies: 5, remembered: 3) == "5 replies · 3 chats remembered")
        #expect(HistoryLogic.personSubtitle(replies: 1, remembered: 1) == "1 reply · 1 chat remembered")
        #expect(HistoryLogic.personSubtitle(replies: 4, remembered: 0) == "4 replies · nothing remembered yet")
    }
}

struct HomeLogicTests {
    @Test func approxReplies() {
        #expect(HomeLogic.approxReplies(balance: 84, costPerReply: 4) == 21)
        #expect(HomeLogic.approxReplies(balance: 3, costPerReply: 4) == 0)
        #expect(HomeLogic.approxReplies(balance: 0, costPerReply: 4) == 0)
        #expect(HomeLogic.approxReplies(balance: 10, costPerReply: 0) == 0)  // never divide by zero
    }

    @Test func lowBalance() {
        #expect(HomeLogic.isLowBalance(balance: 3, costPerReply: 4, devMode: false))
        #expect(!HomeLogic.isLowBalance(balance: 4, costPerReply: 4, devMode: false))
        #expect(!HomeLogic.isLowBalance(balance: 0, costPerReply: 4, devMode: true))  // dev mode never low
    }
}
