// Replr v2 — History capture detail + simplified Memory.
//
// Memory model: ONE evolving paragraph per contact, ~4 sentences. Refined
// silently after each capture; no per-capture archival. Surfaced inline in
// the History capture detail — never a standalone destination.

// ─────────────────────────────────────────────────────────────
// CAPTURE DETAIL — opened from a History row
// ─────────────────────────────────────────────────────────────
function CaptureDetail() {
  return (
    <div style={{ height: '100%', background: R.base, color: R.t1, overflow: 'auto' }}>
      {/* Header */}
      <div style={{
        paddingTop: 56, padding: `56px ${R.s4}px ${R.s3}px`,
        display: 'flex', alignItems: 'center', gap: 14,
        position: 'sticky', top: 0, background: R.base, zIndex: 2,
        borderBottom: `1px solid ${R.border}`,
      }}>
        <button style={iconBtn}><Icon.back style={{ color: R.t1 }} /></button>
        <div style={{
          fontFamily: R.font, fontSize: 15, fontWeight: 500,
          color: R.t1, letterSpacing: '-0.01em',
        }}>21 May 2026, 22:01</div>
        <div style={{ flex: 1 }} />
        <Avatar name="Maya Acheson" size={28} />
      </div>

      <div style={{ padding: `${R.s5}px ${R.s5}px ${R.s7}px`, display: 'flex', flexDirection: 'column', gap: R.s6 }}>
        {/* Screenshot */}
        <div>
          <Label color={R.t3} style={{ marginBottom: 10 }}>Screenshot</Label>
          <div style={{
            background: R.surface, borderRadius: R.rmd,
            border: `1px solid ${R.border}`, padding: 6,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            height: 200,
          }}>
            {/* Faux blurred screenshot placeholder */}
            <div style={{
              width: '100%', height: '100%', borderRadius: R.rsm,
              background: 'linear-gradient(135deg, rgba(255,90,77,0.18) 0%, rgba(74,222,128,0.1) 50%, rgba(96,165,250,0.12) 100%)',
              filter: 'blur(1px)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: R.t3, fontFamily: R.font, fontSize: 11, letterSpacing: '-0.005em',
            }}>blurred for privacy · tap to view</div>
          </div>
        </div>

        {/* Conversation summary */}
        <div>
          <Label color={R.t3} style={{ marginBottom: 10 }}>Conversation summary</Label>
          <div style={{
            background: R.surface, border: `1px solid ${R.border}`,
            borderRadius: R.rmd, padding: 16,
            fontFamily: R.font, fontSize: 14.5, lineHeight: 1.5,
            color: R.t1, letterSpacing: '-0.005em',
          }}>
            Maya is checking in about Friday dinner — she's offered sushi or a wine bar,
            asked you to pick, and wants to know if her flatmate can join.
          </div>
        </div>

        {/* Generated replies */}
        <div>
          <Label color={R.t3} style={{ marginBottom: 10 }}>Generated replies</Label>
          <div style={{
            background: R.surface, border: `1px solid ${R.border}`,
            borderRadius: R.rmd, overflow: 'hidden',
          }}>
            {[
              "Sushi — and bring her, she'll love it.",
              "Wine bar, vest-guy be damned. Yes to flatmate.",
              "You pick. I'm easy. Flatmate's in.",
            ].map((r, i, a) => (
              <div key={i} style={{
                padding: 16, display: 'flex', alignItems: 'flex-start', gap: 12,
                borderBottom: i < a.length - 1 ? `1px solid ${R.border}` : 'none',
              }}>
                <Mono color={R.t3} style={{ width: 18, marginTop: 1 }}>{String(i + 1).padStart(2, '0')}</Mono>
                <div style={{
                  flex: 1,
                  fontFamily: R.font, fontSize: 14.5, lineHeight: 1.45,
                  color: R.t1, letterSpacing: '-0.005em', textWrap: 'pretty',
                }}>{r}</div>
                <button style={{ ...iconBtn, width: 28, height: 28, color: R.accent }}>
                  <Icon.copy />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* Memory — the new simple model */}
        <div>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
            <Label color={R.t3}>Replr remembers about Maya</Label>
            <Mono color={R.t4}>updated just now</Mono>
          </div>
          <div style={{
            background: R.accentSoft,
            border: `1px solid ${R.accent}`,
            borderRadius: R.rmd, padding: 16,
            display: 'flex', flexDirection: 'column', gap: 14,
          }}>
            <div style={{
              fontFamily: R.font, fontSize: 14.5, lineHeight: 1.55,
              color: R.t1, letterSpacing: '-0.005em', textWrap: 'pretty',
            }}>
              Best friend since 2019. Texts in short, dry bursts — rarely punctuation, often
              nicknames. Has a cat named Sergio. Just back from a trip to Lisbon together.
              Doesn't do brunch — late dinners or coffee only.
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button style={{
                appearance: 'none', cursor: 'pointer',
                background: R.base, color: R.t1, border: `1px solid ${R.borderStrong}`,
                padding: '8px 12px', borderRadius: R.rsm,
                fontFamily: R.font, fontSize: 12.5, fontWeight: 500, letterSpacing: '-0.005em',
                display: 'inline-flex', alignItems: 'center', gap: 6,
              }}>
                <Icon.edit style={{ color: R.t1 }} /> Edit
              </button>
              <button style={{
                appearance: 'none', cursor: 'pointer',
                background: 'transparent', color: R.t2, border: `1px solid ${R.border}`,
                padding: '8px 12px', borderRadius: R.rsm,
                fontFamily: R.font, fontSize: 12.5, fontWeight: 500, letterSpacing: '-0.005em',
              }}>Forget</button>
              <div style={{ flex: 1 }} />
            </div>
          </div>
          <Label color={R.t4} style={{ marginTop: 10, fontSize: 11.5, lineHeight: 1.5 }}>
            One short paragraph, updated silently after each capture. Replr never stores
            transcripts or screenshots — only what it learns.
          </Label>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// MEMORY EDITOR — what tapping "Edit" opens
// ─────────────────────────────────────────────────────────────
function MemoryEditor() {
  const [text, setText] = React.useState(
    "Best friend since 2019. Texts in short, dry bursts — rarely punctuation, often nicknames. Has a cat named Sergio. Just back from a trip to Lisbon together. Doesn't do brunch — late dinners or coffee only."
  );
  return (
    <div style={{ height: '100%', background: R.base, color: R.t1, display: 'flex', flexDirection: 'column' }}>
      <div style={{
        paddingTop: 56, padding: `56px ${R.s4}px ${R.s3}px`,
        display: 'flex', alignItems: 'center', gap: 14,
        borderBottom: `1px solid ${R.border}`,
      }}>
        <button style={iconBtn}><Icon.close style={{ color: R.t1 }} /></button>
        <div style={{
          fontFamily: R.font, fontSize: 15, fontWeight: 500,
          color: R.t1, letterSpacing: '-0.01em',
        }}>Memory · Maya</div>
        <div style={{ flex: 1 }} />
        <button style={{
          appearance: 'none', cursor: 'pointer',
          background: R.accent, color: R.accentText, border: 'none',
          padding: '8px 14px', borderRadius: R.rsm,
          fontFamily: R.font, fontSize: 13, fontWeight: 600, letterSpacing: '-0.005em',
        }}>Save</button>
      </div>

      <div style={{ flex: 1, padding: `${R.s5}px ${R.s5}px`, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <Label color={R.t3}>What Replr remembers about Maya</Label>
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          style={{
            appearance: 'none', resize: 'none',
            width: '100%', minHeight: 200,
            background: R.surface, border: `1px solid ${R.borderStrong}`,
            color: R.t1, borderRadius: R.rmd, padding: 16,
            fontFamily: R.font, fontSize: 15, lineHeight: 1.55, letterSpacing: '-0.005em',
            outline: 'none',
          }}
        />
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Mono color={R.t3}>{text.length} characters · ideal under 400</Mono>
          <button style={{
            appearance: 'none', cursor: 'pointer',
            background: 'transparent', border: 'none',
            color: R.accent, fontFamily: R.font, fontSize: 12.5, fontWeight: 500, letterSpacing: '-0.005em',
          }}>Reset to AI suggestion</button>
        </div>

        <div style={{
          marginTop: R.s4, padding: 14,
          background: R.surface, border: `1px solid ${R.border}`,
          borderRadius: R.rmd,
          display: 'flex', gap: 12, alignItems: 'flex-start',
        }}>
          <Icon.shield style={{ color: R.t2, marginTop: 2, flexShrink: 0 }} />
          <div style={{ fontFamily: R.font, fontSize: 12.5, color: R.t2, lineHeight: 1.5, letterSpacing: '-0.005em' }}>
            Memory stays on device. Nothing leaves your phone except the prompts Replr uses
            to draft your replies — and those don't include this paragraph in plain text.
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// HISTORY — only minor change: shows thumbnails now (matches live build)
// ─────────────────────────────────────────────────────────────
function AppHistory() {
  return (
    <div style={{ height: '100%', background: R.base, position: 'relative' }}>
      <AppHeader
        eyebrow="2,418 replies · since January"
        title="History."
        trailing={
          <button style={{
            appearance: 'none', cursor: 'pointer',
            background: 'transparent', border: `1px solid ${R.borderStrong}`,
            color: R.accent, padding: '5px 10px', borderRadius: R.rsm,
            fontFamily: R.font, fontSize: 11.5, fontWeight: 500, letterSpacing: '-0.005em',
          }}>Clear All</button>
        }
      />
      {/* Filter chips */}
      <div style={{
        padding: `0 ${R.s5}px ${R.s3}px`, display: 'flex', gap: 6, overflow: 'auto',
      }}>
        {[
          { l: 'All', active: true },
          { l: 'Maya Acheson', spark: true },
          { l: 'Priya Shankar', spark: true },
          { l: 'Daniel Park', spark: true },
        ].map(f => (
          <button key={f.l} style={{
            appearance: 'none', cursor: 'pointer', flexShrink: 0,
            padding: '6px 12px',
            background: f.active ? R.accent : R.surface,
            color: f.active ? R.accentText : R.t2,
            border: 'none', borderRadius: 999,
            fontFamily: R.font, fontSize: 12.5, fontWeight: 500, letterSpacing: '-0.005em',
            display: 'flex', alignItems: 'center', gap: 5,
          }}>
            {f.l}
            {f.spark && <Icon.spark style={{ color: 'currentColor' }} />}
          </button>
        ))}
      </div>

      <div style={{ overflow: 'auto', paddingBottom: 120, height: 'calc(100% - 244px)' }}>
        {HISTORY_ITEMS.map((h, i) => <HistoryCard key={i} {...h} />)}
      </div>
      <TabBar active="history" />
    </div>
  );
}

function HistoryCard({ name, time, summary }) {
  return (
    <div style={{
      margin: `0 ${R.s5}px ${R.s3}px`,
      padding: 14,
      background: R.surface, border: `1px solid ${R.border}`,
      borderRadius: R.rmd,
      display: 'flex', gap: 14, alignItems: 'flex-start',
    }}>
      {/* Thumbnail */}
      <div style={{
        width: 56, height: 70, borderRadius: R.rxs,
        background: 'linear-gradient(135deg, rgba(255,90,77,0.2) 0%, rgba(96,165,250,0.18) 60%, rgba(74,222,128,0.15) 100%)',
        flexShrink: 0,
      }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
          <span style={{ fontFamily: R.font, fontSize: 13.5, fontWeight: 600, color: R.accent, letterSpacing: '-0.005em' }}>{name}</span>
          <Mono color={R.t4}>·</Mono>
          <Mono color={R.t3}>Today · {time}</Mono>
        </div>
        <div style={{
          fontFamily: R.font, fontSize: 13.5, color: R.t1,
          lineHeight: 1.4, letterSpacing: '-0.005em',
          display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical',
          overflow: 'hidden',
        }}>{summary}</div>
      </div>
      <Icon.chev style={{ color: R.t4, flexShrink: 0, marginTop: 6 }} />
    </div>
  );
}

const HISTORY_ITEMS = [
  { name: 'Maya Acheson', time: '14:32',
    summary: "Maya is checking in about Friday dinner — she's offered sushi or a wine bar, asked you to pick, and wants to know if her flatmate can join." },
  { name: 'Priya Shankar', time: '11:08',
    summary: "Priya shared the Q3 budget draft and is asking for sign-off. She flagged the contractor line on row 14 needs your input." },
  { name: 'Daniel Park', time: '09:14',
    summary: "Daniel is on his way home and asked if you wanted anything from the market. Suggested flowers as a pick-me-up." },
];

// — Empty state, with a first-capture nudge —
function AppHistoryEmpty() {
  return (
    <div style={{ height: '100%', background: R.base, position: 'relative' }}>
      <AppHeader title="History." />
      <div style={{
        position: 'absolute', inset: '180px 24px 140px',
        display: 'flex', flexDirection: 'column', alignItems: 'center',
        justifyContent: 'center', textAlign: 'center', gap: 20,
      }}>
        <div style={{
          width: 56, height: 56, borderRadius: R.rmd,
          background: R.surface, border: `1px solid ${R.border}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: R.t2,
        }}>
          <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
            <rect x="2.5" y="5" width="17" height="13" rx="2" stroke="currentColor" strokeWidth="1.4"/>
            <circle cx="11" cy="11.5" r="3.2" stroke="currentColor" strokeWidth="1.4"/>
            <path d="M7 5l1.5-2h5L15 5" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
          </svg>
        </div>
        <div>
          <div style={{
            fontFamily: R.font, fontSize: 18, fontWeight: 600,
            color: R.t1, letterSpacing: '-0.015em', marginBottom: 6,
          }}>No captures yet</div>
          <div style={{
            fontFamily: R.font, fontSize: 14, color: R.t3,
            letterSpacing: '-0.005em', lineHeight: 1.5, maxWidth: 280,
          }}>
            Open any chat, double-tap the back, and Replr will draft the reply. Captures will appear here.
          </div>
        </div>
        <div style={{
          marginTop: 12, padding: '10px 14px',
          background: R.accentSoft, border: `1px solid ${R.accent}`,
          borderRadius: R.rsm,
          display: 'inline-flex', alignItems: 'center', gap: 8,
          fontFamily: R.font, fontSize: 12.5, fontWeight: 500,
          color: R.accent, letterSpacing: '-0.005em',
        }}>
          <Icon.spark />
          Try a sample capture
        </div>
      </div>
      <TabBar active="history" />
    </div>
  );
}

Object.assign(window, { AppHistoryEmpty });

// ─────────────────────────────────────────────────────────────
// SETTINGS — simplified Memory group
// ─────────────────────────────────────────────────────────────
function AppSettings() {
  return (
    <div style={{ height: '100%', background: R.base, position: 'relative' }}>
      <AppHeader title="Settings." />
      <div style={{ overflow: 'auto', paddingBottom: 120, height: 'calc(100% - 192px)' }}>
        <SettingGroup label="Keyboard">
          <SettingRow title="Default tone" value="Friendly" />
          <SettingRow title="Keep replies between sessions" toggle on />
          <SettingRow title="Languages" value="EN · ES · FR" />
        </SettingGroup>

        <SettingGroup label="AI Model">
          <SettingRow title="Claude · Anthropic" value="" check />
          <SettingRow title="GPT-4o · OpenAI" value="" />
          <SettingHint>Claude is the default. Pro lets you switch.</SettingHint>
        </SettingGroup>

        <SettingGroup label="Memory">
          <SettingRow title="Remember people" toggle on />
          <SettingRow title="Clear all memory" danger />
          <SettingHint>
            Replr keeps one short paragraph per contact — what it's learned about how you talk to them.
            Nothing else is stored.
          </SettingHint>
        </SettingGroup>

        <SettingGroup label="Privacy">
          <SettingRow title="Screenshot retention" value="30s" />
          <SettingRow title="On-device base model" toggle on />
        </SettingGroup>

        <SettingGroup label="Account">
          <SettingRow title="hello@example.com" mono />
          <SettingRow title="Subscription" value="Pro · annual" />
          <SettingRow title="About" value="v1.4.2" />
        </SettingGroup>
      </div>
      <TabBar active="settings" />
    </div>
  );
}

function SettingGroup({ label, children }) {
  return (
    <div style={{ marginTop: 22 }}>
      <Label color={R.t3} style={{ padding: `0 ${R.s5}px ${R.s2}px` }}>{label}</Label>
      <Divider style={{ background: R.border }} />
      {children}
    </div>
  );
}

function SettingHint({ children }) {
  return (
    <div style={{
      padding: `${R.s2}px ${R.s5}px ${R.s3}px`,
      fontFamily: R.font, fontSize: 11.5, color: R.t3,
      letterSpacing: '-0.005em', lineHeight: 1.45,
    }}>{children}</div>
  );
}

function SettingRow({ title, value, toggle, on, danger, mono, check }) {
  return (
    <div style={{
      padding: `${R.s4}px ${R.s5}px`,
      borderBottom: `1px solid ${R.border}`,
      display: 'flex', alignItems: 'center', gap: 12,
    }}>
      <div style={{
        flex: 1,
        fontFamily: mono ? R.fontMono : R.font,
        fontSize: mono ? 13 : 14, fontWeight: 500,
        color: danger ? R.accent : R.t1,
        letterSpacing: mono ? 0 : '-0.005em',
      }}>{title}</div>
      {toggle ? (
        <div style={{
          width: 40, height: 24, borderRadius: 12,
          background: on ? R.accent : R.raised,
          padding: 2, display: 'flex', justifyContent: on ? 'flex-end' : 'flex-start',
        }}>
          <div style={{ width: 20, height: 20, borderRadius: 10, background: on ? R.accentText : R.t1 }} />
        </div>
      ) : check ? (
        <Icon.check style={{ color: R.accent }} />
      ) : (
        <>
          {value && <span style={{ fontFamily: R.font, fontSize: 13, color: R.t3, letterSpacing: '-0.005em' }}>{value}</span>}
          {!danger && <Icon.chev style={{ color: R.t4 }} />}
        </>
      )}
    </div>
  );
}

Object.assign(window, {
  CaptureDetail, MemoryEditor,
  AppHistory, AppSettings, HistoryCard, HISTORY_ITEMS,
});
