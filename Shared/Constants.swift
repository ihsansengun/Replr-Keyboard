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

    // File-based keys (broadcast/scroll capture only)
    static let screenshotFilename     = "screenshot.png"
    static let captureReadyKey        = "capture_ready"
    static let scrollModeKey          = "scroll_mode"
    static let scrollFrameCountKey    = "scroll_frame_count"
    static let scrollCaptureReadyKey  = "scroll_capture_ready"
    static let broadcastActiveKey     = "broadcast_active"
}
