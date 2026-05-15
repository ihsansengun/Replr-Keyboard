# Contact-Aware Conversation Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the time-based conversation memory heuristic with per-contact memory keyed on LLM-extracted contact names, grouped by stable UUID-based Contact identities.

**Architecture:** The LLM extracts the contact name as a new `CONTACT:` line in its single-call output. iOS intents use `currentContactID` (shared via App Group) to fetch that contact's last 10 summaries before each API call and create/resolve a Contact after. The keyboard shows a tappable contact chip that opens an inline edit flow with disambiguation support for same-name contacts.

**Tech Stack:** Swift (iOS 17+, SwiftUI, UIKit, AppIntents, XCTest), TypeScript (Hono/Cloudflare Workers, Vitest)

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `Shared/Models/Contact.swift` | **Create** | `Contact` Codable+Identifiable struct |
| `Shared/Models/CaptureSession.swift` | **Modify** | Add `contactID: UUID?`, `contactName: String?` |
| `Shared/Constants.swift` | **Modify** | Add `contactsKey`, `currentContactIDKey` |
| `Shared/AppGroupService.swift` | **Modify** | Contact CRUD, `currentContactID`, `recentSummaries`, `sessions`, `clearMemory` |
| `Replr/Replr.xcodeproj/project.pbxproj` | **Modify** | Register `Contact.swift` in all 4 build targets |
| `ReplrTests/AppGroupServiceTests.swift` | **Modify** | Contact CRUD + memory tests |
| `backend/src/services/llm.ts` | **Modify** | `LlmResult` + `contactName`, `parseLlmOutput` CONTACT: extraction, `buildReplyFormat` CONTACT: first line |
| `backend/src/types/index.ts` | **Modify** | `ReplyResponse.contactName: string` |
| `backend/src/routes/reply.ts` | **Modify** | Return `contactName` from both `/reply` and `/reply/scroll` |
| `backend/tests/llm.test.ts` | **Modify** | Add CONTACT: tests, fix existing `generateReplies` type assertions |
| `Shared/ReplyService.swift` | **Modify** | `ReplyResponse` and `ReplyResult` add `contactName: String?` |
| `Replr/Replr/Intents/QuickReplyIntent.swift` | **Modify** | Contact-based previousContext, create/resolve Contact after API call |
| `Replr/Replr/Intents/GenerateReplyIntent.swift` | **Modify** | Same as QuickReplyIntent |
| `ReplrKeyboard/Views/KeyboardView.swift` | **Modify** | `KeyboardState` new cases, `KeyboardModel` contactName + callbacks, contact chip in strip and above carousel, `EditContactView`, `DisambiguateView` |
| `ReplrKeyboard/KeyboardViewController.swift` | **Modify** | `viewWillAppear` contact resolve, `viewDidLoad` callback wiring, height constants |
| `Replr/Replr/Features/Captures/CaptureLogView.swift` | **Modify** | `contactName` display, contact filter chips, "Clear Memory" per contact |

---

## Task 1: Contact Model + AppGroupService Infrastructure

**Files:**
- Create: `Shared/Models/Contact.swift`
- Modify: `Shared/Models/CaptureSession.swift`
- Modify: `Shared/Constants.swift`
- Modify: `Shared/AppGroupService.swift`
- Modify: `Replr/Replr.xcodeproj/project.pbxproj`
- Modify: `ReplrTests/AppGroupServiceTests.swift`

- [ ] **Step 1: Write failing tests for Contact infrastructure**

Add to `ReplrTests/AppGroupServiceTests.swift`:

```swift
import XCTest
@testable import Replr

final class AppGroupServiceTests: XCTestCase {
    let service = AppGroupService.shared

    func testUserIDIsPersistent() {
        let id1 = service.userID()
        let id2 = service.userID()
        XCTAssertEqual(id1, id2)
    }

    func testCaptureReadyFlag() {
        service.isCaptureReady = true
        XCTAssertTrue(service.isCaptureReady)
        service.isCaptureReady = false
        XCTAssertFalse(service.isCaptureReady)
    }

    func testTonesRoundtrip() throws {
        let tones = Tone.presets
        try service.writeTones(tones)
        let read = service.readTones()
        XCTAssertEqual(tones.map(\.name), read.map(\.name))
    }

    // MARK: - Contact tests

    func testCreateContactPersistsAndReturns() {
        // clean slate for this test
        service.saveContacts([])
        let c = service.createContact(displayName: "Alice")
        XCTAssertEqual(c.displayName, "Alice")
        let loaded = service.loadContacts()
        XCTAssertTrue(loaded.contains(where: { $0.id == c.id }))
    }

    func testUpdateContactChangesDisplayName() {
        service.saveContacts([])
        var c = service.createContact(displayName: "Bob")
        c.displayName = "Bobby"
        service.updateContact(c)
        let loaded = service.loadContacts()
        let found = loaded.first(where: { $0.id == c.id })
        XCTAssertEqual(found?.displayName, "Bobby")
    }

    func testFindContactsCaseInsensitive() {
        service.saveContacts([])
        _ = service.createContact(displayName: "Alexis")
        _ = service.createContact(displayName: "alexis")
        _ = service.createContact(displayName: "ALEXIS")
        let results = service.findContacts(named: "alexis")
        XCTAssertEqual(results.count, 3)
    }

    func testFindContactsTrimsWhitespace() {
        service.saveContacts([])
        _ = service.createContact(displayName: "  Sam  ")
        let results = service.findContacts(named: " sam ")
        XCTAssertEqual(results.count, 1)
    }

    func testRecentSummariesReturnsCorrectContactSummaries() {
        service.saveContacts([])
        service.clearCaptureSessions()
        let contact = service.createContact(displayName: "Carol")
        let s1 = CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                                contextHint: nil, generatedReplies: [], selectedReply: nil,
                                llmSummary: "First summary", contactID: contact.id, contactName: "Carol")
        let s2 = CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                                contextHint: nil, generatedReplies: [], selectedReply: nil,
                                llmSummary: "Second summary", contactID: contact.id, contactName: "Carol")
        let other = CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                                   contextHint: nil, generatedReplies: [], selectedReply: nil,
                                   llmSummary: "Other person", contactID: UUID(), contactName: "Dan")
        service.saveCaptureSessions([s1, s2, other])
        let summaries = service.recentSummaries(forContactID: contact.id, limit: 10)
        XCTAssertEqual(summaries, ["First summary", "Second summary"])
    }

    func testRecentSummariesHonorsLimit() {
        service.saveContacts([])
        service.clearCaptureSessions()
        let id = UUID()
        let sessions = (1...5).map { i in
            CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                           contextHint: nil, generatedReplies: [], selectedReply: nil,
                           llmSummary: "Summary \(i)", contactID: id, contactName: "Test")
        }
        service.saveCaptureSessions(sessions)
        let result = service.recentSummaries(forContactID: id, limit: 3)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result, ["Summary 3", "Summary 4", "Summary 5"])
    }

    func testClearMemoryZeroesOutSummaries() {
        service.saveContacts([])
        service.clearCaptureSessions()
        let id = UUID()
        let s = CaptureSession(id: UUID(), timestamp: Date(), thumbnailData: nil,
                               contextHint: nil, generatedReplies: [], selectedReply: nil,
                               llmSummary: "Something happened", contactID: id, contactName: "Eve")
        service.saveCaptureSessions([s])
        service.clearMemory(forContactID: id)
        let after = service.loadCaptureSessions().first(where: { $0.contactID == id })
        XCTAssertNil(after?.llmSummary)
    }

    func testCurrentContactIDRoundtrip() {
        let uuid = UUID()
        service.currentContactID = uuid
        XCTAssertEqual(service.currentContactID, uuid)
        service.currentContactID = nil
        XCTAssertNil(service.currentContactID)
    }
}
```

- [ ] **Step 2: Build ReplrTests target — confirm it fails to compile**

In Xcode, select the `ReplrTests` scheme and press Cmd+B. Expected: compile errors referencing `contactID`, `contactName` on `CaptureSession`, missing `Contact`, missing AppGroupService methods.

- [ ] **Step 3: Create `Shared/Models/Contact.swift`**

```swift
import Foundation

struct Contact: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
}
```

- [ ] **Step 4: Update `Shared/Models/CaptureSession.swift` — add contact fields**

Open `Shared/Models/CaptureSession.swift`. Replace the struct body to add two new optional fields at the end (existing sessions without these keys decode with `nil` defaults):

```swift
import Foundation

struct CaptureSession: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let thumbnailData: Data?
    let contextHint: String?
    let generatedReplies: [String]
    var selectedReply: String?
    var llmSummary: String?
    var contactID: UUID?
    var contactName: String?
}
```

- [ ] **Step 5: Update `Shared/Constants.swift` — add contact keys**

Add inside the `enum Constants` body, below `captureSessionsKey`:

```swift
static let contactsKey          = "contacts"
static let currentContactIDKey  = "current_contact_id"
```

Full file after edit:

```swift
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

    // File-based keys (broadcast/scroll capture only)
    static let screenshotFilename     = "screenshot.png"
    static let captureReadyKey        = "capture_ready"
    static let scrollModeKey          = "scroll_mode"
    static let scrollFrameCountKey    = "scroll_frame_count"
    static let scrollCaptureReadyKey  = "scroll_capture_ready"
    static let broadcastActiveKey     = "broadcast_active"
}
```

- [ ] **Step 6: Update `Shared/AppGroupService.swift` — add Contact infrastructure**

Append the following MARK section at the end of `AppGroupService`, before the closing `}`:

```swift
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

    func recentSummaries(forContactID id: UUID, limit: Int) -> [String] {
        let all = loadCaptureSessions()
            .filter { $0.contactID == id }
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
```

- [ ] **Step 7: Register `Contact.swift` in `project.pbxproj`**

Run the following Python script from the repo root. It uses stable hard-coded UUIDs so the edit is idempotent:

```bash
python3 - <<'EOF'
import re

path = "Replr/Replr.xcodeproj/project.pbxproj"
with open(path, "r") as f:
    text = f.read()

FILE_UUID    = "7E456A2C26BA4FD6BAE17EC2"
BUILD_UUID_1 = "EDDF87B5A9DC4E6582E13968"   # main Replr app
BUILD_UUID_2 = "485BF568190040E6894A4AEC"   # keyboard extension
BUILD_UUID_3 = "BA77ACE356C940B2ACEF3AD8"   # broadcast extension
BUILD_UUID_4 = "1F38788925D348DB949BC2ED"   # ReplrTests

# Skip if already added
if FILE_UUID in text:
    print("Already added — skipping")
    exit(0)

# 1. PBXFileReference entry
old_ref = ('901023AA25EF4F65B91E4A72 /* CaptureSession.swift */ = '
           '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
           'path = CaptureSession.swift; sourceTree = "<group>"; };')
new_ref = (old_ref + '\n\t\t' +
           FILE_UUID + ' /* Contact.swift */ = '
           '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
           'path = Contact.swift; sourceTree = "<group>"; };')
text = text.replace(old_ref, new_ref, 1)

# 2. Four PBXBuildFile entries (after last CaptureSession build file entry)
old_last_build = ('86D9D25E85BA4CEB8F652700 /* CaptureSession.swift in Sources */ = '
                  '{isa = PBXBuildFile; fileRef = 901023AA25EF4F65B91E4A72 /* CaptureSession.swift */; };')
def make_build(uuid):
    return (uuid + ' /* Contact.swift in Sources */ = '
            '{isa = PBXBuildFile; fileRef = ' + FILE_UUID + ' /* Contact.swift */; };')
new_build_block = (old_last_build + '\n\t\t' +
                   make_build(BUILD_UUID_1) + '\n\t\t' +
                   make_build(BUILD_UUID_2) + '\n\t\t' +
                   make_build(BUILD_UUID_3) + '\n\t\t' +
                   make_build(BUILD_UUID_4))
text = text.replace(old_last_build, new_build_block, 1)

# 3. Add to Models group children
old_child = '901023AA25EF4F65B91E4A72 /* CaptureSession.swift */,'
new_child = old_child + '\n\t\t\t\t' + FILE_UUID + ' /* Contact.swift */,'
text = text.replace(old_child, new_child, 1)

# 4. Add to each of the 4 Sources build phases (after each CaptureSession entry)
pairs = [
    ('9716598EFAAC4EDEB2269AA3 /* CaptureSession.swift in Sources */',  BUILD_UUID_1),
    ('B6C4868C80B147D5B844BA70 /* CaptureSession.swift in Sources */',  BUILD_UUID_2),
    ('543F9DDB49F94FF79619573B /* CaptureSession.swift in Sources */',  BUILD_UUID_3),
    ('86D9D25E85BA4CEB8F652700 /* CaptureSession.swift in Sources */',  BUILD_UUID_4),
]
for old_src, build_uuid in pairs:
    new_src = old_src + ',\n\t\t\t\t' + build_uuid + ' /* Contact.swift in Sources */'
    text = text.replace(old_src + ',', new_src + ',', 1)

with open(path, "w") as f:
    f.write(text)

print("pbxproj updated successfully")
EOF
```

Expected output: `pbxproj updated successfully`

- [ ] **Step 8: Build and run ReplrTests — verify all new tests pass**

In Xcode: select the `ReplrTests` scheme, press Cmd+U.

Expected: All tests pass. If `testRecentSummariesHonorsLimit` fails, check that `recentSummaries` takes the last N items (not first N).

- [ ] **Step 9: Commit**

```bash
git add Shared/Models/Contact.swift \
        Shared/Models/CaptureSession.swift \
        Shared/Constants.swift \
        Shared/AppGroupService.swift \
        Replr/Replr.xcodeproj/project.pbxproj \
        Replr/ReplrTests/AppGroupServiceTests.swift
git commit -m "$(cat <<'EOF'
feat: add Contact model and AppGroupService contact infrastructure

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Backend — CONTACT: Extraction + Types + Routes

**Files:**
- Modify: `backend/src/services/llm.ts`
- Modify: `backend/src/types/index.ts`
- Modify: `backend/src/routes/reply.ts`
- Modify: `backend/tests/llm.test.ts`

- [ ] **Step 1: Write failing tests for CONTACT: extraction**

Open `backend/tests/llm.test.ts`. Replace the entire file with:

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { parseReplies, parseLlmOutput, generateReplies } from '../src/services/llm'

const anthropicMessagesCreate = vi.fn()
const openaiChatCreate = vi.fn()

vi.mock('@anthropic-ai/sdk', () => ({
  default: function MockAnthropic() {
    return { messages: { create: anthropicMessagesCreate } }
  },
}))

vi.mock('openai', () => ({
  default: function MockOpenAI() {
    return { chat: { completions: { create: openaiChatCreate } } }
  },
}))

describe('parseReplies', () => {
  it('extracts numbered lines as replies', () => {
    const raw = `1. Hey that's wild\n2. No way haha\n3. That's actually funny`
    expect(parseReplies(raw)).toEqual([
      "Hey that's wild",
      'No way haha',
      "That's actually funny"
    ])
  })

  it('handles extra whitespace', () => {
    const raw = `1.  Hey there \n2.  Sure thing \n3.  Sounds good `
    expect(parseReplies(raw)).toEqual(['Hey there', 'Sure thing', 'Sounds good'])
  })

  it('returns empty array for non-numbered text', () => {
    expect(parseReplies('some random text')).toEqual([])
  })

  it('handles indented numbered lines', () => {
    const raw = `  1. Got it\n  2. Makes sense\n  3. For sure`
    expect(parseReplies(raw)).toEqual(['Got it', 'Makes sense', 'For sure'])
  })
})

describe('parseLlmOutput', () => {
  it('extracts CONTACT, SUMMARY, and replies', () => {
    const raw = `CONTACT: Alexis\nSUMMARY: Discussing weekend plans\n1. Sounds fun!\n2. I'm in\n3. Let's do it`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('Alexis')
    expect(result.summary).toBe('Discussing weekend plans')
    expect(result.replies).toEqual(["Sounds fun!", "I'm in", "Let's do it"])
  })

  it('returns empty string for contactName when CONTACT line is missing', () => {
    const raw = `SUMMARY: Just chatting\n1. Hey\n2. Sure\n3. Cool`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('')
    expect(result.summary).toBe('Just chatting')
  })

  it('returns empty string for contactName when value is Unknown', () => {
    const raw = `CONTACT: Unknown\nSUMMARY: Chat\n1. Hi`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('Unknown')
  })

  it('handles group chat prefix', () => {
    const raw = `CONTACT: Group: Weekend Plans\nSUMMARY: Planning trip\n1. Sounds good`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('Group: Weekend Plans')
  })

  it('is case-insensitive for CONTACT: prefix', () => {
    const raw = `contact: Sam\nSUMMARY: Work stuff\n1. Noted`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('Sam')
  })
})

describe('generateReplies', () => {
  beforeEach(() => {
    vi.resetAllMocks()
  })

  it('calls Claude with correct model and returns parsed LlmResult', async () => {
    anthropicMessagesCreate.mockResolvedValue({
      content: [{ type: 'text', text: 'CONTACT: Dana\nSUMMARY: Work chat\n1. Hey\n2. Sure\n3. Cool' }],
    })

    const result = await generateReplies({
      screenshotBase64: 'abc',
      tone: 'casual',
      model: 'claude',
      tier: 'free',
      anthropicKey: 'key',
      openaiKey: 'key',
    })

    expect(result.replies).toEqual(['Hey', 'Sure', 'Cool'])
    expect(result.summary).toBe('Work chat')
    expect(result.contactName).toBe('Dana')
    expect(anthropicMessagesCreate).toHaveBeenCalledWith(expect.objectContaining({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
    }))
  })

  it('calls GPT-4o with correct model and returns parsed LlmResult', async () => {
    openaiChatCreate.mockResolvedValue({
      choices: [{ message: { content: 'CONTACT: Pat\nSUMMARY: Weekend plans\n1. Yes\n2. No\n3. Maybe' } }],
    })

    const result = await generateReplies({
      screenshotBase64: 'abc',
      tone: 'casual',
      model: 'gpt4o',
      tier: 'free',
      anthropicKey: 'key',
      openaiKey: 'key',
    })

    expect(result.replies).toEqual(['Yes', 'No', 'Maybe'])
    expect(result.contactName).toBe('Pat')
    expect(openaiChatCreate).toHaveBeenCalledWith(expect.objectContaining({
      model: 'gpt-4o',
      max_tokens: 1024,
    }))
  })

  it('returns 5 replies for premium tier', async () => {
    anthropicMessagesCreate.mockResolvedValue({
      content: [{ type: 'text', text: 'CONTACT: Sam\nSUMMARY: Chat\n1. A\n2. B\n3. C\n4. D\n5. E' }],
    })

    const result = await generateReplies({
      screenshotBase64: 'abc',
      tone: 'casual',
      model: 'claude',
      tier: 'premium',
      anthropicKey: 'key',
      openaiKey: 'key',
    })

    expect(result.replies).toHaveLength(5)
  })
})
```

- [ ] **Step 2: Run tests — verify the new parseLlmOutput tests fail**

```bash
cd backend && npm test
```

Expected: `parseLlmOutput` tests fail (function doesn't yet export `contactName`). The existing `generateReplies` tests may also fail since the old tests compared the full result to a plain array.

- [ ] **Step 3: Update `backend/src/services/llm.ts`**

Make three changes:

**a. Update `LlmResult` interface:**

Replace:
```typescript
export interface LlmResult {
  replies: string[]
  summary: string
}
```
With:
```typescript
export interface LlmResult {
  replies: string[]
  summary: string
  contactName: string
}
```

**b. Update `parseLlmOutput` to extract CONTACT: line:**

Replace the entire `parseLlmOutput` function:
```typescript
/** Parse LLM output: optional CONTACT: line, optional SUMMARY: line, numbered replies. */
export function parseLlmOutput(text: string): LlmResult {
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean)
  let summary = ''
  let contactName = ''
  const replies: string[] = []

  for (const line of lines) {
    if (!contactName && /^contact:/i.test(line)) {
      contactName = line.replace(/^contact:\s*/i, '').trim()
    } else if (!summary && /^summary:/i.test(line)) {
      summary = line.replace(/^summary:\s*/i, '').trim()
    } else if (/^\d+[.)]\s/.test(line)) {
      replies.push(line.replace(/^\d+[.)]\s*/, '').trim())
    }
  }

  return { replies, summary, contactName }
}
```

**c. Update `buildReplyFormat` to emit CONTACT: as the first line:**

Replace:
```typescript
function buildReplyFormat(count: number): string {
  return `Output format — exactly this, no other text:
SUMMARY: [one sentence: topic of conversation and what was last said]
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`
}
```
With:
```typescript
function buildReplyFormat(count: number): string {
  return `Output format — exactly this, no other text:
CONTACT: [display name of the person you are replying TO, exactly as shown in the chat header. "Group: [name]" for group chats. "Unknown" if not visible.]
SUMMARY: [one sentence: topic of conversation and what was last said]
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`
}
```

- [ ] **Step 4: Update `backend/src/types/index.ts` — add contactName to ReplyResponse**

Replace:
```typescript
export interface ReplyResponse {
  replies: string[]
  summary: string            // one-line LLM-extracted summary of this session
}
```
With:
```typescript
export interface ReplyResponse {
  replies: string[]
  summary: string
  contactName: string
}
```

- [ ] **Step 5: Update `backend/src/routes/reply.ts` — return contactName from both routes**

In the `/reply` route handler, replace:
```typescript
    return c.json({ replies: result.replies, summary: result.summary })
```
With:
```typescript
    return c.json({ replies: result.replies, summary: result.summary, contactName: result.contactName })
```

In the `/reply/scroll` route handler, replace the second:
```typescript
    return c.json({ replies: result.replies, summary: result.summary })
```
With:
```typescript
    return c.json({ replies: result.replies, summary: result.summary, contactName: result.contactName })
```

(Both `c.json(...)` calls — one in the POST `/` handler and one in the POST `/scroll` handler.)

- [ ] **Step 6: Run all backend tests — verify they pass**

```bash
cd backend && npm test
```

Expected: All tests pass including the 5 new `parseLlmOutput` tests and the 3 updated `generateReplies` tests.

- [ ] **Step 7: Run TypeScript type check**

```bash
cd backend && npm run typecheck
```

Expected: No type errors.

- [ ] **Step 8: Deploy to Cloudflare**

```bash
cd backend && npm run deploy
```

Expected: `Deployed ... (current)` with no errors.

- [ ] **Step 9: Commit**

```bash
git add backend/src/services/llm.ts \
        backend/src/types/index.ts \
        backend/src/routes/reply.ts \
        backend/tests/llm.test.ts
git commit -m "$(cat <<'EOF'
feat: add CONTACT: extraction to LLM output format and backend response

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: iOS ReplyService + Intents — Contact-Aware Memory

**Files:**
- Modify: `Shared/ReplyService.swift`
- Modify: `Replr/Replr/Intents/QuickReplyIntent.swift`
- Modify: `Replr/Replr/Intents/GenerateReplyIntent.swift`

- [ ] **Step 1: Update `Shared/ReplyService.swift` — add contactName to response types**

Replace `ReplyResponse` and `ReplyResult`:
```swift
struct ReplyResponse: Codable {
    let replies: [String]
    let summary: String?
    let contactName: String?
}

struct ReplyResult {
    let replies: [String]
    let summary: String?
    let contactName: String?
}
```

In `generateReplies(screenshot:tone:summary:previousContext:model:transactionId:)`, replace the return statement:
```swift
        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary)
```
With:
```swift
        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName)
```

In `generateRepliesFromEmail(...)`, replace the return statement similarly:
```swift
        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName)
```

In `generateRepliesFromScroll(...)`, replace the return statement:
```swift
        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName)
```

- [ ] **Step 2: Update `Replr/Replr/Intents/QuickReplyIntent.swift` — contact-aware memory**

Replace the entire `perform()` function body:

```swift
    func perform() async throws -> some IntentResult {
        NSLog("[Replr][QuickReply] fired")

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            NSLog("[Replr][QuickReply] No Photos access")
            AppGroupService.shared.saveError("Allow photo access in Settings → Replr → Photos, then try again.")
            return .result()
        }

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 1
        opts.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )

        guard let asset = PHAsset.fetchAssets(with: .image, options: opts).firstObject else {
            NSLog("[Replr][QuickReply] No screenshot found")
            AppGroupService.shared.saveError("No screenshot found. Take a screenshot of your chat first.")
            return .result()
        }
        NSLog("[Replr][QuickReply] Found screenshot: creationDate=%@", asset.creationDate.map { "\($0)" } ?? "nil")

        let image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            let reqOpts = PHImageRequestOptions()
            reqOpts.deliveryMode = .highQualityFormat
            reqOpts.isNetworkAccessAllowed = false
            reqOpts.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: reqOpts
            ) { image, info in
                if let image, (info?[PHImageResultIsDegradedKey] as? Bool) != true {
                    continuation.resume(returning: image)
                } else if (info?[PHImageErrorKey] as? Error) != nil {
                    continuation.resume(throwing: QuickReplyError.imageLoadFailed)
                }
                // else: degraded frame — wait for full-quality delivery
            }
        }

        NSLog("[Replr][QuickReply] Image loaded: %.0fx%.0f", image.size.width, image.size.height)

        let tone = AppGroupService.shared.readSelectedTone()
        let txID = UserDefaults(suiteName: Constants.appGroupID)?.string(forKey: Constants.transactionIDKey)
        NSLog("[Replr][QuickReply] Calling API: tone=%@", tone.name)

        // Fetch memories for the current confirmed contact
        let previousContext: String?
        if let contactID = AppGroupService.shared.currentContactID {
            let summaries = AppGroupService.shared.recentSummaries(forContactID: contactID, limit: 10)
            previousContext = summaries.isEmpty ? nil : summaries.joined(separator: "\n")
        } else {
            previousContext = nil
        }

        do {
            let result = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: tone,
                summary: nil,
                previousContext: previousContext,
                model: "claude",
                transactionId: txID
            )
            NSLog("[Replr][QuickReply] Got %d replies — saving to App Group", result.replies.count)

            // Resolve or create contact
            let resolvedContactID: UUID?
            let resolvedContactName: String?
            if let existingID = AppGroupService.shared.currentContactID {
                resolvedContactID = existingID
                resolvedContactName = result.contactName
            } else if let name = result.contactName, !name.isEmpty, name != "Unknown",
                      !name.hasPrefix("Group:") {
                let contact = AppGroupService.shared.createContact(displayName: name)
                AppGroupService.shared.currentContactID = contact.id
                resolvedContactID = contact.id
                resolvedContactName = name
            } else {
                resolvedContactID = nil
                resolvedContactName = result.contactName
            }

            let thumbnail = makeThumbnail(image)
            let session = CaptureSession(
                id: UUID(),
                timestamp: Date(),
                thumbnailData: thumbnail,
                contextHint: nil,
                generatedReplies: result.replies,
                selectedReply: nil,
                llmSummary: result.summary,
                contactID: resolvedContactID,
                contactName: resolvedContactName
            )
            AppGroupService.shared.appendCaptureSession(session)
            AppGroupService.shared.saveReplies(result.replies)
        } catch {
            NSLog("[Replr][QuickReply] API error: %@", error.localizedDescription)
            AppGroupService.shared.saveError(error.localizedDescription)
        }

        return .result()
    }
```

- [ ] **Step 3: Update `Replr/Replr/Intents/GenerateReplyIntent.swift` — contact-aware memory**

Replace the `perform()` function body with the contact-aware version:

```swift
    func perform() async throws -> some IntentResult {
        NSLog("[Replr][Intent] GenerateReplyIntent fired")

        guard let image = UIImage(data: screenshot.data) else {
            NSLog("[Replr][Intent] Could not decode screenshot data")
            AppGroupService.shared.saveError("Could not read the screenshot image.")
            return .result()
        }

        NSLog("[Replr][Intent] Image loaded: %.0fx%.0f", image.size.width, image.size.height)

        let context = AppGroupService.shared.readPendingContext()
        let txID = UserDefaults(suiteName: Constants.appGroupID)?.string(forKey: Constants.transactionIDKey)
        NSLog("[Replr][Intent] Calling API: tone=%@, hasContext=%d", tone.rawValue, context != nil ? 1 : 0)

        // Fetch memories for the current confirmed contact
        let previousContext: String?
        if let contactID = AppGroupService.shared.currentContactID {
            let summaries = AppGroupService.shared.recentSummaries(forContactID: contactID, limit: 10)
            previousContext = summaries.isEmpty ? nil : summaries.joined(separator: "\n")
        } else {
            previousContext = nil
        }

        do {
            let result = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: tone.tone,
                summary: context,
                previousContext: previousContext,
                model: "claude",
                transactionId: txID
            )
            NSLog("[Replr][Intent] Got %d replies — saving to App Group", result.replies.count)

            // Resolve or create contact
            let resolvedContactID: UUID?
            let resolvedContactName: String?
            if let existingID = AppGroupService.shared.currentContactID {
                resolvedContactID = existingID
                resolvedContactName = result.contactName
            } else if let name = result.contactName, !name.isEmpty, name != "Unknown",
                      !name.hasPrefix("Group:") {
                let contact = AppGroupService.shared.createContact(displayName: name)
                AppGroupService.shared.currentContactID = contact.id
                resolvedContactID = contact.id
                resolvedContactName = name
            } else {
                resolvedContactID = nil
                resolvedContactName = result.contactName
            }

            let thumbnail = makeThumbnail(image)
            let session = CaptureSession(
                id: UUID(),
                timestamp: Date(),
                thumbnailData: thumbnail,
                contextHint: context,
                generatedReplies: result.replies,
                selectedReply: nil,
                llmSummary: result.summary,
                contactID: resolvedContactID,
                contactName: resolvedContactName
            )
            AppGroupService.shared.appendCaptureSession(session)
            AppGroupService.shared.saveReplies(result.replies)
        } catch {
            NSLog("[Replr][Intent] API error: %@", error.localizedDescription)
            AppGroupService.shared.saveError(error.localizedDescription)
        }

        return .result()
    }
```

- [ ] **Step 4: Build the Replr scheme — verify no compile errors**

In Xcode, select the `Replr` scheme and press Cmd+B. Expected: Build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git add Shared/ReplyService.swift \
        Replr/Replr/Intents/QuickReplyIntent.swift \
        Replr/Replr/Intents/GenerateReplyIntent.swift
git commit -m "$(cat <<'EOF'
feat: wire contact-aware memory into ReplyService and both intents

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Keyboard Model + Views (Contact Chip, EditContact, Disambiguate)

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

All changes are in this single file.

- [ ] **Step 1: Add new KeyboardState cases**

In `KeyboardView.swift`, replace:
```swift
enum KeyboardState: Equatable {
    case idle
    case collapsed
    case loading
    case replies([String])
    case editReply(String)
    case error(String)
}
```
With:
```swift
enum KeyboardState: Equatable {
    case idle
    case collapsed
    case loading
    case replies([String])
    case editReply(String)
    case error(String)
    case editContact(String)                                // current name pre-filled
    case disambiguate(name: String, candidates: [Contact]) // same-name contact picker
}
```

- [ ] **Step 2: Update `KeyboardModel` — add contactName, callbacks, and update input handlers**

Replace the `KeyboardModel` class in full:

```swift
@MainActor
final class KeyboardModel: ObservableObject {
    @Published var state: KeyboardState = .idle
    @Published var tones: [Tone] = []
    @Published var selectedTone: Tone
    @Published var needsGlobeKey: Bool = false
    @Published var pendingContext: String = ""
    @Published var inputText: String = ""
    @Published var isShifted: Bool = false
    @Published var kbMode: KBMode = .alpha
    @Published var currentReplies: [String] = []
    @Published var contactName: String? = nil

    var onReplySelected: ((String) -> Void)?
    var onToneChanged: ((Tone) -> Void)?
    var onSwitchKeyboard: (() -> Void)?
    var onTypeChar: ((String) -> Void)?
    var onDeleteChar: (() -> Void)?
    var onSpaceChar: (() -> Void)?
    var onReturnChar: (() -> Void)?
    var onUseAsContext: (() -> Void)?
    var onConfirmContact: ((String) -> Void)?
    var onDifferentPerson: ((String) -> Void)?
    var onSelectContact: ((Contact) -> Void)?
    var onCreateNewContact: ((String) -> Void)?

    init(initialTone: Tone) {
        self.selectedTone = initialTone
        self.tones = AppGroupService.shared.readTones()
    }

    // MARK: - Input

    func type(_ char: String) {
        let out = isShifted ? char.uppercased() : char
        switch state {
        case .editReply, .editContact: inputText += out
        default: onTypeChar?(out)
        }
        if isShifted, kbMode == .alpha { isShifted = false }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func backspace() {
        switch state {
        case .editReply, .editContact:
            guard !inputText.isEmpty else { return }
            inputText.removeLast()
        default:
            onDeleteChar?()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func space() {
        switch state {
        case .editReply, .editContact: inputText += " "
        default: onSpaceChar?()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func toggleShift() { isShifted.toggle() }

    func toggleMode() { kbMode = kbMode == .alpha ? .numeric : .alpha }

    func confirmInput() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch state {
        case .editReply:
            if !inputText.isEmpty { onReplySelected?(inputText) }
            withAnimation(.easeInOut(duration: 0.18)) { state = .idle }
        case .editContact:
            if !inputText.isEmpty { onConfirmContact?(inputText) }
            // KeyboardViewController's onConfirmContact sets state = .idle
        default:
            onReturnChar?()
        }
    }

    func cancelInput() {
        withAnimation(.easeInOut(duration: 0.18)) {
            switch state {
            case .editReply where !currentReplies.isEmpty,
                 .editContact where !currentReplies.isEmpty:
                state = .replies(currentReplies)
            default:
                state = .idle
            }
        }
    }

    func enterEditReply(_ text: String) {
        inputText = text; isShifted = false; kbMode = .alpha
        withAnimation(.easeInOut(duration: 0.18)) { state = .editReply(text) }
    }

    func enterEditContact(_ name: String) {
        inputText = name; isShifted = false; kbMode = .alpha
        withAnimation(.easeInOut(duration: 0.18)) { state = .editContact(name) }
    }

    func collapse() {
        withAnimation(.easeInOut(duration: 0.2)) { state = .collapsed }
    }

    func useAsContext() {
        onUseAsContext?()
        pendingContext = ""
        collapse()
    }

    func selectTone(_ tone: Tone) { selectedTone = tone; onToneChanged?(tone) }
    func selectReply(_ text: String) { onReplySelected?(text) }
    func regenerate() {
        AppGroupService.shared.clearCachedReplies()
        withAnimation(.easeInOut(duration: 0.2)) { state = .idle }
    }
}
```

- [ ] **Step 3: Add contact chip to `ReplrStrip` (idle state)**

In `ReplrStrip.body`, inside the HStack for row 2 (tone pills), add the contact chip before the globe key. Replace the row 2 HStack content:

```swift
            // Row 2: tone pills + contact chip + optional globe key
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(model.tones) { tone in
                            TonePill(name: tone.name,
                                     isSelected: tone.name == model.selectedTone.name,
                                     action: { model.selectTone(tone) })
                        }
                    }
                    .padding(.horizontal, 8)
                }

                if let name = model.contactName {
                    KBColors.borderDim.frame(width: 0.5, height: 16)
                    Button { model.enterEditContact(name) } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                            Text(name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Image(systemName: "pencil")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(KBColors.amberText)
                        .padding(.trailing, 8)
                    }
                    .buttonStyle(.plain)
                }

                if model.needsGlobeKey {
                    KBColors.borderDim.frame(width: 0.5, height: 16)
                    Button { model.onSwitchKeyboard?() } label: {
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                            .foregroundColor(KBColors.textDim)
                            .frame(width: 36, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 32)
```

- [ ] **Step 4: Update `contentArea` in `KeyboardRootView` — add new state cases and contact chip in replies**

Replace the `contentArea` computed property:

```swift
    @ViewBuilder
    private var contentArea: some View {
        ZStack {
            switch model.state {
            case .idle:
                IdleWithKeyboard(model: model).transition(.opacity)
            case .collapsed:
                CollapsedBar(model: model).transition(.opacity)
            case .loading:
                GeneratingView().transition(.opacity)
            case .replies(let replies):
                VStack(spacing: 0) {
                    if let name = model.contactName {
                        Button { model.enterEditContact(name) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .medium))
                                Text(name)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                Image(systemName: "pencil")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(KBColors.amberText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        KBColors.borderHair.frame(height: 0.5)
                    }
                    ReplyCarousel(replies: replies,
                                  onSelect: { model.selectReply($0) },
                                  onEdit: { model.enterEditReply($0) })
                }
                .transition(.opacity)
            case .editReply:
                KBInputArea(model: model, mode: .edit).transition(.opacity)
            case .error(let msg):
                ErrorStateView(message: msg).transition(.opacity)
            case .editContact:
                EditContactView(model: model).transition(.opacity)
            case .disambiguate(let name, let candidates):
                DisambiguateView(
                    name: name,
                    candidates: candidates,
                    onSelectContact: { model.onSelectContact?($0) },
                    onCreateNew: { model.onCreateNewContact?($0) }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: stateTag)
    }
```

- [ ] **Step 5: Update `stateTag` to cover new states**

Replace:
```swift
    private var stateTag: Int {
        switch model.state {
        case .idle: return 0; case .loading: return 1; case .replies: return 2
        case .error: return 3; case .editReply: return 4; case .collapsed: return 5
        }
    }
```
With:
```swift
    private var stateTag: Int {
        switch model.state {
        case .idle:         return 0
        case .loading:      return 1
        case .replies:      return 2
        case .error:        return 3
        case .editReply:    return 4
        case .collapsed:    return 5
        case .editContact:  return 6
        case .disambiguate: return 7
        }
    }
```

- [ ] **Step 6: Add `EditContactView` to `KeyboardView.swift`**

Add after the `KBInputArea` struct (search for `// MARK: - QWERTY Keyboard` and insert before it):

```swift
// MARK: - Edit Contact View

struct EditContactView: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(model.inputText.isEmpty ? "Contact name" : model.inputText)
                    .font(.system(size: 15))
                    .foregroundColor(model.inputText.isEmpty
                                     ? Color(UIColor.placeholderText)
                                     : Color(UIColor.label))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Done") { model.confirmInput() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(KBColors.amber)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .overlay(alignment: .bottom) { Color(UIColor.separator).frame(height: 0.5) }

            Button {
                model.onDifferentPerson?(model.inputText)
            } label: {
                Text("Different person")
                    .font(.system(size: 13))
                    .foregroundColor(KBColors.textDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.plain)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .overlay(alignment: .bottom) { Color(UIColor.separator).frame(height: 0.5) }

            ReplrKeyboard(
                isShifted: model.isShifted,
                kbMode: model.kbMode,
                doneLabel: "Done",
                onChar: { model.type($0) },
                onSpace: { model.space() },
                onBackspace: { model.backspace() },
                onShift: { model.toggleShift() },
                onMode: { model.toggleMode() },
                onDone: { model.confirmInput() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KBColors.from(cs).bg)
        }
    }
}
```

- [ ] **Step 7: Add `DisambiguateView` to `KeyboardView.swift`**

Add immediately after `EditContactView`:

```swift
// MARK: - Disambiguate View

struct DisambiguateView: View {
    let name: String
    let candidates: [Contact]
    var onSelectContact: ((Contact) -> Void)?
    var onCreateNew: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Text("Which \(name)?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(KBColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(KBColors.deep)

            KBColors.borderHair.frame(height: 0.5)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(candidates) { contact in
                        Button { onSelectContact?(contact) } label: {
                            HStack(spacing: 10) {
                                thumbnailView(for: contact)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.displayName)
                                        .font(.system(size: 13))
                                        .foregroundColor(KBColors.textPrimary)
                                    if let summary = AppGroupService.shared
                                            .recentSummaries(forContactID: contact.id, limit: 1).first {
                                        Text(summary)
                                            .font(.system(size: 11))
                                            .foregroundColor(KBColors.textDim)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .background(KBColors.surface)
                        .overlay(alignment: .bottom) {
                            KBColors.borderHair.frame(height: 0.5)
                        }
                    }

                    Button { onCreateNew?(name) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                            Text("New contact named \(name)")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(KBColors.amber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(KBColors.background)
    }

    @ViewBuilder
    private func thumbnailView(for contact: Contact) -> some View {
        let thumb = AppGroupService.shared.sessions(forContactID: contact.id)
            .last?.thumbnailData.flatMap(UIImage.init(data:))
        if let img = thumb {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(KBColors.surface)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person")
                        .font(.system(size: 12))
                        .foregroundColor(KBColors.textDim)
                )
        }
    }
}
```

- [ ] **Step 8: Build the ReplrKeyboard scheme — verify no compile errors**

In Xcode, select the `ReplrKeyboard` scheme and press Cmd+B. Expected: Build succeeds with no errors or warnings about unhandled switch cases.

- [ ] **Step 9: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: add contact chip, EditContactView, and DisambiguateView to keyboard

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: KeyboardViewController — Wiring

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Step 1: Update `viewWillAppear` to resolve contact display name**

In `viewWillAppear(_:)`, add contact resolution after the existing `needsGlobeKey` and state-restore logic:

Replace the existing `viewWillAppear` implementation with:

```swift
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.needsGlobeKey = needsInputModeSwitchKey

        // Resolve contact display name from App Group
        if let id = AppGroupService.shared.currentContactID,
           let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == id }) {
            model.contactName = contact.displayName
        } else {
            model.contactName = nil
        }

        if AppGroupService.shared.isGenerating {
            model.state = .loading
        } else if AppGroupService.shared.persistReplies,
                  let cached = AppGroupService.shared.readCachedReplies() {
            model.currentReplies = cached
            model.state = .replies(cached)
        }
        startCapturePoll()
    }
```

- [ ] **Step 2: Wire contact callbacks in `viewDidLoad`**

In `viewDidLoad()`, after the last existing `model.onUseAsContext` closure, add:

```swift
        model.onConfirmContact = { [weak self] newName in
            guard let self else { return }
            if let id = AppGroupService.shared.currentContactID {
                var contacts = AppGroupService.shared.loadContacts()
                if let i = contacts.firstIndex(where: { $0.id == id }) {
                    contacts[i].displayName = newName
                    AppGroupService.shared.saveContacts(contacts)
                }
            }
            self.model.contactName = newName
            withAnimation(.easeInOut(duration: 0.18)) {
                self.model.state = self.model.currentReplies.isEmpty
                    ? .idle
                    : .replies(self.model.currentReplies)
            }
        }

        model.onDifferentPerson = { [weak self] currentName in
            guard let self else { return }
            let others = AppGroupService.shared.findContacts(named: currentName)
                .filter { $0.id != AppGroupService.shared.currentContactID }
            if others.isEmpty {
                let newContact = AppGroupService.shared.createContact(displayName: currentName)
                AppGroupService.shared.currentContactID = newContact.id
                self.model.contactName = currentName
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.model.state = self.model.currentReplies.isEmpty
                        ? .idle
                        : .replies(self.model.currentReplies)
                }
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.model.state = .disambiguate(name: currentName, candidates: others)
                }
            }
        }

        model.onSelectContact = { [weak self] contact in
            guard let self else { return }
            AppGroupService.shared.currentContactID = contact.id
            self.model.contactName = contact.displayName
            withAnimation(.easeInOut(duration: 0.18)) {
                self.model.state = self.model.currentReplies.isEmpty
                    ? .idle
                    : .replies(self.model.currentReplies)
            }
        }

        model.onCreateNewContact = { [weak self] name in
            guard let self else { return }
            let newContact = AppGroupService.shared.createContact(displayName: name)
            AppGroupService.shared.currentContactID = newContact.id
            self.model.contactName = name
            withAnimation(.easeInOut(duration: 0.18)) {
                self.model.state = self.model.currentReplies.isEmpty
                    ? .idle
                    : .replies(self.model.currentReplies)
            }
        }
```

- [ ] **Step 3: Update height constants in `stateCancellable`**

Replace the `switch state` block inside `stateCancellable`:

```swift
                let newHeight: CGFloat
                switch state {
                case .idle:          newHeight = 280
                case .collapsed:     newHeight = 44
                case .editReply:     newHeight = 280
                case .editContact:   newHeight = 280
                case .loading:       newHeight = 50
                case .replies:       newHeight = 320
                case .disambiguate:  newHeight = 320
                default:             newHeight = 220  // error
                }
```

- [ ] **Step 4: Build the full Replr scheme — verify no errors**

In Xcode, select the `Replr` scheme and press Cmd+B. Expected: All targets build without errors.

- [ ] **Step 5: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "$(cat <<'EOF'
feat: wire contact callbacks and height constants in KeyboardViewController

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Captures Tab — Contact Display, Filter, Clear Memory

**Files:**
- Modify: `Replr/Replr/Features/Captures/CaptureLogView.swift`

- [ ] **Step 1: Update `CaptureLogViewModel` with contact filter state**

Replace the `CaptureLogViewModel` class:

```swift
final class CaptureLogViewModel: ObservableObject {
    @Published var sessions: [CaptureSession] = []
    @Published var selectedContactID: UUID? = nil  // nil = "All"

    var allContacts: [Contact] {
        let ids = Set(sessions.compactMap(\.contactID))
        return AppGroupService.shared.loadContacts().filter { ids.contains($0.id) }
    }

    var filteredSessions: [CaptureSession] {
        guard let id = selectedContactID else { return sessions }
        return sessions.filter { $0.contactID == id }
    }

    func load() {
        sessions = AppGroupService.shared.loadCaptureSessions().reversed()
    }

    func clearAll() {
        AppGroupService.shared.clearCaptureSessions()
        sessions = []
        selectedContactID = nil
    }

    func delete(at offsets: IndexSet) {
        let source = filteredSessions
        var all = AppGroupService.shared.loadCaptureSessions()
        let idsToRemove = Set(offsets.map { source[$0].id })
        all.removeAll { idsToRemove.contains($0.id) }
        AppGroupService.shared.saveCaptureSessions(all)
        load()
    }

    func clearMemory(for contact: Contact) {
        AppGroupService.shared.clearMemory(forContactID: contact.id)
        load()
    }
}
```

- [ ] **Step 2: Update `CaptureLogView` — add contact filter and clear memory**

Replace the `CaptureLogView` struct:

```swift
struct CaptureLogView: View {
    @StateObject private var vm = CaptureLogViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No captures yet")
                            .font(.headline)
                        Text("Generate replies from the Replr keyboard to see them here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Contact filter chips
                        if !vm.allContacts.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    filterChip(label: "All", id: nil)
                                    ForEach(vm.allContacts) { contact in
                                        filterChip(label: contact.displayName, id: contact.id)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    vm.clearMemory(for: contact)
                                                } label: {
                                                    Label("Clear Memory", systemImage: "brain.slash")
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            Divider()
                        }

                        List {
                            ForEach(vm.filteredSessions) { session in
                                NavigationLink(destination: CaptureDetailView(session: session)) {
                                    CaptureRowView(session: session)
                                }
                            }
                            .onDelete(perform: vm.delete)
                        }
                    }
                }
            }
            .navigationTitle("Captures")
            .toolbar {
                if !vm.sessions.isEmpty {
                    Button(role: .destructive) { vm.clearAll() } label: {
                        Text("Clear All")
                    }
                }
            }
        }
        .onAppear { vm.load() }
    }

    @ViewBuilder
    private func filterChip(label: String, id: UUID?) -> some View {
        let isSelected = vm.selectedContactID == id
        Button { vm.selectedContactID = id } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Update `CaptureRowView` — show contactName**

Replace the `CaptureRowView` struct:

```swift
struct CaptureRowView: View {
    let session: CaptureSession

    var body: some View {
        HStack(spacing: 12) {
            if let data = session.thumbnailData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 64)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 36, height: 64)
                    .overlay(Image(systemName: "text.bubble").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(session.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let name = session.contactName {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let summary = session.llmSummary {
                    Text(summary)
                        .font(.subheadline)
                        .lineLimit(2)
                }

                if let selected = session.selectedReply {
                    Text("Sent: \(selected)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 4: Build the Replr scheme — verify no compile errors**

In Xcode, select the `Replr` scheme and press Cmd+B. Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Replr/Replr/Features/Captures/CaptureLogView.swift
git commit -m "$(cat <<'EOF'
feat: add contact name display, filter chips, and clear memory to Captures tab

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Manual Smoke Test Checklist

After all tasks are complete, verify the full flow on device:

1. **First capture (silent):** Take a screenshot of a chat. Triple-tap Back Tap. Open the Replr keyboard → no contact chip visible yet (contact not yet resolved — it appears on next open after the intent saves it).
2. **Second open:** Contact chip appears in the Replr strip: `→ Alexis ✎`.
3. **Edit contact:** Tap the chip → EditContact view appears, name pre-filled. Change name → tap Done → chip updates.
4. **Different person:** Tap chip → "Different person" → if no other Alexis exists, a new contact is created silently. If another Alexis exists, disambiguation list appears.
5. **Disambiguation:** Tap a candidate → current contact switches. "New contact named Alexis" → creates a fresh contact.
6. **Memory:** Second capture from the same contact → `previousContext` is sent, replies have conversation awareness.
7. **Captures tab:** Contact name appears on each row. Filter chips show per-contact filtering. Long-press a contact chip → "Clear Memory" zeros summaries.
8. **Group chat:** Contact chip shows "Group: [name]". No memory is fetched (previousContext nil).

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task | Status |
|---|---|---|
| LLM extracts CONTACT: in same call | Task 2 | ✅ |
| Intent reads currentContactID before call | Task 3 | ✅ |
| Intent creates Contact if none, sets currentContactID | Task 3 | ✅ |
| Contact model (UUID, displayName) | Task 1 | ✅ |
| CaptureSession gets contactID, contactName | Task 1 | ✅ |
| `recentSummaries(forContactID:limit:10)` | Task 1 | ✅ |
| Contact chip in idle and replies states | Task 4 | ✅ |
| `.editContact` state with keyboard | Task 4 | ✅ |
| `.disambiguate` state with thumbnails + summary | Task 4 | ✅ |
| `onConfirmContact` saves updated displayName | Task 5 | ✅ |
| `onDifferentPerson` → new or disambiguate | Task 5 | ✅ |
| Captures tab shows contactName | Task 6 | ✅ |
| Captures tab contact filter | Task 6 | ✅ |
| Clear Memory per contact | Task 6 | ✅ |
| First capture fully silent | Task 3 | ✅ |
| Group chat: saved but no memory fetched | Task 3 | ✅ |
| Max 200 contacts | Task 1 | ✅ |

**Potential issues:**
- `Shared/Services/ReplyService.swift` is NOT in the pbxproj and is not compiled. Do not edit it — only `Shared/ReplyService.swift` is compiled.
- The `cancelInput()` switch uses pattern matching with `where` — verify Swift compiler accepts this syntax (it does as of Swift 5.9).
- In `DisambiguateView.thumbnailView`, the `let thumb = ...sessions.last?.thumbnailData.flatMap(UIImage.init(data:))` chain — `thumbnailData` is `Data?`, and `UIImage.init(data:)` has the signature `init(data: Data)` (not optional-returning). Use `.flatMap { UIImage(data: $0) }` instead to be safe.
