import Foundation

/// Pure display rules for the History tab. No UI, fully unit-tested.
enum HistoryLogic {
    /// "Today" / "Yesterday" / "Jun 9".
    static func dayLabel(for date: Date, now: Date = Date(),
                         calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(.abbreviated).day()
        if !calendar.isDate(date, equalTo: now, toGranularity: .year) {
            style = style.year()
        }
        return date.formatted(style)
    }

    /// Buckets newest-first items into day sections, newest day first.
    /// Order within a day is preserved from the input.
    static func dayGroups<T>(_ items: [T], date: (T) -> Date, now: Date = Date(),
                             calendar: Calendar = .current, locale: Locale = .current)
        -> [(day: Date, label: String, items: [T])] {
        let byDay = Dictionary(grouping: items) { calendar.startOfDay(for: date($0)) }
        return byDay.keys.sorted(by: >).map { day in
            (day: day,
             label: dayLabel(for: day, now: now, calendar: calendar, locale: locale),
             items: byDay[day] ?? [])
        }
    }

    /// "5 replies · 3 chats remembered" — the person-header subtitle.
    static func personSubtitle(replies: Int, remembered: Int) -> String {
        let r = "\(replies) \(replies == 1 ? "reply" : "replies")"
        guard remembered > 0 else { return "\(r) · nothing remembered yet" }
        return "\(r) · \(remembered) \(remembered == 1 ? "chat" : "chats") remembered"
    }
}
