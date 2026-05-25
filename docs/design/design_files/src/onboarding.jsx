// Replr v2 onboarding — six steps, modern & functional.
//
// Real product reality: the keyboard can't screenshot its host app, so
// capture relies on an iOS Shortcut wired to Back Tap (triple-tap). The
// onboarding's job is to set that up without ever feeling like a checklist.
//
// Visual rules: 24px horizontal padding, 32px between sections, 8px grid
// everywhere else. One coral spotlight per screen.

function OnbShell({ stepNum, total = 6, eyebrow, title, lede, children, primaryLabel = 'Continue', primaryIcon, secondary }) {
  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      background: R.base, color: R.t1, fontFamily: R.font,
    }}>
      {/* Header: progress dots + step counter */}
      <div style={{ padding: `64px ${R.s5}px 0` }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Mark size={14} />
          <Mono color={R.t3}>
            {stepNum != null ? `${String(stepNum).padStart(2, '0')} / ${String(total).padStart(2, '0')}` : 'Welcome'}
          </Mono>
        </div>
        {stepNum != null && (
          <div style={{ display: 'flex', gap: 4, marginTop: 20 }}>
            {Array.from({ length: total }, (_, i) => (
              <div key={i} style={{
                flex: 1, height: 2, borderRadius: 2,
                background: i < stepNum ? R.accent : i === stepNum - 1 ? R.t1 : R.raised,
              }} />
            ))}
          </div>
        )}
      </div>

      {/* Body */}
      <div style={{ flex: 1, padding: `40px ${R.s5}px 0`, display: 'flex', flexDirection: 'column' }}>
        {eyebrow && <Label color={R.accent} style={{ marginBottom: 12, fontSize: 12 }}>{eyebrow}</Label>}
        {title && (
          <h1 style={{
            fontFamily: R.font, fontSize: 34, fontWeight: 600,
            letterSpacing: '-0.028em', lineHeight: 1.05,
            color: R.t1, margin: 0,
          }}>{title}</h1>
        )}
        {lede && (
          <p style={{
            fontFamily: R.font, fontSize: 15, fontWeight: 400,
            color: R.t2, letterSpacing: '-0.005em',
            lineHeight: 1.5, marginTop: 16, marginBottom: 0,
            textWrap: 'pretty',
          }}>{lede}</p>
        )}
        <div style={{ flex: 1, marginTop: 32, display: 'flex', flexDirection: 'column' }}>
          {children}
        </div>
      </div>

      {/* Footer actions */}
      <div style={{ padding: `0 ${R.s5}px 40px`, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <Primary leading={primaryIcon}>{primaryLabel}</Primary>
        {secondary && (
          <button style={{
            appearance: 'none', border: 'none', cursor: 'pointer',
            background: 'transparent',
            padding: '14px', textAlign: 'center',
            fontFamily: R.font, fontSize: 13, fontWeight: 500,
            color: R.t2, letterSpacing: '-0.005em',
          }}>{secondary}</button>
        )}
      </div>
    </div>
  );
}

// — A reusable iOS-path crumb diagram (used on steps that defer to Settings) —
function PathCrumb({ path, active }) {
  return (
    <div style={{
      padding: '14px 16px',
      background: R.surface,
      border: `1px solid ${R.border}`,
      borderRadius: R.rsm,
      display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap',
    }}>
      {path.map((p, i) => (
        <React.Fragment key={i}>
          {i > 0 && <Icon.chev style={{ color: R.t4 }} />}
          <span style={{
            fontFamily: R.font, fontSize: 13.5,
            fontWeight: p === active ? 600 : 400,
            color: p === active ? R.accent : R.t2,
            letterSpacing: '-0.005em',
          }}>{p}</span>
        </React.Fragment>
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 00 · Welcome
// ─────────────────────────────────────────────────────────────
function OnbWelcome() {
  return (
    <OnbShell primaryLabel="Set it up" primaryIcon={<Icon.arrow />} secondary="I have an account">
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', gap: 28 }}>
        <Mark size={52} />
        <h1 style={{
          fontFamily: R.font, fontSize: 40, fontWeight: 600,
          letterSpacing: '-0.03em', lineHeight: 1.02,
          color: R.t1, margin: 0,
        }}>
          The reply is<br/>
          <span style={{ color: R.t3 }}>already written.</span>
        </h1>
        <p style={{
          fontFamily: R.font, fontSize: 15, color: R.t2, margin: 0,
          letterSpacing: '-0.005em', lineHeight: 1.5, textWrap: 'pretty',
          maxWidth: 280,
        }}>
          Triple-tap the back of your phone. Replr reads the chat, drafts the reply, you tap to send. Six steps to set up — most are one tap.
        </p>
        <div style={{
          display: 'flex', gap: 16, paddingTop: 8,
          fontFamily: R.font, fontSize: 12, color: R.t3, letterSpacing: '-0.005em',
        }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Icon.shield style={{ color: R.t3 }} /> On-device capture
          </span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Icon.spark style={{ color: R.t3 }} /> 90 seconds
          </span>
        </div>
      </div>
    </OnbShell>
  );
}

// ─────────────────────────────────────────────────────────────
// 01 · Add the keyboard
// ─────────────────────────────────────────────────────────────
function OnbStep1() {
  return (
    <OnbShell
      stepNum={1}
      eyebrow="Keyboard"
      title="Add Replr to iOS."
      lede="The keyboard is where the replies show up. iOS will ask you to add it from Settings."
      primaryLabel="Open Keyboard Settings"
      primaryIcon={<Icon.arrow />}
      secondary="Already added"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <Label color={R.t3}>You'll tap, in order</Label>
        <PathCrumb
          path={['Settings', 'General', 'Keyboard', 'Keyboards', 'Add New', 'Replr']}
          active="Replr"
        />
        <div style={{
          padding: '12px 14px',
          background: R.surface, border: `1px solid ${R.border}`,
          borderRadius: R.rsm,
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{
            width: 36, height: 36, background: R.raised, borderRadius: 8,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Mark size={14} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: R.font, fontSize: 14, fontWeight: 500, color: R.t1, letterSpacing: '-0.005em' }}>
              Replr
            </div>
            <Mono style={{ marginTop: 2 }}>English (US)</Mono>
          </div>
          <Icon.check style={{ color: R.success }} />
        </div>
      </div>
    </OnbShell>
  );
}

// ─────────────────────────────────────────────────────────────
// 02 · Allow full access
// ─────────────────────────────────────────────────────────────
function OnbStep2() {
  return (
    <OnbShell
      stepNum={2}
      eyebrow="Permissions"
      title="Allow full access."
      lede="Replr needs this to read the screenshot the Shortcut hands it, and to write the reply into your text field."
      primaryLabel="Allow"
      secondary="What this means"
    >
      <div style={{
        background: R.surface, border: `1px solid ${R.border}`,
        borderRadius: R.rsm, padding: '4px 16px',
      }}>
        {[
          { i: <Icon.shield />, t: 'On-device first', d: 'The base model runs locally. Cloud only kicks in for long emails.' },
          { i: <Icon.clip />, t: 'No clipboard sniffing', d: 'We only read the clipboard when you tap Generate.' },
          { i: <Icon.spark />, t: 'Screenshots deleted', d: 'Each capture is processed in a sandbox and gone in 30s.' },
        ].map((r, i, a) => (
          <div key={i} style={{
            display: 'flex', gap: 12, padding: '14px 0',
            borderBottom: i < a.length - 1 ? `1px solid ${R.border}` : 'none',
          }}>
            <div style={{
              width: 28, height: 28, borderRadius: 6, background: R.raised,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: R.t1, flexShrink: 0,
            }}>{r.i}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: R.font, fontSize: 14, fontWeight: 500, color: R.t1, letterSpacing: '-0.005em' }}>{r.t}</div>
              <div style={{ fontFamily: R.font, fontSize: 12.5, color: R.t3, letterSpacing: '-0.005em', lineHeight: 1.4, marginTop: 2 }}>{r.d}</div>
            </div>
          </div>
        ))}
      </div>
    </OnbShell>
  );
}

// ─────────────────────────────────────────────────────────────
// 03 · Photo permission
// ─────────────────────────────────────────────────────────────
function OnbStep3() {
  return (
    <OnbShell
      stepNum={3}
      eyebrow="Photos"
      title="Latest photo only."
      lede="The Shortcut takes a screenshot of the chat and hands the latest photo to Replr. Choose 'Latest Photo Only' when iOS asks."
      primaryLabel="Continue"
      secondary="Show me the technical detail"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{
          padding: 20,
          background: R.surface, border: `1px solid ${R.border}`,
          borderRadius: R.rsm,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 16 }}>
            <div style={{
              width: 44, height: 44, borderRadius: 8, overflow: 'hidden', position: 'relative',
              background: 'linear-gradient(135deg, #FF5A4D 0%, #F5C24E 40%, #4ADE80 100%)',
              flexShrink: 0,
            }}>
              <div style={{ position: 'absolute', top: 6, right: 6, width: 8, height: 8, borderRadius: 4, background: 'rgba(255,255,255,0.8)' }} />
            </div>
            <div>
              <div style={{ fontFamily: R.font, fontSize: 13.5, fontWeight: 500, color: R.t1, letterSpacing: '-0.005em' }}>
                "Replr" would like access to
              </div>
              <div style={{ fontFamily: R.font, fontSize: 13.5, fontWeight: 500, color: R.t1, letterSpacing: '-0.005em' }}>
                your photos
              </div>
            </div>
          </div>
          <Divider style={{ background: R.border, margin: '0 -20px' }} />
          <div style={{ padding: '14px 0 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
            {[
              { v: 'Latest Photo Only', rec: true },
              { v: 'Selected Photos' },
              { v: "Don't Allow" },
            ].map(o => (
              <div key={o.v} style={{
                display: 'flex', alignItems: 'center',
                padding: '10px 12px',
                background: o.rec ? R.raised : 'transparent',
                border: `1px solid ${o.rec ? R.borderStrong : R.border}`,
                borderRadius: R.rsm,
              }}>
                <span style={{ flex: 1, fontFamily: R.font, fontSize: 13.5, fontWeight: o.rec ? 600 : 400, color: o.rec ? R.t1 : R.t2, letterSpacing: '-0.005em' }}>
                  {o.v}
                </span>
                {o.rec && <Label color={R.accent} style={{ fontSize: 11 }}>Recommended</Label>}
              </div>
            ))}
          </div>
        </div>
      </div>
    </OnbShell>
  );
}

// ─────────────────────────────────────────────────────────────
// 04 · Install Shortcut
// ─────────────────────────────────────────────────────────────
function OnbStep4() {
  return (
    <OnbShell
      stepNum={4}
      eyebrow="Shortcut"
      title="Install the Shortcut."
      lede="A small recipe lives in iOS Shortcuts. It takes the screenshot, hands it to Replr, opens the keyboard. You wire it to Back Tap next."
      primaryLabel="Add to Shortcuts"
      primaryIcon={<Icon.bolt />}
      secondary="Inspect the recipe"
    >
      <div style={{
        background: R.surface, border: `1px solid ${R.border}`,
        borderRadius: R.rsm, overflow: 'hidden',
      }}>
        <div style={{
          padding: '12px 14px',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          borderBottom: `1px solid ${R.border}`,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{
              width: 24, height: 24, borderRadius: 6, background: R.accent,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: R.accentText,
            }}>
              <Icon.bolt />
            </div>
            <span style={{ fontFamily: R.font, fontSize: 13.5, fontWeight: 500, color: R.t1, letterSpacing: '-0.005em' }}>
              Replr Capture
            </span>
          </div>
          <Mono>4 actions</Mono>
        </div>
        {[
          { n: '01', t: 'Take Screenshot' },
          { n: '02', t: 'Save to Photos' },
          { n: '03', t: 'Open Replr' },
          { n: '04', t: 'Show Keyboard' },
        ].map((r, i, a) => (
          <div key={r.n} style={{
            padding: '12px 14px',
            display: 'flex', alignItems: 'center', gap: 12,
            borderBottom: i < a.length - 1 ? `1px solid ${R.border}` : 'none',
          }}>
            <Mono color={R.t3} style={{ width: 18 }}>{r.n}</Mono>
            <span style={{ flex: 1, fontFamily: R.font, fontSize: 13.5, color: R.t1, letterSpacing: '-0.005em' }}>{r.t}</span>
            <Icon.check style={{ color: R.success }} />
          </div>
        ))}
      </div>
    </OnbShell>
  );
}

// ─────────────────────────────────────────────────────────────
// 05 · Back Tap
// ─────────────────────────────────────────────────────────────
function OnbStep5() {
  return (
    <OnbShell
      stepNum={5}
      eyebrow="Back Tap"
      title="Triple-tap = capture."
      lede="iOS Back Tap turns a tap on the back of the phone into a Shortcut. Wire triple-tap to Replr Capture and you'll never open the app again."
      primaryLabel="Open Back Tap Settings"
      primaryIcon={<Icon.arrow />}
      secondary="Use double-tap instead"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <Label color={R.t3}>The path</Label>
        <PathCrumb
          path={['Accessibility', 'Touch', 'Back Tap', 'Triple Tap', 'Replr Capture']}
          active="Replr Capture"
        />
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginTop: 4 }}>
          {/* Phone silhouette */}
          <svg width="72" height="100" viewBox="0 0 72 100">
            <rect x="2" y="2" width="68" height="96" rx="12" fill={R.surface} stroke={R.border} strokeWidth="1"/>
            <circle cx="36" cy="38" r="14" fill="none" stroke={R.accent} strokeWidth="1.4" opacity="0.5"/>
            <circle cx="36" cy="38" r="9" fill="none" stroke={R.accent} strokeWidth="1.4" opacity="0.75"/>
            <circle cx="36" cy="38" r="4.5" fill={R.accent} />
            <text x="36" y="76" textAnchor="middle" fontFamily={R.font} fontWeight="500" fontSize="9" fill={R.t3} letterSpacing="0.06em">TAP · TAP · TAP</text>
          </svg>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: R.font, fontSize: 16, fontWeight: 500, color: R.t1, letterSpacing: '-0.012em' }}>
              Three taps. The apple, the back, anywhere.
            </div>
            <div style={{ fontFamily: R.font, fontSize: 12.5, color: R.t3, letterSpacing: '-0.005em', lineHeight: 1.45, marginTop: 6 }}>
              Works through most cases. Sensitivity calibrates after your first capture.
            </div>
          </div>
        </div>
      </div>
    </OnbShell>
  );
}

// ─────────────────────────────────────────────────────────────
// 06 · Default tone
// ─────────────────────────────────────────────────────────────
function OnbStep6() {
  const [picked, setPicked] = React.useState('Friendly');
  return (
    <OnbShell
      stepNum={6}
      eyebrow="Defaults"
      title="One last thing."
      lede="Pick a default tone. You can override it per-person and per-reply later. Most people start with Friendly."
      primaryLabel="Try a sample capture"
      primaryIcon={<Icon.spark />}
      secondary="Skip"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <Label color={R.t3}>Default tone</Label>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {TONES.map(t => (
            <button key={t} onClick={() => setPicked(t)} style={{
              appearance: 'none', cursor: 'pointer',
              padding: '10px 14px',
              background: t === picked ? R.accent : R.surface,
              color: t === picked ? R.accentText : R.t1,
              border: t === picked ? 'none' : `1px solid ${R.border}`,
              borderRadius: R.rsm,
              fontFamily: R.font, fontSize: 13.5, fontWeight: 500, letterSpacing: '-0.005em',
            }}>{t}</button>
          ))}
        </div>
        <div style={{
          marginTop: 8, padding: 16,
          background: R.surface, border: `1px solid ${R.border}`,
          borderRadius: R.rsm,
        }}>
          <Label color={R.t3} style={{ marginBottom: 8 }}>Sample · {picked}</Label>
          <div style={{
            fontFamily: R.font, fontSize: 15, color: R.t1,
            letterSpacing: '-0.011em', lineHeight: 1.4,
          }}>
            {{
              Casual:       "yeah friday works, ill grab the table",
              Friendly:     "Friday works — happy to grab the table.",
              Direct:       "Friday. I'll get the table.",
              Witty:        "Friday, and yes — I'll claim the booth before the influencers do.",
              Professional: "Friday works for me. I'll reserve the table.",
              Dating:       "Friday's a yes — and I'll get us the good table 😉",
            }[picked]}
          </div>
        </div>
      </div>
    </OnbShell>
  );
}

Object.assign(window, {
  OnbShell, OnbWelcome, OnbStep1, OnbStep2, OnbStep3, OnbStep4, OnbStep5, OnbStep6,
});
