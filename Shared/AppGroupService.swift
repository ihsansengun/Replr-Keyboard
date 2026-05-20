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
            return readTones().first ?? Tone.presets[0]
        }
        return tone
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
              let tones = try? JSONDecoder().decode([Tone].self, from: data) else { return Tone.presets }
        return tones
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
}

enum AppGroupError: Error {
    case encodingFailed
    case decodingFailed
}
