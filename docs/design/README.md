# Handoff · Replr v2 — Full UX Redesign

A complete redesign of the Replr keyboard and companion app — onboarding, the back‑tap capture flow, the keyboard state machine, history, and the simplified memory model.

---

## About the design files

The files in `design_files/` are **design references**, not production code. They are HTML + React (Babel‑in‑browser) prototypes built to lock down look, layout, interactions, and copy. Your job is to **recreate these designs in the existing Replr iOS codebase** (Swift / SwiftUI per the repo) using its established patterns, components, and naming conventions — *not* to literally port HTML/CSS.

Specifically:

* The Replr keyboard is an iOS keyboard extension. Build keyboard screens in **SwiftUI** (or the existing `ReplrKeyboard/` view stack), not WebKit.
* The companion app is a standard iOS app. Use **SwiftUI** views, native `NavigationStack`, `Form`/`List` for Settings, sheets for Memory editor.
* The capture flow uses the existing **iOS Shortcut + Back Tap** plumbing already in the repo.

Read the HTML if you need pixel‑level reference, but implement natively.

---

## Fidelity

**High‑fidelity.** Final colors, typography, spacing, animations are specified. Recreate pixel‑perfect using SwiftUI primitives and the codebase's existing patterns. Where a value isn't given explicitly, derive it from the design tokens in `tokens.md`.

---

## What's in this handoff

| Surface | Screens |
|---|---|
| **Onboarding** | Welcome + 6 steps (Add keyboard, Full access, Photos, Install Shortcut, Configure Back Tap, Default tone) |
| **Keyboard** | Idle Chat, Idle Email (no clipboard / clipboard ready), Capture bar (+ first‑run coachmark), Loading, Replies (carousel positions 1‑3), Edit reply, Rename contact, Error |
| **Capture moment** | 3‑frame storyboard (tap Capture → minimised + triple/double tap → replies ready) |
| **Companion app** | History (empty + populated), Capture Detail, Memory Editor, Settings |
| **Memory** | Per‑contact paragraph, surfaced inline in Capture Detail. Anatomy artboard included. |

Open `design_files/Replr — full UX.html` in a browser to navigate the full design canvas. Each artboard is independently scrollable.

---

## Design tokens

Full token reference is in **`tokens.md`** in this folder. The short version:

* **Palette**: dark, near‑black base (`#0A0A0B`), three neutral grays, one **coral accent (`#FF5A4D`)**. No purple, no blue, no gradients. Coral is a *spotlight*: exactly one primary coral action per screen.
* **Typography**: **single typeface — Geist** (Geist Mono for technical/numeric labels). Weights 400/500/600. Tight tracking (−0.025em on display, −0.005em on body). For SwiftUI use **SF Pro Rounded** or **SF Pro** if Geist isn't licensed for the binary — they have similar metrics; keep the tracking.
* **Spacing**: **strict 8px grid**. Token names `s1..s8` = `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64`. Panel margins = 16–24 (s4–s5). Section gaps = 32 (s6).
* **Radii**: `4 / 8 / 12 / 16 / 20`. Cards = 12. Buttons = 8 or 12. Sheets = 16.
* **Heights**: primary buttons 48pt. Tab pills 44pt. Tone chips 28pt. Reply card min 96pt.

---

## Surfaces — screen by screen

### 1 · Onboarding (welcome + 6 steps)

**Purpose**: Get the user through the real iOS setup (Add Keyboard, Full Access, Photos, Install Shortcut, wire Back Tap) without it feeling like a checklist.

**Layout (every step)**:
* 56pt top inset
* Mark + step counter (`01 / 06`) on one row, then a 6‑segment progress bar
* 24px horizontal padding for the body
* Eyebrow (coral, 12pt, sentence case) → H1 (34pt / 600 / −0.028em) → lede (15pt / 400 / line‑height 1.5) → variable‑height content
* Footer: full‑width primary CTA (48pt tall), optional secondary text button below

**Style notes**:
* Title‑top layout is from this design. Your live build uses a centered‑icon treatment (icon mid‑bottom, title under). Pick one and commit. **Recommended: keep centered‑icon for emotional weight** in onboarding moments; reserve title‑top for the in‑app screens.
* Progress: small horizontal bars at top (this design), or dots at bottom (live build). Either works — but be consistent across the whole flow.

**Step content**:

| # | Title | Content | Primary | Secondary |
|---|---|---|---|---|
| 0 | "The reply is already written." | 4‑sentence lede + 2 trust badges (on‑device, 90 seconds) | Set it up | I have an account |
| 1 | Add Replr to iOS. | Path crumb: `Settings → General → Keyboard → Keyboards → Add New → Replr`. Faux "Replr" row showing it added. | Open Keyboard Settings | Already added |
| 2 | Allow full access. | 3 reassurance bullets (on‑device first, no clipboard sniffing, screenshots deleted) | Allow | What this means |
| 3 | Latest photo only. | Faux iOS permission sheet with 3 options, "Latest Photo Only" recommended | Continue | Show me the technical detail |
| 4 | Install the Shortcut. | A 4‑action recipe card (Take Screenshot · Save to Photos · Open Replr · Show Keyboard) | Add to Shortcuts | Inspect the recipe |
| 5 | Triple/double‑tap = capture. | Path crumb: `Accessibility → Touch → Back Tap → Triple/Double Tap → Replr Capture`. Phone glyph with pulse rings. | Open Back Tap Settings | Use the other tap |
| 6 | One last thing. | Tone picker — 6 chips. Live preview card under it that updates as the user picks. | Try a sample capture | Skip |

> **⚠ Inconsistency in the current build**: your live onboarding says **"double tap"** but the keyboard's idle caption says **"triple‑tap"**. Pick one and use it everywhere. Recommendation: **double‑tap** (it's the iOS Back Tap default).

> **Optional**: collapse steps 4 + 5 into one combined "Set up double tap" step to match the live build's 5‑step flow.

---

### 2 · Keyboard — state machine

The keyboard sits as a child of the host app's input area. It cannot screenshot its host, so capture is two steps: minimise → Back Tap → capture fires.

**States**:

```
idle-chat ──tap "Capture this chat"──┐
                                     ▼
                              capture (collapsed bar)
                                     │ Back Tap detected
                                     ▼
                                  loading
                                     │
                                     ▼
                                  replies ──┬─→ edit ─┐
                                            ├─→ rename
                                            └─→ insert into host

idle-email ──"Generate from clipboard"──→ loading → replies (email mode)

Any state can drop to ──→ error → "Try again" → previous state
```

**Universal keyboard chrome**:
* Top: slim 32pt segmented control `Chat | Email` on the left, small `replr` mark on the right
* Bottom: globe + mic (standard iOS keyboard chrome), 36×36pt buttons
* Body height varies by state (~64pt collapsed for capture, ~280–340pt expanded)
* Background `#0A0A0B`, hairline top border

#### Idle · Chat
* Single full‑width primary "Capture this chat" with a leading sparkle icon (48pt tall, coral fill, dark text)
* Sub‑caption (12pt, t3): "Minimises the keyboard so you can [double‑tap] to screenshot"
* Compact tone chip bottom‑right: `Friendly ⌄` (28pt pill, secondary text, hairline border). Tap opens the tone picker as a small overlay.
* **Note**: the live build keeps the full horizontal tone row visible on idle. That's a faster UX (user picks tone *before* triggering capture) — recommended to keep that behavior. If you adopt the full tone row, treat the design here as a fallback for narrow phones.

#### Idle · Email
* Same shell as Chat
* Primary "Generate from clipboard" with envelope icon — **disabled** until clipboard contains text
* Clipboard status row (8pt below primary): clip icon + "Nothing copied yet" / "Email text ready" (+ char count in mono when ready)
* Tone chip same position

#### Capture bar (collapsed)
* ~64pt tall, replaces the expanded body
* Inside: 1‑line card with `surface` fill, **3pt coral left border**, animated phone glyph (pulse rings), instruction (13.5pt / 500): "Triple/double‑tap the back of your phone", sub‑line (11.5pt / t3): "to capture this chat", and a × cancel button
* **First‑run only**: coachmark balloon above the bar with two beats: "① Keyboard's minimised. ② [Double‑tap] the back." Show **once**, persist a `coachmarkSeen` flag, then never again.

#### Loading
* Skeleton contact row (avatar + name placeholder + position placeholder)
* Skeleton reply card with **the exact same dimensions** as the real reply card → no jump when content arrives. Three shimmer lines (92%, 82%, 58% width).
* Status row centered: text (12.5pt / t2) "Reading the conversation" → "Writing replies", with 3 pulsing coral dots

#### Replies (the hero)
* Contact row: avatar (24pt) · contact name (14pt / 500) · ✎ edit icon · spacer · position `1 of 3` (mono, t3)
* Reply card: `surface` background, 12pt radius, hairline border, 18pt top / 14pt bottom / 16pt sides padding, 16pt body type with 1.4 line‑height, *the reply is the hero — give it room*
* Carousel dots beneath: active dot is **14×5pt** (wider), others are 5×5pt circles, coral active
* Action row: full‑width coral **"Insert reply"** with up‑arrow icon (~70% width) + neutral **"Edit"** (~30%, raised fill)
* Tone row: horizontal scroll of 7 tones (`Casual / Friendly / Direct / Witty / Professional / Bold / Formal`), with a refresh `↻` button pinned right. Selected tone = coral fill / dark text; others = transparent / t2 / hairline border. Soft gradient mask on both edges to communicate scrollability.
* Tapping a tone *regenerates* in that tone. The `↻` regenerates in the current tone.

#### Edit
* Back chevron + "Back to replies" · spacer · avatar + contact name (right)
* Editable card: `surface`, stronger border, 14pt padding, 15.5pt body, animated coral caret
* Char count bottom‑right (mono, t3): `128 chars`
* Actions: full‑width coral "Insert reply" + neutral "Cancel"

#### Rename / disambiguate
* Title (14pt / 500): "Who is this conversation with?" · spacer · × close
* List of candidate contact rows (avatar + name + sub‑caption + check if active). Active row gets a stronger background.
* Bottom: dashed button "+ Use a different name" (opens a text input sheet)

#### Error
* Centered: 40pt coral‑tinted circle with a warning glyph (1.4 stroke), message (14.5pt / 500 / t1), hint (12.5pt / t3), and a coral "Try again" button with refresh icon

---

### 3 · Companion app · 2 tabs

The live build is a 2‑tab app: **Settings + History**. This design matches.

**Tab bar**: floating pill at bottom, centered, 6pt padding around two pills (each ~120pt wide). Active pill gets `raised` fill + coral text and icon; inactive pills are transparent / t2. Floats 28pt from the home indicator with a soft shadow.

#### History — empty
* Standard header (replr mark, "History." H1)
* Centered: 56pt rounded square icon (camera/screenshot glyph), title "No captures yet" (18pt / 600), lede (14pt / t3, max 280pt wide): "Open any chat, double‑tap the back, and Replr will draft the reply…"
* CTA below: small coral‑tinted pill "✦ Try a sample capture"

#### History — populated
* Header + "Clear All" outline button (top‑right, coral text)
* Filter chip row: `All` (active = coral) + one pill per recent contact, each with a small ✨ sparkle indicating memory exists for that contact
* List of `HistoryCard`s:
  * `surface` background, 12pt radius
  * Left: 56×70pt thumbnail (in the live build this is a blurred screenshot; in this design we use a soft gradient placeholder)
  * Middle: contact name (13.5pt / 600 / **coral**) · mono separator · `Today · 14:32`. Below: conversation summary (13.5pt / t1, max 3 lines, ellipsis)
  * Right: chevron

#### Capture Detail
Opens when a history card is tapped. Top‑sticky header with back chevron + timestamp + avatar.

Sections, stacked with 32pt gaps:
1. **Screenshot** — labeled `Label` eyebrow + a 200pt tall card showing the screenshot (blurred for privacy by default, "tap to view" affordance)
2. **Conversation summary** — single paragraph of what the AI extracted from the chat (14.5pt / 500 line‑height)
3. **Generated replies** — 3 rows, each: numeric prefix (mono, t3), body text, copy icon (coral). Behavior: copy puts the reply on the clipboard; consider also adding "Re‑insert" if the keyboard is open
4. **Memory** — the new simple model (see Memory section below)

#### Memory Editor (sheet over Capture Detail)
* Top bar: × close · "Memory · Maya" (15pt / 500) · spacer · **Save** (coral pill, 13pt)
* Body: a single textarea (200pt min height, `surface` background, strong border) bound to the paragraph
* Below: char counter (mono, t3) `120 characters · ideal under 400` and a small "Reset to AI suggestion" button (coral text)
* Bottom: small privacy reassurance card with a shield icon

#### Settings
Native `Form`/`List` feel, dark surface. Sections (header in t3 small label):

* **Keyboard** — Default tone (chev to picker), Keep replies between sessions (toggle, default ON), Languages (chev to multi‑select)
* **AI Model** — Claude · Anthropic (check) / GPT‑4o · OpenAI / hint text below ("Claude is the default. Pro lets you switch.")
* **Memory** — Remember people (toggle, default ON), Clear all memory (danger, coral text). Hint text: "Replr keeps one short paragraph per contact…"
* **Privacy** — Screenshot retention (chev: 30s default), On‑device base model (toggle)
* **Account** — email (mono), Subscription (Pro · annual), About (v1.4.2)

---

### 4 · The Memory model (important — simpler than v1)

**Rule**: one short paragraph per contact. ~3–5 sentences. Plain English. Updated silently after each capture. **No transcripts. No per‑capture archive. No facts list. No timeline.**

**Example** for a contact named Maya:

> Best friend since 2019. Texts in short, dry bursts — rarely punctuation, often nicknames. Has a cat named Sergio. Just back from a trip to Lisbon together. Doesn't do brunch — late dinners or coffee only.

**Behavior**:
* On every capture, the AI may *revise* the paragraph (add/remove/rewrite a sentence). Treat it as editorial, not append‑only.
* The user can **Edit** the paragraph directly (sheet with a textarea), or **Forget** to wipe it for that contact.
* In Settings, a global **Clear all memory** wipes paragraphs across all contacts. There is no per‑capture retention.

**Where it's shown**:
* Inline in Capture Detail (the surface a user would naturally look on), under "Replr remembers about [Contact]" — coral‑tinted card with the paragraph + Edit + Forget buttons
* Nowhere else. No "Memory" tab. No "Memory" view in the app shell. Memory is a property of a person, surfaced where you'd look.

**Storage**: on device. Use Core Data or a simple JSON file in the keyboard's shared App Group container. Persist `{contactId: string, paragraph: string, updatedAt: Date}`.

---

## Interactions & motion

* All state transitions cross‑fade at **220ms**, ease‑out
* Capture‑bar tap glyph: 1.2s infinite pulse
* Loading dots: 1s stagger, 0.15s delay between dots
* Reply card carousel: horizontal swipe (or tap a tone to regenerate). On swipe, the dots animate; the card transitions slide at 240ms
* Skeleton shimmer: 1.4s linear, infinite, 200% gradient travel
* Toggle: 180ms ease for the thumb slide
* All animation must respect `UIAccessibility.isReduceMotionEnabled` — replace transitions with instant swaps

---

## State management

These are the persistent pieces of state the implementation needs to track. Names are suggestions.

| Key | Type | Where | Purpose |
|---|---|---|---|
| `onboarding.completed` | Bool | UserDefaults (shared app group) | Has the user finished onboarding? |
| `onboarding.step` | Int | UserDefaults | Resume mid‑flow |
| `keyboard.defaultTone` | String | UserDefaults | Default tone if no per‑contact override |
| `keyboard.lastTone` | String | UserDefaults | Re‑select after a session |
| `keyboard.coachmarkSeen` | Bool | UserDefaults | Show capture coachmark once |
| `keyboard.keepRepliesBetweenSessions` | Bool | UserDefaults | Restore last replies when keyboard opens |
| `ai.model` | Enum `.claude / .gpt4o` | UserDefaults | Selected model |
| `memory.enabled` | Bool | UserDefaults | Memory feature toggle |
| `memory[contactId]` | String | Core Data / SQLite | One paragraph per contact |
| `history[]` | Array | Core Data / SQLite | Capture records (timestamp + contact + summary + 3 replies + screenshot ref) |

Capture lifecycle:
1. User taps "Capture this chat" → keyboard transitions to `capture` state → keyboard reports to host that it should minimise (existing iOS API in your repo)
2. User triggers Back Tap → iOS Shortcut runs → screenshot saved → Shortcut hands it to Replr → keyboard transitions to `loading`
3. Replr calls AI (Claude or GPT‑4o per setting) with the screenshot + prior memory paragraph → receives 3 replies + a summary + optionally a memory paragraph update
4. Keyboard transitions to `replies`. History record persisted. Memory paragraph silently updated.
5. Screenshot is deleted from the keyboard's storage after 30s (or immediately after replies render — depends on the Photos retention setting)

---

## Files in this handoff

```
design_handoff_replr_v2/
├── README.md                                  ← you are here
├── tokens.md                                  ← exhaustive design tokens
└── design_files/
    ├── Replr — full UX.html                   ← open this in a browser to navigate the canvas
    ├── styles.css                             ← global CSS variables (mirrors tokens.md)
    ├── design-canvas.jsx                      ← canvas shell (ignore — design tool, not product)
    ├── ios-frame.jsx                          ← iPhone bezel (ignore — design tool)
    ├── tweaks-panel.jsx                       ← tweaks panel (ignore — design tool)
    └── src/
        ├── system.jsx                         ← tokens, Mark, Avatar, Icon set, Primary, Secondary, Mono, Label, Divider
        ├── keyboard.jsx                       ← ReplrKeyboard component + every state
        ├── onboarding.jsx                     ← OnbWelcome + OnbStep1..6
        ├── companion.jsx                      ← AppHeader, TabBar, AppHome*, AppPeople*, RelationshipTagger* (* see note)
        ├── contact-and-more.jsx               ← AppHistory, AppHistoryEmpty, CaptureDetail, MemoryEditor, AppSettings
        ├── moment.jsx                         ← 3‑frame capture storyboard (illustrative, not a real app screen)
        └── canvas-app.jsx                     ← top‑level canvas wiring (ignore for implementation)
```

**Note on `companion.jsx`**: this file contains some legacy screens (`AppHome`, `AppPeople`, `RelationshipTagger`) from an earlier 4‑tab version of the app design. **Do not implement these.** The live build (and the agreed direction) is **Settings + History only**. Implement the screens documented in `contact-and-more.jsx` instead.

---

## Assets

No raster image assets are required. Every glyph in the design is an inline SVG you can recreate in SwiftUI with `SF Symbols` or simple `Path` shapes. Specifically:

| Icon in design | SF Symbol equivalent |
|---|---|
| Back chevron | `chevron.left` |
| Forward chevron | `chevron.right` |
| Plus | `plus` |
| Close × | `xmark` |
| Check | `checkmark` |
| Search | `magnifyingglass` |
| Globe (keyboard switcher) | `globe` |
| Mic | `mic` |
| Sparkle | `sparkles` |
| Edit pencil | `pencil` |
| Refresh | `arrow.clockwise` |
| Envelope | `envelope` |
| Bolt (Shortcut) | `bolt.fill` |
| Clip (clipboard) | `doc.on.clipboard` |
| Shield | `shield` |
| Warning | `exclamationmark.triangle` |
| Up arrow (insert) | `arrow.up` |
| Copy | `doc.on.doc` |

**Replr mark**: the wordmark is just "replr" set in Geist 500 (or SF Pro Rounded 600), tracking −0.04em, with a small coral dot to the right of the `r`. Build it as a single `Text` view + a `Circle()`. No graphic asset.

---

## Implementation order (suggested)

If you want the biggest UX gain per step:

1. **Replace the keyboard idle screen** with the single coral "Capture this chat" primary + auto‑minimise on tap. (Most of the value of the redesign is here.)
2. **Rework the capture bar** with the animated tap glyph, instruction, and × cancel
3. **Redesign the replies screen** — contact row, hero card, dots + carousel, coral Insert primary + neutral Edit
4. **Apply colour discipline everywhere** — one coral per screen; everything else neutral
5. **Add the Memory paragraph + editor** flow (Settings toggle + per‑contact paragraph + Capture Detail inline card)
6. **Polish**: skeleton loading, error state, first‑run coachmark, motion

Steps 1–3 alone would transform how the product feels.

---

*Built as part of an interactive Replr v2 design exploration. Open `design_files/Replr — full UX.html` in a browser to see every screen in context.*
