import Foundation
import UIKit

final class AppGroupService {
    static let shared = AppGroupService()

    private let defaults: UserDefaults
    private let container: URL

    private init() {
        guard let ud = UserDefaults(suiteName: Constants.appGroupID) else {
            fatalError("App Group not configured: \(Constants.appGroupID)")
        }
        defaults = ud

        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupID
        ) else { fatalError("App Group container not found") }
        container = url
    }

    // MARK: - Pending replies (UserDefaults — fast, no stale files)

    func saveReplies(_ replies: [String]) {
        NSLog("[Replr][AppGroup] saveReplies count=%d", replies.count)
        guard let data = try? JSONEncoder().encode(replies) else { return }
        defaults.set(data, forKey: Constants.pendingRepliesKey)
        defaults.set(true, forKey: Constants.hasNewRepliesKey)
        saveCachedReplies(replies)
        defaults.synchronize()
        NSLog("[Replr][AppGroup] saveReplies: wrote to UserDefaults + synchronize()")
    }

    /// Returns replies and clears the flag. Returns nil if nothing new.
    func consumeReplies() -> [String]? {
        defaults.synchronize()
        guard defaults.bool(forKey: Constants.hasNewRepliesKey) else { return nil }
        defaults.set(false, forKey: Constants.hasNewRepliesKey)
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.pendingRepliesKey),
              let replies = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        NSLog("[Replr][AppGroup] consumeReplies: got %d replies", replies.count)
        return replies
    }

    /// Call this in the keyboard process before reading any value the intent process may have just written.
    func synchronize() {
        defaults.synchronize()
    }

    // MARK: - Captured screenshot tracking (for opt-in cleanup)

    func recordCapturedScreenshotID(_ id: String) {
        var ids = capturedScreenshotIDs()
        guard !ids.contains(id) else { return }
        ids.append(id)
        if let data = try? JSONEncoder().encode(ids) {
            defaults.set(data, forKey: Constants.capturedScreenshotIDsKey)
            defaults.synchronize()
        }
    }

    func capturedScreenshotIDs() -> [String] {
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.capturedScreenshotIDsKey),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return ids
    }

    func clearCapturedScreenshotIDs() {
        defaults.removeObject(forKey: Constants.capturedScreenshotIDsKey)
        defaults.synchronize()
    }

    var autoClearScreenshots: Bool {
        get { defaults.bool(forKey: Constants.autoClearScreenshotsKey) }
        set { defaults.set(newValue, forKey: Constants.autoClearScreenshotsKey); defaults.synchronize() }
    }

    // MARK: - Error relay

    func saveError(_ message: String) {
        NSLog("[Replr][AppGroup] saveError: %@", message)
        defaults.set(message, forKey: Constants.pendingErrorKey)
        defaults.synchronize()
    }

    func consumeError() -> String? {
        defaults.synchronize()
        guard let msg = defaults.string(forKey: Constants.pendingErrorKey), !msg.isEmpty else { return nil }
        defaults.removeObject(forKey: Constants.pendingErrorKey)
        defaults.synchronize()
        return msg
    }

    // MARK: - Generation in-flight flag

    var isGenerating: Bool {
        get { defaults.bool(forKey: Constants.isGeneratingKey) }
        set { defaults.set(newValue, forKey: Constants.isGeneratingKey); defaults.synchronize() }
    }

    // MARK: - Setup detection flags (written by keyboard extension, read by companion onboarding)

    var keyboardInstalled: Bool {
        get { defaults.bool(forKey: Constants.keyboardInstalledKey) }
        set { defaults.set(newValue, forKey: Constants.keyboardInstalledKey); defaults.synchronize() }
    }

    // File-backed (not UserDefaults) — the keyboard writes this and the app reads it across
    // processes; App Group UserDefaults caches stalely between processes, files do not.
    var fullAccessGranted: Bool {
        get { FileManager.default.fileExists(atPath: container.appendingPathComponent(Constants.fullAccessGrantedKey).path) }
        set {
            let url = container.appendingPathComponent(Constants.fullAccessGrantedKey)
            if newValue { FileManager.default.createFile(atPath: url.path, contents: nil) }
            else { try? FileManager.default.removeItem(at: url) }
        }
    }

    // MARK: - Memory cue (written by GenerateReplyIntent, read + consumed by keyboard)

    var memoryUsedContactName: String? {
        get { defaults.string(forKey: Constants.memoryUsedContactKey) }
        set {
            if let v = newValue { defaults.set(v, forKey: Constants.memoryUsedContactKey) }
            else { defaults.removeObject(forKey: Constants.memoryUsedContactKey) }
            defaults.synchronize()
        }
    }

    // MARK: - First-capture consent (set once by keyboard after user acknowledges)

    var hasConsentedToCapture: Bool {
        get { defaults.bool(forKey: Constants.hasConsentedToCaptureKey) }
        set { defaults.set(newValue, forKey: Constants.hasConsentedToCaptureKey); defaults.synchronize() }
    }

    // MARK: - Back Tap skipped during onboarding

    var backTapSkipped: Bool {
        get { defaults.bool(forKey: Constants.backTapSkippedKey) }
        set { defaults.set(newValue, forKey: Constants.backTapSkippedKey); defaults.synchronize() }
    }

    var backTapSetupStarted: Bool {
        get { defaults.bool(forKey: Constants.backTapSetupStartedKey) }
        set { defaults.set(newValue, forKey: Constants.backTapSetupStartedKey); defaults.synchronize() }
    }

    var lastIntentFiredAt: Date? {
        get { defaults.object(forKey: Constants.lastIntentFiredAtKey) as? Date }
        set {
            if let v = newValue { defaults.set(v, forKey: Constants.lastIntentFiredAtKey) }
            else { defaults.removeObject(forKey: Constants.lastIntentFiredAtKey) }
            defaults.synchronize()
        }
    }

    // MARK: - Capture sessions

    private static let maxSessions = 50
    private static let conversationWindowSeconds: TimeInterval = 4 * 60 * 60  // 4 hours

    func saveCaptureSessions(_ sessions: [CaptureSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: Constants.captureSessionsKey)
        defaults.synchronize()
    }

    func loadCaptureSessions() -> [CaptureSession] {
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.captureSessionsKey),
              let sessions = try? JSONDecoder().decode([CaptureSession].self, from: data)
        else { return [] }
        return sessions
    }

    func appendCaptureSession(_ session: CaptureSession) {
        var sessions = loadCaptureSessions()
        sessions.append(session)
        if sessions.count > Self.maxSessions {
            sessions.removeFirst(sessions.count - Self.maxSessions)
        }
        saveCaptureSessions(sessions)
    }

    func markLastSessionReplySelected(_ reply: String) {
        var sessions = loadCaptureSessions()
        guard !sessions.isEmpty else { return }
        sessions[sessions.count - 1].selectedReply = reply
        saveCaptureSessions(sessions)
    }

    /// Summaries from sessions within the last 4 hours, oldest first.
    func activeSessionSummaries() -> [String] {
        let cutoff = Date().addingTimeInterval(-Self.conversationWindowSeconds)
        return loadCaptureSessions()
            .filter { $0.timestamp > cutoff }
            .compactMap { $0.llmSummary }
    }

    func clearCaptureSessions() {
        defaults.removeObject(forKey: Constants.captureSessionsKey)
        defaults.synchronize()
    }

    // MARK: - Reply persistence (restore on keyboard reopen)

    var persistReplies: Bool {
        get { defaults.object(forKey: Constants.persistRepliesKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Constants.persistRepliesKey); defaults.synchronize() }
    }

    /// Free-text "About You" the user writes about themselves; sent per-request to steer replies.
    var aboutUser: String {
        get { defaults.string(forKey: Constants.aboutUserKey) ?? "" }
        set { defaults.set(newValue, forKey: Constants.aboutUserKey); defaults.synchronize() }
    }

    /// How many times the in-keyboard "type a direction" coachmark has shown.
    /// Coachmark appears while < 3; dismissing (✕) sets it to 3 so it stops.
    var intentTipShowCount: Int {
        get { defaults.integer(forKey: Constants.intentTipShowCountKey) }
        set { defaults.set(newValue, forKey: Constants.intentTipShowCountKey); defaults.synchronize() }
    }

    func saveCachedReplies(_ replies: [String]) {
        guard let data = try? JSONEncoder().encode(replies) else { return }
        defaults.set(data, forKey: Constants.cachedRepliesKey)
        defaults.synchronize()
    }

    func readCachedReplies() -> [String]? {
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.cachedRepliesKey),
              let replies = try? JSONDecoder().decode([String].self, from: data),
              !replies.isEmpty else { return nil }
        return replies
    }

    func clearCachedReplies() {
        defaults.removeObject(forKey: Constants.cachedRepliesKey)
        defaults.synchronize()
    }

    // MARK: - Selected tone (keyboard writes, intent reads)

    func saveSelectedTone(_ tone: Tone) {
        guard let data = try? JSONEncoder().encode(tone) else { return }
        defaults.set(data, forKey: Constants.selectedToneKey)
        defaults.synchronize()
    }

    func readSelectedTone() -> Tone {
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.selectedToneKey),
              let tone = try? JSONDecoder().decode(Tone.self, from: data) else {
            // Default: Natural (the clean base), falling back to first available tone.
            return defaultTone
        }
        // If the stored tone is a preset whose name no longer exists (e.g. renamed Dating → Flirty),
        // fall back to Natural so the user never sees a dangling tone name.
        let validPresetNames = Set(Tone.presets.map(\.name))
        if tone.isPreset && !validPresetNames.contains(tone.name) {
            return defaultTone
        }
        return tone
    }

    private var defaultTone: Tone {
        let all = readTones()
        return all.first { $0.name == "Natural" } ?? all.first ?? Tone.presets[0]
    }

    // MARK: - Tones list

    func writeTones(_ tones: [Tone]) throws {
        let data = try JSONEncoder().encode(tones)
        defaults.set(data, forKey: Constants.tonesKey)
        defaults.synchronize()
    }

    func readTones() -> [Tone] {
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.tonesKey),
              let saved = try? JSONDecoder().decode([Tone].self, from: data) else { return Tone.presets }
        // Merge: add any new presets that aren't in the saved array yet (e.g. after an app update).
        // Existing presets keep their saved isEnabled value; new ones use the preset default.
        let savedPresetNames = Set(saved.filter(\.isPreset).map(\.name))
        let addedPresets = Tone.presets.filter { !savedPresetNames.contains($0.name) }
        let presets = saved.filter(\.isPreset) + addedPresets
        let custom  = saved.filter { !$0.isPreset }
        return presets + custom
    }

    // MARK: - User ID

    func userID() -> String {
        if let id = defaults.string(forKey: Constants.userIDKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Constants.userIDKey)
        defaults.synchronize()
        return id
    }

    // MARK: - Reply context (companion app sets, keyboard shows, intent reads)

    func savePendingContext(_ text: String) {
        if text.isEmpty {
            defaults.removeObject(forKey: Constants.pendingContextKey)
        } else {
            defaults.set(text, forKey: Constants.pendingContextKey)
        }
        defaults.synchronize()
    }

    func readPendingContext() -> String? {
        defaults.synchronize()
        guard let text = defaults.string(forKey: Constants.pendingContextKey), !text.isEmpty else { return nil }
        return text
    }

    // MARK: - Screenshot file (broadcast/scroll capture only)

    func writeScreenshot(_ image: UIImage) throws {
        guard let data = image.pngData() else { throw AppGroupError.encodingFailed }
        let url = container.appendingPathComponent(Constants.screenshotFilename)
        try data.write(to: url, options: .atomic)
        NSLog("[Replr][AppGroup] writeScreenshot file: %.0fx%.0f (%d bytes)", image.size.width, image.size.height, data.count)
    }

    func readScreenshot() throws -> UIImage {
        let url = container.appendingPathComponent(Constants.screenshotFilename)
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else { throw AppGroupError.decodingFailed }
        NSLog("[Replr][AppGroup] readScreenshot file: %.0fx%.0f", image.size.width, image.size.height)
        return image
    }

    // MARK: - Capture ready flag (broadcast flow only)

    var isCaptureReady: Bool {
        get { FileManager.default.fileExists(atPath: container.appendingPathComponent(Constants.captureReadyKey).path) }
        set {
            let url = container.appendingPathComponent(Constants.captureReadyKey)
            if newValue { FileManager.default.createFile(atPath: url.path, contents: nil) }
            else { try? FileManager.default.removeItem(at: url) }
        }
    }

    var isBroadcastActive: Bool {
        get { FileManager.default.fileExists(atPath: container.appendingPathComponent(Constants.broadcastActiveKey).path) }
        set {
            let url = container.appendingPathComponent(Constants.broadcastActiveKey)
            if newValue { FileManager.default.createFile(atPath: url.path, contents: nil) }
            else { try? FileManager.default.removeItem(at: url) }
        }
    }

    // MARK: - Contacts

    private static let maxContacts = 200

    func saveContacts(_ contacts: [Contact]) {
        guard let data = try? JSONEncoder().encode(contacts) else { return }
        defaults.set(data, forKey: Constants.contactsKey)
        defaults.synchronize()
    }

    func loadContacts() -> [Contact] {
        defaults.synchronize()
        guard let data = defaults.data(forKey: Constants.contactsKey),
              let contacts = try? JSONDecoder().decode([Contact].self, from: data)
        else { return [] }
        return contacts
    }

    @discardableResult
    func createContact(displayName: String) -> Contact {
        var contacts = loadContacts()
        let contact = Contact(id: UUID(), displayName: displayName)
        contacts.append(contact)
        if contacts.count > Self.maxContacts {
            contacts.removeFirst(contacts.count - Self.maxContacts)
        }
        saveContacts(contacts)
        return contact
    }

    func updateContact(_ contact: Contact) {
        var contacts = loadContacts()
        if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[i] = contact
            saveContacts(contacts)
        }
    }

    func findContacts(named name: String) -> [Contact] {
        let needle = name.trimmingCharacters(in: .whitespaces).lowercased()
        return loadContacts().filter {
            $0.displayName.trimmingCharacters(in: .whitespaces).lowercased() == needle
        }
    }

    var currentContactID: UUID? {
        get {
            defaults.synchronize()
            guard let str = defaults.string(forKey: Constants.currentContactIDKey) else { return nil }
            return UUID(uuidString: str)
        }
        set {
            if let id = newValue {
                defaults.set(id.uuidString, forKey: Constants.currentContactIDKey)
            } else {
                defaults.removeObject(forKey: Constants.currentContactIDKey)
            }
            defaults.synchronize()
        }
    }

    // MARK: - Memory settings

    /// 0 means all time; any positive value is a day count.
    var memoryWindowDays: Int {
        get { defaults.integer(forKey: Constants.memoryWindowDaysKey) } // 0 if unset = all time
        set { defaults.set(newValue, forKey: Constants.memoryWindowDaysKey); defaults.synchronize() }
    }

    /// Hard max is 20; default is 10 when unset.
    var memoryDepth: Int {
        get {
            let v = defaults.integer(forKey: Constants.memoryDepthKey)
            return v > 0 ? min(v, 20) : 10
        }
        set { defaults.set(min(newValue, 20), forKey: Constants.memoryDepthKey); defaults.synchronize() }
    }

    var memoryEnabled: Bool {
        get { defaults.object(forKey: Constants.memoryEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Constants.memoryEnabledKey); defaults.synchronize() }
    }

    func recentSummaries(forContactID id: UUID, limit: Int) -> [String] {
        let cutoff: Date? = memoryWindowDays > 0
            ? Calendar.current.date(byAdding: .day, value: -memoryWindowDays, to: Date())
            : nil
        let all = loadCaptureSessions()
            .filter { $0.contactID == id }
            .filter { cutoff == nil || $0.timestamp >= cutoff! }
            .compactMap { $0.llmSummary }
        let start = max(0, all.count - limit)
        return Array(all[start...])
    }

    func sessions(forContactID id: UUID) -> [CaptureSession] {
        loadCaptureSessions().filter { $0.contactID == id }
    }

    func clearMemory(forContactID id: UUID) {
        var all = loadCaptureSessions()
        for i in all.indices where all[i].contactID == id {
            all[i].llmSummary = nil
        }
        saveCaptureSessions(all)
    }

    // MARK: - Intent hint (keyboard writes, keyboard reads, cleared after generation)

    func saveIntentHint(_ text: String?) {
        if let text, !text.isEmpty {
            defaults.set(text, forKey: Constants.intentHintKey)
        } else {
            defaults.removeObject(forKey: Constants.intentHintKey)
        }
        defaults.synchronize()
    }

    func readIntentHint() -> String? {
        defaults.synchronize()
        guard let text = defaults.string(forKey: Constants.intentHintKey), !text.isEmpty else { return nil }
        return text
    }

    // MARK: - Switch keyboard (companion app requests keyboard switch before screenshot)

    var switchKeyboardRequested: Bool {
        defaults.synchronize()
        return defaults.bool(forKey: Constants.switchKeyboardKey)
    }

    func setSwitchKeyboardRequested(_ value: Bool) {
        defaults.set(value, forKey: Constants.switchKeyboardKey)
        defaults.synchronize()
    }

    // MARK: - Trial + paywall

    var trialUsedCount: Int {
        get { defaults.integer(forKey: Constants.trialUsedCountKey) }
        set {
            defaults.set(newValue, forKey: Constants.trialUsedCountKey)
            if newValue >= 10 {
                defaults.set(true, forKey: Constants.trialExhaustedKey)
            }
            defaults.synchronize()
        }
    }

    var trialExhausted: Bool {
        get { defaults.bool(forKey: Constants.trialExhaustedKey) }
        set { defaults.set(newValue, forKey: Constants.trialExhaustedKey); defaults.synchronize() }
    }

    var paywallRequested: Bool {
        get { defaults.bool(forKey: Constants.paywallRequestedKey) }
        set { defaults.set(newValue, forKey: Constants.paywallRequestedKey); defaults.synchronize() }
    }

    // MARK: - Credits + model selection + dev mode

    var creditBalance: Int {
        get { defaults.integer(forKey: Constants.creditBalanceKey) }
        set { defaults.set(newValue, forKey: Constants.creditBalanceKey); defaults.synchronize() }
    }

    /// User's production model choice (shown in Settings → AI Model). Sonnet or GPT-5.4.
    var userModel: String {
        get { defaults.string(forKey: Constants.selectedModelKey) ?? "claude-sonnet-4-6" }
        set { defaults.set(newValue, forKey: Constants.selectedModelKey); defaults.synchronize() }
    }

    /// Dev override model (only active when devMode=true). Can be any model in the expanded list.
    var devModel: String {
        get { defaults.string(forKey: Constants.devModelKey) ?? "claude-sonnet-4-6" }
        set { defaults.set(newValue, forKey: Constants.devModelKey); defaults.synchronize() }
    }

    /// The model actually used for generation.
    /// When dev mode ON → devModel (can be any experimental model).
    /// When dev mode OFF → userModel (Sonnet or GPT-5.4 from Settings).
    var selectedModel: String {
        get { devMode ? devModel : userModel }
        set {
            if devMode { devModel = newValue } else { userModel = newValue }
        }
    }

    var devMode: Bool {
        get { defaults.bool(forKey: Constants.devModeKey) }
        set { defaults.set(newValue, forKey: Constants.devModeKey); defaults.synchronize() }
    }

    /// Returns 9_999 in dev mode so the keyboard never shows a paywall during testing.
    var effectiveCreditBalance: Int {
        devMode ? 9_999 : creditBalance
    }

    /// Credits required for the currently selected model. Returns 0 in dev mode.
    /// Defined here (in Shared) so keyboard extension can use it without importing ReplrModel.
    var creditsRequired: Int {
        if devMode { return 0 }
        switch selectedModel {
        case "claude-sonnet-4-6":        return 8
        case "gpt-5.4":                  return 7
        case "claude-opus-4-6":          return 15
        case "gpt-5.5":                  return 15
        case "gemini-3.1-pro-preview":   return 6
        case "gemini-3.1-pro-low":       return 6
        case "gemini-3-flash-preview":   return 3
        case "grok-4":                   return 7
        case "grok-4.3":                 return 2
        case "gpt-5.4-mini":             return 2
        default:                          return 7
        }
    }

    /// Short label for the active model — shown in keyboard header during dev mode.
    var selectedModelShortLabel: String {
        switch selectedModel {
        case "claude-sonnet-4-6":      return "Sonnet 4.6"
        case "gpt-5.4":               return "GPT-5.4"
        case "claude-opus-4-6":        return "Opus 4.6"
        case "gpt-5.5":               return "GPT-5.5"
        case "gemini-3.1-pro-preview": return "Pro High"
        case "gemini-3.1-pro-low":     return "Pro Low"
        case "gemini-3-flash-preview": return "Gemini Flash"
        case "grok-4":                return "Grok 4"
        case "grok-4.3":              return "Grok 4.3"
        case "gpt-5.4-mini":          return "5.4 Mini"
        default:                       return selectedModel
        }
    }

}

enum AppGroupError: Error {
    case encodingFailed
    case decodingFailed
}
