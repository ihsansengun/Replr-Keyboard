# Replr — ground-up redesign

A from-scratch rethink of the whole product: what Replr is, who it's for, how it should work, and how it should look. Written as a UX/product strategy — opinionated on purpose, because that's what a redesign needs. Earlier work in this project (the monochrome design system, the keyboard state model) is referenced where it still holds; everything else is reopened.

---

## 1. What Replr actually is

Replr is described in its own settings as an "AI-powered reply keyboard." That's a description of the *mechanism*, not the *product*. It's the first thing to fix.

What Replr actually does for a person: **it removes the hardest part of messaging — knowing what to say back.** It reads a conversation and hands you a reply you'd be happy to send.

Look at the conversations used to test it throughout this project: a tense dispute with a garage about a faulty car, a customer-service back-and-forth. Not "lol what do I say to my friend." The real pull of Replr is **consequential replies** — messages where the wording matters and getting it wrong has a cost:

- complaints, disputes, negotiations
- professional or semi-professional replies (a contractor, a landlord, a client)
- difficult personal conversations
- replying confidently in a second language
- the tedious-but-must-be-done (the apology, the chase-up, the polite no)

That is the sharp wedge. Replr is not a toy for witty banter — it *can* do that, but its center of gravity is **"help me respond well when responding is hard."** Every decision below follows from taking that seriously.

The job-to-be-done, stated plainly: *"I need to reply to this and I want to get it right — write it for me."*

---

## 2. Who it's for

Three audiences, in priority order:

1. **The conflict-avoidant capable adult.** Competent, busy, but freezes on charged messages — disputes, awkward asks, saying no. They don't lack words, they lack the *confidence* that their words are the right ones. Replr is their composure.
2. **The second-language messenger.** Replies in English (or any language) that they could write slowly and anxiously — Replr makes them sound fluent and appropriate instantly. Huge, underserved, and Replr is genuinely excellent for them.
3. **The professional juggling many threads.** Landlords, freelancers, small-business owners, anyone running customer conversations from their personal phone. Volume + tone control.

What they share: the reply *matters*, and they want it *handled*. They are not looking for entertainment. They will pay for reliability and trust. This audience wants a tool that feels **serious, private, and competent** — which, usefully, is exactly what the monochrome premium visual direction already says.

---

## 3. The five problems a ground-up redesign has to solve

**Problem 1 — Setup is a one-time gauntlet.** The per-use capture is actually fine: once configured, a single Back Tap captures the chat and the screenshot is passed straight to Replr in memory — one gesture, no permissions (confirmed in the code: `GenerateReplyIntent` receives the screenshot as an in-memory `IntentFile`, never via the photo library). The problem is everything required *before* that works — install the keyboard, grant Full Access, install a Shortcut, bind it to Back Tap — four setup tasks, several trips into iOS Settings, one (Back Tap) with no deep link. Every one is a place a new user abandons before ever seeing a reply. (See §4.)

**Problem 2 — Setup friction front-loads everything painful.** Six onboarding steps, multiple trips into iOS Settings, a step (Back Tap) that Apple gives no deep link to. The user must complete almost all of it *before experiencing any value at all*. Every step is a drop-off cliff.

**Problem 3 — Trust is treated as a footnote.** Replr reads screenshots of private conversations and sends them to a server that calls an external AI. For an audience using it on *consequential, private* messages, trust isn't a line in onboarding — it's the foundation of the brand. Right now it's one grey subtitle ("Nothing is stored").

**Problem 4 — The differentiator is buried.** Replr's genuine moat is **memory**: it summarises each conversation and feeds past context back in, so replies sound like *your* relationship with that person, not generic AI. No generic reply tool does this. Yet memory is an off-by-default-looking toggle in Settings and a screen you reach by discovering that a History filter chip is tappable. The best thing about the product is hidden.

**Problem 5 — The reply view is cramped — but the keyboard's height is a variable, not a fact.** Reading and choosing between three full-sentence, nuanced replies in a ~300px panel is genuinely bad, and no amount of polish fixes a letterbox. But a custom keyboard extension is *not* locked to the standard keyboard height — it sets its own. The fix is not to move replies off the keyboard (that re-introduces per-use friction); it's to let the keyboard **expand** for the replies state into a tall, comfortable reading panel, then collapse back. The constraint everyone assumes is fixed isn't. (See §4, Move 5.)

---

## 4. The reframe — the strategic moves

Five moves. Together they are the redesign.

### Move 1 — Keep the capture model; fix what's actually broken around it

An earlier draft of this doc proposed replacing Back Tap capture with the iOS Share Sheet. Reviewing the code shows that was wrong.

The per-use capture flow is already right. `GenerateReplyIntent` receives the screenshot as an in-memory `IntentFile` straight from the Shortcut's "Take Screenshot" action — `openAppWhenRun = false`, runs in the background, fetches memory, writes replies to the App Group. Triggered by Back Tap, the whole thing is **one physical gesture, no permissions, and the screenshot never touches the photo library.** A Share Sheet flow would be slower *every single use* (screenshot → open share sheet → find Replr → tap) — it trades painful *setup* for painful *daily use*, the wrong trade. Back Tap → Shortcut → `GenerateReplyIntent` stays as the primary path.

What's actually broken sits *around* that good core:

**The "Allow photos" onboarding step is misplaced.** Photos is used by exactly one intent — `QuickReplyIntent` — which reads your latest screenshot from the library as a *no-setup fallback*. The primary Back Tap path never touches Photos. So onboarding currently demands a photo-library permission the main flow doesn't use. Fix: remove Photos from the required onboarding path; surface it only if the user opts into the no-setup QuickReply mode. Most users should never see a Photos prompt.

**There are duplicate capture intents.** `GenerateReplyIntent` and `AnalyzeScreenshotIntent` do nearly the same job; `GenerateReplyIntent` is the better one (tone, memory, contact resolution, capture session) and `AnalyzeScreenshotIntent` looks superseded. Two near-identical Shortcuts actions invite users to wire up the weaker one — consolidate to one. And confirm the iCloud Shortcut installed in onboarding chains `Take Screenshot → Generate Reply`, not the Photos-based QuickReply.

**The Shortcut should run invisibly.** Configure it to run without confirmation and without a notification, so a Back Tap feels like nothing happened until the replies are simply there.

**Optional: offer the Action Button.** On iPhone 15 Pro and newer, the same Shortcut can be bound to the Action Button — a physical one-press capture. Same Shortcut, alternative trigger; Back Tap stays the universal default.

The one genuinely unavoidable cost is the *one-time setup* — binding the Shortcut to Back Tap in Settings → Accessibility, which Apple gives no deep link to. That's a setup cost, not a per-use cost. Move 2 makes it as painless as a one-time thing can be.

### Move 2 — Make the one-time setup a guided install with a real payoff

The primary path needs the Back Tap setup before it works, so onboarding can't skip it — but it can stop feeling like a gauntlet:

1. One screen: what Replr does + the privacy promise.
2. The setup steps — keyboard, Full Access, install Shortcut, bind Back Tap — each with **auto-detection** so the user never has to guess whether it worked, honest sequential step numbering, and strong visual coaching for the one step Apple won't let us deep-link (Back Tap).
3. A guided **first capture** as the finale: "Open any chat and double-tap the back of your phone." The first reply appears — the payoff that makes the setup worth it.

The Photos step is removed from this path (Move 1).

**What happens if the user abandons at the Back Tap step** — the hardest one, the one with no deep link. They must not hit a dead end. Replr already has a graceful reduced-capability mode in the code: `QuickReplyIntent` reads the most recent screenshot from Photos with no Back Tap and no Shortcut. So the abandon branch is real and designed: "Skip for now" drops the user into **QuickReply mode** — take a screenshot the normal way, then open Replr (or run the Quick Reply shortcut) and it reads that screenshot. It costs the Photos permission and one extra step per use, but the user is *using the product the same day*, not stuck. Replr then re-offers Back Tap setup later, framed as the upgrade to one-gesture capture — earned, once they've felt the value. Nobody is ever blocked behind the Back Tap step.

### Move 3 — Make trust a designed pillar

Trust is the foundation of the brand, so it has to be *designed*, not asserted. Concretely:

**Where it lives.** A dedicated **Privacy** screen, top-level inside Settings (not buried), also reachable from onboarding. A real surface, not a paragraph.

**What it says — a plain data-flow statement, honest and specific:** the screenshot is sent to Replr's server, which calls an AI provider (Claude or GPT-4o) to write the replies; the screenshot itself is not retained server-side; the only thing kept is the one-line conversation *summary*, stored **on your device** in the App Group for the memory feature — nowhere else; Replr's primary path never has access to your photo library at all. Critically: do not say "nothing is stored" if a summary is stored — say exactly what is kept and where. Precision *is* the trust.

**The moments that matter — trust shown, not just stated:**
- *Onboarding:* one honest screen (not a grey subtitle) carrying the data-flow statement in plain language.
- *First capture:* the very first time Replr sends a conversation, a one-time confirmation so the user consciously consents — once, then never again. This surfaces in Replr's own UI (the keyboard panel, before the first send), **not** in the Shortcut — so it doesn't conflict with the Shortcut running silently (Move 1); the Shortcut stays invisible, the consent moment lives in Replr.
- *Every capture:* the keyboard's loading state names what is happening — "Reading this conversation…" — calm and legible, so a capture is never silent or sneaky.

**Memory as a trust surface.** The Memory screen is where trust becomes tangible: the user can *see* every summary Replr holds and delete any of it. Memory you can inspect and clear is memory you can trust — this move and Move 4 reinforce each other.

The brand line: "the reply tool you can trust with the messages that matter."

### Move 4 — Promote memory to the front

Memory is the differentiator, so it leads:

- It's introduced in onboarding as the reason replies get better over time.
- It has its own clear home in the app (not buried under a History filter).
- On the reply screen, when memory is informing a reply, say so quietly — "Remembering your last chat with Sam" — so the user *feels* the product getting smarter.

### Move 5 — Let the keyboard expand; the app keeps the history

The replies appear in the keyboard because that is how you stay in the chat — but the keyboard does not have to be a letterbox. A custom keyboard extension controls its own height. So the **replies state expands** the panel into a tall, comfortable reading surface — enough to see three full-sentence replies without squinting, with room to read, compare and edit — then collapses back to a normal height for idle and insertion. This is the honest answer to the reading problem (§3, Problem 5): a momentary in-context expansion — no app switch, no per-use friction, no Share Sheet. Two implementation constraints for the spec: the expanded height must be a **fixed** value (keyboard extensions set explicit heights — as the current code already does, 280/320/44px — and cannot auto-size to content), and that fixed value needs an upper bound tested per device — too tall and the conversation scrolls out of view above the panel on smaller phones, leaving the user unable to see the message they're replying to. Expand tall, not edge-to-edge; treat the height ceiling as a per-device-size decision.

At that expanded height the reply view still deserves real polish: options shown clearly, one-tap tone re-roll, comfortable edit, one obvious **Insert**.

The **companion app** is the comfortable screen for everything that *isn't* time-critical — reviewing past captures, reading and editing memory. Live reply = expanded keyboard; reflection and management = app.

---

## 5. Positioning & brand

**Brand idea:** *Composure.* Replr is the quiet competence of always knowing what to say — especially when it's hard. Not "AI replies," not "faster texting." Composure.

**One-line positioning:** Replr writes the reply you'd send if you had the time, the words, and a clear head.

**Name:** "Replr" stays — short, ownable, app-store-friendly. Wordmark lowercase `replr`.

**Voice:** calm, precise, quietly confident. Short sentences. Never hypey, never cute. It speaks like a discreet, capable assistant — because that builds the trust the product runs on. Replace feature-speak ("AI-powered reply keyboard") with benefit-speak.

**Taglines to consider:** "Know what to say." / "The reply, handled." / "Never lost for words." — "Know what to say" is the strongest: calm, complete, true.

---

## 6. Information architecture

```
REPLR
│
├─ Keyboard extension ......... the product in use — Back Tap capture,
│                                expands tall for replies, one-tap insert
│
├─ Companion app  (3 tabs)
│   ├─ Replies (home) ......... recent captures and their replies
│   ├─ Memory ................. contacts Replr remembers + their summaries
│   └─ Settings ............... model, tones, Privacy, Back Tap setup, subscription
│
└─ Shortcut + App Intents ..... Take Screenshot → Generate Reply, fired by Back Tap
```

Migration from today: the shipped app has a **2-tab** companion app (History, Settings). This proposes **3 tabs** — a deliberate, small change, not a rebuild. History becomes **Replies** (the home). **Memory** is promoted from being buried under a History filter chip to its own tab — it's the one destination that genuinely earns promotion. **Tones stays inside Settings**, where it already lives; it's configured occasionally and doesn't merit a tab. So the net change is one rename and one promotion.

---

## 7. The experience, redesigned

### First run
Three beats: *what it does + the privacy promise* → *the guided one-time setup, with auto-detection at every step* → *a guided first capture that pays it off with a real reply.*

### The core loop — capture → reply
In any chat: double-tap the back of the phone → the Shortcut silently captures the screen → `GenerateReplyIntent` generates in the background → the replies appear in the Replr keyboard. One gesture, no permissions, no photo library.

The **keyboard reply view** is the heart of the product and must be excellent within its constraints: the suggested replies shown clearly, the active tone visible with one-tap re-roll, a quiet memory cue when past context was used, comfortable editing, and one obvious **Insert**. (A no-setup alternative exists for users who haven't configured Back Tap — `QuickReplyIntent` reads the latest screenshot from Photos — offered as a fallback, not the main path.)

### Companion app (3 tabs)
- **Replies (home):** a calm space showing recent captures and their replies.
- **Memory:** the contacts Replr remembers, what it remembers, fully editable and clearable — memory you can *see* is memory you can *trust*. Doubles as a trust surface (§4, Move 3).
- **Settings:** AI model, tones (preset + custom), the Privacy screen, Back Tap setup, subscription.

### Keyboard
Two heights: a normal height for idle and insertion, and an **expanded** tall panel for the replies state so three replies are comfortable to read and choose between (§4, Move 5). States stay simple — idle, capturing, loading, replies, edit, error — and the visual system applies.

---

## 8. Visual system

The monochrome premium direction chosen earlier is the right fit for this strategy — a serious, private, competent tool should *look* serious, private, and competent, and monochrome with real material depth says exactly that without dating or looking like an AI-wrapper template. It stands; it is specified in full in `REPLR_DESIGN_SYSTEM.md`.

In brief: pure monochrome, adaptive light + dark, premium feel carried by depth (layered shadows, lit surfaces, glass material, fine texture, high contrast) rather than color. The primary action is the highest-contrast element on the screen. Logo is the universal reply mark. Typography is SF Pro with a precise scale where weight and size carry the hierarchy color usually would.

Nothing in this redesign reopens the visual system — it reopens the *product* around it.

---

## 9. Feature decisions — keep, cut, change

**Memory — keep, and promote.** The moat. Top-level destination, introduced in onboarding, surfaced on the reply screen. (§4, Move 4.)

**Tones — cut from seven to four.** The current seven overlap: Casual and Friendly are one register, Professional and Formal are one register, Bold and Witty both just mean "has personality." The proposed core set — four genuinely distinct tones: **Friendly** (warm, relaxed), **Professional** (polished, appropriate for work and business), **Direct** (concise and firm, no fluff — the workhorse for the consequential-reply wedge), and **Witty** (light, clever). **Dating** leaves the default set — it's situational and off-wedge — and becomes a *suggested custom tone* instead. Custom tones already exist; lean on them so users build their own voice rather than scanning a crowded row.

**Email mode — keep as a distinct mode.** Email replies work from clipboard text rather than a screenshot, so the Chat/Email toggle stays meaningful — it tells Replr which input to expect. Keep it, and make sure both modes clearly read as one product with two input types.

**History — fold into "Replies."** It doesn't need to be its own tab; recent captures live on the home space.

**Tiers — keep, re-pitch.** Free vs Premium is fine, but premium should be sold on the strategic strengths: deeper memory, more reply options, the keyboard fast-path conveniences. Sell composure, not quotas.

**Capture via Back Tap — keep as the primary path.** It's already one gesture and Photos-free; the work is fixing the setup and plumbing around it, not replacing it. (§4, Move 1.)

---

## 10. Priorities

1. **Fix the capture plumbing.** Confirm the onboarding Shortcut chains `Take Screenshot → Generate Reply` (`GenerateReplyIntent`); consolidate the duplicate `AnalyzeScreenshotIntent`; make the Shortcut run silently (no confirmation, no notification); remove Photos from the primary onboarding path.
2. **Rebuild onboarding** as a guided one-time install — auto-detection at every step, honest step numbering, strong coaching for the Back Tap step, and a first-capture payoff.
3. **Promote Memory** to a top-level destination; add the keyboard's memory cue.
4. **Make the Privacy surface** real and reachable; rewrite the trust copy honestly.
5. **Polish the keyboard reply view** — it hosts the live reply, so it has to be excellent.
6. **Tighten tones**, fold History into the home space.
7. Apply the monochrome visual system throughout (already specified).

Items 1–2 are the foundation. The capture model is already sound — so the leverage is in removing the setup friction and the misplaced Photos permission around it, and in making the one-time setup feel like a confident guided install that ends in a real reply.

---

*This is the product rethink. The visual system (`REPLR_DESIGN_SYSTEM.md`) and the staged build prompt still hold for execution — but the build order should lead with the capture-plumbing fixes and the rebuilt onboarding, since those are what stand between a new user and their first reply.*
