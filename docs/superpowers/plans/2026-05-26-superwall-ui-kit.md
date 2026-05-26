# Superwall UI Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completely replace Replr's coral/ember design language with a pixel-accurate copy of Superwall's teal dark-navy aesthetic — new color tokens, redesigned buttons, badge component, and a standalone HTML design system demo.

**Architecture:** Central change is `ReplrTheme.swift` (all tokens) and `ReplrComponents.swift` (button/badge visual logic). One UIKit hardcoded color in `KeyboardViewController.swift` also needs updating. A standalone HTML file (`docs/design/replr-ui-kit.html`) demonstrates the full design system so the team can QA colors/components before building in Xcode.

**Tech Stack:** SwiftUI, UIKit (keyboard extension), standalone HTML/CSS (design demo)

---

## Color tokens being replaced

| Token | Old (coral) | New (teal) |
|---|---|---|
| `accent` dark | `#FF6B4A` | `#17EAD9` |
| `accent` light | `#EA4C2C` | `#00B4A0` |
| `onAccent` dark | white | `#0D1117` (dark text on bright teal) |
| `onAccent` light | white | white (unchanged) |
| `bg` dark | `#111827` | `#0D1117` |
| `surface` dark | `#1C2739` | `#131929` |
| `surfaceRaised` dark | `#243352` | `#1C2539` |
| UIKit bg (KeyboardVC) | `#111827` | `#0D1117` |

## Files

| File | Action |
|---|---|
| `docs/design/replr-ui-kit.html` | **Create** — standalone design system demo |
| `Shared/ReplrTheme.swift` | **Modify** lines 14–57 — new token values |
| `Shared/ReplrComponents.swift` | **Modify** PrimaryButtonStyle + SecondaryButtonStyle; **add** `Badge` component |
| `ReplrKeyboard/KeyboardViewController.swift` | **Modify** line 70 — UIKit bg hardcode |

---

### Task 1: HTML Design System Demo

**Files:**
- Create: `docs/design/replr-ui-kit.html`

- [ ] **Step 1: Create the file**

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Replr · UI Kit</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --bg:            #0D1117;
  --surface:       #131929;
  --raised:        #1C2539;
  --accent:        #17EAD9;
  --accent-dim:    rgba(23,234,217,.10);
  --accent-border: rgba(23,234,217,.30);
  --accent-glow:   rgba(23,234,217,.45);
  --text-1:        #FFFFFF;
  --text-2:        #8A96AA;
  --text-3:        #4D5A6F;
  --border:        rgba(255,255,255,.07);
  --border-glass:  rgba(255,255,255,.12);
  --radius-sm:     8px;
  --radius-md:     12px;
  --radius-lg:     16px;
  --radius-full:   999px;
}

body {
  font-family: -apple-system, "Inter", system-ui, sans-serif;
  background: var(--bg);
  color: var(--text-1);
  line-height: 1.5;
}

/* ── Nav ── */
.nav {
  display: flex; align-items: center; justify-content: space-between;
  padding: 16px 48px;
  border-bottom: 1px solid var(--border);
  position: sticky; top: 0; z-index: 10;
  background: rgba(13,17,23,.92);
  backdrop-filter: blur(12px);
}
.nav-logo { font-weight: 800; font-size: 18px; letter-spacing: -0.5px; }
.nav-logo span { color: var(--accent); }
.nav-links {
  background: var(--raised); border: 1px solid var(--border-glass);
  border-radius: var(--radius-full); padding: 6px 8px;
  display: flex; gap: 2px;
}
.nav-links a {
  font-size: 13px; color: var(--text-2); padding: 6px 14px;
  border-radius: var(--radius-full); cursor: pointer;
  text-decoration: none; white-space: nowrap;
  transition: background .12s, color .12s;
}
.nav-links a:hover { color: var(--text-1); background: rgba(255,255,255,.06); }

/* ── Buttons ── */
.btn-primary {
  background: var(--accent); color: var(--bg);
  font-size: 15px; font-weight: 700; letter-spacing: -0.2px;
  padding: 12px 24px; border-radius: var(--radius-full); border: none;
  cursor: pointer; display: inline-flex; align-items: center; gap: 6px;
  box-shadow: 0 4px 24px var(--accent-glow), 0 2px 8px rgba(0,0,0,.45);
  transition: transform .12s, box-shadow .12s, filter .12s;
}
.btn-primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 32px var(--accent-glow), 0 4px 12px rgba(0,0,0,.55);
  filter: brightness(1.06);
}
.btn-primary:active { transform: scale(.97); }

.btn-secondary {
  background: rgba(255,255,255,.04); color: var(--text-1);
  font-size: 15px; font-weight: 500;
  padding: 12px 24px; border-radius: var(--radius-full);
  border: 1px solid rgba(255,255,255,.16);
  cursor: pointer; display: inline-flex; align-items: center; gap: 6px;
  transition: background .12s;
}
.btn-secondary:hover { background: rgba(255,255,255,.09); }
.btn-secondary:active { transform: scale(.97); }

.btn-sm { padding: 8px 18px; font-size: 13px; }

/* ── Badge ── */
.badge {
  display: inline-flex; align-items: center; gap: 6px;
  background: var(--accent-dim); border: 1px solid var(--accent-border);
  color: var(--accent); border-radius: var(--radius-full);
  padding: 6px 14px; font-size: 12px; font-weight: 600;
}

/* ── Hero ── */
.hero {
  text-align: center; padding: 100px 48px 64px;
  position: relative; overflow: hidden;
}
.hero-orb {
  position: absolute; top: -80px; left: 50%; transform: translateX(-50%);
  width: 700px; height: 500px;
  background: radial-gradient(ellipse, rgba(23,234,217,.07) 0%, transparent 65%);
  pointer-events: none;
}
.hero h1 {
  font-size: clamp(40px, 5.5vw, 68px); font-weight: 800;
  line-height: 1.08; letter-spacing: -2px; margin-bottom: 22px;
}
.hero h1 .teal { color: var(--accent); }
.hero-sub {
  font-size: 18px; color: var(--text-2); max-width: 580px;
  margin: 0 auto 36px; line-height: 1.75;
}
.hero-btns { display: flex; gap: 12px; justify-content: center; align-items: center; }
.hero-glow {
  width: 480px; height: 1px; margin: 56px auto 0;
  background: linear-gradient(90deg, transparent, var(--accent) 50%, transparent);
  box-shadow: 0 0 24px var(--accent-glow), 0 0 48px rgba(23,234,217,.15);
}

/* ── Section ── */
.section { padding: 88px 48px; }
.section-header { text-align: center; margin-bottom: 56px; }
.section-header h2 {
  font-size: 40px; font-weight: 800; letter-spacing: -1.2px; margin-bottom: 14px;
}
.section-header p { font-size: 16px; color: var(--text-2); max-width: 480px; margin: 0 auto; line-height: 1.75; }

/* ── Feature Cards (2×2) ── */
.cards-grid {
  display: grid; grid-template-columns: 1fr 1fr;
  gap: 16px; max-width: 880px; margin: 0 auto;
}
.feature-card {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--radius-lg); padding: 48px 36px; text-align: center;
  transition: border-color .18s, box-shadow .18s;
}
.feature-card:hover {
  border-color: var(--border-glass);
  box-shadow: 0 4px 24px rgba(0,0,0,.3);
}
.icon-circle {
  width: 60px; height: 60px; border-radius: 50%;
  background: var(--accent-dim); border: 1px solid rgba(23,234,217,.22);
  display: flex; align-items: center; justify-content: center;
  margin: 0 auto 22px; font-size: 24px;
  box-shadow: 0 0 20px rgba(23,234,217,.18);
}
.feature-card h3 { font-size: 18px; font-weight: 700; margin-bottom: 12px; }
.feature-card p { font-size: 14px; color: var(--text-2); line-height: 1.75; }

/* ── Testimonials ── */
.testimonials-section {
  padding: 88px 48px;
  background: linear-gradient(180deg, var(--bg) 0%, #0F1422 60%, #0D1117 100%);
  position: relative; overflow: hidden;
}
.testimonials-section::after {
  content: '';
  position: absolute; right: -100px; top: 50%; transform: translateY(-50%);
  width: 500px; height: 500px;
  background: radial-gradient(ellipse, rgba(88,60,200,.12) 0%, transparent 65%);
  pointer-events: none;
}
.testimonials-header { margin-bottom: 48px; }
.testimonials-header h2 { font-size: 40px; font-weight: 800; letter-spacing: -1.2px; margin-bottom: 12px; }
.testimonials-header p { font-size: 16px; color: var(--text-2); }
.testimonial-cards { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
.testimonial-card {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--radius-lg); padding: 32px 28px;
  transition: border-color .18s;
}
.testimonial-card.active { border-color: rgba(23,234,217,.20); }
.testimonial-card blockquote {
  font-size: 16px; font-weight: 600; line-height: 1.65;
  margin-bottom: 28px; color: var(--text-1);
}
.testimonial-author { font-size: 14px; font-weight: 600; }
.testimonial-role { font-size: 12px; color: var(--text-2); margin-top: 3px; }

/* ── UI Kit Reference ── */
.kit-section { padding: 88px 48px; border-top: 1px solid var(--border); }
.kit-h { font-size: 13px; font-weight: 600; color: var(--text-3); text-transform: uppercase; letter-spacing: 1.2px; margin-bottom: 16px; }
.kit-block { margin-bottom: 48px; }
.kit-row { display: flex; gap: 12px; align-items: flex-start; flex-wrap: wrap; }
.kit-item { display: flex; flex-direction: column; gap: 8px; }
.kit-item label { font-size: 11px; color: var(--text-3); }

.swatch-grid { display: flex; gap: 8px; flex-wrap: wrap; }
.swatch {
  width: 64px; border-radius: var(--radius-md);
  border: 1px solid var(--border); overflow: hidden;
}
.swatch-color { height: 48px; }
.swatch-meta { padding: 6px; background: var(--surface); }
.swatch-name { font-size: 9px; font-weight: 600; color: var(--text-2); }
.swatch-hex { font-size: 9px; color: var(--text-3); }

/* chip */
.chip {
  display: inline-flex; align-items: center; padding: 7px 14px;
  border-radius: var(--radius-full); font-size: 13px; font-weight: 500;
  border: 1px solid var(--border-glass); background: var(--surface);
  color: var(--text-2); cursor: pointer; transition: all .12s;
}
.chip.selected {
  background: var(--accent); color: var(--bg); border-color: var(--accent);
  box-shadow: 0 0 12px var(--accent-glow);
}
</style>
</head>
<body>

<!-- NAV -->
<nav class="nav">
  <div class="nav-logo">repl<span>r</span> ✦</div>
  <div class="nav-links">
    <a href="#">History</a>
    <a href="#">Memory</a>
    <a href="#">Tones</a>
    <a href="#">Settings</a>
  </div>
  <button class="btn-primary btn-sm">Sign Up →</button>
</nav>

<!-- HERO -->
<section class="hero">
  <div class="hero-orb"></div>
  <h1>The reply is<br><span class="teal">already written.</span></h1>
  <p class="hero-sub">Triple-tap the back of your phone. Replr reads the chat, drafts the reply, you tap to send. Six steps to set up — most are one tap.</p>
  <div class="hero-btns">
    <button class="btn-primary">Set it up →</button>
    <button class="btn-secondary">I have an account →</button>
  </div>
  <div class="hero-glow"></div>
</section>

<!-- KEY CAPABILITIES -->
<section class="section">
  <div class="section-header">
    <h2>Key capabilities</h2>
    <p>AI that reads the full context and writes replies that actually sound like you.</p>
  </div>
  <div class="cards-grid">
    <div class="feature-card">
      <div class="icon-circle">🧠</div>
      <h3>Context-aware replies</h3>
      <p>Replr reads the full conversation before drafting — not just the last message.</p>
    </div>
    <div class="feature-card">
      <div class="icon-circle">🎨</div>
      <h3>Tone control</h3>
      <p>Switch between Friendly, Direct, Professional, or Witty in a single tap.</p>
    </div>
    <div class="feature-card">
      <div class="icon-circle">💾</div>
      <h3>Contact memory</h3>
      <p>Replr remembers each person you chat with and improves over time.</p>
    </div>
    <div class="feature-card">
      <div class="icon-circle">⚡</div>
      <h3>One gesture</h3>
      <p>Triple-tap the back of your iPhone. Replies appear instantly in the keyboard.</p>
    </div>
  </div>
</section>

<!-- TESTIMONIALS -->
<section class="testimonials-section">
  <div class="testimonials-header">
    <div class="badge" style="margin-bottom: 20px;">📣 Reviews</div>
    <h2>People love Replr</h2>
    <p>See how people are replying faster without losing their voice.</p>
  </div>
  <div class="testimonial-cards">
    <div class="testimonial-card">
      <blockquote>"Replr nails my tone every time. I stopped dreading long message threads."</blockquote>
      <div class="testimonial-author">Alex K.</div>
      <div class="testimonial-role">Founder, Indie Hacker</div>
    </div>
    <div class="testimonial-card active">
      <blockquote>"The memory feature is wild. It remembered I was annoyed at someone from 3 weeks ago."</blockquote>
      <div class="testimonial-author">Sara M.</div>
      <div class="testimonial-role">Product Designer</div>
    </div>
    <div class="testimonial-card">
      <blockquote>"I respond to DMs in seconds now. Game changer for staying on top of customer support."</blockquote>
      <div class="testimonial-author">James T.</div>
      <div class="testimonial-role">Startup Founder</div>
    </div>
  </div>
</section>

<!-- ── UI KIT REFERENCE ── -->
<section class="kit-section">
  <h2 style="font-size: 28px; font-weight: 800; letter-spacing: -0.5px; color: var(--text-2); margin-bottom: 56px;">— UI Kit Reference</h2>

  <!-- Colors -->
  <div class="kit-block">
    <div class="kit-h">Color Tokens</div>
    <div class="swatch-grid">
      <div class="swatch">
        <div class="swatch-color" style="background:#0D1117;"></div>
        <div class="swatch-meta"><div class="swatch-name">bg</div><div class="swatch-hex">#0D1117</div></div>
      </div>
      <div class="swatch">
        <div class="swatch-color" style="background:#131929;"></div>
        <div class="swatch-meta"><div class="swatch-name">surface</div><div class="swatch-hex">#131929</div></div>
      </div>
      <div class="swatch">
        <div class="swatch-color" style="background:#1C2539;"></div>
        <div class="swatch-meta"><div class="swatch-name">raised</div><div class="swatch-hex">#1C2539</div></div>
      </div>
      <div class="swatch">
        <div class="swatch-color" style="background:#17EAD9; box-shadow: 0 0 12px rgba(23,234,217,.5);"></div>
        <div class="swatch-meta"><div class="swatch-name">accent</div><div class="swatch-hex">#17EAD9</div></div>
      </div>
      <div class="swatch">
        <div class="swatch-color" style="background:rgba(23,234,217,.10); border-bottom: 1px solid rgba(23,234,217,.30);"></div>
        <div class="swatch-meta"><div class="swatch-name">accentDim</div><div class="swatch-hex">10% + 30%</div></div>
      </div>
      <div class="swatch">
        <div class="swatch-color" style="background:rgba(255,255,255,.07);"></div>
        <div class="swatch-meta"><div class="swatch-name">border</div><div class="swatch-hex">wht 7%</div></div>
      </div>
      <div class="swatch">
        <div class="swatch-color" style="background:rgba(255,255,255,.12);"></div>
        <div class="swatch-meta"><div class="swatch-name">glassBorder</div><div class="swatch-hex">wht 12%</div></div>
      </div>
      <div class="swatch">
        <div class="swatch-color" style="background:#8A96AA;"></div>
        <div class="swatch-meta"><div class="swatch-name">text-2</div><div class="swatch-hex">#8A96AA</div></div>
      </div>
    </div>
  </div>

  <!-- Buttons -->
  <div class="kit-block">
    <div class="kit-h">Buttons</div>
    <div class="kit-row">
      <div class="kit-item"><label>Primary CTA</label><button class="btn-primary">Insert reply →</button></div>
      <div class="kit-item"><label>Secondary</label><button class="btn-secondary">Talk to sales →</button></div>
      <div class="kit-item"><label>Nav Sign Up</label><button class="btn-primary btn-sm">Sign Up →</button></div>
      <div class="kit-item"><label>Disabled</label><button class="btn-primary" style="opacity:.38; pointer-events:none;">Disabled →</button></div>
    </div>
  </div>

  <!-- Badges -->
  <div class="kit-block">
    <div class="kit-h">Badges</div>
    <div class="kit-row">
      <span class="badge">📣 Testimonials</span>
      <span class="badge">✦ Overview</span>
      <span class="badge">⚡ Keyboard</span>
      <span class="badge">🧠 Memory</span>
    </div>
  </div>

  <!-- Chips (tone selector) -->
  <div class="kit-block">
    <div class="kit-h">Chips (Tone Selector)</div>
    <div class="kit-row">
      <span class="chip selected">Friendly</span>
      <span class="chip">Professional</span>
      <span class="chip">Direct</span>
      <span class="chip">Witty</span>
      <span class="chip">Casual</span>
    </div>
  </div>

  <!-- Feature Card single -->
  <div class="kit-block">
    <div class="kit-h">Feature Card</div>
    <div style="max-width:320px;">
      <div class="feature-card">
        <div class="icon-circle">⚡</div>
        <h3>One gesture</h3>
        <p>Triple-tap the back. Replies appear instantly in the keyboard below.</p>
      </div>
    </div>
  </div>

  <!-- Typography -->
  <div class="kit-block">
    <div class="kit-h">Typography Scale</div>
    <div style="padding:32px; background:var(--surface); border-radius:var(--radius-lg); border:1px solid var(--border); max-width:560px;">
      <div style="font-size:52px; font-weight:800; letter-spacing:-2px; line-height:1; margin-bottom:16px;">Display / 52 Bold</div>
      <div style="font-size:36px; font-weight:800; letter-spacing:-1px; line-height:1.1; margin-bottom:16px;">Title / 36 Bold</div>
      <div style="font-size:24px; font-weight:700; letter-spacing:-0.4px; margin-bottom:14px;">Heading / 24 Semibold</div>
      <div style="font-size:17px; font-weight:600; margin-bottom:12px;">Headline / 17 Semibold</div>
      <div style="font-size:15px; color:var(--text-2); margin-bottom:10px;">Body / 15 Regular</div>
      <div style="font-size:13px; color:var(--text-3); font-weight:500;">Caption · 13 Medium &nbsp;|&nbsp; <span style="letter-spacing:1.2px; text-transform:uppercase; font-size:11px;">OVERLINE / 11 SEMIBOLD</span></div>
    </div>
  </div>

  <!-- Icon Circle -->
  <div class="kit-block">
    <div class="kit-h">Icon Circle (Feature / App Icon)</div>
    <div class="kit-row">
      <div class="kit-item"><label>Small (40)</label>
        <div class="icon-circle" style="width:40px;height:40px;font-size:18px;margin:0;">🧠</div>
      </div>
      <div class="kit-item"><label>Default (60)</label>
        <div class="icon-circle" style="margin:0;">⚡</div>
      </div>
      <div class="kit-item"><label>Large (72)</label>
        <div class="icon-circle" style="width:72px;height:72px;font-size:30px;margin:0;">✦</div>
      </div>
    </div>
  </div>
</section>

</body>
</html>
```

- [ ] **Step 2: Open in browser and verify**

```bash
open docs/design/replr-ui-kit.html
```

Expected: Dark navy page with teal accent, hero section, feature cards, testimonials, component reference all visible.

- [ ] **Step 3: Commit**

```bash
git add docs/design/replr-ui-kit.html
git commit -m "feat: Superwall UI kit design system demo (HTML)"
```

---

### Task 2: ReplrTheme — Teal Palette

**Files:**
- Modify: `Shared/ReplrTheme.swift:14–57`

- [ ] **Step 1: Replace the bg/surface/accent color block**

Replace everything from `// Backgrounds` through `static let accentSoft` with:

```swift
    enum Color {
        // Backgrounds — dark: Superwall deep navy; light: native gray
        private static let _bg = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1) // #0D1117
                : .systemGray6
        }
        // Surface — dark: #131929, light: white card
        private static let _surface = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.075, green: 0.098, blue: 0.161, alpha: 1) // #131929
                : .systemBackground
        }
        static let bg              = SwiftUI.Color(_bg)
        static let surface         = SwiftUI.Color(_surface)
        static let surfaceRaised   = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.145, blue: 0.224, alpha: 1) // #1C2539
                : UIColor.tertiarySystemBackground
        })
        static let surfaceRaisedHi = SwiftUI.Color(UIColor.systemFill)
        static let surfaceSunken   = SwiftUI.Color(UIColor.secondarySystemFill)
        static let surfaceGlass    = SwiftUI.Color(_bg).opacity(0.72)

        // Borders / separators
        static let border          = SwiftUI.Color(UIColor.separator).opacity(0.5)
        static let borderStrong    = SwiftUI.Color(UIColor.separator)
        // Glass border: 1px white at 12%
        static let glassBorder     = SwiftUI.Color.white.opacity(0.12)

        // Text — iOS semantic labels
        static let textPrimary     = SwiftUI.Color.primary
        static let textSecondary   = SwiftUI.Color.secondary
        static let textTertiary    = SwiftUI.Color(UIColor.tertiaryLabel)

        // Accent — Superwall Teal, hardcoded so keyboard extension bundle gets it too
        private static let _accent = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.090, green: 0.918, blue: 0.851, alpha: 1) // #17EAD9
                : UIColor(red: 0.000, green: 0.706, blue: 0.627, alpha: 1) // #00B4A0
        }
        static let accent          = SwiftUI.Color(_accent)
        static let accentPressed   = SwiftUI.Color(_accent)
        // onAccent: dark navy in dark mode (text on bright teal), white in light mode
        static let onAccent        = SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1) // #0D1117
                : .white
        })
        static let accentSubtle    = SwiftUI.Color(_accent).opacity(0.12)
        static let accentSoft      = SwiftUI.Color(_accent).opacity(0.12)
```

- [ ] **Step 2: Verify the file compiles (no syntax errors)**

Open `Shared/ReplrTheme.swift` and check the block closes with matching braces up to line ~62.

- [ ] **Step 3: Commit**

```bash
git add Shared/ReplrTheme.swift
git commit -m "feat: accent coral → Superwall teal (#17EAD9), updated bg/surface/raised tokens"
```

---

### Task 3: KeyboardViewController UIKit Background

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift:68–73`

- [ ] **Step 1: Update hardcoded UIColor to new #0D1117**

Find:
```swift
        let adaptiveBg = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.067, green: 0.094, blue: 0.153, alpha: 1) // #111827 navy
```

Replace with:
```swift
        let adaptiveBg = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1) // #0D1117
```

- [ ] **Step 2: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "fix: KeyboardViewController UIKit bg → #0D1117 (matches new theme)"
```

---

### Task 4: ReplrComponents — Buttons & Badge

**Files:**
- Modify: `Shared/ReplrComponents.swift`

The changes needed:
1. `PrimaryButtonStyle` — remove specular highlight (it's a white gradient; on teal button the white-on-teal just looks washed, not glass). The teal is already bright enough. Keep glow + depth shadows.
2. `SecondaryButtonStyle` — change to transparent + white border (Superwall outlined style).
3. Add `Badge` component after `Chip`.

- [ ] **Step 1: Update PrimaryButtonStyle**

Find the existing `PrimaryButtonStyle` (lines ~37–67) and replace it:

```swift
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ReplrTheme.Font.headline)
            .foregroundColor(ReplrTheme.Color.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .fill(ReplrTheme.Color.accent.opacity(isEnabled ? 1 : 0.40))
                    .overlay(isEnabled ? ShimmerOverlay(cornerRadius: ReplrTheme.Radius.md) : nil)
            )
            // Accent bloom glow
            .shadow(color: ReplrTheme.Color.accent.opacity(isEnabled ? 0.55 : 0), radius: 24, x: 0, y: 8)
            // Depth shadow
            .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(ReplrTheme.Motion.quick, value: configuration.isPressed)
    }
}
```

- [ ] **Step 2: Update SecondaryButtonStyle to Superwall outlined style**

Find the existing `SecondaryButtonStyle` (lines ~69–100) and replace:

```swift
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ReplrTheme.Font.headline)
            .foregroundColor(ReplrTheme.Color.textPrimary.opacity(isEnabled ? 1 : 0.45))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.04 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                            .strokeBorder(Color.white.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ReplrTheme.Motion.quick, value: configuration.isPressed)
    }
}
```

- [ ] **Step 3: Add Badge component after the Chip component**

Find `// MARK: - SegmentedControl` and insert before it:

```swift
// MARK: - Badge

struct Badge: View {
    let systemImage: String?
    let label: String

    init(_ label: String, systemImage: String? = nil) {
        self.label = label
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(ReplrTheme.Color.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ReplrTheme.Color.accentSubtle)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(ReplrTheme.Color.accent.opacity(0.30), lineWidth: 1))
    }
}
```

- [ ] **Step 4: Update Chip accent border opacity for teal**

Find inside `Chip.body`:
```swift
                        : ReplrTheme.Color.glassBorder,
```

Keep as-is (glassBorder still works for unselected chips). The selected state uses `accent.opacity(0.5)` as border — update that to match teal more closely:

Find:
```swift
                            isSelected
                                ? ReplrTheme.Color.accent.opacity(0.4)
                                : ReplrTheme.Color.glassBorder,
```

Replace with:
```swift
                            isSelected
                                ? ReplrTheme.Color.accent.opacity(0.50)
                                : ReplrTheme.Color.glassBorder,
```

- [ ] **Step 5: Commit**

```bash
git add Shared/ReplrComponents.swift
git commit -m "feat: Superwall components — outlined secondary button, Badge component, teal chip border"
```

---

### Task 5: Use Badge in Onboarding + Keyboard (replace section overline labels)

**Files:**
- Modify: `Replr/Replr/Features/Onboarding/OnboardingView.swift` (section labels)
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift` (HOW TO CAPTURE overline)

The Superwall screenshots show section labels as `Badge` components, not plain uppercase text. Replace the two most visible ones.

- [ ] **Step 1: In OnboardingView, each step already has `sectionLabel` displayed as overline text**

In `OnboardingStep.body`, find:
```swift
                Text(sectionLabel)
                    .font(ReplrTheme.Font.overline)
                    .tracking(1.5)
                    .foregroundColor(ReplrTheme.Color.accent)
```

Replace with:
```swift
                Badge(sectionLabel)
```

- [ ] **Step 2: In IdlePanelView, replace "HOW TO CAPTURE" overline with Badge**

Find:
```swift
                    Text("HOW TO CAPTURE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .tracking(0.8)
```

Replace with:
```swift
                    Badge("Capture", systemImage: "scope")
```

- [ ] **Step 3: Commit**

```bash
git add Replr/Replr/Features/Onboarding/OnboardingView.swift ReplrKeyboard/Views/IdlePanelView.swift
git commit -m "feat: replace overline labels with Superwall Badge component"
```

---

## Self-Review

**Spec coverage:**
- ✅ Exact copy of Superwall box colors — Tasks 2 + 3
- ✅ Exact copy of buttons (primary teal pill + dark text + glow; secondary outlined) — Task 4
- ✅ Badges ("Testimonials", "Overview" style pill labels) — Task 4 step 3 + Task 5
- ✅ Feature cards (dark surface + subtle border + icon circle + centered text) — shown in HTML, existing `Card` + `IconTile` components cover iOS
- ✅ Design demo file to "demonstrate" — Task 1
- ✅ "Forget about the ember" (coral removed) — Task 2

**Placeholder scan:** All steps have complete code. No TODOs.

**Type consistency:** `Badge(_ label: String, systemImage: String? = nil)` — matches usage in Task 5.
