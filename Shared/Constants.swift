enum Constants {
    static let appGroupID             = "group.com.ihsan.replr"
    static let backendURL             = "https://api.replr.app"
    static let broadcastExtensionID   = "Theory-of-Web.Replr.ReplrBroadcast"

    // UserDefaults keys (App Group)
    static let pendingRepliesKey      = "pending_replies"
    static let hasNewRepliesKey       = "has_new_replies"
    static let pendingErrorKey        = "pending_error"
    static let selectedToneKey        = "selected_tone"
    static let tonesKey               = "tones"
    static let userIDKey              = "user_id"
    static let transactionIDKey       = "transaction_id"
    static let pendingContextKey      = "pending_context"
    static let persistRepliesKey      = "persist_replies"
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
    // Update this URL once the new shortcut (Take Screenshot → Generate Reply) is created:
    static let shortcutInstallURL         = "https://www.icloud.com/shortcuts/REPLACE_WITH_NEW_URL"

    // File-based keys (broadcast/scroll capture only)
    static let screenshotFilename     = "screenshot.png"
    static let captureReadyKey        = "capture_ready"
    static let scrollModeKey          = "scroll_mode"
    static let scrollFrameCountKey    = "scroll_frame_count"
    static let scrollCaptureReadyKey  = "scroll_capture_ready"
    static let broadcastActiveKey     = "broadcast_active"
}
