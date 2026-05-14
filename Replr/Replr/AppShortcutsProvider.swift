import AppIntents

struct ReplrShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .orange

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickReplyIntent(),
            phrases: [
                "Quick reply with \(.applicationName)",
                "Reply to my chat with \(.applicationName)",
                "Get reply suggestions with \(.applicationName)",
                "Help me reply with \(.applicationName)"
            ],
            shortTitle: "Quick Reply",
            systemImageName: "bolt.fill"
        )
    }
}
