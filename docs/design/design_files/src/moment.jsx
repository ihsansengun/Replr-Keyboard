// Replr v2 — the capture moment storyboard.
// Three frames: chat with keyboard idle → keyboard auto-minimised + triple-tap
// → keyboard expanded with replies. The full mechanic in one row.

// — Fake iMessage-style chat host (just enough context) —
function ChatHost({ dim = false }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: '#000' }}>
      <div style={{
        paddingTop: 56, background: 'rgba(255,255,255,0.04)',
        borderBottom: '0.5px solid rgba(255,255,255,0.06)',
      }}>
        <div style={{
          padding: `${R.s2}px ${R.s4}px ${R.s3}px`,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <svg width="16" height="22" viewBox="0 0 16 22"><path d="M13 2L4 11l9 9" stroke="#0a84ff" strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
            <Avatar name="Maya Acheson" size={32} />
            <div style={{ fontFamily: R.font, fontSize: 11, color: 'rgba(255,255,255,0.55)', letterSpacing: '-0.005em' }}>
              Maya
            </div>
          </div>
          <svg width="22" height="22" viewBox="0 0 22 22"><path d="M11 4v14M4 11h14" stroke="#0a84ff" strokeWidth="2.2" fill="none" strokeLinecap="round"/></svg>
        </div>
      </div>

      <div style={{
        flex: 1, padding: `${R.s4}px ${R.s3}px`, overflow: 'auto',
        opacity: dim ? 0.6 : 1, transition: 'opacity 0.2s',
        display: 'flex', flexDirection: 'column', gap: 4,
      }}>
        <div style={{ textAlign: 'center', fontFamily: R.font, fontSize: 11, color: 'rgba(255,255,255,0.35)', letterSpacing: '-0.005em', marginBottom: 12 }}>
          Today 2:31 PM
        </div>
        <Bubble side="them">
          okay so dinner Friday — sushi place we tried or that wine bar where the guy in the vest hated us
        </Bubble>
        <Bubble side="them">you pick 🙏</Bubble>
        <Bubble side="me">🤔</Bubble>
        <Bubble side="them">
          also can my flatmate come, she's been miserable
        </Bubble>
        <div style={{ textAlign: 'center', fontFamily: R.font, fontSize: 10.5, color: 'rgba(255,255,255,0.3)', letterSpacing: '-0.005em', marginTop: 6 }}>
          Delivered
        </div>
      </div>

      <div style={{
        padding: `${R.s2}px ${R.s3}px`,
        background: 'rgba(255,255,255,0.04)',
        borderTop: '0.5px solid rgba(255,255,255,0.06)',
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <button style={{
          width: 30, height: 30, borderRadius: 15,
          background: 'rgba(255,255,255,0.1)', border: 'none',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon.plus style={{ color: 'rgba(255,255,255,0.65)' }} />
        </button>
        <div style={{
          flex: 1, height: 32, borderRadius: 16,
          background: 'rgba(255,255,255,0.07)',
          border: '0.5px solid rgba(255,255,255,0.08)',
          display: 'flex', alignItems: 'center', paddingLeft: 14,
          fontFamily: R.font, fontSize: 13.5, color: 'rgba(255,255,255,0.35)',
          letterSpacing: '-0.005em',
        }}>iMessage</div>
        <button style={{
          width: 30, height: 30, borderRadius: 15,
          background: 'rgba(255,255,255,0.1)', border: 'none',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon.mic style={{ color: 'rgba(255,255,255,0.65)' }} />
        </button>
      </div>
    </div>
  );
}

function Bubble({ children, side }) {
  const me = side === 'me';
  return (
    <div style={{ display: 'flex', justifyContent: me ? 'flex-end' : 'flex-start' }}>
      <div style={{
        maxWidth: '76%',
        background: me ? '#0a84ff' : '#26252A',
        color: '#fff',
        padding: '8px 13px 9px',
        borderRadius: 18,
        fontFamily: R.font, fontSize: 14, lineHeight: 1.35,
        letterSpacing: '-0.005em', textWrap: 'pretty',
      }}>{children}</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// FRAME 1: keyboard idle, user about to tap "Capture this chat"
// ─────────────────────────────────────────────────────────────
function MomentFrame1() {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}>
        <ChatHost />
      </div>
      <div style={{ position: 'relative' }}>
        <ReplrKeyboard state="idle-chat" />
        {/* Pointer at the Capture button */}
        <div style={{
          position: 'absolute', top: 38, left: 16, right: 16,
          pointerEvents: 'none',
        }}>
          <div style={{
            position: 'absolute', top: -34, right: 16,
            display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <div style={{
              padding: '6px 10px',
              background: R.accent, color: R.accentText, borderRadius: 6,
              fontFamily: R.font, fontSize: 11, fontWeight: 600, letterSpacing: '-0.005em',
            }}>
              ① Tap to start
            </div>
            <svg width="18" height="30" viewBox="0 0 18 30"><path d="M9 1 Q 9 16, 9 28" stroke={R.accent} strokeWidth="1.4" fill="none" strokeDasharray="3 3" strokeLinecap="round"/><path d="M5 24l4 6 4-6" stroke={R.accent} strokeWidth="1.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// FRAME 2: keyboard minimised to capture bar, waiting for triple-tap
// ─────────────────────────────────────────────────────────────
function MomentFrame2() {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', position: 'relative' }}>
      <div style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}>
        <ChatHost />
      </div>
      <KbCaptureBar />
      {/* Hint: pointing at the back of the phone, off-canvas via SVG */}
      <div style={{
        position: 'absolute', right: -4, top: '46%',
        display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4,
        pointerEvents: 'none',
      }}>
        <div style={{
          padding: '6px 10px',
          background: R.accent, color: R.accentText, borderRadius: 6,
          fontFamily: R.font, fontSize: 11, fontWeight: 600, letterSpacing: '-0.005em',
          lineHeight: 1.2, textAlign: 'right',
        }}>
          ② Triple-tap<br/>the back
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// FRAME 3: keyboard expanded with replies ready
// ─────────────────────────────────────────────────────────────
function MomentFrame3() {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', position: 'relative' }}>
      <div style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}>
        <ChatHost />
      </div>
      <ReplrKeyboard state="replies" />
      <div style={{
        position: 'absolute', top: 38, right: 16,
        display: 'flex', alignItems: 'center', gap: 8,
        pointerEvents: 'none',
      }}>
        <div style={{
          padding: '6px 10px',
          background: R.accent, color: R.accentText, borderRadius: 6,
          fontFamily: R.font, fontSize: 11, fontWeight: 600, letterSpacing: '-0.005em',
        }}>
          ③ Already written
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ChatHost, Bubble, MomentFrame1, MomentFrame2, MomentFrame3 });
