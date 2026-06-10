enum Constants {
    static let appGroupID             = "group.com.ihsan.replr"
    static let backendURL             = "https://api.replr.app"

    // UserDefaults keys (App Group)
    static let pendingRepliesKey      = "pending_replies"
    static let hasNewRepliesKey       = "has_new_replies"
    static let pendingErrorKey        = "pending_error"
    static let selectedToneKey        = "selected_tone"
    static let capturedScreenshotIDsKey = "captured_screenshot_ids"
    static let autoClearScreenshotsKey  = "auto_clear_screenshots"
    static let deleteScreenshotAfterEachKey = "delete_screenshot_after_each"
    static let tonesKey               = "tones"
    static let userIDKey              = "user_id"
    static let transactionIDKey       = "transaction_id"
    static let pendingContextKey      = "pending_context"
    static let persistRepliesKey      = "persist_replies"
    static let aboutUserKey           = "about_user"
    static let intentTipShowCountKey  = "intent_tip_show_count"
    static let cachedRepliesKey       = "cached_replies"
    static let isGeneratingKey        = "is_generating"
    static let captureSessionsKey     = "capture_sessions"
    static let contactsKey            = "contacts"
    static let currentContactIDKey    = "current_contact_id"
    static let memoryWindowDaysKey    = "memory_window_days"   // Int, 0 = all time
    static let memoryDepthKey         = "memory_depth"         // Int, default 10, max 20
    static let memoryEnabledKey       = "memory_enabled"
    static let intentHintKey          = "intent_hint"
    static let switchKeyboardKey      = "switch_keyboard_requested"
    static let coachmarkSeenKey       = "keyboard.coachmarkSeen"
    static let keyboardInstalledKey       = "keyboard_installed"
    static let fullAccessGrantedKey       = "full_access_granted"
    static let memoryUsedContactKey       = "memory_used_contact"
    static let hasConsentedToCaptureKey   = "has_consented_to_capture"
    static let backTapSkippedKey          = "back_tap_skipped"
    static let backTapSetupStartedKey     = "back_tap_setup_started"
    static let lastIntentFiredAtKey        = "last_intent_fired_at"
    static let shortcutInstallURL         = "https://www.icloud.com/shortcuts/73472454024d4a48b1d2a9108fec4bc8"
    static let preferredCaptureKey        = "preferred_capture"   // "keyboard" | "backtap"
    static let selectedModeKey            = "selected_mode"       // "chat" | "email" | "dating" — keyboard writes, intents read
    static let remoteShortcutInstallURLKey = "remote_shortcut_install_url"  // overrides shortcutInstallURL, fetched from /config
    static let sessionRegenerateCountKey  = "session_regenerate_count"      // regenerates since last capture
    static let lastConsumedScreenshotIDKey  = "last_consumed_screenshot_id"
    static let tipDismissedPrefix         = "tip_dismissed_"                // + tip id
    static let tipShowCountPrefix         = "tip_show_count_"               // + tip id

    // Trial + paywall
    static let trialUsedCountKey     = "replr.trial.usedCount"
    static let trialExhaustedKey     = "replr.trial.exhausted"
    static let paywallRequestedKey   = "replr.paywall.requested"

    // Credits + model + dev mode
    static let creditBalanceKey      = "replr.credits.balance"
    static let selectedModelKey      = "replr.credits.model"      // user's production choice
    static let devModelKey           = "replr.dev.model"          // dev override (only used when devMode=true)
    static let devModeKey            = "replr.dev.mode"
    static let creditsMigratedKey    = "replr.credits.migrated"
    static let serverCreditsMigratedKey = "replr.credits.serverMigrated"  // local balance adopted into the server ledger
    static let grantedTxIDsKey       = "replr.credits.grantedTxIDs"       // locally-granted StoreKit tx ids (offline fallback dedup)
    static let remoteModelCatalogKey = "remote_model_catalog"             // JSON [RemoteModelInfo] fetched from /config
    static let remotePaywallConfigKey = "remote_paywall_config"           // JSON RemotePaywallConfig fetched from /paywall
    static let colorSchemeAppearanceKey = "replr.appearance.colorScheme"

    // Shared screenshot file (written at capture, read by Regenerate)
    static let screenshotFilename     = "screenshot.png"
}
