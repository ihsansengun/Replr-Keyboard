# Replr keyboard — UX redesign

A from-scratch redesign of the Replr keyboard, based on the five screenshots of the current build (Chat idle, the collapsed capture bar, the typed-hint state, Email idle, and the replies screen). This is a design specification — layout, interaction, and visual system. No code.

---

## 1. What the current design is doing

The keyboard today has these states:

- **Idle — Chat**: a `Chat | Email` toggle, a scrolling tone-chip row, and a large card containing a phone icon and the text "Tap to minimise, then Back Tap / screenshot → AI replies".
- **Idle — Email**: same toggle and tone row, with a large amber "Generate from clipboard" button and the helper line "Copy the email text first, then tap above".
- **Collapsed**: a thin amber bar reading "Back Tap to capture".
- **Typed-hint**: when the user types in the host app, an "AI hint: …" strip appears under the panel.
- **Replies**: a contact header (`ahmet` · "New replies"), one reply in a card, page dots, an "Edit" button and an amber "↑" insert button.

The bones are right — the brand is dark + amber, the Chat/Email split is sensible, and tones are context-aware (Dating shows for Chat, not Email). The problems are in hierarchy, the capture interaction, and discipline.

---

## 2. Diagnosis — the problems, ranked

**1. The core action is an instruction, not a button.** Replr's whole job is "capture a chat → get replies," yet the idle Chat screen spends its entire canvas *explaining a gesture* ("Tap to minimise, then Back Tap"). When a screen has to narrate how to use it, the interaction is broken. A new user has no idea what "Back Tap" is, and the phone icon is decorative — it does nothing.

**2. Two full rows of chrome before any content.** The `Chat | Email` toggle and the tone-chip row stack on top of each other. On a surface this short, that's a large share of the height gone before the user can act — and in the idle state, neither row is what the user needs *yet*.

**3. Amber is overused, so nothing leads.** The toggle's selected tab, the selected tone chip, the instruction text, and the primary buttons are all amber. When everything is the accent color, there is no accent — the eye has no single place to land.

**4. Muddy surfaces.** The idle card sits on a brown-tinted dark fill. The brown is amber bleeding into the neutral. It makes the panel feel dim and slightly dirty rather than crisp.

**5. The replies card wastes its space.** The reply text sits at the top, a large void sits below it, and the controls (dots, Edit, insert) are crammed into the bottom edge. The most important action — inserting the reply — is the smallest control on the screen, a tiny amber square. "New replies" (regenerate) is easy to miss.

**6. Inconsistent control shapes.** Big amber pills (tabs), outlined pills (tones), a big amber rectangle (Generate), a small amber square (insert), a grey pill (Edit) — five treatments for actions of similar weight.

**7. The "AI hint" strip is unclear.** It surfaces a suggestion based on what was typed, but it isn't obvious what it is, whether it's tappable, or why it's valuable. It adds a row of noise.

**8. Small polish gaps.** The contact name renders lowercase ("ahmet"). "Witty" is clipped mid-word at the screen edge — meant to signal scrolling, but reads as a bug. Helper text and titles don't share a consistent scale.

---

## 3. Design principles

Five principles the redesign is held to.

**One job per state.** Each state should make exactly one thing obvious. Idle = capture. Replies = read and insert. Anything that isn't that job steps back or disappears.

**The action is a button, never a caption.** If the user must do something, it is a tappable control with a verb on it. Instructions become momentary coaching, not permanent furniture.

**Amber is a spotlight, not paint.** Amber marks the single primary action on a screen, plus the current selection. Everything else lives in the neutral dark ramp. One amber "hero" per screen.

**Respect the height.** This is a keyboard — short and shared with the host app. Every row of chrome must earn its place. Controls the user doesn't need *right now* are deferred to the state where they're actionable.

**Quiet, then confident.** The keyboard sits inside someone else's app, so it stays calm and recessive — until the user is reading replies, where it can be crisp and direct.

---

## 4. The central fix — the capture interaction

This is the most important change, so it gets its own section.

**Why capture is two steps.** A keyboard extension cannot screenshot the app it sits in. Replr's workaround: the user minimises the keyboard (so it isn't covering the chat), then triggers a Back Tap (triple-tap on the back of the phone), which runs a Shortcut that captures the screen and hands it to Replr. That constraint is real and isn't going away — so the redesign's job is to make the two steps feel like one guided motion instead of a riddle.

**The redesigned flow:**

1. **Idle** shows a single primary button: **"Capture this chat."** No instruction paragraph. Just the button and one quiet sub-line.
2. Tapping it **automatically minimises** the keyboard and transitions straight to the **capture bar** — the user never has to discover "minimise" themselves.
3. The **capture bar** is explicit and active: it names the exact gesture — "Triple-tap the back of your phone" — with a small animated phone-tap glyph, and a clear way to cancel back up.
4. After the Back Tap fires, Replr goes to **loading**, then **replies**.

**First-run coaching.** The very first time, overlay a two-beat coachmark on the capture bar ("1. We've minimised the keyboard → 2. Now triple-tap the back of your phone"). After the user succeeds once, it never shows again — returning users see only the button and the bar. The instruction is *temporary scaffolding*, not the permanent UI.

This single change reclaims the entire idle canvas and turns Replr's hardest moment into a one-tap start.

---

## 5. Information architecture — cutting the chrome

**Decision: tone leaves the idle state.** In idle, the user's only job is to capture. A tone row there is premature — tone matters at *generation* time, when you can see a reply and want it warmer or sharper. So:

- **Idle** shows tone as a single compact control in a corner — `Friendly ⌄` — tappable to change, defaulted to last used. One small chip, not a full row.
- The **full tone row** appears on the **replies** screen, where tapping a tone regenerates in that tone. Tone is now adjacent to its actual effect.

This removes a whole row of chrome from the most-seen screen.

**Decision: the `Chat | Email` toggle shrinks.** It stays — it's a genuine mode switch — but becomes a slim segmented control (standard ~32px height, neutral selected fill), not two tall amber pills. It's navigation, not the hero, so it must not wear the hero color.

**Decision: the "AI hint" strip is removed** from the idle/typing surface. It's an unclear feature competing for height. If inline suggestions return later, they should be a single, clearly-labelled, tappable suggestion shown only when genuinely confident — not an ambient strip.

**The resulting state map:**

```
                 ┌─────────────┐
                 │    IDLE     │   Chat or Email mode
                 │  (capture)  │   one primary CTA
                 └──────┬──────┘
                        │ tap "Capture" / "Generate"
                        ▼
   Chat ──▶ ┌─────────────┐        Email ──▶ generates直接
            │ CAPTURE BAR │                 from clipboard
            │ (collapsed) │
            └──────┬──────┘
                   │ Back Tap fires
                   ▼
            ┌─────────────┐
            │   LOADING   │
            └──────┬──────┘
                   ▼
            ┌─────────────┐   ┌──────────────┐
            │   REPLIES   │──▶│  EDIT REPLY  │
            │  (carousel) │   └──────────────┘
            └──────┬──────┘
                   │ contact unclear / wrong
                   ▼
        ┌──────────────────────┐
        │ RENAME / DISAMBIGUATE │
        └──────────────────────┘

   Any state can fall to ──▶ ┌────────┐
                             │ ERROR  │
                             └────────┘
```

---

## 6. Screen-by-screen redesign

Wireframes below; the keyboard panel is the full width of the phone and roughly 300px tall. `▓` = amber, `░` = neutral fill, `·` = quiet/secondary text.

### 6.1 Idle — Chat

```
┌────────────────────────────────────────────────┐
│   ┌──────────┬──────────┐                       │  slim segmented
│   │ ▌ Chat   │  Email   │                       │  control (~32px)
│   └──────────┴──────────┘                       │
├────────────────────────────────────────────────┤
│                                                  │
│                                                  │
│        ┌────────────────────────────────┐        │
│        │  ▓▓  Capture this chat   ▓▓▓▓  │        │  PRIMARY — amber
│        └────────────────────────────────┘        │
│                                                  │
│        · Minimises the keyboard so you can       │  one quiet line
│          triple-tap to screenshot                │
│                                                  │
│                                  Friendly  ⌄     │  compact tone
├────────────────────────────────────────────────┤
│  🌐                                         🎤   │
└────────────────────────────────────────────────┘
```

Spec: one job — capture. The button is the only amber element. The sub-line is a single quiet sentence, not a diagram. Tone is a small chip bottom-right, opening a picker sheet on tap. The phone icon is gone — it was decorative. Tapping "Capture this chat" minimises and advances to the capture bar.

### 6.2 Idle — Email

```
┌────────────────────────────────────────────────┐
│   ┌──────────┬──────────┐                       │
│   │   Chat   │ ▌ Email  │                       │
│   └──────────┴──────────┘                       │
├────────────────────────────────────────────────┤
│                                                  │
│        ┌────────────────────────────────┐        │
│        │  ▓▓  Generate from clipboard ▓ │        │  PRIMARY — amber
│        └────────────────────────────────┘        │
│                                                  │
│        · Copy the email you're replying to,      │
│          then tap above                          │
│                                                  │
│        ⎘  Nothing copied yet                     │  live clipboard
│                                                  │  status
│                                  Friendly  ⌄     │
├────────────────────────────────────────────────┤
│  🌐                                         🎤   │
└────────────────────────────────────────────────┘
```

Spec: structurally identical to Chat idle — same button position, same sub-line pattern, same tone chip. The two idle states should feel like one screen with a different verb, not two different designs. Added: a **live clipboard status** line — "Nothing copied yet" vs "Email text ready ✓" — so the user knows whether the button will work *before* tapping it. The button is disabled-styled until the clipboard has text.

### 6.3 Capture bar (collapsed)

```
┌────────────────────────────────────────────────┐
│  ▓ ┌──┐                                          │
│  ▓ │▫▫│  Triple-tap the back of your phone   ✕   │
│  ▓ └──┘  to capture this chat                    │
└────────────────────────────────────────────────┘
        ▲ animated tap glyph        ▲ cancel → back to idle
```

Spec: the collapsed bar is now *instructional and active*, not a label. It names the exact gesture, shows a small looping phone-tap animation so the motion is unmistakable, and offers an explicit `✕` to cancel back to idle. Height stays minimal (~44px) so the chat above is fully visible for the screenshot. First run only: a brief coachmark balloon points at it.

### 6.4 Loading

```
┌────────────────────────────────────────────────┐
│   ┌──────────┬──────────┐                       │
│   │ ▌ Chat   │  Email   │                       │
│   └──────────┴──────────┘                       │
├────────────────────────────────────────────────┤
│                                                  │
│        ┌────────────────────────────────┐        │
│        │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │        │  skeleton card
│        │ ░░░░░░░░░░░░░░░░░░░░            │        │  with shimmer
│        └────────────────────────────────┘        │
│                                                  │
│              Reading the conversation…           │  · honest status
│              ● ● ●                                │  pulsing dots
│                                                  │
├────────────────────────────────────────────────┤
│  🌐                                         🎤   │
└────────────────────────────────────────────────┘
```

Spec: show a skeleton of the reply card the user is about to get — same shape, same position — so the transition into replies is seamless, not a jump. A short honest status line ("Reading the conversation…" → "Writing replies…") plus a calm pulsing-dot animation. No generic spinner.

### 6.5 Replies (the hero screen)

```
┌────────────────────────────────────────────────┐
│   ┌──────────┬──────────┐                       │
│   │ ▌ Chat   │  Email   │                       │
│   └──────────┴──────────┘                       │
├────────────────────────────────────────────────┤
│  👤 Ahmet  ✎                            1 of 3  │  contact + position
├────────────────────────────────────────────────┤
│                                                  │
│   Thank you for the prompt response. I           │  reply = the hero,
│   appreciate the reassurance and will reach      │  generous margins,
│   out if anything else comes up.                 │  vertically settled
│                                                  │
│              ● ○ ○   ‹ swipe for more ›          │  carousel affordance
├────────────────────────────────────────────────┤
│  ┌────────────────────────┐  ┌────────┐          │
│  │ ▓▓  Insert reply  ▓▓▓▓ │  │  Edit  │          │  PRIMARY + secondary
│  └────────────────────────┘  └────────┘          │
├────────────────────────────────────────────────┤
│  Casual ‹Friendly› Dating Professional…   ↻      │  tone row + regen
└────────────────────────────────────────────────┘
```

Spec, top to bottom:

- **Contact row**: name properly capitalised, with a small `✎` to rename — and `1 of 3` so the user knows how many replies exist.
- **Reply body**: the reply is the hero. Comfortable side margins, vertically centred in its space, larger readable type. No dead void.
- **Carousel affordance**: dots *plus* a "swipe for more" cue the first few times, so users discover there are three options. Consider a slim peek of the next card's edge.
- **Actions**: "Insert reply" becomes a wide, obvious amber primary button — it's the whole point of the screen. "Edit" is a neutral secondary button beside it. The tiny amber square is gone.
- **Tone row lives here**: the full scrollable tone row sits at the bottom. Tapping a different tone **regenerates** in that tone — tone is finally next to its effect. The `↻` regenerates in the current tone. This is where the tone row earns its row.

### 6.6 Edit reply

```
┌────────────────────────────────────────────────┐
│  ‹ Back to replies                       Ahmet  │
├────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────┐ │
│  │ Thank you for the prompt response. I       │ │  editable field,
│  │ appreciate the reassurance and will reach  │ │  sunken well,
│  │ out if anything else comes up.▏            │ │  amber caret
│  └────────────────────────────────────────────┘ │
│                                       128 chars  │
├────────────────────────────────────────────────┤
│  ┌────────────────────────┐  ┌────────┐          │
│  │ ▓▓  Insert reply  ▓▓▓▓ │  │ Cancel │          │
│  └────────────────────────┘  └────────┘          │
└────────────────────────────────────────────────┘
```

Spec: the chosen reply opens into a sunken editable well with an amber caret. A clear "Back to replies" exit, a live character count, and the same Insert primary so the action stays consistent across screens.

### 6.7 Rename / disambiguate contact

```
┌────────────────────────────────────────────────┐
│  Who is this conversation with?            ✕     │
├────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────┐ │
│  │ 👤  Ahmet                                  │ │  ← detected
│  └────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────┐ │
│  │ 👤  Ahmet K. (work)                        │ │  ← other matches
│  └────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────┐ │
│  │ +  Use a different name…                   │ │
│  └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

Spec: when the contact is ambiguous or wrong, a clean list of candidate names plus a free-entry option. Getting the contact right is what makes Replr's memory feature work, so this screen should feel quick and low-stakes, not like an error.

### 6.8 Error

```
┌────────────────────────────────────────────────┐
│   ┌──────────┬──────────┐                       │
│   │ ▌ Chat   │  Email   │                       │
│   └──────────┴──────────┘                       │
├────────────────────────────────────────────────┤
│                                                  │
│                  ⚠                               │  calm amber glyph
│         Couldn't generate replies                │
│         · Check your connection and try again    │
│                                                  │
│            ┌──────────────────────┐              │
│            │ ▓▓  Try again  ▓▓▓▓▓ │              │  retry = the CTA
│            └──────────────────────┘              │
│                                                  │
├────────────────────────────────────────────────┤
│  🌐                                         🎤   │
└────────────────────────────────────────────────┘
```

Spec: errors get their own treatment — they must not look like the idle state (today they reuse idle, which makes failure invisible). Calm, non-alarming, one clear retry action. The message says what happened in plain words; the sub-line says what to do.

---

## 7. Component system

A small, consistent kit. Every control on every screen is one of these.

**Segmented control** (`Chat | Email`): full-width, ~32px tall, neutral track, the selected segment gets a light neutral fill (`raised`) and brighter text — *not* an amber fill. It's navigation; it stays quiet.

**Primary button**: the one amber action per screen. Full-width or near it, ~46px tall, 14px corner radius, amber fill, dark text, a leading icon. Only one exists per screen — capture, generate, insert, retry.

**Secondary button**: neutral fill (`raised`), `border` hairline, primary text. Sits beside the primary (Edit, Cancel). Never amber.

**Tone chip**: capsule, ~30px tall. Unselected = transparent with a `border` hairline and secondary text. Selected = amber fill with dark text. In the tone row, the selected chip auto-scrolls into view so it's never clipped; the row has a soft fade on both edges to signal scrollability honestly.

**Tone chip (compact)**: in idle, a single `Friendly ⌄` chip — secondary text, hairline border, a chevron — opening a tone picker.

**Reply card**: `surface` fill, 14px radius, generous internal padding, the reply text as the dominant element.

**Skeleton card**: same footprint as the reply card, `raised` fill, a slow shimmer. Used only in loading.

**Capture bar**: ~44px, `surface` fill, an amber left edge, instruction text, an animated tap glyph, a cancel `✕`.

**Icon buttons** (globe, mic): unchanged in function, but given a fixed touch target and balanced spacing so they don't float.

---

## 8. Visual system

**Color — the discipline matters more than the values.**

| Token | Value | Use |
|---|---|---|
| Base | `#0F0F12` | keyboard background |
| Surface | `#1B1B20` | cards, capture bar, reply card |
| Raised | `#26262C` | selected segment, secondary buttons |
| Border | `#2E2E36` | 0.5px hairlines |
| Amber | `#F2A93C` | the one primary action + selected states only |
| Amber-dark | `#3A2401` | text on amber fills |
| Text primary | `#EDE9E3` | reply text, titles |
| Text secondary | `#9A968E` | helper lines, unselected chips |
| Text tertiary | `#6E6A62` | timestamps, counts |
| Success | `#34C759` | "email ready", sent confirmation |

The key move: surfaces are **neutral dark**, never brown. The current muddy tint comes from amber leaking into the fills — keep the neutrals truly neutral and the amber reads as a spotlight. Rule of thumb: if a second amber element wants to appear on a screen, demote it to neutral.

**Typography** (system / SF):

- Reply body — 17px regular, the largest text in the product; it's what people read.
- Button labels — 16px medium.
- Titles / contact name — 15px medium.
- Helper lines, chips — 13px regular.
- Counts, timestamps — 12px regular.

Sentence case everywhere. Capitalise contact names.

**Spacing**: 8-point grid. 16px panel margins. 12px between stacked controls. Let the reply card breathe — its inner padding should be generous; that space is not "wasted," it's legibility.

**Motion** (brief — for the separate animation work): state changes cross-fade at ~0.22s; the capture-bar tap glyph and loading dots loop gently; reply cards fade-and-rise in with a slight stagger. All motion respects Reduce Motion.

---

## 9. Build priority

If this ships in stages, this order delivers the most UX gain per step:

1. **Replace the idle Chat instruction card with the "Capture this chat" button** + auto-minimise. This is the single biggest win — it turns the hardest moment into one tap.
2. **Rework the capture bar** into the explicit, animated, cancellable instruction. Pairs with step 1.
3. **Redesign the replies screen** — wide "Insert reply" primary, contact capitalised, `1 of 3`, the tone row moved here.
4. **Apply colour discipline** — neutral surfaces, amber only on the one primary per screen, shrink the `Chat | Email` toggle.
5. **Give error its own state**; move tone out of idle into the compact chip.
6. **Polish** — skeleton loading, carousel affordance, motion.

Steps 1–3 alone would transform how the product feels.

---

*This spec is build-ready: it can be handed to a designer for high-fidelity mockups, fed into the UX Pilot prompts, or scoped directly for implementation. Every screen above is a real state in the keyboard's existing state machine — nothing here requires new architecture, only a redesign of the views.*
