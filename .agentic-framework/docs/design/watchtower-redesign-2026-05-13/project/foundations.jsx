// Foundations: type pairing cards + color palette cards.
// Each is sized to live in a DCArtboard (~540 × 360).

// ── Type pairings ───────────────────────────────────────────────────────────

const TYPE_PAIRS = [
  {
    id: 'inter',
    label: 'A · Modern technical',
    sans: 'Inter',
    mono: 'JetBrains Mono',
    desc: 'Neutral, optical clarity. Workhorse for dense product UI.',
    bg: '#ffffff', fg: '#0e1116', muted: '#5f6772', accent: '#1f2937',
  },
  {
    id: 'geist',
    label: 'B · Quiet & contemporary',
    sans: 'Geist',
    mono: 'Geist Mono',
    desc: 'Vercel-quiet. Geometric, even color, generous counters.',
    bg: '#fafafa', fg: '#0a0a0a', muted: '#737373', accent: '#0a0a0a',
  },
  {
    id: 'plex',
    label: 'C · Engineered, slightly warm',
    sans: 'IBM Plex Sans',
    mono: 'IBM Plex Mono',
    desc: 'Mechanical character, distinctive numerals. Reads serious.',
    bg: '#fbfaf6', fg: '#1b1a17', muted: '#646057', accent: '#3a3633',
  },
  {
    id: 'manrope',
    label: 'D · Friendly, rounded',
    sans: 'Manrope',
    mono: 'DM Mono',
    desc: 'Softer terminals, approachable. Less austere than Inter.',
    bg: '#fbfaf8', fg: '#15141a', muted: '#6c6a78', accent: '#1a1923',
  },
  {
    id: 'newsreader',
    label: 'E · Editorial serif headlines',
    sans: 'Newsreader',
    serifHead: true,
    mono: 'JetBrains Mono',
    bodySans: 'Inter',
    desc: 'Serif H1s, sans body. Slows the eye on heroes & section heads.',
    bg: '#faf8f3', fg: '#1c1a15', muted: '#69635a', accent: '#3a342b',
  },
  {
    id: 'system',
    label: 'F · Native & fast',
    sans: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui',
    mono: 'ui-monospace, "SF Mono", Menlo',
    desc: 'No web font load. Matches the user’s OS \u2014 zero latency.',
    bg: '#ffffff', fg: '#111111', muted: '#6b6b6b', accent: '#111111',
  },
];

const TypePairCard = ({ pair, selected, onSelect }) => {
  const headFont = pair.serifHead ? 'Newsreader' : pair.sans;
  const bodyFont = pair.bodySans || pair.sans;
  return (
    <div className="ab" onClick={onSelect} style={{
      background: pair.bg, color: pair.fg,
      padding: '22px 26px 20px',
      display: 'flex', flexDirection: 'column', gap: 14,
      cursor: 'pointer',
      boxShadow: selected ? `inset 0 0 0 3px ${pair.accent}` : 'none',
      transition: 'box-shadow .15s',
    }}>
      {selected && (
        <div style={{
          position: 'absolute', top: 10, right: 10,
          width: 22, height: 22, borderRadius: 999,
          background: pair.accent, color: pair.bg,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: '0 1px 3px rgba(0,0,0,0.2)', zIndex: 2,
        }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </div>
      )}
      {/* eyebrow */}
      <div style={{
        fontFamily: 'JetBrains Mono, ui-monospace, monospace',
        fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase',
        color: pair.muted, display: 'flex', justifyContent: 'space-between',
      }}>
        <span>{pair.label}</span>
        <span>{pair.sans.split(',')[0]} · {pair.mono.split(',')[0]}</span>
      </div>

      {/* showpiece headline */}
      <div style={{ fontFamily: headFont, fontWeight: 600, fontSize: 36, lineHeight: 1.05, letterSpacing: pair.serifHead ? '-0.01em' : '-0.02em', color: pair.accent }}>
        Watchtower
      </div>

      {/* body sample */}
      <div style={{ fontFamily: bodyFont, fontSize: 13, lineHeight: 1.5, color: pair.fg }}>
        {pair.desc}
      </div>

      {/* numerals + UI snippet */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginTop: 'auto' }}>
        <div>
          <div style={{ fontFamily: 'JetBrains Mono, ui-monospace, monospace', fontSize: 9, letterSpacing: '0.1em', textTransform: 'uppercase', color: pair.muted, marginBottom: 4 }}>Body 13 / Mono 12</div>
          <div style={{ fontFamily: bodyFont, fontSize: 13, fontWeight: 500, color: pair.fg }}>Approvals queue</div>
          <div style={{ fontFamily: pair.mono, fontSize: 12, color: pair.muted }}>T-1453 · ready</div>
        </div>
        <div>
          <div style={{ fontFamily: 'JetBrains Mono, ui-monospace, monospace', fontSize: 9, letterSpacing: '0.1em', textTransform: 'uppercase', color: pair.muted, marginBottom: 4 }}>Numerals</div>
          <div style={{ fontFamily: pair.mono, fontSize: 18, fontVariantNumeric: 'tabular-nums', fontWeight: 500, color: pair.accent }}>1,284 · 99.7%</div>
        </div>
      </div>

      {/* footnote pill */}
      <div style={{
        marginTop: 4, alignSelf: 'flex-start',
        display: 'inline-flex', alignItems: 'center', gap: 6,
        padding: '3px 8px', borderRadius: 999,
        background: 'rgba(0,0,0,0.04)',
        fontFamily: pair.mono, fontSize: 10, color: pair.muted,
      }}>
        <span>Aa Bb Cc · 0123 · — ‘ ’ “ ”</span>
      </div>
    </div>
  );
};

// ── Color palettes ─────────────────────────────────────────────────────────

const PALETTES = [
  {
    id: 'slate',
    label: 'P1 · Slate + Indigo',
    desc: 'Cool, technical. Default Linear / Vercel-adjacent.',
    bg: '#fafafa',
    surface: '#ffffff',
    border: '#e5e7eb',
    text: '#0f172a',
    muted: '#64748b',
    accent: '#4f46e5',
    accentInk: '#ffffff',
    success: '#10b981', warn: '#f59e0b', danger: '#ef4444', info: '#0ea5e9',
    darkBg: '#0b0f17', darkSurface: '#11161f', darkText: '#e5e7eb', darkMuted: '#94a3b8', darkBorder: '#1f2937',
  },
  {
    id: 'linen',
    label: 'P2 · Linen + Terracotta',
    desc: 'Warm paper. Editorial, calm.',
    bg: '#f7f4ec',
    surface: '#fbf8f1',
    border: '#e8e1d2',
    text: '#1f1b16',
    muted: '#7a7163',
    accent: '#c4623f',
    accentInk: '#fbf8f1',
    success: '#5b8a5a', warn: '#c98a2b', danger: '#b1503e', info: '#3a7088',
    darkBg: '#16130e', darkSurface: '#1d1913', darkText: '#ebe5d8', darkMuted: '#9b9180', darkBorder: '#2d2820',
  },
  {
    id: 'stone',
    label: 'P3 · Stone + Olive',
    desc: 'Neutral stone with deep olive accent. Quietly confident.',
    bg: '#f5f4f0',
    surface: '#ffffff',
    border: '#e6e4dd',
    text: '#1a1a17',
    muted: '#6b685e',
    accent: '#5a6b3a',
    accentInk: '#ffffff',
    success: '#5a8a3a', warn: '#c08418', danger: '#a44a2d', info: '#36647a',
    darkBg: '#15150f', darkSurface: '#1c1c16', darkText: '#e8e7df', darkMuted: '#a09c8e', darkBorder: '#2a2a22',
  },
  {
    id: 'paper',
    label: 'P4 · Paper + Cobalt',
    desc: 'Crisp paper white, deep cobalt. Stripe/Linear-ops.',
    bg: '#fafafa',
    surface: '#ffffff',
    border: '#ececec',
    text: '#111111',
    muted: '#6b6b6b',
    accent: '#1f4ed8',
    accentInk: '#ffffff',
    success: '#0e8a4f', warn: '#cf8a14', danger: '#d33232', info: '#1f4ed8',
    darkBg: '#0a0a0a', darkSurface: '#141414', darkText: '#ededed', darkMuted: '#9c9c9c', darkBorder: '#222222',
  },
  {
    id: 'bone',
    label: 'P5 · Bone + Amber',
    desc: 'Warm bone, amber gold. Inviting, but still serious.',
    bg: '#f6f2eb',
    surface: '#fbf8f1',
    border: '#e6dfd0',
    text: '#1b1814',
    muted: '#7a7160',
    accent: '#b87a17',
    accentInk: '#1b1814',
    success: '#5e8a3a', warn: '#c98a2b', danger: '#a8442e', info: '#3a6a82',
    darkBg: '#14110b', darkSurface: '#1c1810', darkText: '#ece5d2', darkMuted: '#a59a7f', darkBorder: '#2b2517',
  },
  {
    id: 'console',
    label: 'P6 · Console + Neon',
    desc: 'Near-black monitoring console. High signal, terminal feel.',
    bg: '#fafafa', surface: '#ffffff', border: '#e5e7eb', text: '#0b0d10', muted: '#5a6270',
    accent: '#22c55e', accentInk: '#06140b',
    success: '#22c55e', warn: '#f5b73c', danger: '#f87171', info: '#67e8f9',
    darkBg: '#0a0c0e', darkSurface: '#101316', darkText: '#dbe5e0', darkMuted: '#79858c', darkBorder: '#1a1f24',
  },
];

const Swatch = ({ color, label, size = 28, dark = false }) => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
    <div style={{
      width: '100%', height: size, borderRadius: 4,
      background: color, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.06)',
    }}/>
    <div style={{
      fontFamily: 'JetBrains Mono, ui-monospace, monospace', fontSize: 9,
      color: dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.5)',
      letterSpacing: '0.04em', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
    }}>{label}</div>
  </div>
);

const PalettePreviewCard = ({ palette: p, selected, onSelect }) => {
  return (
    <div className="ab" onClick={onSelect} style={{
      background: p.bg, color: p.text, padding: 0,
      display: 'flex', flexDirection: 'column',
      cursor: 'pointer',
      boxShadow: selected ? `inset 0 0 0 3px ${p.accent}` : 'none',
      transition: 'box-shadow .15s',
      position: 'relative',
    }}>
      {selected && (
        <div style={{
          position: 'absolute', top: 10, right: 10,
          width: 22, height: 22, borderRadius: 999,
          background: p.accent, color: p.accentInk,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: '0 1px 3px rgba(0,0,0,0.2)', zIndex: 3,
        }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </div>
      )}
      {/* header */}
      <div style={{ padding: '14px 18px 8px', display: 'flex', flexDirection: 'column', gap: 4 }}>
        <div style={{
          fontFamily: 'JetBrains Mono, ui-monospace, monospace', fontSize: 9,
          letterSpacing: '0.12em', textTransform: 'uppercase', color: p.muted,
          display: 'flex', justifyContent: 'space-between',
        }}>
          <span>{p.label}</span>
          <span>{p.accent}</span>
        </div>
        <div style={{ fontSize: 12, color: p.text, opacity: 0.7 }}>{p.desc}</div>
      </div>

      {/* light token row */}
      <div style={{ padding: '6px 18px 10px', display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 6 }}>
        <Swatch color={p.bg} label="bg" />
        <Swatch color={p.surface} label="surface" />
        <Swatch color={p.border} label="border" />
        <Swatch color={p.text} label="text" />
        <Swatch color={p.muted} label="muted" />
        <Swatch color={p.accent} label="accent" />
        <Swatch color={p.accentInk} label="accent.ink" />
      </div>

      {/* dark token row */}
      <div style={{ background: p.darkBg, padding: '10px 18px 10px', display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 6 }}>
        <Swatch color={p.darkBg} label="bg" dark size={22}/>
        <Swatch color={p.darkSurface} label="surface" dark size={22}/>
        <Swatch color={p.darkBorder} label="border" dark size={22}/>
        <Swatch color={p.darkText} label="text" dark size={22}/>
        <Swatch color={p.darkMuted} label="muted" dark size={22}/>
      </div>

      {/* semantic row + sample UI */}
      <div style={{ padding: '10px 18px 14px', display: 'flex', alignItems: 'center', gap: 10, marginTop: 'auto' }}>
        <div style={{ display: 'flex', gap: 4 }}>
          {[
            ['success', p.success], ['warn', p.warn], ['danger', p.danger], ['info', p.info],
          ].map(([k, c]) => (
            <div key={k} style={{
              display: 'flex', alignItems: 'center', gap: 4,
              padding: '2px 6px 2px 4px', borderRadius: 999,
              background: 'rgba(0,0,0,0.04)',
              fontFamily: 'JetBrains Mono, ui-monospace, monospace', fontSize: 9, color: p.text,
            }}>
              <span style={{ width: 8, height: 8, borderRadius: 999, background: c }}/>
              {k}
            </div>
          ))}
        </div>
        <div style={{ flex: 1 }}/>
        <button style={{
          padding: '5px 10px', borderRadius: 6, border: 'none',
          background: p.accent, color: p.accentInk,
          fontFamily: 'inherit', fontSize: 11, fontWeight: 500, cursor: 'pointer',
        }}>Primary action</button>
      </div>
    </div>
  );
};

Object.assign(window, { TYPE_PAIRS, PALETTES, TypePairCard, PalettePreviewCard });
