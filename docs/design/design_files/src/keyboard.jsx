// Replr v2 keyboard — built around the real state machine.
//
// Keyboard extensions can't screenshot their host app. So capture is two
// steps: the keyboard minimises to a thin capture bar, exposing the chat
// above, then the user triple-taps the back of the phone — the iOS Shortcut
// fires the screenshot, hands it to Replr, and the keyboard expands back.
//
// States: idle-chat | idle-email | capture-bar | loading | replies |
//         edit | rename | error
//
// One amber/coral per screen. Strict 4px grid inside, 16px panel margins.

const TONES = ['Casual', 'Friendly', 'Direct', 'Witty', 'Professional', 'Dating'];

// ─────────────────────────────────────────────────────────────
// Shells
// ─────────────────────────────────────────────────────────────

// Expanded keyboard wrapper (~ 300px tall). State-specific bodies plug in.
function KbExpanded({ mode = 'chat', onModeChange, children }) {
  return (
    <div style={{
      background: R.base, color: R.t1,
      borderTop: `1px solid ${R.border}`,
      fontFamily: R.font,
      paddingBottom: 28,  // home indicator clearance
    }}>
      <KbStyles />
      {/* Top chrome — slim segmented + replr mark */}
      <div style={{
        padding: `${R.s3}px ${R.s4}px ${R.s2}px`,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        gap: R.s3,
      }}>
        <SegChatEmail value={mode} onChange={onModeChange} />
        <Mark size={14} />
      </div>
      {children}
      <KbFooter />
    </div>
  );
}

// — Slim segmented control (Chat | Email), ~32px tall —
function SegChatEmail({ value = 'chat', onChange }) {
  return (
    <div style={{
      display: 'inline-flex', background: R.surface,
      borderRadius: R.rsm, padding: 3, gap: 2,
      border: `1px solid ${R.border}`,
    }}>
      {['chat', 'email'].map(v => (
        <button key={v} onClick={() => onChange?.(v)} style={{
          appearance: 'none', border: 'none', cursor: 'pointer',
          padding: '6px 14px',
          background: value === v ? R.raised : 'transparent',
          color: value === v ? R.t1 : R.t2,
          borderRadius: 6,
          fontFamily: R.font, fontSize: 13, fontWeight: 500,
          letterSpacing: '-0.005em', textTransform: 'capitalize',
        }}>{v}</button>
      ))}
    </div>
  );
}

// — Bottom row: globe + mic. Calm, balanced. —
function KbFooter() {
  return (
    <div style={{
      padding: `${R.s2}px ${R.s4}px 0`,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    }}>
      <button style={kbIconBtn}><Icon.globe style={{ color: R.t2 }} /></button>
      <button style={kbIconBtn}><Icon.mic style={{ color: R.t2 }} /></button>
    </div>
  );
}

const kbIconBtn = {
  appearance: 'none', border: 'none', background: 'transparent',
  width: 36, height: 36, borderRadius: 8, cursor: 'pointer',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
};

// — Inline shared CSS for animated bits —
function KbStyles() {
  return (
    <style>{`
      @keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
      @keyframes pulse  { 0%, 100% { opacity: 0.35; } 50% { opacity: 1; } }
      @keyframes tapY   { 0%, 60%, 100% { transform: translateY(0); } 30% { transform: translateY(2px); } }
      @keyframes dot3   { 0%, 80%, 100% { opacity: .25; } 40% { opacity: 1; } }
    `}</style>
  );
}

// ─────────────────────────────────────────────────────────────
// IDLE — Chat
// ─────────────────────────────────────────────────────────────
function KbIdleChat({ tone = 'Friendly', onCapture, onToneChange }) {
  return (
    <div style={{ padding: `${R.s5}px ${R.s4}px ${R.s4}px`, display: 'flex', flexDirection: 'column', gap: R.s3 }}>
      <Primary onClick={onCapture} leading={<Icon.spark />}>
        Capture this chat
      </Primary>
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        paddingTop: 2,
      }}>
        <div style={{
          fontFamily: R.font, fontSize: 12, color: R.t3,
          letterSpacing: '-0.005em', maxWidth: 240,
        }}>
          Minimises the keyboard so you can triple-tap to screenshot
        </div>
        <ToneChip value={tone} onClick={onToneChange} />
      </div>
    </div>
  );
}

// — Compact tone chip used on the idle screens —
function ToneChip({ value, onClick }) {
  return (
    <button onClick={onClick} style={{
      appearance: 'none', cursor: 'pointer',
      background: 'transparent', border: `1px solid ${R.borderStrong}`,
      color: R.t2, borderRadius: 999,
      padding: '5px 8px 5px 10px',
      display: 'inline-flex', alignItems: 'center', gap: 4,
      fontFamily: R.font, fontSize: 12, fontWeight: 500,
      letterSpacing: '-0.005em',
    }}>
      {value}
      <Icon.chevDown style={{ color: R.t3, marginTop: 1 }} />
    </button>
  );
}

// ─────────────────────────────────────────────────────────────
// IDLE — Email
// ─────────────────────────────────────────────────────────────
function KbIdleEmail({ clipboardReady = false, tone = 'Professional' }) {
  return (
    <div style={{ padding: `${R.s5}px ${R.s4}px ${R.s4}px`, display: 'flex', flexDirection: 'column', gap: R.s3 }}>
      <Primary disabled={!clipboardReady} leading={<Icon.envelope />}>
        Generate from clipboard
      </Primary>
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: R.s3,
      }}>
        <div style={{
          fontFamily: R.font, fontSize: 12, color: R.t3,
          letterSpacing: '-0.005em', maxWidth: 220,
        }}>
          Copy the email you're replying to, then tap above
        </div>
        <ToneChip value={tone} />
      </div>
      <div style={{
        marginTop: 4, padding: '8px 10px',
        background: R.surface, border: `1px solid ${R.border}`,
        borderRadius: R.rsm,
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <Icon.clip style={{ color: clipboardReady ? R.success : R.t3 }} />
        <span style={{ flex: 1, fontFamily: R.font, fontSize: 12.5, color: clipboardReady ? R.t1 : R.t2, letterSpacing: '-0.005em' }}>
          {clipboardReady ? 'Email text ready' : 'Nothing copied yet'}
        </span>
        {clipboardReady && <Mono color={R.t3}>1,840 chars</Mono>}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// CAPTURE BAR — collapsed (~ 60px)
// ─────────────────────────────────────────────────────────────
function KbCaptureBar({ coachmark = false }) {
  return (
    <div style={{
      background: R.base, borderTop: `1px solid ${R.border}`,
      paddingBottom: 28, fontFamily: R.font,
      position: 'relative',
    }}>
      <KbStyles />
      {coachmark && (
        <div style={{
          position: 'absolute', left: R.s4, right: R.s4, bottom: '100%', marginBottom: 8,
          background: R.accent, color: R.accentText,
          padding: '10px 14px', borderRadius: R.rmd,
          fontFamily: R.font, fontSize: 12.5, fontWeight: 500, letterSpacing: '-0.005em',
          display: 'flex', alignItems: 'flex-start', gap: 8, boxShadow: '0 8px 24px rgba(0,0,0,0.5)',
        }}>
          <Icon.spark style={{ marginTop: 1 }} />
          <div>
            <div style={{ fontWeight: 600 }}>Two beats:</div>
            <div style={{ marginTop: 2, opacity: 0.8 }}>① Keyboard's minimised. ② Triple-tap the back.</div>
          </div>
          {/* tail */}
          <div style={{
            position: 'absolute', left: 24, bottom: -5,
            width: 10, height: 10, background: R.accent,
            transform: 'rotate(45deg)',
          }} />
        </div>
      )}
      <div style={{
        margin: `${R.s3}px ${R.s4}px`,
        background: R.surface,
        border: `1px solid ${R.border}`,
        borderLeft: `3px solid ${R.accent}`,
        borderRadius: R.rsm,
        padding: '10px 12px',
        display: 'flex', alignItems: 'center', gap: 10, minHeight: 44,
      }}>
        <TapGlyph />
        <div style={{ flex: 1 }}>
          <div style={{
            fontFamily: R.font, fontSize: 13.5, fontWeight: 500,
            color: R.t1, letterSpacing: '-0.005em',
          }}>Triple-tap the back of your phone</div>
          <div style={{
            fontFamily: R.font, fontSize: 11.5, color: R.t3,
            letterSpacing: '-0.005em', marginTop: 1,
          }}>to capture this chat</div>
        </div>
        <button style={kbIconBtn}><Icon.close style={{ color: R.t2 }} /></button>
      </div>
    </div>
  );
}

// — Animated mini phone with tap pulses —
function TapGlyph() {
  return (
    <div style={{ width: 22, height: 28, position: 'relative', flexShrink: 0 }}>
      <svg width="22" height="28" viewBox="0 0 22 28" fill="none">
        <rect x="2" y="2" width="18" height="24" rx="3" stroke={R.t2} strokeWidth="1.2"/>
        <circle cx="11" cy="11" r="2" fill={R.accent} style={{ animation: 'pulse 1.2s ease-in-out infinite' }}/>
        <circle cx="11" cy="11" r="4" stroke={R.accent} strokeWidth="0.8" opacity="0.4" style={{ animation: 'pulse 1.2s ease-in-out infinite', animationDelay: '0.2s' }}/>
      </svg>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// LOADING — skeleton matches the reply card
// ─────────────────────────────────────────────────────────────
function KbLoading({ phase = 'reading' }) {
  return (
    <div style={{ padding: `${R.s4}px ${R.s4}px`, display: 'flex', flexDirection: 'column', gap: R.s3 }}>
      {/* Contact skeleton */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <div style={{ width: 22, height: 22, borderRadius: 22, background: R.raised }} />
        <div style={{ width: 80, height: 12, borderRadius: 4, background: R.raised }} />
        <div style={{ flex: 1 }} />
        <div style={{ width: 40, height: 10, borderRadius: 3, background: R.raised, opacity: 0.6 }} />
      </div>
      {/* Reply card skeleton */}
      <div style={{
        background: R.surface, borderRadius: R.rmd,
        border: `1px solid ${R.border}`,
        padding: 16, minHeight: 100,
        display: 'flex', flexDirection: 'column', gap: 8,
      }}>
        {[0.92, 0.82, 0.58].map((w, i) => (
          <div key={i} style={{
            height: 11, width: `${w * 100}%`, borderRadius: 3,
            background: `linear-gradient(90deg, ${R.raised} 0%, ${R.raisedHi} 50%, ${R.raised} 100%)`,
            backgroundSize: '200% 100%',
            animation: 'shimmer 1.4s ease-in-out infinite',
            animationDelay: `${i * 0.1}s`,
          }} />
        ))}
      </div>
      {/* status */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, padding: '2px 0' }}>
        <span style={{
          fontFamily: R.font, fontSize: 12.5, color: R.t2, letterSpacing: '-0.005em',
        }}>
          {phase === 'reading' ? 'Reading the conversation' : 'Writing replies'}
        </span>
        <div style={{ display: 'flex', gap: 3 }}>
          {[0, 1, 2].map(i => (
            <div key={i} style={{
              width: 4, height: 4, borderRadius: 4, background: R.accent,
              animation: 'dot3 1s ease-in-out infinite',
              animationDelay: `${i * 0.15}s`,
            }} />
          ))}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// REPLIES (the hero screen)
// ─────────────────────────────────────────────────────────────
const SAMPLE_REPLIES = [
  "Friday works — want me to grab the table or you got it?",
  "Down. 7pm at the usual spot.",
  "Yeah, sushi sounds great. Bring her along.",
];

function KbReplies({
  contact = 'Maya', position = 1, total = 3,
  replies = SAMPLE_REPLIES, tone = 'Friendly',
  onTone, onRegen, onInsert, onEdit,
}) {
  const current = replies[position - 1];
  return (
    <div style={{ padding: `${R.s3}px ${R.s4}px ${R.s2}px`, display: 'flex', flexDirection: 'column', gap: R.s3 }}>
      {/* Contact row */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <Avatar name={contact} size={24} />
        <span style={{ fontFamily: R.font, fontSize: 14, fontWeight: 500, color: R.t1, letterSpacing: '-0.01em' }}>
          {contact}
        </span>
        <button style={{ ...kbIconBtn, width: 24, height: 24, color: R.t3 }}><Icon.edit /></button>
        <div style={{ flex: 1 }} />
        <Mono color={R.t3}>{position} of {total}</Mono>
      </div>

      {/* Reply card — the hero */}
      <div style={{
        background: R.surface, borderRadius: R.rmd,
        border: `1px solid ${R.border}`,
        padding: '18px 16px 14px', position: 'relative',
        minHeight: 96,
      }}>
        <div style={{
          fontFamily: R.font, fontSize: 16, fontWeight: 400,
          color: R.t1, lineHeight: 1.4, letterSpacing: '-0.011em',
          textWrap: 'pretty',
        }}>{current}</div>
        {/* Carousel dots */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          marginTop: 14,
        }}>
          {replies.map((_, i) => (
            <div key={i} style={{
              width: i === position - 1 ? 14 : 5, height: 5, borderRadius: 5,
              background: i === position - 1 ? R.accent : R.raisedHi,
              transition: 'all 0.2s',
            }} />
          ))}
        </div>
      </div>

      {/* Actions */}
      <div style={{ display: 'flex', gap: 8 }}>
        <Primary onClick={onInsert} leading={<Icon.arrowUp />} full style={{ flex: 1 }}>
          Insert reply
        </Primary>
        <Secondary onClick={onEdit}>Edit</Secondary>
      </div>

      {/* Tone row — lives here, next to its effect */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 6,
        margin: `${R.s1}px -${R.s4}px 0`,
        padding: `${R.s2}px ${R.s4}px ${R.s1}px`,
        overflow: 'auto',
        position: 'relative',
        maskImage: 'linear-gradient(90deg, transparent 0, black 16px, black calc(100% - 36px), transparent 100%)',
        WebkitMaskImage: 'linear-gradient(90deg, transparent 0, black 16px, black calc(100% - 36px), transparent 100%)',
      }}>
        {TONES.map(t => (
          <button key={t} onClick={() => onTone?.(t)} style={{
            appearance: 'none', cursor: 'pointer', flexShrink: 0,
            padding: '6px 10px',
            background: t === tone ? R.accent : 'transparent',
            color: t === tone ? R.accentText : R.t2,
            border: t === tone ? 'none' : `1px solid ${R.border}`,
            borderRadius: 999,
            fontFamily: R.font, fontSize: 12.5, fontWeight: 500, letterSpacing: '-0.005em',
          }}>{t}</button>
        ))}
        <button onClick={onRegen} style={{
          ...kbIconBtn, width: 30, height: 30, flexShrink: 0,
          background: R.surface, border: `1px solid ${R.border}`,
          marginLeft: 4,
        }}>
          <Icon.refresh style={{ color: R.t2 }} />
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// EDIT
// ─────────────────────────────────────────────────────────────
function KbEdit({ contact = 'Maya', draft = SAMPLE_REPLIES[0] }) {
  return (
    <div style={{ padding: `${R.s3}px ${R.s4}px`, display: 'flex', flexDirection: 'column', gap: R.s3 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <button style={{ ...kbIconBtn, width: 24, height: 24 }}>
          <Icon.back style={{ color: R.t2 }} />
        </button>
        <span style={{ fontFamily: R.font, fontSize: 13, color: R.t2, letterSpacing: '-0.005em' }}>Back to replies</span>
        <div style={{ flex: 1 }} />
        <Avatar name={contact} size={20} />
        <span style={{ fontFamily: R.font, fontSize: 13, fontWeight: 500, color: R.t1, letterSpacing: '-0.005em' }}>{contact}</span>
      </div>
      <div style={{
        background: R.surface, border: `1px solid ${R.borderStrong}`,
        borderRadius: R.rmd, padding: '14px 14px 10px',
        minHeight: 108,
      }}>
        <div style={{
          fontFamily: R.font, fontSize: 15.5, color: R.t1,
          lineHeight: 1.4, letterSpacing: '-0.011em',
        }}>
          {draft}<span style={{ borderLeft: `1.5px solid ${R.accent}`, marginLeft: 1, animation: 'pulse 1s steps(2) infinite' }} />
        </div>
        <div style={{
          display: 'flex', justifyContent: 'flex-end', marginTop: 6,
        }}>
          <Mono color={R.t3}>{draft.length} chars</Mono>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <Primary leading={<Icon.arrowUp />} style={{ flex: 1 }}>Insert reply</Primary>
        <Secondary>Cancel</Secondary>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// RENAME / disambiguate contact
// ─────────────────────────────────────────────────────────────
function KbRename() {
  return (
    <div style={{ padding: `${R.s3}px ${R.s4}px`, display: 'flex', flexDirection: 'column', gap: R.s3 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ fontFamily: R.font, fontSize: 14, fontWeight: 500, color: R.t1, letterSpacing: '-0.01em' }}>
          Who is this conversation with?
        </div>
        <button style={kbIconBtn}><Icon.close style={{ color: R.t2 }} /></button>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        {[
          { n: 'Maya Acheson', sub: 'Best friend · 142 captures', active: true },
          { n: 'Maya K. (work)', sub: 'Colleague · 6 captures' },
        ].map(p => (
          <button key={p.n} style={{
            appearance: 'none', cursor: 'pointer', textAlign: 'left',
            display: 'flex', alignItems: 'center', gap: 12,
            padding: '10px 12px',
            background: p.active ? R.raised : R.surface,
            border: `1px solid ${p.active ? R.borderStrong : R.border}`,
            borderRadius: R.rsm,
          }}>
            <Avatar name={p.n} size={28} />
            <div>
              <div style={{ fontFamily: R.font, fontSize: 13.5, fontWeight: 500, color: R.t1, letterSpacing: '-0.005em' }}>{p.n}</div>
              <div style={{ fontFamily: R.font, fontSize: 11.5, color: R.t3, letterSpacing: '-0.005em', marginTop: 1 }}>{p.sub}</div>
            </div>
            <div style={{ flex: 1 }} />
            {p.active && <Icon.check style={{ color: R.accent }} />}
          </button>
        ))}
        <button style={{
          appearance: 'none', cursor: 'pointer', textAlign: 'left',
          display: 'flex', alignItems: 'center', gap: 12,
          padding: '10px 12px',
          background: 'transparent',
          border: `1px dashed ${R.borderStrong}`,
          borderRadius: R.rsm,
          color: R.t2, fontFamily: R.font, fontSize: 13, fontWeight: 500, letterSpacing: '-0.005em',
        }}>
          <Icon.plus />
          Use a different name
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// ERROR
// ─────────────────────────────────────────────────────────────
function KbError({ message = "Couldn't generate replies", hint = "Check your connection and try again" }) {
  return (
    <div style={{ padding: `${R.s5}px ${R.s4}px ${R.s4}px`, display: 'flex', flexDirection: 'column', gap: R.s4, alignItems: 'center' }}>
      <div style={{
        width: 40, height: 40, borderRadius: 999,
        background: R.accentSoft,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <Icon.warn style={{ color: R.accent }} />
      </div>
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontFamily: R.font, fontSize: 14.5, fontWeight: 500, color: R.t1, letterSpacing: '-0.01em' }}>
          {message}
        </div>
        <div style={{ fontFamily: R.font, fontSize: 12.5, color: R.t3, letterSpacing: '-0.005em', marginTop: 4 }}>
          {hint}
        </div>
      </div>
      <Primary leading={<Icon.refresh />} full={false} style={{ minWidth: 180 }}>
        Try again
      </Primary>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Composed keyboard — drives state from props
// ─────────────────────────────────────────────────────────────
function ReplrKeyboard({ state = 'idle-chat', mode, coachmark, position = 1 }) {
  const [m, setM] = React.useState(mode || (state.endsWith('email') ? 'email' : 'chat'));
  React.useEffect(() => { if (mode) setM(mode); }, [mode]);

  if (state === 'capture') {
    return <KbCaptureBar coachmark={coachmark} />;
  }

  let body = null;
  if (state === 'idle-chat')   body = <KbIdleChat />;
  else if (state === 'idle-email') body = <KbIdleEmail clipboardReady={false} />;
  else if (state === 'idle-email-ready') body = <KbIdleEmail clipboardReady />;
  else if (state === 'loading') body = <KbLoading phase="reading" />;
  else if (state === 'loading-writing') body = <KbLoading phase="writing" />;
  else if (state === 'replies') body = <KbReplies position={position} />;
  else if (state === 'edit')    body = <KbEdit />;
  else if (state === 'rename')  body = <KbRename />;
  else if (state === 'error')   body = <KbError />;

  return (
    <KbExpanded mode={m} onModeChange={setM}>
      {body}
    </KbExpanded>
  );
}

Object.assign(window, {
  ReplrKeyboard, KbExpanded, KbIdleChat, KbIdleEmail, KbCaptureBar,
  KbLoading, KbReplies, KbEdit, KbRename, KbError,
  TONES, SAMPLE_REPLIES,
});
