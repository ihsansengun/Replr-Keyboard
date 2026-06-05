# Relationship dynamic (per contact) — PARKED

**Status:** 🅿️ PARKED — feature wanted, but the **keyboard UX is undecided**. User wants to think about it. Do NOT implement until the UX is settled.

## The idea
Let the user tell Replr the **relationship** with the person they're chatting with, to steer the reply dynamic:
`family · friends · flirt · none (default)`. Complements the shipped gender/About-Me work (this is about the *recipient relationship*, not gender).

## What's decided
- **Model:** selected **per-reply, in the keyboard, before generating** (so it's known pre-generation — no contact-detection timing issue). *(Per-contact "set once, remembered" was considered but lags by a reply because Replr only learns who a chat is with AFTER generation.)*
- **Default:** `none` (no steering / current behavior).
- **Backend:** would add an optional `relationship` request field (like `aboutUser`) and inject a short line into the prompt; `none` ⇒ inject nothing. (Cheap, additive, backward-compatible — same shape as the About-Me feature.)

## The open problem — keyboard UX
The keyboard is fixed-height and already has the tone-chips row. The user **does not want chips everywhere**. Three mocked placements were **rejected**:
- A · header menu pill · B · relationship icons + tones in one row · C · dedicated relationship row.
(Mockups: `.superpowers/brainstorm/1393-1780692642/content/relationship-placement.html`.)

## Leading directions to revisit
1. **Dropdown near the "Start" button** (user's idea) — a compact, optional relationship dropdown in the empty area beside Start, instead of chips. Avoids chip clutter; keeps it per-reply.
2. **Relationship drives the tone options** — pick relationship first → the tone chips become context-appropriate (Flirt → Playful/Smooth/Bold; Family → Warm/Caring). Merges the two selectors instead of adding one.
3. **Companion contact settings** — set relationship per-contact in the app's contact memory/detail screen (default none). Lowest keyboard footprint, but per-contact (timing lag) + more friction.

## Next step when revisited
Resume brainstorming from the UX question (placement), then spec → plan. The backend + data shape is straightforward; the keyboard placement is the only real open question.
