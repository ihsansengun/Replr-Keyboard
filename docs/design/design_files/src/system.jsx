// Replr v2 — design system: tokens, mark, type, icons.
// Discipline: single typeface (Geist), single accent (coral), strict 8px grid.

const R = {
  // Surfaces
  base: '#0A0A0B',
  surface: '#131318',
  raised: '#1E1E25',
  raisedHi: '#2A2A33',
  border: 'rgba(255,255,255,0.07)',
  borderStrong: 'rgba(255,255,255,0.12)',

  // Text
  t1: '#F4F4F2',       // primary
  t2: '#8E8E92',       // secondary
  t3: '#5C5C60',       // tertiary
  t4: '#3D3D42',       // disabled

  // Accent (coral)
  accent: '#FF5A4D',
  accentDim: '#B43E35',
  accentSoft: 'rgba(255,90,77,0.12)',
  accentText: '#1A0707',

  success: '#4ADE80',
  warning: '#F5C24E',

  // Font
  font: '"Geist", -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif',
  fontMono: '"Geist Mono", ui-monospace, "JetBrains Mono", Menlo, monospace',

  // Spacing
  s1: 4, s2: 8, s3: 12, s4: 16, s5: 24, s6: 32, s7: 48, s8: 64,

  // Radii
  rxs: 4, rsm: 8, rmd: 12, rlg: 16, rxl: 20,
};

// — Brand wordmark — clean lowercase with a single dot —
function Mark({ size = 18, color, dotColor, style }) {
  return (
    <span style={{
      display: 'inline-flex',
      alignItems: 'center',
      gap: 0,
      fontFamily: R.font,
      fontWeight: 500,
      fontSize: size,
      lineHeight: 1,
      letterSpacing: '-0.04em',
      color: color || R.t1,
      ...style,
    }}>
      replr
      <span style={{
        width: size * 0.22,
        height: size * 0.22,
        borderRadius: '50%',
        background: dotColor || R.accent,
        marginLeft: size * 0.12,
        marginBottom: -size * 0.02,
      }} />
    </span>
  );
}

// — Label (small caps, lowercase, well-tracked) —
function Label({ children, color, style, size = 11 }) {
  return (
    <div style={{
      fontFamily: R.font,
      fontSize: size,
      fontWeight: 500,
      letterSpacing: '0.01em',
      color: color || R.t2,
      ...style,
    }}>{children}</div>
  );
}

// — Mono caption for counts, timestamps, technical bits —
function Mono({ children, color, style, size = 11 }) {
  return (
    <span style={{
      fontFamily: R.fontMono,
      fontSize: size,
      fontWeight: 400,
      letterSpacing: '-0.005em',
      color: color || R.t3,
      fontVariantNumeric: 'tabular-nums',
      ...style,
    }}>{children}</span>
  );
}

// — Avatar with monogram —
function Avatar({ name = '?', size = 40, bg, style }) {
  const palette = ['#FF5A4D', '#4ADE80', '#60A5FA', '#F5C24E', '#A78BFA', '#FB7185'];
  const idx = ((name.charCodeAt(0) || 0) + (name.charCodeAt(1) || 0)) % palette.length;
  const initials = name.split(' ').map(s => s[0]).slice(0, 2).join('').toUpperCase();
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: bg || palette[idx],
      color: R.base,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: R.font, fontSize: size * 0.36, fontWeight: 600,
      letterSpacing: '-0.02em', flexShrink: 0,
      ...style,
    }}>{initials}</div>
  );
}

// — Hairline divider —
function Divider({ color, style }) {
  return <div style={{ height: 1, background: color || R.border, ...style }} />;
}

// — Primary button (single coral per screen) —
function Primary({ children, leading, trailing, disabled, full = true, onClick, style }) {
  return (
    <button onClick={onClick} disabled={disabled} style={{
      appearance: 'none', border: 'none', cursor: disabled ? 'default' : 'pointer',
      background: disabled ? R.raised : R.accent,
      color: disabled ? R.t3 : R.accentText,
      width: full ? '100%' : 'auto',
      height: 48,
      borderRadius: R.rmd,
      padding: '0 16px',
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      fontFamily: R.font, fontSize: 15, fontWeight: 600, letterSpacing: '-0.01em',
      transition: 'background 0.15s',
      ...style,
    }}>
      {leading}
      {children}
      {trailing}
    </button>
  );
}

// — Secondary button (neutral) —
function Secondary({ children, leading, full = false, onClick, style }) {
  return (
    <button onClick={onClick} style={{
      appearance: 'none', border: 'none', cursor: 'pointer',
      background: R.raised, color: R.t1,
      width: full ? '100%' : 'auto',
      height: 48,
      borderRadius: R.rmd,
      padding: '0 18px',
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      fontFamily: R.font, fontSize: 15, fontWeight: 500, letterSpacing: '-0.01em',
      ...style,
    }}>
      {leading}
      {children}
    </button>
  );
}

// — Icon set (line, 1.5 stroke, 16x16 base) —
const Icon = {
  back: (p = {}) => <svg width="16" height="16" viewBox="0 0 16 16" fill="none" {...p}><path d="M10 3L5 8l5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  chev: (p = {}) => <svg width="12" height="12" viewBox="0 0 12 12" fill="none" {...p}><path d="M4 2l4 4-4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  chevDown: (p = {}) => <svg width="10" height="6" viewBox="0 0 10 6" fill="none" {...p}><path d="M1 1l4 4 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  plus: (p = {}) => <svg width="14" height="14" viewBox="0 0 14 14" fill="none" {...p}><path d="M7 2v10M2 7h10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>,
  close: (p = {}) => <svg width="14" height="14" viewBox="0 0 14 14" fill="none" {...p}><path d="M3 3l8 8M11 3l-8 8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>,
  check: (p = {}) => <svg width="14" height="14" viewBox="0 0 14 14" fill="none" {...p}><path d="M2.5 7.5l3 3 6-7" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  search: (p = {}) => <svg width="16" height="16" viewBox="0 0 16 16" fill="none" {...p}><circle cx="7" cy="7" r="5" stroke="currentColor" strokeWidth="1.4"/><path d="M11 11l3 3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/></svg>,
  globe: (p = {}) => <svg width="16" height="16" viewBox="0 0 16 16" fill="none" {...p}><circle cx="8" cy="8" r="6.2" stroke="currentColor" strokeWidth="1.3"/><path d="M1.8 8h12.4M8 1.8c2.3 2.3 2.3 10.1 0 12.4M8 1.8c-2.3 2.3-2.3 10.1 0 12.4" stroke="currentColor" strokeWidth="1.3"/></svg>,
  return: (p = {}) => <svg width="18" height="14" viewBox="0 0 18 14" fill="none" {...p}><path d="M16 1v6H4m0 0l3-3M4 7l3 3" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  mic: (p = {}) => <svg width="14" height="16" viewBox="0 0 14 16" fill="none" {...p}><rect x="4.5" y="1.5" width="5" height="8" rx="2.5" stroke="currentColor" strokeWidth="1.4"/><path d="M1.5 8a5.5 5.5 0 0011 0M7 13.5V15" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/></svg>,
  spark: (p = {}) => <svg width="14" height="14" viewBox="0 0 14 14" fill="none" {...p}><path d="M7 1.5l1.6 4 4 1.5-4 1.5L7 12.5l-1.6-4-4-1.5 4-1.5L7 1.5z" fill="currentColor"/></svg>,
  arrow: (p = {}) => <svg width="16" height="16" viewBox="0 0 16 16" fill="none" {...p}><path d="M3 8h10m0 0L9 4m4 4l-4 4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  arrowUp: (p = {}) => <svg width="16" height="16" viewBox="0 0 16 16" fill="none" {...p}><path d="M8 13V3m0 0l4 4M8 3L4 7" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  refresh: (p = {}) => <svg width="14" height="14" viewBox="0 0 14 14" fill="none" {...p}><path d="M2 7a5 5 0 018-3.5L11 5M12 7a5 5 0 01-8 3.5L3 9M11 2v3H8M3 12V9h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  envelope: (p = {}) => <svg width="16" height="13" viewBox="0 0 16 13" fill="none" {...p}><rect x="1.2" y="1.2" width="13.6" height="10.6" rx="1.5" stroke="currentColor" strokeWidth="1.4"/><path d="M1.5 2.5l6.5 5 6.5-5" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/></svg>,
  dots: (p = {}) => <svg width="16" height="4" viewBox="0 0 16 4" fill="none" {...p}><circle cx="2" cy="2" r="1.5" fill="currentColor"/><circle cx="8" cy="2" r="1.5" fill="currentColor"/><circle cx="14" cy="2" r="1.5" fill="currentColor"/></svg>,
  edit: (p = {}) => <svg width="14" height="14" viewBox="0 0 14 14" fill="none" {...p}><path d="M9.5 1.5l3 3-7.5 7.5H2v-3l7.5-7.5z" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/></svg>,
  bolt: (p = {}) => <svg width="12" height="16" viewBox="0 0 12 16" fill="none" {...p}><path d="M8 1L1 9h4l-1 6 7-8H7l1-6z" fill="currentColor"/></svg>,
  clip: (p = {}) => <svg width="14" height="14" viewBox="0 0 14 14" fill="none" {...p}><rect x="3" y="2" width="8" height="11" rx="1.2" stroke="currentColor" strokeWidth="1.4"/><path d="M5.5 1.5h3v2h-3z" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round" fill="currentColor"/></svg>,
  copy: (p = {}) => <svg width="14" height="14" viewBox="0 0 14 14" fill="none" {...p}><rect x="3.5" y="3.5" width="8" height="9" rx="1.2" stroke="currentColor" strokeWidth="1.4"/><path d="M9.5 3V2a1 1 0 00-1-1H3a1 1 0 00-1 1v6.5a1 1 0 001 1h.5" stroke="currentColor" strokeWidth="1.4"/></svg>,
  shield: (p = {}) => <svg width="14" height="14" viewBox="0 0 14 14" fill="none" {...p}><path d="M7 1l5 1.5v5c0 3-2.5 5-5 5.5C4.5 12 2 10 2 7.5v-5L7 1z" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/></svg>,
  warn: (p = {}) => <svg width="16" height="16" viewBox="0 0 16 16" fill="none" {...p}><path d="M8 1.5L15 14H1L8 1.5z" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/><path d="M8 6v3.5M8 11.5v.5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/></svg>,
};

// — Compact eyebrow-ish: small all-lower label —
function Eyebrow({ children, color, style }) {
  return (
    <div style={{
      fontFamily: R.font, fontSize: 12, fontWeight: 500,
      color: color || R.t2, letterSpacing: '-0.005em',
      ...style,
    }}>{children}</div>
  );
}

Object.assign(window, { R, Mark, Label, Mono, Eyebrow, Avatar, Divider, Primary, Secondary, Icon });
