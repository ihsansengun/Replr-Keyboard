# Replr — UX Pilot AI prompts (Nightshift direction)

How to use: paste the **Design system** block into UX Pilot's design-system / style field (or prepend it to any screen prompt). Then paste one **screen prompt** at a time. Each screen prompt is self-contained — it restates the essentials so it works even without the design-system block. Generate keyboard states first; they're the core product.

---

## Design system — paste this first

Design system for "Replr — Nightshift". Replr is an iOS app that suggests AI-written replies from chat screenshots; it lives mostly inside a custom keyboard. Mood: discreet, premium, warm-dark — a precision tool. Calm and confident, never loud.

Theme: dark throughout.

Colors: app background #0F0F12 (near-black, faintly warm); raised surfaces and cards #1B1B20; elevated elements and hairline borders #2A2A31; primary accent honey-amber #F2A93C, used sparingly for selection, the single primary action, and the brand mark; accent-soft = #F2A93C at 16% opacity for tints and badges; primary text #EDE9E3 (warm off-white); secondary text #9A968E; tertiary text #6E6A62; success green #34C759; destructive red #FF453A.

Typography: SF Pro / system sans. Screen titles 24–28px semibold. Section headers 16px medium. Body 16px regular. Captions 12–13px. The wordmark is "replr" set lowercase in a geometric, slightly warm sans.

Shape: capsule/pill for chips, tone selectors and reply suggestions; 14px corner radius for cards and buttons; 22px radius for hero surfaces. Borders are 0.5px hairlines in #2A2A31.

Spacing: 8-point grid, 16px screen margins, generous breathing room.

Icons: thin-line SF Symbols style, ~1.5px stroke.

Surfaces stay flat — no gradients, no heavy shadows. Depth comes only from the background → raised → elevated color ramp.

---

## Keyboard states

The keyboard is an iOS custom keyboard extension — a fixed panel docked at the bottom of the screen, roughly 300px tall, shown inside a third-party messaging app. Always render it docked at the bottom of an iPhone frame with a generic chat thread visible above it.

### KB-1 — Idle

Design the Replr keyboard in its idle state, docked at the bottom of an iPhone inside a messaging app, Nightshift dark style. Top: a slim 44px action bar — a small honey-amber "replr" wordmark on the left, and a centered primary pill button labelled "Capture conversation" with a small viewfinder icon. Below the bar: a full QWERTY keyboard in dark theme — keys #1B1B20 with #EDE9E3 labels, keyboard background #0F0F12, modifier keys (shift, delete, globe, return) slightly darker, the return key tinted honey-amber. Flat keys, 0.5px hairline separators #2A2A31. The keyboard should feel recessive and calm — like it belongs inside someone else's app.

### KB-2 — Loading

Design the Replr keyboard in its loading state, Nightshift dark style. The action bar at top now reads "Generating replies…" in #9A968E with three small honey-amber animated dots. The area below shows three skeleton reply cards stacked or in a row — rounded 14px rectangles in #1B1B20 with a soft shimmer placeholder, no text. Background #0F0F12. Quiet, patient, no spinner clutter.

### KB-3 — Reply suggestions (hero screen)

Design the Replr keyboard showing AI reply suggestions, Nightshift dark style — this is the most important screen. Top: a contact chip showing the detected person's name "Maya" with a small edit-pencil icon. Middle: a horizontally swipeable carousel of three reply suggestion cards — each card #1B1B20, 14px radius, reply text in #EDE9E3 at ~15px, a small honey send-arrow at the bottom-right corner; page dots below the carousel with the active dot in honey-amber. Bottom: a tone selector — a horizontal row of capsule pills (Friendly, Flirty, Professional, Funny, Short) where the selected pill is filled honey-amber #F2A93C with dark #3A2401 text and the rest are outlined in #2A2A31 with #9A968E text; a small circular "regenerate" icon button at the right end. Background #0F0F12, everything flat.

### KB-4 — Edit reply

Design the Replr keyboard editing a reply, Nightshift dark style. One reply suggestion is expanded into an editable text field — a sunken input well #0A0A0C, 14px radius, the editable text in #EDE9E3 with a honey-amber text caret. Below the field: two buttons side by side — "Cancel" outlined in #2A2A31, and "Use reply" filled honey-amber with dark text. A compact QWERTY keyboard in dark theme below. Background #0F0F12.

### KB-5 — Error

Design the Replr keyboard in an error state, Nightshift dark style. Centered in the panel: a thin-line alert icon in honey-amber, a short message "Couldn't generate replies" in #EDE9E3, a one-line hint "Check your connection and try again" in #9A968E, and a "Try again" pill button outlined in honey-amber. Background #0F0F12, calm and non-alarming.

---

## Onboarding flow

Design a 5-step onboarding flow for the Replr iOS app, Nightshift dark style — five iPhone screens. Each screen: background #0F0F12; a step indicator near the top (five dots, the current one honey-amber); a 56px thin-line icon in honey-amber in the upper third; a 24px semibold title in #EDE9E3; a 16px description in #9A968E, centered; where setup steps are needed, a numbered instruction list inside a #1B1B20 card with 14px radius and small honey-amber numbered circles; and a full-width primary button at the bottom filled honey-amber with dark text. The five screens are:

1. "Enable the Replr keyboard" — icon of a keyboard; instructions to add Replr in Settings → Keyboards.
2. "Allow Full Access" — icon of a shield/lock; explains Full Access is needed to generate replies, with a reassuring privacy line.
3. "Allow photo access" — icon of stacked photos; explains Replr reads chat screenshots to suggest replies.
4. "Set up the Back Tap shortcut" — icon of a phone with a tap ripple; numbered steps to bind a triple Back Tap to the Replr shortcut.
5. "You're all set" — large honey-amber checkmark; a short confident closing line and a "Start using Replr" button.

---

## Companion app

The companion app is dark Nightshift, with a bottom tab bar of four tabs (Captures, Memory, Tones, Settings) — the active tab icon and label in honey-amber, inactive in #6E6A62.

### APP-1 — Captures

Design the Captures screen of the Replr iOS app, Nightshift dark style. Large title "Captures" in #EDE9E3. Below it, a horizontally scrolling row of contact filter chips — capsule pills, the selected one filled honey-amber. Then a vertical list of capture rows: each row has a tall screenshot thumbnail on the left (about 46×64px, 9px radius), the contact name in honey-amber 12px semibold with a tertiary timestamp, a 2–3 line conversation summary in #EDE9E3, and — when a reply was sent — a small green checkmark with a snippet of the sent reply. Rows separated by 0.5px #2A2A31 hairlines. Also show the empty state: a centered thin-line camera icon, "No captures yet" and a one-line hint. Bottom tab bar with Captures active.

### APP-2 — Memory

Design the Memory screen of the Replr iOS app, Nightshift dark style. Large title "Memory". A vertical list of contact memory rows: each row has a 48px circular avatar (a photo, or a honey-tinted gradient circle with the contact's initial), the contact name as a headline in #EDE9E3, a small honey-amber capsule badge showing the number of past conversations, and a one-to-two line snippet of the last summary in #9A968E. Show the empty state too: a centered thin-line spark/brain icon with "No memories yet". Bottom tab bar with Memory active.

### APP-3 — Tones

Design the Tones screen of the Replr iOS app, Nightshift dark style. Large title "Tones". Two grouped sections — "Presets" and "Custom". Each tone row has a 3px-wide vertical honey-amber bar on its left edge (full opacity for presets, dimmed for custom tones), the tone name as a headline in #EDE9E3, and the tone's instruction as a caption in #9A968E. A "+" button in the navigation bar to add a custom tone. Preset rows like Friendly, Flirty, Professional, Funny, Short. Bottom tab bar with Tones active.

### APP-4 — Settings

Design the Settings screen of the Replr iOS app, Nightshift dark style. At the top, a brand header card #1B1B20, 14px radius: a 56px rounded-square honey-amber tile holding a reply-arrow glyph, next to it "replr" as the wordmark and a tagline "Know what to say" in #9A968E. Below, grouped setting rows in #1B1B20 cards: an AI model selector (Claude / GPT-4o), a "Keep replies between sessions" toggle with a honey-amber switch, a memory time-window picker, a memory depth picker, an "Account" row that links to subscription with a chevron, and an app version row. Section footers in #6E6A62. Bottom tab bar with Settings active.

### APP-5 — Subscription

Design the Subscription screen of the Replr iOS app, Nightshift dark style. A hero card at the top with 22px radius, subtly honey-tinted: a "Replr Premium" heading, and a feature list each with a honey-amber checkmark — "5 reply suggestions instead of 3", "Scroll capture for long conversations", "No daily limit". Below the hero: the price and billing period, then a full-width "Subscribe" button filled honey-amber with dark text, and a small "Restore purchases" text link. Also show the active state: the hero replaced by a "Premium active" panel with a green checkmark-seal.

---

## App icon and brand

### ICON — App icon

Design an iOS app icon for Replr, Nightshift style. Background a warm near-black, #0F0F12 deepening slightly toward #1B1B20 at the edges. Centered mark in honey-amber #F2A93C — try two concepts: (1) a text cursor / caret that doubles as a reply arrow, suggesting "helps you finish the thought"; (2) a speech bubble shown being completed — a solid bubble emerging from an outlined one. Flat, bold, geometric, no literal photo or gradient sheen. Must read clearly at small sizes.

### LOGO — Logo and brand sheet

Design a brand sheet for Replr, Nightshift style, on a #0F0F12 background. Include: the wordmark "replr" set lowercase in a geometric, slightly warm sans in honey-amber #F2A93C and a second version in off-white #EDE9E3; the standalone mark (the caret-as-reply-arrow); a row of palette swatches (#0F0F12, #1B1B20, #2A2A31, #F2A93C, #EDE9E3) with hex labels; and the app icon. Keep it minimal and confident.

---

Notes: every prompt assumes the dark Nightshift palette. If you later want to test the warm-light "Open Line" variant for the companion app only, swap the app screen backgrounds to cream #FBF6EF, surfaces to #FFFFFF, text to ink-brown #2A2521, and the accent to coral #FB6F5C — the keyboard prompts stay dark either way.
