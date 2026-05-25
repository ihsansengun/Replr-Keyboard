// Replr v2 companion app — Home, People, Tagging, Contact memory (3 variants),
// History, Settings. Dark, single typeface, strict 8px grid.

// ─────────────────────────────────────────────────────────────
// Header + Tab bar (shared)
// ─────────────────────────────────────────────────────────────
function AppHeader({ title, eyebrow, leading, trailing, large = true }) {
  return (
    <div style={{
      paddingTop: 56, background: R.base,
    }}>
      <div style={{
        padding: `${R.s3}px ${R.s5}px 0`,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{ width: 32, display: 'flex' }}>{leading}</div>
        <Mark size={14} />
        <div style={{ width: 32, display: 'flex', justifyContent: 'flex-end' }}>{trailing}</div>
      </div>
      {large && (
        <div style={{ padding: `${R.s5}px ${R.s5}px ${R.s3}px` }}>
          {eyebrow && <Label color={R.t3} style={{ marginBottom: 8 }}>{eyebrow}</Label>}
          <h1 style={{
            fontFamily: R.font, fontSize: 32, fontWeight: 600,
            letterSpacing: '-0.028em', lineHeight: 1.05,
            color: R.t1, margin: 0,
          }}>{title}</h1>
        </div>
      )}
    </div>
  );
}

// Floating pill tab bar — matches live build: just Settings + History.
function TabBar({ active = 'settings' }) {
  const tabs = [
    { id: 'settings', label: 'Settings', icon: (c) => (
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
        <circle cx="8" cy="8" r="2.4" stroke={c} strokeWidth="1.4"/>
        <path d="M8 1.5v1.5M8 13v1.5M14.5 8h-1.5M3 8H1.5M12.6 3.4l-1.05 1.05M4.45 11.55L3.4 12.6M12.6 12.6l-1.05-1.05M4.45 4.45L3.4 3.4" stroke={c} strokeWidth="1.4" strokeLinecap="round"/>
      </svg>
    )},
    { id: 'history', label: 'History', icon: (c) => (
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
        <circle cx="8" cy="8" r="6.2" stroke={c} strokeWidth="1.4"/>
        <path d="M8 4.5V8l2.5 1.6" stroke={c} strokeWidth="1.4" strokeLinecap="round"/>
      </svg>
    )},
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 28, left: 0, right: 0,
      display: 'flex', justifyContent: 'center',
      pointerEvents: 'none',
    }}>
      <div style={{
        display: 'flex', gap: 6,
        background: R.surface, border: `1px solid ${R.border}`,
        padding: 6, borderRadius: 999,
        boxShadow: '0 8px 24px rgba(0,0,0,0.4)',
        pointerEvents: 'auto',
      }}>
        {tabs.map(t => {
          const on = t.id === active;
          return (
            <button key={t.id} style={{
              appearance: 'none', border: 'none', cursor: 'pointer',
              background: on ? R.raised : 'transparent',
              padding: '10px 18px', borderRadius: 999,
              display: 'flex', alignItems: 'center', gap: 8,
              fontFamily: R.font, fontSize: 12.5, fontWeight: 600,
              letterSpacing: '-0.005em',
              color: on ? R.accent : R.t2,
            }}>
              {t.icon(on ? R.accent : R.t2)}
              {t.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}

const iconBtn = {
  appearance: 'none', border: 'none', background: 'transparent',
  width: 32, height: 32, borderRadius: 8, cursor: 'pointer',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  color: R.t2,
};

// ─────────────────────────────────────────────────────────────
// HOME · today's captures + stat band
// ─────────────────────────────────────────────────────────────
function AppHome() {
  return (
    <div style={{ height: '100%', background: R.base, color: R.t1, position: 'relative' }}>
      <AppHeader
        eyebrow="Thursday · May 22"
        title="Three replies today."
        trailing={<button style={iconBtn}><Icon.search /></button>}
      />
      <div style={{ padding: `${R.s2}px 0 120px`, overflow: 'auto', height: 'calc(100% - 192px)' }}>
        {/* Stat band */}
        <div style={{
          margin: `${R.s2}px ${R.s5}px ${R.s5}px`,
          padding: `${R.s4}px ${R.s4}px`,
          background: R.surface, border: `1px solid ${R.border}`,
          borderRadius: R.rmd,
        }}>
          <Label color={R.t3} style={{ marginBottom: 14 }}>This week</Label>
          <div style={{ display: 'flex', gap: 28 }}>
            {[
              { v: '47', l: 'sent' },
              { v: '12m', l: 'saved', accent: true },
              { v: '94%', l: 'accepted' },
            ].map((s, i) => (
              <div key={i}>
                <div style={{
                  fontFamily: R.font, fontSize: 28, fontWeight: 600,
                  letterSpacing: '-0.025em', lineHeight: 1,
                  color: s.accent ? R.accent : R.t1,
                  fontVariantNumeric: 'tabular-nums',
                }}>{s.v}</div>
                <Label color={R.t3} style={{ marginTop: 6 }}>{s.l}</Label>
              </div>
            ))}
          </div>
        </div>

        {/* Today's captures */}
        <div style={{ padding: `0 ${R.s5}px ${R.s3}px` }}>
          <Label color={R.t3}>Today</Label>
        </div>
        {TODAY_CAPTURES.map((c, i, a) => (
          <CaptureRow key={i} {...c} isLast={i === a.length - 1} />
        ))}

        {/* People you reply to most */}
        <div style={{ padding: `${R.s6}px ${R.s5}px ${R.s3}px` }}>
          <Label color={R.t3}>People you reply to most</Label>
        </div>
        <div style={{ padding: `0 ${R.s5}px`, display: 'flex', gap: 12, overflow: 'auto' }}>
          {[
            { name: 'Maya Acheson', tag: 'Best friend', count: 142 },
            { name: 'Daniel Park', tag: 'Partner', count: 98 },
            { name: 'Priya Shankar', tag: 'Boss', count: 64 },
          ].map(p => (
            <div key={p.name} style={{
              minWidth: 168, flexShrink: 0,
              padding: R.s4,
              background: R.surface, border: `1px solid ${R.border}`,
              borderRadius: R.rmd,
            }}>
              <Avatar name={p.name} size={32} />
              <div style={{
                fontFamily: R.font, fontSize: 14, fontWeight: 500,
                color: R.t1, marginTop: 12, letterSpacing: '-0.01em',
              }}>{p.name}</div>
              <Label color={R.t3} style={{ marginTop: 2 }}>{p.tag}</Label>
              <div style={{
                fontFamily: R.font, fontSize: 22, fontWeight: 600,
                color: R.accent, marginTop: 14,
                letterSpacing: '-0.02em',
                fontVariantNumeric: 'tabular-nums',
                display: 'flex', alignItems: 'baseline', gap: 6,
              }}>
                {p.count}
                <span style={{ fontFamily: R.font, fontSize: 11, fontWeight: 500, color: R.t3, letterSpacing: '-0.005em' }}>replies</span>
              </div>
            </div>
          ))}
        </div>
      </div>
      <TabBar active="home" />
    </div>
  );
}

function CaptureRow({ time, name, snippet, tone, app, isLast }) {
  return (
    <button style={{
      appearance: 'none', border: 'none', textAlign: 'left',
      width: '100%', padding: `${R.s4}px ${R.s5}px`,
      background: 'transparent', cursor: 'pointer',
      display: 'flex', alignItems: 'flex-start', gap: 14,
      borderBottom: isLast ? 'none' : `1px solid ${R.border}`,
    }}>
      <div style={{ width: 40, flexShrink: 0, paddingTop: 2 }}>
        <Mono color={R.t2}>{time}</Mono>
        <Label color={R.t4} style={{ marginTop: 2, fontSize: 10 }}>{app}</Label>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
          <span style={{ fontFamily: R.font, fontSize: 14, fontWeight: 500, color: R.t1, letterSpacing: '-0.005em' }}>
            {name}
          </span>
          <Mono color={R.t4}>·</Mono>
          <Label color={R.t3}>{tone}</Label>
        </div>
        <div style={{
          fontFamily: R.font, fontSize: 13.5, color: R.t2,
          letterSpacing: '-0.005em', lineHeight: 1.4,
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
          overflow: 'hidden',
        }}>{snippet}</div>
      </div>
      <Icon.chev style={{ color: R.t4, marginTop: 6, flexShrink: 0 }} />
    </button>
  );
}

const TODAY_CAPTURES = [
  { time: '14:32', name: 'Maya Acheson', tone: 'Casual', app: 'IMSG',
    snippet: "Friday works — want me to grab the table or you got it?" },
  { time: '11:08', name: 'Priya Shankar', tone: 'Direct', app: 'MAIL',
    snippet: "Approved on my side — the contractor line should sit under Ops, not Marketing." },
  { time: '09:14', name: 'Daniel Park', tone: 'Friendly', app: 'IMSG',
    snippet: "On it. Picking up flowers on the way home — peonies?" },
];

// ─────────────────────────────────────────────────────────────
// PEOPLE · relationship list
// ─────────────────────────────────────────────────────────────
function AppPeople() {
  return (
    <div style={{ height: '100%', background: R.base, position: 'relative' }}>
      <AppHeader
        eyebrow="74 people · 6 relationships"
        title="People."
        trailing={<button style={iconBtn}><Icon.search /></button>}
      />
      <div style={{
        padding: `0 ${R.s5}px ${R.s4}px`, display: 'flex', gap: 6, overflow: 'auto',
      }}>
        {['All', 'Best friends 4', 'Family 12', 'Partner 1', 'Colleagues 18', 'Boss 3'].map((t, i) => (
          <button key={t} style={{
            appearance: 'none', cursor: 'pointer', flexShrink: 0,
            padding: '7px 12px',
            background: i === 0 ? R.t1 : 'transparent',
            color: i === 0 ? R.base : R.t2,
            border: i === 0 ? 'none' : `1px solid ${R.border}`,
            borderRadius: 999,
            fontFamily: R.font, fontSize: 12.5, fontWeight: 500, letterSpacing: '-0.005em',
          }}>{t}</button>
        ))}
      </div>
      <div style={{ overflow: 'auto', paddingBottom: 120, height: 'calc(100% - 220px)' }}>
        {PEOPLE.map((p, i, a) => (
          <PersonRow key={p.name} {...p} isLast={i === a.length - 1} />
        ))}
      </div>
      <TabBar active="people" />
    </div>
  );
}

function PersonRow({ name, tag, lastReplied, fresh, isLast }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 14,
      padding: `${R.s4}px ${R.s5}px`,
      borderBottom: isLast ? 'none' : `1px solid ${R.border}`,
    }}>
      <Avatar name={name} size={40} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontFamily: R.font, fontSize: 14.5, fontWeight: 500, color: R.t1, letterSpacing: '-0.01em' }}>{name}</span>
          {fresh && <span style={{ width: 6, height: 6, borderRadius: 6, background: R.accent }} />}
        </div>
        <Label color={R.t3} style={{ marginTop: 3 }}>
          {tag} · last reply {lastReplied}
        </Label>
      </div>
      <Icon.chev style={{ color: R.t4 }} />
    </div>
  );
}

const PEOPLE = [
  { name: 'Maya Acheson', tag: 'Best friend', lastReplied: '2h ago', fresh: true },
  { name: 'Daniel Park', tag: 'Partner', lastReplied: '5h ago' },
  { name: 'Priya Shankar', tag: 'Boss', lastReplied: '3h ago' },
  { name: 'Jordan Reyes', tag: 'Colleague', lastReplied: 'yesterday', fresh: true },
  { name: 'Elena Whitfield', tag: 'Sister', lastReplied: '2d ago' },
  { name: 'Theo Ng', tag: 'Friend', lastReplied: '4d ago' },
  { name: 'Marcus Adler', tag: 'Dad', lastReplied: 'last week' },
];

// ─────────────────────────────────────────────────────────────
// RELATIONSHIP TAGGING (sheet over a dimmed app)
// ─────────────────────────────────────────────────────────────
function RelationshipTagger() {
  const [picked, setPicked] = React.useState('Best friend');
  return (
    <div style={{
      height: '100%', background: R.base, position: 'relative', overflow: 'hidden',
    }}>
      {/* dimmed faux backdrop */}
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.55)', zIndex: 1 }} />
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        background: R.surface,
        borderTopLeftRadius: R.rlg, borderTopRightRadius: R.rlg,
        padding: `${R.s3}px ${R.s5}px ${R.s6}px`,
        zIndex: 2,
        boxShadow: '0 -16px 40px rgba(0,0,0,0.4)',
      }}>
        <div style={{ width: 36, height: 4, background: R.raisedHi, borderRadius: 4, margin: '0 auto 18px' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 20 }}>
          <Avatar name="Maya Acheson" size={44} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: R.font, fontSize: 16, fontWeight: 500, color: R.t1, letterSpacing: '-0.01em' }}>
              Maya Acheson
            </div>
            <Mono color={R.t3} style={{ marginTop: 2 }}>+1 (415) 555 0142</Mono>
          </div>
        </div>
        <div style={{
          fontFamily: R.font, fontSize: 22, fontWeight: 600,
          color: R.t1, marginBottom: 14, letterSpacing: '-0.02em', lineHeight: 1.1,
        }}>Who is Maya to you?</div>
        <Label color={R.t3} style={{ marginBottom: 12 }}>Pick one — you can change it later</Label>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {[
            'Best friend', 'Friend', 'Partner', 'Family', 'Boss',
            'Colleague', 'Client', 'Acquaintance', 'Custom',
          ].map(t => (
            <button key={t} onClick={() => setPicked(t)} style={{
              appearance: 'none', cursor: 'pointer',
              padding: '10px 14px',
              background: t === picked ? R.accent : R.raised,
              color: t === picked ? R.accentText : R.t1,
              border: 'none',
              borderRadius: R.rsm,
              fontFamily: R.font, fontSize: 13.5, fontWeight: 500, letterSpacing: '-0.005em',
            }}>{t}</button>
          ))}
        </div>
        <div style={{
          marginTop: 18, padding: '12px 14px',
          background: R.raised, border: `1px solid ${R.border}`, borderRadius: R.rsm,
          display: 'flex', alignItems: 'flex-start', gap: 10,
        }}>
          <Icon.spark style={{ color: R.accent, marginTop: 2, flexShrink: 0 }} />
          <div style={{ fontFamily: R.font, fontSize: 12.5, color: R.t2, lineHeight: 1.45, letterSpacing: '-0.005em' }}>
            <span style={{ color: R.t1 }}>"Best friend"</span> tells Replr to keep replies short, warm, often without punctuation.
          </div>
        </div>
        <div style={{ marginTop: 18 }}>
          <Primary>Save</Primary>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  AppHome, AppPeople, AppHeader, TabBar, RelationshipTagger,
  iconBtn, PEOPLE, TODAY_CAPTURES,
});
