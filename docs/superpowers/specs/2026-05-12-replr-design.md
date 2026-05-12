# Replr — Design Spec
*2026-05-12*

## Overview

Replr is an iOS keyboard extension that generates human-like, contextually aware replies to any conversation — iMessage, WhatsApp, Tinder, Hinge, Gmail, Instagram DMs, and more. The user captures a screenshot of the conversation from within the keyboard, the screenshot is sent to a vision LLM, and three reply options appear instantly. The user taps one to insert it and auto-switches back to their native keyboard.

The product works across every language and app without per-app or per-language integration, because all context is derived from the screenshot via vision LLM.

---

## Architecture

Replr is a single Xcode project with three targets sharing one App Group container.

### Target 1 — Keyboard Extension (`ReplrKeyboard`)
A `UIInputViewController` with Full Access enabled. This is the core product.
- Capture button triggers screen capture via ReplayKit
- Tone selector (preset + custom)
- Three reply cards, each tappable to insert
- Globe button + auto-switch back to native keyboard after insert
- Reads from shared App Group: screenshot, conversation summary, tones
- Makes LLM API call and displays results

### Target 2 — Broadcast Upload Extension (`ReplrBroadcast`)
An `RPBroadcastSampleHandler` that receives ReplayKit frames.
- Triggered by the keyboard's capture button
- Captures one frame on demand
- Converts `CMSampleBuffer` → `UIImage` → PNG data
- Writes to shared App Group: `screenshot.png`, sets `capture_ready = true`
- Stops broadcast immediately after

### Target 3 — Companion App (`Replr`)
Standard iOS app. The setup and memory hub.
- Conversation summaries per contact
- Custom tones library
- Onboarding flow (permissions walkthrough)
- Settings: model preference, API key or subscription

### Shared App Group (`group.com.replr.shared`)
| Key | Contents |
|---|---|
| `screenshot.png` | Latest captured frame |
| `summaries/` | JSON files per contact |
| `tones.json` | All presets + custom tones |
| `capture_ready` | Boolean flag: broadcast complete |

---

## Data Flow

```
User in any messaging app
        ↓
Opens Replr keyboard (one globe tap from native keyboard)
        ↓
Taps "Capture" button
→ First time: iOS "Allow Replr to record your screen?" prompt
→ Subsequently: instant
        ↓
Broadcast Extension captures one frame
→ PNG written to App Group
→ capture_ready = true
→ Broadcast stops immediately
        ↓
Keyboard reads screenshot.png + conversation summary (if exists) + selected tone
        ↓
Builds four-layer prompt → sends to vision LLM (Claude or GPT-4o)
        ↓
LLM returns 3 reply options
        ↓
Three reply cards displayed
        ↓
User taps a card → inserted via textDocumentProxy
→ Auto-switches back to native keyboard
→ User sends
```

**Latency target:** Capture to replies in under 3 seconds.

The captured frame is written temporarily to the App Group shared container (`screenshot.png`) to pass between the Broadcast Extension and the Keyboard Extension. It is not saved to Photos or the clipboard. It is overwritten on every new capture and never exposed outside the app group.

---

## Keyboard UI

The keyboard extension uses its full height for the AI reply experience. No keyboard layout is included — users type with their own native keyboard (Arabic, Chinese, Japanese, English, anything). Replr is a specialist tool, not a replacement keyboard.

### Idle state
```
┌─────────────────────────────────────┐
│  [📷 Capture]   [💬 Casual ▾]  [⚙️]│
│                                     │
│                                     │
│              📷                     │
│       Capture a screenshot          │
│         to generate a reply         │
│                                     │
│                                     │
│  🌐  Switch keyboard                │
└─────────────────────────────────────┘
```

### Loading state
```
┌─────────────────────────────────────┐
│  [📷 Capture]   [💬 Casual ▾]  [⚙️]│
│                                     │
│                                     │
│           Generating...             │
│              ● ● ●                  │
│                                     │
│                                     │
│                                     │
│  🌐  Switch keyboard                │
└─────────────────────────────────────┘
```

### Reply state
```
┌─────────────────────────────────────┐
│  [📷 Capture]   [💬 Casual ▾]  [⚙️]│
├─────────────────────────────────────┤
│  "Haha that's actually so true,     │
│   where did you even find that?"   ││
├─────────────────────────────────────┤
│  "No way 😂 I was thinking the      │
│   same thing"                      ││
├─────────────────────────────────────┤
│  "That tracks honestly"            ││
│                                     │
│  🌐  Switch keyboard                │
└─────────────────────────────────────┘
```

Tone selector dropdown: all presets + custom tones + "Create tone" option.
Settings icon (⚙️): opens companion app.

---

## Prompt Engineering

Every LLM call assembles four layers in sequence. This is the core IP of the product and will evolve with real usage.

### Layer 1 — Identity (static)
```
You are Replr. You generate human-like replies to text conversations.

Rules:
- Never sound like AI
- No filler openers: "Certainly", "Of course", "Great question", "I'd be happy to"
- Never ask more than one question per reply
- Output exactly 3 numbered reply options, nothing else
- Each option must be distinct in angle or energy, not just paraphrased versions of each other
- Match the reply length rhythm of the conversation
```

### Layer 2 — Role (dynamic, per tone selection)

| Preset | Instruction |
|---|---|
| 💬 Casual | Relaxed, warm, natural. Contractions always. Match their energy exactly. |
| ❤️ Dating | Confident and genuine. Light wit when it fits. Never desperate, never try-hard. Real interest without intensity. |
| 💼 Professional | Clear, competent, respectful. Formal but not stiff. |
| 📧 Email | Structured reply. Appropriate formality read from the screenshot. |
| 🔥 Bold | Short, direct, punchy. No filler. Gets to the point. |
| ✏️ Custom | User's own description injected verbatim. |

### Layer 3 — Context (dynamic, built per request)
```
CONVERSATION BACKGROUND:
{companion app summary if available, otherwise omitted}

SCREENSHOT:
{image}

Reading guide:
- Bubbles on the RIGHT = sent by the user
- Bubbles on the LEFT = sent by the other person
- Read the last few exchanges and understand the full dynamic before replying
```

### Layer 4 — Decisions (static)
```
Before generating replies, assess:
1. Language and cultural dialect → reply in the exact same register, not translated English
2. Conversation energy → match it
3. Typical message length in this conversation → stay consistent
4. What the last message is asking, saying, or implying → address it
5. Whether to advance the conversation or simply respond
6. For dating contexts: where are they in the relationship?

Reply format — output only this, nothing else:
1. [reply]
2. [reply]
3. [reply]
```

### Cultural language handling
No language selection is required from the user. The LLM detects language and cultural dialect directly from the screenshot and replies in kind. Argentine Spanish uses *vos* and local expressions. Brazilian Portuguese differs from European. Egyptian Arabic differs from Gulf. British English differs from American. This is handled automatically by the model.

---

## Companion App

Three screens only:

### Summaries
Searchable list of contacts. Each entry:
- Name and platform (WhatsApp, Tinder, Gmail, etc.)
- Editable short summary: shared topics, tone, key context, relationship stage
- Auto-update prompt after each keyboard session: *"Update summary for this person?"* — one tap, LLM generates 3 sentences from the screenshot and merges with existing summary

### Tones
- View and edit all presets
- Create custom tones: name + plain English description of the voice
- Custom tones sync to keyboard via App Group instantly

### Onboarding (shown once)
1. Enable Replr keyboard in Settings — guided with a deep link
2. Grant Full Access — explains why (needed for LLM network calls)
3. Allow screen recording — explains: one frame only, nothing saved
4. Pick default model: Claude or GPT-4o
5. Done → Summaries screen

---

## LLM Integration

**Primary model:** Claude (Anthropic) — strongest at natural, human-like tone and cultural nuance.
**Secondary model:** GPT-4o (OpenAI) — strong vision, fast, widely trusted.
User can switch between models in Settings.

Both models support vision (screenshot as image input) and 100+ languages at a cultural, not just translational, level.

### Backend

Replr manages a lightweight backend server. Users never touch API keys — they just subscribe and the app works.

**Responsibilities:**
- Receive screenshot(s) + tone + summary from the keyboard extension
- Validate the user's active subscription via Apple's App Store Server API (StoreKit 2 receipt validation)
- Enforce free tier rate limit (20 generations/day per user)
- Route the request to Claude or GPT-4o based on user preference
- Return 3–5 reply options to the keyboard
- No conversation data is stored — every request is stateless

**Stack:** Cloudflare Workers + Hono. Deployed to `api.replr.app` (domain already registered on Cloudflare). Zero cold starts, 300+ global edge locations — critical for a multi-language product with users worldwide. Rate limiting uses Cloudflare KV (persists across Worker instances, TTL-based, no database needed).

**Cost model:** LLM API cost per generation is baked into subscription pricing. Free tier generations are subsidised as acquisition cost. Premium subscription covers per-user LLM cost with margin. Workers paid plan ($5/month) covers 10M requests — vastly more than needed at any realistic user scale.

---

## Error Handling

| Situation | Keyboard shows |
|---|---|
| No screenshot captured | Idle state prompt |
| Screenshot unreadable | "Couldn't read the conversation. Try again." |
| LLM API error / timeout | "Something went wrong. Tap Capture to retry." |
| No internet | "No connection." |
| Full Access not granted | "Enable Full Access in Settings." + deep link |
| Screen recording not permitted | "Allow screen recording to capture context." + deep link |

---

## Testing Targets

**Apps:** iMessage, WhatsApp, Tinder, Hinge, Gmail, Instagram DMs
**Languages:** English, Spanish (ES + LATAM), French, Arabic, Portuguese (BR + EU), Chinese
**Models:** Claude and GPT-4o across all of the above
**Behaviour:** Auto-switch back to native keyboard after insert, error states, first-time permission flows

---

## Monetization

Replr uses a **freemium subscription model**. The free tier is genuinely useful — enough for users to experience the core value and convert. Premium unlocks everything that makes replies significantly better.

| Feature | Free | Premium |
|---|---|---|
| Single screenshot capture | ✅ | ✅ |
| Preset tones | 3 | All 5 + custom |
| Reply options per generation | 3 | 5 |
| Generations per day | 20 | Unlimited |
| Reply regeneration | ❌ | ✅ |
| Scroll capture | ❌ | ✅ |
| Tone memory per contact | ❌ | ✅ |
| AI tone builder | ❌ | ✅ |
| iCloud sync (summaries + tones) | ❌ | ✅ |
| Model selection (Claude + GPT-4o) | One model | Both |

Pricing is a business decision to validate against comparable AI productivity apps — the tier structure above is what matters for the build.

Subscription is managed via **StoreKit 2** (Apple's native in-app purchase framework). No external payment processor needed — Apple handles billing, renewal, and cancellation.

---

## Premium Features

### Scroll Capture
Instead of a single screenshot (~10–15 messages), the user taps "Scroll Capture", scrolls up through the conversation for 5–10 seconds, then taps "Done". The Broadcast Extension collects frames continuously during the scroll.

**Processing approach (V1):** Send 4–6 key frames as multiple images in one LLM API call. Both Claude and GPT-4o support multiple images per request. Higher API cost per call — justifies the premium tier.

**Processing approach (V2 optimisation):** Use Apple Vision framework on-device OCR to extract text from each frame, deduplicate overlapping content, reconstruct the full conversation as a text string, and send text instead of images. Cheaper, faster, better deduplication.

**Value:** Free tier gets ~10–15 messages of context. Premium gets 50–100+ messages. Noticeably better reply quality — a felt difference users will pay for.

### Reply Regeneration
If the user doesn't like the generated options, they tap "Try again" and get 3–5 fresh replies from the same screenshot. Free tier gets one generation per capture. Premium gets unlimited regenerations. This removes the biggest frustration point of any AI reply tool.

### Tone Memory Per Contact
The companion app already stores summaries per contact. Tone memory extends this: the app remembers which tone the user selects most often per contact and auto-selects it next time. No manual selection needed for regular conversations.

### More Reply Options
Free tier returns 3 replies. Premium returns 5 — with deliberate range: one safe, one bold, one question-forward, and two variations. Users find something they like more often.

### AI Tone Builder
Instead of writing a custom tone description manually, the companion app runs a short 5-question interview: texting length preference, humour style, directness level, relationship style, what to avoid. The LLM constructs an optimised tone prompt from the answers. Lowers the barrier to a well-tuned custom tone significantly.

### iCloud Sync
Conversation summaries and custom tones sync across all the user's devices via iCloud. Free tier is local only. Essential for users who upgrade devices or use iPad.

---

## Platform & Compatibility

**Minimum iOS version: iOS 16**

iOS 16 was released September 2022. As of 2026 it covers virtually all active iPhone users. Targeting it means zero legacy fallbacks and a clean modern codebase.

| Component | Requires |
|---|---|
| Keyboard Extension | iOS 8+ |
| ReplayKit `RPSystemBroadcastPickerView` | iOS 12+ |
| Vision OCR (scroll capture V2) | iOS 13+ |
| StoreKit 2 | iOS 15+ |
| Swift Concurrency | iOS 15+ |
| **iOS 16 minimum (recommended)** | All of the above + no legacy paths |

**Minimum supported device:** iPhone 8 (A11 chip, released 2017). Covers the full realistic market.

**iPhone only for V1.** iPad keyboard extensions require a separate UX treatment. Out of scope until V2.

**Performance:**
- LLM inference is server-side — device hardware does not affect reply quality or speed
- ReplayKit frame capture is hardware-accelerated on all supported devices
- Vision OCR (scroll capture V2) runs on-device — performs well on A12+ (iPhone XS and newer), acceptable on A11 (iPhone 8/X)

---

## Out of Scope (V1)

- Built-in keyboard layout (any language)
- Storing or training on user conversation data
- Continuous screen recording
- iPad support
- Android
- Web / desktop
- Per-app integrations

---

## Open Questions

- App Store privacy disclosure strategy for screen recording permission
- Pricing tiers: monthly and annual amounts (validate against comparable AI productivity apps)
