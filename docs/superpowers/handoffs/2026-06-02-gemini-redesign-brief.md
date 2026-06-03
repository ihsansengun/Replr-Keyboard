# Gemini Redesign Brief — Replr

**Use this prompt when feeding the current screenshots + asking Gemini (or any AI design tool) to generate the v2 UI for Replr.**

Paste the screenshots from `docs/design/screenshots/IMG_8535.PNG`–`IMG_8565.PNG` alongside the prompt below.

---

REDESIGN BRIEF

This is a redesign of Replr — an iOS app that already exists in production. The attached screenshots show the current state. Your job is to rethink the visual language and component design from the ground up, while preserving the underlying product mechanics and information architecture.

Do not mimic the existing UI. Use the screenshots only to understand what each screen does, what components exist, and how navigation flows. The new design should feel like a different generation of the product — what Replr v2 would look like in the hands of a top-tier design studio.

PRODUCT (unchanged — for context)

Replr ships as two parts:
1. A companion app (full screen, normal iOS app)
2. A custom iOS keyboard extension (~280–320px tall, constrained)

The user flow: in any chat app (iMessage, WhatsApp, Instagram, Telegram, etc.), the user triple-taps the back of their iPhone. This screenshots the current conversation and sends it to an AI backend (Claude / GPT). The AI reads the chat, identifies the contact, and generates 3 reply suggestions written in the user's chosen "tone" (Friendly, Witty, Direct, Professional, Casual). The Replr keyboard then shows those 3 suggestions as tappable cards. User taps one → it inserts into the chat's text field → they send.

SCREENS NEEDED (all to be redesigned)

Companion app:
- Onboarding (multi-step setup walking the user through: adding the Replr keyboard, enabling Full Access, installing a Shortcuts shortcut, configuring Back Tap)
- Replies / History — list of past capture sessions with thumbnails, contact name, timestamp, the generated replies, and which one was sent
- Memory — list of contacts Replr has talked to, with editable conversation summaries that give the AI continuity across sessions
- Settings — tone management, AI model picker, memory toggle, subscription / credits, privacy, terms
- Credits / Paywall — current balance, 4 in-app purchase packs ($0.99 / $2.49 / $4.99 / $11.99), restore purchases
- Capture detail — screenshot + summary + the 3 generated replies, opened from history

Keyboard extension (within iOS keyboard size constraints):
- Idle state — tone selector + Chat/Email mode toggle + instructions
- Loading — animated indicator while the AI generates
- Replies — 3 reply cards, tappable to insert; contact name chip; regenerate option
- Error — message + retry
- Collapsed strip — 44px-tall version that appears during capture so the chat behind the keyboard stays visible
- Contact disambiguation — when the AI detects an ambiguous name, lets the user pick the correct contact
- Paywall card — shown when out of credits, with CTA to open the companion app

DESIGN DIRECTION

Target: the kind of UI Apple chooses to feature. Reference quality of apps like Things 3, Bear, Mela, Linea Sketch, Mona, Reeder, Day One. Premium, considered, calm. Not flashy, not "AI-themed," not gimmicky.

THE ONBOARDING CHALLENGE — SOLVE THIS PROPERLY

The hardest part of Replr's onboarding is wiring up the trigger. The user must navigate iOS Settings → Accessibility → Touch → Back Tap → Triple Tap → Shortcuts → Replr Capture. That is six levels deep into a system menu the user has likely never opened. This has been the single point where every previous onboarding attempt has fallen apart.

Hard platform constraints you must respect:
- Apple does NOT allow third-party apps to deep-link past the top-level Settings screen. We can only open the Settings app at its root, then the user must navigate the rest by hand.
- We cannot script the iOS Settings UI, simulate taps, or read where the user is in Settings.
- We can detect after-the-fact that they succeeded (we know when Back Tap fires for the first time).

Your job: design an onboarding experience that turns this six-level Settings dive from a chore into something the user feels confident about completing. The Back Tap setup screen specifically must feel like a high point of the product, not the dropout cliff. Brainstorm aggressively. Possible directions include (but should not be limited to):

- A looping, premium screen-recorded animation that shows the exact path through Settings, played silently in the card itself
- A custom-illustrated step-by-step walkthrough where each Settings screen is recreated as a stylized Replr-branded diagram
- A "we'll be waiting" return state — a softly animated screen that greets the user when they come back from Settings and instantly confirms success
- A persistent guide layer that pre-loads visual aides the moment the user taps the Settings CTA, so the moment they arrive in Settings they remember where to go
- A first-time celebration moment when Back Tap fires successfully — a small, exquisitely-crafted confirmation that makes the user feel they accomplished something
- Progressive disclosure — never show all six steps at once. Reveal each step only when the previous is complete
- A voice / narrated walkthrough option for users who prefer guidance over reading

The bar is not "users figure it out eventually." The bar is "users complete this on the first try, feel competent doing it, and remember it as the best setup flow they've ever used in an app."

Whatever solution you propose for the Back Tap setup, it must:
- Feel as premium as the rest of the product. No "help article" tone, no cluttered diagrams, no apologetic copy.
- Use the custom component language you've established elsewhere in the design.
- Be testable. We can detect success the moment Back Tap fires. Use that signal to advance and reward the user.
- Survive the case where the user leaves the app and returns — the flow must pick up exactly where they left off, never reset.

Treat the onboarding as the single most important deliverable in this brief alongside the reply-selection moment. If the onboarding is mediocre, nothing else matters.

CUSTOM ICONS AND COMPONENTS (CRITICAL — this is what makes the redesign feel premium and ownable)

- Design a unique, original icon set for Replr. Do not use SF Symbols as the visual identity. The icon set should feel like a custom-drawn family — consistent line weight, consistent corner radii, consistent visual rhythm. Cohesive enough that any single icon clearly belongs to the system.
- Define a small library of unique UI components that are Replr's own — not standard iOS list rows, not stock card patterns. The tone selector, the reply card, the contact memory cell, the capture session row, the credit pack card, the setup checklist — each should have a distinctive, considered shape that the user comes to associate with Replr.
- These custom components should still respect iOS interaction conventions (you can tap, swipe, scroll them in expected ways). What's custom is the *form*, not the *behavior*.
- A small, deliberate visual signature should run through the product — could be a particular shape, a particular accent treatment, a particular way of pairing two type sizes. Pick one and use it everywhere with discipline.

OVERALL DESIGN PRINCIPLES

- Editorial typography — generous line height, clear hierarchy, magazine-grade restraint. SF Pro family throughout for legibility, but typography itself should feel composed, not default.
- Generous whitespace — content breathes. No information density for its own sake.
- Restrained color — one accent color used sparingly, otherwise neutrals. Use system materials (UIBlurEffect / ultraThinMaterial) where depth is needed.
- Considered motion — subtle, intentional. Spring animations for state changes, never gratuitous. Every animation has a job.
- Tactile interactions — buttons that feel pressed, cards that respond, transitions that flow.
- Both light and dark mode — both must feel deliberate, not afterthought. Dark mode should not just invert; it should be its own composition.
- Empty states designed as carefully as populated ones. Loading states feel purposeful, not impatient.
- One job per screen, done beautifully. No screen tries to do two things.

EXPLICITLY AVOID

- Anything that signals "AI app" — purple/blue gradients, sparkle emojis ✨, glowing borders, neural-network motifs, "magic wand" iconography, robot avatars, holographic shimmer, "GPT" language, raw chat-bubble metaphors
- Generic AI startup aesthetic — gradient hero text, sparkle accents on every button, blurry orb backgrounds
- Excessive shadows, neumorphism, glassy 3D buttons
- Cluttered tone pickers, busy toolbars, decorative chrome
- Stock-template look — rounded card on rounded card on rounded card
- Loud color combinations or saturated palettes
- Marketing-speak in microcopy. Use plain, confident language.
- Off-the-shelf SF Symbols treated as the icon language. Use custom drawings.
- Onboarding screens that look like help articles, FAQs, or "please follow these steps" instructions. The setup must feel like the product itself, not documentation.

CONSTRAINTS

- iOS only, modern iPhone screen sizes (iPhone 15 / 16 family)
- Keyboard extension cannot exceed iOS size limits (280–320px tall typical, 44px collapsed)
- The companion app uses a bottom tab bar (Replies / Memory / Settings)
- The reply-selection moment — when the user sees 3 suggestions and picks one — is the single most important interaction in the entire product. It should feel fast, effortless, and quietly impressive.
- The Back Tap onboarding moment is the second most important. Solve it.

DELIVERABLES

For each screen above:
- Empty, loading, populated, and error states where applicable
- Both light and dark color schemes
- Annotated callouts for the custom components and where they're used
- The full custom icon set on a single sheet (showing every icon used across the product)
- Notes on the visual signature you chose and how it threads through the product

For the Back Tap onboarding moment specifically:
- A step-by-step storyboard of every state the user passes through, including the "user has left the app" state and the "user has returned" state
- The exact piece of motion or visual aide that carries them through the six-level Settings dive
- The success moment when Back Tap fires for the first time

Prioritize, in order: (1) the Back Tap onboarding moment, (2) the reply-selection moment in the keyboard, (3) the custom icon set, (4) the overall cohesion between companion app and keyboard. The product should look like something a senior Apple designer would be proud to ship — and like nothing else on the App Store.
