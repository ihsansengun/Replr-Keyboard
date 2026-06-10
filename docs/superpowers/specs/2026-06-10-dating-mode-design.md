# Dating Mode — Design

**Date:** 2026-06-10 · **Status:** approved in brainstorm (pending final spec review)
**Decision context:** Launch waits for full dating mode (user decision). Marketing is dating-first. Goal per user: "focus on getting more matches — like a pickup artist."

## 1. Concept

A third keyboard mode (`Chat | Email | Dating`) that turns Replr into a dating wingman. One unified flow — **screenshot anything, tap once** — and the AI classifies what it's looking at:

| The screenshot shows | The AI returns |
|---|---|
| A **profile** (no chat bubbles) | 3 openers / like-comments built from that profile's specifics (Hinge comment-with-like, Bumble first move, Tinder opener) |
| An **empty/near-empty chat** (match header, no real exchange) | 3 icebreakers |
| An **ongoing conversation** | 3 replies that carry it forward — build attraction, keep momentum, move toward the number/date |

No pre-analysis step, no background AI, no new capture mechanics: the existing screenshot-watcher kernel + tap-to-generate is unchanged, so the privacy posture ("nothing is sent anywhere until you tap") is unchanged. The delayed-match case is covered by behavior, not engineering: every dating app lets you open the match's profile from the chat — screenshot it there, return to the chat, the keyboard offers it within the existing freshness window.

**Conversion research baked into the prompt, not the tones:** referencing the other person's specific profile details ≈3× response rate vs generic; assertive plan-making openers strongly outperform; humor wins only when anchored to specifics. These are DATING_IDENTITY rules — every tone inherits them.

## 2. Keyboard UX

- `ModeSegmentedControl` gains a third segment: **Dating** (`KeyboardInputMode.dating`). `repliesGeneratedInMode` logic extends unchanged.
- **Mode persistence (new — today's chat/email mode is keyboard-session-local):** the selected mode is persisted to the App Group (`selected_mode` key). The keyboard restores it on open, and the intent paths (Back Tap, QuickReply) read it so a capture fired with dating mode selected uses the dating prompt family.
- **Tone fallback on mode switch** mirrors the existing email-mode pattern: entering dating mode with a non-dating tone selected switches the selection to Tease (or the first enabled dating tone).
- Idle copy (dating): "Screenshot a profile or a chat — Replr does the rest." Collapsed-strip copy unchanged.
- Tone row in dating mode shows **dating tones only** (see §4). Replies panel, regenerate, steer hints, undo: all unchanged.
- Capture flows that work in chat mode (screenshot chip, Back Tap intent, QuickReply) work identically; the intent path reads the persisted mode and passes it through.

## 3. Backend — separate prompt family

Hard separation per requirement: dating prompts share NOTHING textual with chat/email prompts.

- `ReplyRequest` gains optional `mode: 'chat' | 'email' | 'dating'` (absent → 'chat'; old clients unaffected).
- New `DATING_IDENTITY` (in `services/llm.ts` beside `IDENTITY`): the confident wingman. Core rules: write FOR the user TO the person in the screenshot; always anchor to ≥1 specific detail from the profile/conversation; never needy, never generic ("hey", "you're gorgeous" banned); assertive plan-making encouraged once rapport exists; mirror the platform's register (Hinge comment ≠ Tinder opener); same language-native and seriousness-override rules as chat. **Boundary: confident and forward, never manipulative — no negging, no degrading her worth; challenge the situation, not the person.** (App Review + brand shield.)
- New `DATING_DECISIONS`: classify the screenshot — profile vs empty chat vs ongoing conversation — then branch per §1 table. For profiles: extract name, read bio AND photos for hooks, pick the 1–2 strongest. For conversations: assess stage (banter / rapport / ready-to-close) and escalate appropriately.
- Output format unchanged (`CONTACT:` = profile/match name, `SUMMARY:`, numbered replies) — `parseLlmOutput` untouched. For profile captures the SUMMARY doubles as the profile essence ("Maya, 28 — climbs, golden retriever, dry humor about her pasta obsession") which becomes match memory (§5).
- `toneSpecFor` resolution unchanged; dating tones are new TONE_LIBRARY keys (§4).

## 4. Dating tones — 11 new + 4 shared

**Mechanism (mirrors the existing pattern):** `Tone.datingToneNames` set + `availableInDating` computed var. Dating row = the 11 dating presets + shared everyday tones (**Natural, Casual, Chill, Confident**) + custom tones (custom tones remain available in every mode). Romance chat tones (Flirty, Seductive, …) stay chat-only — separation preserved. Default dating tone: **Tease**. Backend `TONE_LIBRARY` gains 11 entries (separate keys → zero blending with chat voices).

**Settings:** Tones screen groups into sections — "Dating" section listing the 11 (enable/disable + reorder within the section, same interactions as today), clearly separated from the general list. `ToneBuilder` custom tones appear everywhere (v1; per-mode custom availability deferred).

### Style tones (how you sound)

| # | Name | Temp | Blurb (Settings) | Voice instruction (LLM) |
|---|---|---|---|---|
| 1 | **Tease** (default) | 0.90 | Playful push-pull — turns their profile into a bit. | Playful challenge and push-pull. Find the one detail in their profile/messages that's gently mockable and build the bit around it. Mock-accuse, never insult. Compliments arrive disguised as complaints. End where they have to defend themselves — playfully. |
| 2 | **Smooth** | 0.85 | Effortless charm — compliments with craft. | Charm that looks effortless. Compliments must be specific and earned from their profile — never about generic beauty. Interest reads as good taste, not eagerness. Unhurried sentences; let one line do the work of three. |
| 3 | **Bold** | 0.80 | States intent, makes the plan. | Direct intent. Say what you want — the match, the drink, the date — without hedging or apology. Concrete plans beat abstract interest ("thursday, that wine bar" not "we should hang out sometime"). Short. Confidence is the content. |
| 4 | **Banter** | 0.95 | Committed humor built on their details. | Go for the laugh, anchored to THEIR specifics — their photos, bio lines, contradictions. Absurd scenarios, rankings, mock-petitions, callbacks. Commit fully to the bit. Generic jokes are banned; if the humor could be sent to anyone, start over. |
| 5 | **Intrigue** | 0.90 | Says less — opens loops they must close. | Curiosity gaps. Refer to a thought you don't finish, an observation you withhold, a theory about them you won't explain yet. Shorter than expected. They should have to ask. Deliberate, never cold. |
| 6 | **Challenge** | 0.85 | Flips the frame — they convince you. | Qualification energy: playful skepticism about compatibility — make them earn the next step. Challenge claims in their profile ("everyone says adventurous — prove it"). High standards worn lightly. Challenge the situation or claim, NEVER their worth or looks. |

### Scenario tones (the moments that happen)

| # | Name | Temp | Blurb | Voice instruction |
|---|---|---|---|---|
| 7 | **Closer** | 0.80 | Locks in the number or the date. | The close. Assume the yes; propose a concrete time and place drawn from the conversation or their profile. Move off-app naturally ("before this app starts charging us rent"). One clean ask — no double-asking, no "maybe sometime". |
| 8 | **Revive** | 0.90 | Resurrects a dead conversation. | The conversation died — restart it with zero guilt and zero reference to the silence being anyone's fault. Callback to an earlier thread or open a fresh specific angle. Make replying effortless. Banned: "hey stranger", guilt-trips, asking why they vanished. |
| 9 | **Recovery** | 0.90 | Left on read? Reset the frame, unbothered. | Your last message didn't land or got left on read. Reset with self-aware humor — acknowledge lightly, never grovel or over-apologize. Pivot to a new specific topic. Unbothered is the whole game. |
| 10 | **Slow Burn** | 0.80 | The long game — depth with a spark. | For matches worth investing in. Trade one layer of banter for one layer of genuine curiosity about their life. Specific questions over flirty volleys — but keep one ember of spark so it never reads platonic. Patience as confidence. |
| 11 | **Spice** | 0.95 | Turns up the heat — for mutual energy. | Escalation when the energy is already mutual. Forward and suggestive, tension over explicitness — say less, imply more. Read the room hard: if their energy is not clearly matching, dial back to charm. Never crude openers to a cold profile. |

### Few-shot examples (TONE_LIBRARY entries — flavor only, never reused verbatim)

- **Tease:** "a golden retriever AND an oat milk order in the same profile… dangerously close to a walking cliché. lucky for you it's working" · "we'd argue about the aux cord within a week and you know it" · "i was going to open with something nice but your taste in pizza toppings needs addressing first"
- **Smooth:** "okay the hiking photo sold me — anyone who climbs that far for a view has taste. dinner views are easier though" · "you have the kind of smile that makes someone forget their opener. i had one. it's gone" · "see, now you're just showing off. keep going"
- **Bold:** "you seem like trouble in the best way. drinks thursday — i know a place that matches your tattoo energy" · "i don't do small-talk marathons. you're interesting, i'm interested. that taco place in your third photo, this week?" · "matching with you was the easy part. now i'm pretending i haven't already planned where we're going"
- **Banter:** "ranking your photos: 1) the dog 2) the pasta 3) you. it's a competitive lineup, don't take it personally" · "your bio says 'fluent in sarcasm' — finally someone i can marry for tax purposes AND emotional damage" · "petition to hear the full karaoke-photo story. i've already taken a side and need to know if i'm right"
- **Intrigue:** "i have a theory about you based entirely on your second photo. it's flattering. mostly" · "there's something in your bio most people scroll right past. i didn't" · "you remind me of someone i almost didn't recover from. anyway — coffee?"
- **Challenge:** "cute profile. but everyone's adventurous on here — what's the last thing you did that actually scared you?" · "i'm 70% convinced. the other 30% depends on your taco order" · "you say you're competitive — name the game. loser plans the first date"
- **Closer:** "we've established you have good taste and i'm a great time. thursday, that wine bar — i'll book it" · "this is officially too fun for an app. number, before hinge starts charging us rent" · "you free saturday or do i have to keep being charming until you are?"
- **Revive:** "so anyway, back to what's important: did the pasta place live up to the hype or not" · "i'm choosing to believe you got lost in ikea and only just found wifi. welcome back" · "resurfacing like that voice memo you never sent. how was the trip?"
- **Recovery:** "i see my last message is doing community service in your read pile. it deserves a second chance" · "in my defense, that joke was funnier in my head. let's pretend i said something charming about your dog instead" · "new topic: what's a hill you'd actually die on? mine is that read receipts build character"
- **Slow Burn:** "i was going to ask something flirty but honestly i'm more curious what made you move cities" · "you said that like someone with a story. i've got time" · "okay we'll get back to the banter — first, the bookshop photo. explain"
- **Spice:** "keep texting me like that and you're going to have to follow through in person" · "i'd tell you what i thought when i saw your last photo, but you haven't earned it yet" · "careful. i'm exactly the kind of trouble your bio says you're looking for"

## 5. Match memory

A profile capture's `CONTACT:` + `SUMMARY:` create/attach to the contact via the existing `resolveContact` + `CaptureSession` pipeline — the profile essence becomes the match's first memory with zero new infrastructure. When the conversation develops later, `recentSummaries` already injects it ("Replr remembers every match").

**Dating mode always uses match memory**, independent of the global Memory toggle (which continues to govern chat mode). Rationale: match memory is dating mode's core value; a global off-default would silently kill the differentiator. The existing cross-contamination protection (clear `currentContactID` on fresh capture, resolve after) applies unchanged.

## 6. Out of scope (v1.1 candidates)

App-side Dating console (full analysis cards), multi-profile tray, pre-analysis, extended freshness window, per-tone model routing (Grok-for-dating hypothesis), per-mode custom-tone availability.

## 7. Edge cases & errors

- Non-dating screenshot in dating mode → AI falls through the classification to ongoing-conversation behavior; never errors on content.
- Unknown/group contact → existing `resolveContact` nil-handling unchanged.
- Old clients / missing `mode` → chat behavior, byte-identical responses.
- Credits/pricing: a dating generation costs exactly a chat generation (one image, same models, same `creditsRequired`).

## 8. Testing

- Backend: tone resolution for all 11 new keys; `mode: 'dating'` selects the dating prompt family (assert system prompt contains DATING_IDENTITY, not chat IDENTITY); request validation accepts/defaults `mode`; existing suites stay green.
- iOS: build gate; manual device script — profile screenshot → openers; empty chat → icebreakers; ongoing chat → continuation; Settings shows the Dating section; tone row filtering per mode.
