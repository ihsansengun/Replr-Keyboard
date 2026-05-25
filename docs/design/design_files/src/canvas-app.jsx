// Replr v2 — canvas app. Wires every screen into one design canvas.

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "coral",
  "showCoachmark": true,
  "toneOnIdle": true
}/*EDITMODE-END*/;

const ACCENTS = {
  coral:  { v: '#FF5A4D', dim: '#B43E35', soft: 'rgba(255,90,77,0.12)',  text: '#1A0707', name: 'Coral' },
  amber:  { v: '#F5C24E', dim: '#B58B2E', soft: 'rgba(245,194,78,0.14)', text: '#1A1306', name: 'Amber' },
  lime:   { v: '#BEF264', dim: '#85A845', soft: 'rgba(190,242,100,0.14)',text: '#0F1505', name: 'Lime'  },
  iris:   { v: '#A78BFA', dim: '#7A63C5', soft: 'rgba(167,139,250,0.14)',text: '#0F0820', name: 'Iris'  },
};

function ReplrCanvas() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  // Push accent into R so inline-styled components see updates.
  React.useEffect(() => {
    const a = ACCENTS[t.accent] || ACCENTS.coral;
    R.accent = a.v;
    R.accentDim = a.dim;
    R.accentSoft = a.soft;
    R.accentText = a.text;
    document.documentElement.style.setProperty('--accent', a.v);
  }, [t.accent]);

  return (
    <>
      <DesignCanvas>
        <DCSection id="system" title="Replr · the system" subtitle="Dark surfaces, one coral, one typeface, an 8px grid. The keyboard is not editorial — it's a tool that sits inside someone else's app.">
          <DCArtboard id="sys" label="System" width={820} height={460}>
            <SystemOverview t={t} setTweak={setTweak} />
          </DCArtboard>
        </DCSection>

        <DCSection id="moment" title="The capture moment" subtitle="The keyboard can't screenshot its host — so capture is two steps. The redesign turns it into a guided one-tap motion.">
          <DCArtboard id="m1" label="① Tap Capture" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><MomentFrame1 /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="m2" label="② Triple-tap the back" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><MomentFrame2 /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="m3" label="③ Reply ready" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><MomentFrame3 /></IOSDevice>
          </DCArtboard>
        </DCSection>

        <DCSection id="kb" title="Keyboard · every state" subtitle="One amber/coral per state. The reply card is the hero on the screen it appears.">
          <DCArtboard id="k-idle-chat" label="Idle · Chat" width={402} height={874}>
            <KbInPhone state="idle-chat" />
          </DCArtboard>
          <DCArtboard id="k-idle-email" label="Idle · Email · no clip" width={402} height={874}>
            <KbInPhone state="idle-email" />
          </DCArtboard>
          <DCArtboard id="k-idle-email-ready" label="Idle · Email · ready" width={402} height={874}>
            <KbInPhone state="idle-email-ready" />
          </DCArtboard>
          <DCArtboard id="k-capture" label="Capture bar" width={402} height={874}>
            <KbInPhone state="capture" />
          </DCArtboard>
          <DCArtboard id="k-capture-coach" label="Capture · first-run" width={402} height={874}>
            <KbInPhone state="capture" coachmark />
          </DCArtboard>
          <DCArtboard id="k-loading" label="Loading · reading" width={402} height={874}>
            <KbInPhone state="loading" />
          </DCArtboard>
          <DCArtboard id="k-replies" label="Replies · 1 of 3" width={402} height={874}>
            <KbInPhone state="replies" position={1} />
          </DCArtboard>
          <DCArtboard id="k-replies2" label="Replies · 2 of 3" width={402} height={874}>
            <KbInPhone state="replies" position={2} />
          </DCArtboard>
          <DCArtboard id="k-edit" label="Edit reply" width={402} height={874}>
            <KbInPhone state="edit" />
          </DCArtboard>
          <DCArtboard id="k-rename" label="Rename contact" width={402} height={874}>
            <KbInPhone state="rename" />
          </DCArtboard>
          <DCArtboard id="k-error" label="Error" width={402} height={874}>
            <KbInPhone state="error" />
          </DCArtboard>
        </DCSection>

        <DCSection id="kbzoom" title="Keyboard · anatomy" subtitle="Replies up close — the type, the dots, the actions.">
          <DCArtboard id="kz" label="Replies — 2× scale" width={820} height={500}>
            <KeyboardAnatomy />
          </DCArtboard>
        </DCSection>

        <DCSection id="onboarding" title="Onboarding · six steps" subtitle="Triple-tap and a custom Shortcut are real iOS plumbing. The framing makes them feel inevitable.">
          <DCArtboard id="o0" label="Welcome" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><OnbWelcome /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="o1" label="01 · Add keyboard" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><OnbStep1 /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="o2" label="02 · Full access" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><OnbStep2 /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="o3" label="03 · Latest photo" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><OnbStep3 /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="o4" label="04 · Install Shortcut" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><OnbStep4 /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="o5" label="05 · Back Tap" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><OnbStep5 /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="o6" label="06 · Default tone" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><OnbStep6 /></IOSDevice>
          </DCArtboard>
        </DCSection>

        <DCSection id="app" title="Companion app" subtitle="Two tabs, like the live build. The keyboard is the product; the app is configuration + audit.">
          <DCArtboard id="a-hist" label="History · empty" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><AppHistoryEmpty /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="a-hist-full" label="History · with captures" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><AppHistory /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="a-detail" label="Capture detail" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><CaptureDetail /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="a-mem-edit" label="Memory editor" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><MemoryEditor /></IOSDevice>
          </DCArtboard>
          <DCArtboard id="a-set" label="Settings" width={402} height={874}>
            <IOSDevice width={402} height={874} dark><AppSettings /></IOSDevice>
          </DCArtboard>
        </DCSection>

        <DCSection id="memory" title="Memory · the simple model" subtitle="One short paragraph per contact, refined silently after each capture. No transcripts, no per-capture archive — just what Replr has learned about how you talk to them.">
          <DCArtboard id="mem-card" label="In capture detail" width={760} height={520}>
            <MemoryCardZoom />
          </DCArtboard>
        </DCSection>
      </DesignCanvas>

      <TweaksPanel>
        <TweakSection label="Brand" />
        <TweakColor label="Accent" value={ACCENTS[t.accent].v}
                    options={Object.values(ACCENTS).map(a => a.v)}
                    onChange={(hex) => {
                      const key = Object.keys(ACCENTS).find(k => ACCENTS[k].v === hex);
                      setTweak('accent', key || 'coral');
                    }} />
        <TweakSection label="Capture flow" />
        <TweakToggle label="First-run coachmark" value={t.showCoachmark}
                     onChange={(v) => setTweak('showCoachmark', v)} />
      </TweaksPanel>
    </>
  );
}

// — Phone-shaped wrapper that places the keyboard at the bottom with a host
//   stub above, so each keyboard state reads in context.
function KbInPhone({ state, position, coachmark }) {
  // Capture state is small (~64px). Other expanded states are taller.
  return (
    <IOSDevice width={402} height={874} dark>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}>
          <ChatHost dim={state === 'capture' || state === 'loading'} />
        </div>
        <ReplrKeyboard state={state} position={position} coachmark={coachmark} />
      </div>
    </IOSDevice>
  );
}

// ─────────────────────────────────────────────────────────────
// System overview artboard
// ─────────────────────────────────────────────────────────────
function SystemOverview({ t, setTweak }) {
  return (
    <div style={{
      width: '100%', height: '100%', background: R.base, color: R.t1,
      padding: 36, display: 'grid', gridTemplateColumns: '1.1fr 1fr', gap: 40,
    }}>
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        <Mark size={20} />
        <h1 style={{
          fontFamily: R.font, fontSize: 46, fontWeight: 600,
          letterSpacing: '-0.03em', lineHeight: 1.02,
          color: R.t1, margin: '24px 0 0',
        }}>
          The reply is<br/>
          <span style={{ color: R.t3 }}>already written.</span>
        </h1>
        <p style={{
          fontFamily: R.font, fontSize: 14.5, color: R.t2, margin: 0,
          letterSpacing: '-0.005em', lineHeight: 1.55, textWrap: 'pretty',
          maxWidth: 400, marginTop: 18,
        }}>
          Replr is a dark, single-coral system built around a two-step capture flow that's the central UX challenge. Every screen has one job, one primary action, no editorial flourish.
        </p>
        <div style={{ flex: 1 }} />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16, marginTop: 20 }}>
          <Spec label="Type" v={<>Geist · single family<br/>500 weight · −0.025em</>} />
          <Spec label="Palette" v={<>Black · 3 grays<br/>One coral spotlight</>} />
          <Spec label="Grid" v={<>8px scale, strict<br/>16px panel margins</>} />
        </div>
      </div>
      <div style={{
        background: R.surface, border: `1px solid ${R.border}`,
        borderRadius: R.rmd, padding: 24,
        display: 'flex', flexDirection: 'column', gap: 18,
      }}>
        <div>
          <Label color={R.t3} style={{ marginBottom: 10 }}>Surface ramp</Label>
          <div style={{ display: 'flex', gap: 6 }}>
            {[
              { n: 'base', c: R.base, fg: R.t1 },
              { n: 'surface', c: R.surface, fg: R.t1 },
              { n: 'raised', c: R.raised, fg: R.t1 },
              { n: 'raised+', c: R.raisedHi, fg: R.t1 },
              { n: 'accent', c: R.accent, fg: R.accentText },
            ].map(s => (
              <div key={s.n} style={{
                flex: 1, height: 56, background: s.c, borderRadius: R.rxs,
                border: `1px solid ${R.border}`,
                display: 'flex', alignItems: 'flex-end', padding: 8,
                fontFamily: R.font, fontSize: 11, fontWeight: 500, color: s.fg, letterSpacing: '-0.005em',
              }}>{s.n}</div>
            ))}
          </div>
        </div>
        <div>
          <Label color={R.t3} style={{ marginBottom: 10 }}>Type scale</Label>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {[
              { s: 32, w: 600, l: '-0.028em', t: 'Display 32 / 600' },
              { s: 20, w: 600, l: '-0.02em', t: 'Title 20 / 600' },
              { s: 15, w: 400, l: '-0.005em', t: 'Body 15 / 400' },
              { s: 12, w: 500, l: '-0.005em', t: 'Label 12 / 500' },
            ].map(r => (
              <div key={r.t} style={{
                fontFamily: R.font, fontSize: r.s, fontWeight: r.w,
                letterSpacing: r.l, color: R.t1, lineHeight: 1.1,
              }}>{r.t}</div>
            ))}
          </div>
        </div>
        <div style={{ flex: 1 }} />
        <div>
          <Label color={R.t3} style={{ marginBottom: 10 }}>Accent options</Label>
          <div style={{ display: 'flex', gap: 6 }}>
            {Object.entries(ACCENTS).map(([k, a]) => (
              <button key={k} onClick={() => setTweak('accent', k)} style={{
                flex: 1, padding: 10, borderRadius: R.rsm,
                background: R.raised,
                border: `1px solid ${t.accent === k ? a.v : R.border}`,
                cursor: 'pointer',
                display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'center',
              }}>
                <div style={{ width: '100%', height: 14, background: a.v, borderRadius: R.rxs }} />
                <Label color={t.accent === k ? R.t1 : R.t3} style={{ fontSize: 11 }}>{a.name}</Label>
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function Spec({ label, v }) {
  return (
    <div>
      <Label color={R.t3} style={{ marginBottom: 6 }}>{label}</Label>
      <div style={{ fontFamily: R.font, fontSize: 12.5, color: R.t1, letterSpacing: '-0.005em', lineHeight: 1.5 }}>{v}</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Keyboard anatomy artboard
// ─────────────────────────────────────────────────────────────
function KeyboardAnatomy() {
  return (
    <div style={{
      width: '100%', height: '100%', background: R.base,
      padding: 32, display: 'flex', gap: 36, alignItems: 'stretch',
    }}>
      <div style={{
        width: 380, borderRadius: R.rmd, overflow: 'hidden',
        border: `1px solid ${R.border}`,
        background: R.base, flexShrink: 0,
      }}>
        <ReplrKeyboard state="replies" />
      </div>
      <div style={{ flex: 1, paddingTop: 6, display: 'flex', flexDirection: 'column' }}>
        <Label color={R.accent} style={{ marginBottom: 8, fontSize: 11 }}>Anatomy</Label>
        <div style={{ fontFamily: R.font, fontSize: 32, fontWeight: 600, color: R.t1, letterSpacing: '-0.028em', lineHeight: 1.05 }}>
          Five elements.<br/>One job each.
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', marginTop: 28 }}>
          {[
            { n: '01', t: 'Chat / Email toggle', d: 'Navigation, never the hero. Neutral fill on selected.' },
            { n: '02', t: 'Contact row', d: 'Name capitalised, edit icon to rename, 1 of N on the right.' },
            { n: '03', t: 'Reply card', d: 'The reply is the hero. 16px body, comfortable padding, dots beneath.' },
            { n: '04', t: 'Action row', d: 'One coral Insert + a neutral Edit. Single primary per screen.' },
            { n: '05', t: 'Tone row', d: 'Lives here, next to its effect. Tap to regenerate in that tone.' },
          ].map((r, i, a) => (
            <div key={r.n} style={{
              display: 'flex', gap: 16, padding: '12px 0',
              borderBottom: i < a.length - 1 ? `1px solid ${R.border}` : 'none',
            }}>
              <Mono color={R.accent} style={{ width: 24, fontSize: 12 }}>{r.n}</Mono>
              <div>
                <div style={{ fontFamily: R.font, fontSize: 14.5, fontWeight: 500, color: R.t1, letterSpacing: '-0.005em' }}>{r.t}</div>
                <div style={{ fontFamily: R.font, fontSize: 12.5, color: R.t3, letterSpacing: '-0.005em', lineHeight: 1.45, marginTop: 4 }}>{r.d}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Memory card anatomy artboard — explains the simple model
// ─────────────────────────────────────────────────────────────
function MemoryCardZoom() {
  return (
    <div style={{
      width: '100%', height: '100%', background: R.base,
      padding: 36, display: 'flex', gap: 40, alignItems: 'stretch',
    }}>
      <div style={{ flex: 1, paddingTop: 6, display: 'flex', flexDirection: 'column', maxWidth: 340 }}>
        <Label color={R.accent} style={{ marginBottom: 8, fontSize: 11 }}>Memory</Label>
        <div style={{
          fontFamily: R.font, fontSize: 32, fontWeight: 600,
          color: R.t1, letterSpacing: '-0.028em', lineHeight: 1.05,
        }}>
          One paragraph<br/>per person.
        </div>
        <p style={{
          fontFamily: R.font, fontSize: 14, color: R.t2,
          letterSpacing: '-0.005em', lineHeight: 1.55, textWrap: 'pretty',
          margin: '18px 0 0',
        }}>
          Refined silently after each capture. No transcripts, no per-capture archive. Just what Replr has learned about how you talk to this person.
        </p>
        <div style={{ flex: 1 }} />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 28 }}>
          {[
            { n: '01', t: 'Plain language', d: 'Reads like a friend\'s note. No tags, no schema.' },
            { n: '02', t: 'Editable', d: 'Tap Edit to add or fix anything. You own the paragraph.' },
            { n: '03', t: 'Forgettable', d: 'One tap clears all of it. No undo, no shadow copy.' },
            { n: '04', t: 'On-device', d: 'Stored locally. Never sent to the model in plain text.' },
          ].map((r, i, a) => (
            <div key={r.n} style={{
              display: 'flex', gap: 14, paddingBottom: 14,
              borderBottom: i < a.length - 1 ? `1px solid ${R.border}` : 'none',
            }}>
              <Mono color={R.accent} style={{ width: 22, fontSize: 11 }}>{r.n}</Mono>
              <div>
                <div style={{ fontFamily: R.font, fontSize: 13.5, fontWeight: 500, color: R.t1, letterSpacing: '-0.005em' }}>{r.t}</div>
                <div style={{ fontFamily: R.font, fontSize: 12, color: R.t3, letterSpacing: '-0.005em', lineHeight: 1.45, marginTop: 3 }}>{r.d}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
      <div style={{
        flex: 1, background: R.surface, border: `1px solid ${R.border}`,
        borderRadius: R.rmd, padding: 24,
        display: 'flex', flexDirection: 'column', justifyContent: 'center',
      }}>
        <Label color={R.t3} style={{ marginBottom: 10 }}>
          Replr remembers about Maya · <span style={{ color: R.t4 }}>updated just now</span>
        </Label>
        <div style={{
          background: R.accentSoft, border: `1px solid ${R.accent}`,
          borderRadius: R.rmd, padding: 20,
        }}>
          <div style={{
            fontFamily: R.font, fontSize: 16, lineHeight: 1.55,
            color: R.t1, letterSpacing: '-0.005em', textWrap: 'pretty',
          }}>
            Best friend since 2019. Texts in short, dry bursts — rarely punctuation, often nicknames. Has a cat named Sergio. Just back from a trip to Lisbon together. Doesn't do brunch — late dinners or coffee only.
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
            <button style={{
              appearance: 'none', cursor: 'pointer',
              background: R.base, color: R.t1, border: `1px solid ${R.borderStrong}`,
              padding: '8px 14px', borderRadius: R.rsm,
              fontFamily: R.font, fontSize: 13, fontWeight: 500, letterSpacing: '-0.005em',
              display: 'inline-flex', alignItems: 'center', gap: 6,
            }}>
              <Icon.edit /> Edit
            </button>
            <button style={{
              appearance: 'none', cursor: 'pointer',
              background: 'transparent', color: R.t2, border: `1px solid ${R.border}`,
              padding: '8px 14px', borderRadius: R.rsm,
              fontFamily: R.font, fontSize: 13, fontWeight: 500, letterSpacing: '-0.005em',
            }}>Forget</button>
          </div>
        </div>
        <Label color={R.t4} style={{ marginTop: 14, fontSize: 11.5, lineHeight: 1.5 }}>
          That's the whole memory surface. No timeline, no facts list, no schema.
        </Label>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<ReplrCanvas />);
