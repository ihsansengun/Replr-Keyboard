# Contact-Aware Conversation Memory Design

## Goal

Replace the time-based conversation memory heuristic with per-contact memory keyed on LLM-extracted contact names. The LLM reads the contact name from each screenshot, the keyboard shows it with an edit chip, and the user can correct mismatches or disambiguate two people with the same name. Memory is grouped by a stable Contact identity (UUID), not by name string, so renaming never breaks history and two Alexises stay permanently separate.

## Architecture

Three layers cooperate:

1. **Backend** — LLM extracts the contact name as part of its existing single-call output (`CONTACT:` line alongside `SUMMARY:` and numbered replies). Zero extra cost or latency.
2. **iOS intents** — before each API call, the intent reads the confirmed `currentContactID` from App Group, fetches that contact's last 10 summaries, and sends them as `previousContext`. After the call, it creates a new Contact if none exists and saves the session with `contactID`.
3. **Keyboard** — shows a tappable contact chip in both the idle and replies states. Tapping opens an inline edit flow (reusing the existing custom key input pattern). If the user indicates a different person with the same name, a disambiguation screen shows other known contacts with that name (thumbnail + summary snippet) so the user can pick the right one or create a new entry.

## Data Model

### New: `Contact`

```swift
// Shared/Models/Contact.swift
struct Contact: Codable, Identifiable {
    let id: UUID
    var displayName: String
}
```

Stored in App Group UserDefaults under `Constants.contactsKey`. Max 200 contacts (trim oldest by last-session date if exceeded).

### Modified: `CaptureSession`

Two new optional fields appended (existing sessions decode safely — both default to `nil`):

```swift
var contactID: UUID?      // stable link to Contact.id
var contactName: String?  // snapshot of displayName at capture time (for display without Contact lookup)
```

### New `AppGroupService` methods

```swift
// Contact CRUD
func saveContacts(_ contacts: [Contact])
func loadContacts() -> [Contact]
func createContact(displayName: String) -> Contact   // appends + saves, returns new Contact
func updateContact(_ contact: Contact)               // updates matching id, saves
func findContacts(named name: String) -> [Contact]   // case-insensitive, trimmed match

// Current session contact (keyboard ↔ intent shared state)
var currentContactID: UUID?   // get/set, persisted in UserDefaults

// Memory
func recentSummaries(forContactID id: UUID, limit: Int) -> [String]
// Returns up to `limit` llmSummary values from the most recent sessions
// with matching contactID, oldest first. Replaces activeSessionSummaries().

// Captures tab helpers
func sessions(forContactID id: UUID) -> [CaptureSession]
func clearMemory(forContactID id: UUID)   // sets llmSummary = nil on all matching sessions, re-saves
```

### New `Constants` keys

```swift
static let contactsKey        = "contacts"
static let currentContactIDKey = "current_contact_id"
```

## Backend Changes

### `backend/src/services/llm.ts` — prompt format

`buildReplyFormat(count)` output changes to:

```
CONTACT: [display name of the person you are replying TO, exactly as shown in the chat header. "Group: [name]" for group chats. "Unknown" if not visible.]
SUMMARY: [one sentence: topic of conversation and what was last said]
1. [reply]
2. [reply]
...
```

### `parseLlmOutput` — extract `CONTACT:` line

```typescript
export interface LlmResult {
  replies: string[]
  summary: string
  contactName: string   // empty string if not found
}

export function parseLlmOutput(text: string): LlmResult {
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean)
  let summary = ''
  let contactName = ''
  const replies: string[] = []

  for (const line of lines) {
    if (!contactName && line.startsWith('CONTACT:')) {
      contactName = line.replace(/^CONTACT:\s*/i, '').trim()
    } else if (!summary && line.startsWith('SUMMARY:')) {
      summary = line.replace(/^SUMMARY:\s*/i, '').trim()
    } else if (/^\d+[.)]\s/.test(line)) {
      replies.push(line.replace(/^\d+[.)]\s*/, '').trim())
    }
  }

  return { replies, summary, contactName }
}
```

### `backend/src/types/index.ts` — response type

```typescript
export interface ReplyResponse {
  replies: string[]
  summary: string
  contactName: string
}
```

### `backend/src/routes/reply.ts`

Both `/reply` and `/reply/scroll` return `{ replies, summary, contactName }` from `result`.

## iOS Intent Changes

Applies to both `QuickReplyIntent` and `GenerateReplyIntent` (the compiled versions in `Replr/Replr/Intents/`).

### Before API call

```swift
// Fetch memories for the current confirmed contact
let previousContext: String?
if let contactID = AppGroupService.shared.currentContactID {
    let summaries = AppGroupService.shared.recentSummaries(forContactID: contactID, limit: 10)
    previousContext = summaries.isEmpty ? nil : summaries.joined(separator: "\n")
} else {
    previousContext = nil
}
```

### After API returns `result`

```swift
// Resolve or create contact
let contactID: UUID
if let existingID = AppGroupService.shared.currentContactID {
    contactID = existingID
} else if !result.contactName.isEmpty && result.contactName != "Unknown" {
    let contact = AppGroupService.shared.createContact(displayName: result.contactName)
    contactID = contact.id
    AppGroupService.shared.currentContactID = contactID
} else {
    // No name detected and no prior contact — save session without contact
    // currentContactID stays nil
    contactID = UUID() // ephemeral, not saved to contacts list
}

let session = CaptureSession(
    id: UUID(),
    timestamp: Date(),
    thumbnailData: thumbnail,
    contextHint: context,
    generatedReplies: result.replies,
    selectedReply: nil,
    llmSummary: result.summary,
    contactID: contactID,
    contactName: result.contactName.isEmpty ? nil : result.contactName
)
AppGroupService.shared.appendCaptureSession(session)
AppGroupService.shared.saveReplies(result.replies)
```

Note: `currentContactID` is only updated when it was previously nil (first capture). If already set, the keyboard handles any correction; the intent does not override user-confirmed identity.

## Keyboard Changes

### `ReplyService.swift` — updated response decode

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

### `KeyboardModel`

New published property:

```swift
@Published var contactName: String? = nil
```

New keyboard states appended to `KeyboardState`:

```swift
case editContact(String)                                // current name pre-filled
case disambiguate(name: String, candidates: [Contact])  // same-name contact picker
```

### `KeyboardViewController`

In `viewWillAppear`:

```swift
// Resolve contact display name from App Group
if let id = AppGroupService.shared.currentContactID,
   let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == id }) {
    model.contactName = contact.displayName
} else {
    model.contactName = nil
}
```

New model callbacks wired in `viewDidLoad`:

```swift
model.onConfirmContact = { [weak self] newName in
    guard let self else { return }
    if let id = AppGroupService.shared.currentContactID {
        var contact = AppGroupService.shared.loadContacts().first(where: { $0.id == id })
        contact?.displayName = newName
        if let c = contact { AppGroupService.shared.updateContact(c) }
    }
    self.model.contactName = newName
    self.model.state = .idle
}

model.onDifferentPerson = { [weak self] currentName in
    guard let self else { return }
    let others = AppGroupService.shared.findContacts(named: currentName)
        .filter { $0.id != AppGroupService.shared.currentContactID }
    if others.isEmpty {
        // No other contact with this name — create new immediately
        let newContact = AppGroupService.shared.createContact(displayName: currentName)
        AppGroupService.shared.currentContactID = newContact.id
        self.model.contactName = currentName
        self.model.state = .idle
    } else {
        self.model.state = .disambiguate(name: currentName, candidates: others)
    }
}

model.onSelectContact = { [weak self] contact in
    guard let self else { return }
    AppGroupService.shared.currentContactID = contact.id
    self.model.contactName = contact.displayName
    self.model.state = .idle
}

model.onCreateNewContact = { [weak self] name in
    guard let self else { return }
    let newContact = AppGroupService.shared.createContact(displayName: name)
    AppGroupService.shared.currentContactID = newContact.id
    self.model.contactName = name
    self.model.state = .idle
}
```

Height for new states in `stateCancellable`:

```swift
case .editContact:    newHeight = 280
case .disambiguate:   newHeight = 320
```

### Keyboard UI

**Contact chip** — shown in both `.idle` and `.replies` states:

```
→ Alexis  ✎
```

Small, subdued. Located in the Replr strip area for `.idle`, above the reply carousel for `.replies`. Tapping transitions to `.editContact(currentName)`.

**`.editContact` view** — inline name editor above the standard Replr keyboard:

```
[ Alexis            ] ✓
           [Different person]
```

Text field pre-filled. Confirm button saves. "Different person" triggers `onDifferentPerson`.

**`.disambiguate` view** — list of same-name candidates:

```
Which Alexis?
┌─────────────────────────────┐
│ [thumb] Alexis              │  ← last summary snippet
│         "discussed dinner…" │
├─────────────────────────────┤
│ [thumb] Alexis              │
│         "talked about work" │
├─────────────────────────────┤
│  + New contact named Alexis │
└─────────────────────────────┘
```

Each row tappable. "New contact" creates a fresh Contact entry and assigns it.

## Captures Tab Changes

- Session rows show `contactName` below the summary line
- Navigation bar gets a contact filter: "All" / per-contact chips
- Long-press or swipe on a contact section header exposes "Clear Memory" — calls `clearMemory(forContactID:)`, zeroes out `llmSummary` on all sessions for that contact without deleting them

## First-Capture Behaviour (no regression)

- `currentContactID` is nil
- No `previousContext` sent
- LLM returns `contactName`
- If name is non-empty and not "Unknown": new Contact created, `currentContactID` set
- Keyboard shows `→ [name]` on next open (reads from resolved contact)
- User sees no prompt during this first capture — it is fully silent

## What Is Not In Scope

- Syncing contacts across devices
- Merging two contacts retroactively (user can rename; old sessions retain their contactID)
- Automatic detection of contact switches without user confirmation
- Group chat memory (sessions saved with `contactName = "Group: [name]"` but no memory is fetched for group contacts — `previousContext` remains nil for groups)
