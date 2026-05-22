// LivePreview — a single Cockpit screen that themes itself from the
// currently-selected type pairing + color palette + nav pattern.
// Lets the user combine choices and see them as one coherent product.

const LIGHT_MODE = 'light';
const DARK_MODE  = 'dark';

// Compose a runtime "theme" from a TYPE_PAIRS entry, a PALETTES entry and a
// nav-kind string ('topbar' | 'sidebar' | 'rail') + an optional mode override.
function buildTheme(pair, palette, mode = LIGHT_MODE) {
  const isDark = mode === DARK_MODE;
  const bg       = isDark ? palette.darkBg       : palette.bg;
  const surface  = isDark ? palette.darkSurface  : palette.surface;
  const surface2 = isDark ? mix(palette.darkBg, palette.darkSurface, 0.5) : mix(palette.bg, palette.surface, 0.5);
  const border   = isDark ? palette.darkBorder   : palette.border;
  const text     = isDark ? palette.darkText     : palette.text;
  const muted    = isDark ? palette.darkMuted    : palette.muted;
  return {
    bg, surface, surface2, border, text, muted,
    accent:    palette.accent,
    accentInk: palette.accentInk,
    accentSoft: isDark ? hexA(palette.accent, 0.15) : hexA(palette.accent, 0.10),
    success: palette.success, warn: palette.warn, danger: palette.danger, info: palette.info,
    successSoft: hexA(palette.success, isDark ? 0.16 : 0.14),
    warnSoft:    hexA(palette.warn,    isDark ? 0.16 : 0.18),
    dangerSoft:  hexA(palette.danger,  isDark ? 0.18 : 0.14),
    infoSoft:    hexA(palette.info,    isDark ? 0.18 : 0.14),
    font:    pair.serifHead ? (pair.bodySans || 'Inter') : pair.sans,
    serif:   pair.serifHead ? pair.sans : null,
    mono:    pair.mono,
    isDark,
  };
}

function hexA(hex, alpha) {
  if (!hex || hex[0] !== '#') return `rgba(0,0,0,${alpha})`;
  let h = hex.slice(1);
  if (h.length === 3) h = h.split('').map((c) => c + c).join('');
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return `rgba(${r},${g},${b},${alpha})`;
}
function mix(a, b, t = 0.5) {
  const ah = a.slice(1), bh = b.slice(1);
  const ar = parseInt(ah.slice(0,2),16), ag = parseInt(ah.slice(2,4),16), ab = parseInt(ah.slice(4,6),16);
  const br = parseInt(bh.slice(0,2),16), bg = parseInt(bh.slice(2,4),16), bb = parseInt(bh.slice(4,6),16);
  const r = Math.round(ar + (br - ar) * t).toString(16).padStart(2,'0');
  const g = Math.round(ag + (bg - ag) * t).toString(16).padStart(2,'0');
  const bl = Math.round(ab + (bb - ab) * t).toString(16).padStart(2,'0');
  return `#${r}${g}${bl}`;
}

// ── Nav variants (themed) ──────────────────────────────────────────────────

const ThemedTopNav = ({ th, breadcrumb = ['Watchtower', 'Cockpit'] }) => (
  <div style={{ background: th.surface, borderBottom: `1px solid ${th.border}` }}>
    {/* primary */}
    <div style={{ height: 48, padding: '0 22px', display: 'flex', alignItems: 'center', gap: 4, borderBottom: `1px solid ${th.border}` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginRight: 22, fontWeight: 600, color: th.text, fontFamily: th.serif || th.font, fontSize: th.serif ? 17 : 14 }}>
        <WTMark size={16} color={th.accent}/>
        Watchtower
      </div>
      {['Work', 'Knowledge', 'Architecture', 'Govern'].map((g) => (
        <div key={g} style={{
          padding: '6px 12px', borderRadius: 6, cursor: 'pointer',
          background: g === 'Work' ? th.accentSoft : 'transparent',
          color: g === 'Work' ? th.accent : th.muted,
          fontWeight: g === 'Work' ? 600 : 500, fontSize: 13, display: 'flex', alignItems: 'center', gap: 4,
        }}>{g}<Icon name="chevronD" size={11} color={g === 'Work' ? th.accent : th.muted}/></div>
      ))}
      <div style={{ flex: 1 }}/>
      <ThemedCmdK th={th}/>
      <button style={{ width: 32, height: 32, marginLeft: 8, padding: 0, borderRadius: 6, border: 'none', background: 'transparent', cursor: 'pointer', color: th.muted, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
        <Icon name="bell" size={15}/>
        <span style={{ position: 'absolute', top: 6, right: 6, width: 7, height: 7, borderRadius: 999, background: th.danger }}/>
      </button>
      <div style={{ width: 28, height: 28, marginLeft: 6, borderRadius: 999, background: th.accent, color: th.accentInk, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 600 }}>JG</div>
    </div>
    {/* sub */}
    <div style={{ height: 40, padding: '0 22px', display: 'flex', alignItems: 'center', gap: 2, borderBottom: `1px solid ${th.border}` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginRight: 14, fontFamily: th.mono, fontSize: 11, color: th.muted }}>
        {breadcrumb.map((b, i) => (
          <React.Fragment key={i}>
            {i > 0 && <Icon name="chevron" size={9} color={th.muted}/>}
            <span style={{ color: i === breadcrumb.length - 1 ? th.text : th.muted }}>{b}</span>
          </React.Fragment>
        ))}
      </div>
      {['Overview', 'Activity', 'Health', 'Inbox'].map((t, i) => (
        <div key={t} style={{
          padding: '7px 12px', borderRadius: 6, fontSize: 12.5,
          background: i === 0 ? th.accentSoft : 'transparent',
          color: i === 0 ? th.accent : th.muted, fontWeight: i === 0 ? 600 : 500, cursor: 'pointer',
        }}>{t}</div>
      ))}
      <div style={{ flex: 1 }}/>
      <span style={{ fontFamily: th.mono, fontSize: 10.5, color: th.muted }}>scan 2m ago · audit PASS</span>
    </div>
    <ThemedAmbient th={th}/>
  </div>
);

const ThemedSidebarNav = ({ th, children }) => (
  <div style={{ display: 'grid', gridTemplateColumns: '224px 1fr', height: '100%' }}>
    {/* sidebar */}
    <div style={{ background: th.surface, borderRight: `1px solid ${th.border}`, padding: '14px 12px', display: 'flex', flexDirection: 'column', gap: 3, overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px 12px', borderBottom: `1px solid ${th.border}`, marginBottom: 8 }}>
        <WTMark size={16} color={th.accent}/>
        <span style={{ fontWeight: 600, fontFamily: th.serif || th.font, fontSize: th.serif ? 16 : 14, color: th.text }}>Watchtower</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '6px 8px', borderRadius: 6, background: th.surface2, border: `1px solid ${th.border}`, color: th.muted, marginBottom: 8 }}>
        <Icon name="search" size={12}/>
        <span style={{ fontSize: 11.5, flex: 1 }}>Search…</span>
        <span style={{ fontFamily: th.mono, fontSize: 9, color: th.muted, padding: '1px 5px', background: th.bg, borderRadius: 3 }}>⌘K</span>
      </div>
      <div style={{ fontFamily: th.mono, fontSize: 9, letterSpacing: '0.12em', textTransform: 'uppercase', color: th.muted, padding: '6px 8px 2px' }}>Pinned</div>
      {[
        ['Approvals', 4, 'pin'], ['Tasks · Board', null, 'pin'], ['Fabric · Auth', null, 'pin'],
      ].map(([l, c, i]) => (
        <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '5px 8px', borderRadius: 5, fontSize: 12.5, color: th.text, cursor: 'pointer' }}>
          <Icon name={i} size={11} color={th.accent}/>
          <span style={{ flex: 1 }}>{l}</span>
          {c != null && <span style={{ fontFamily: th.mono, fontSize: 10, color: th.warn, background: th.warnSoft, padding: '1px 5px', borderRadius: 3 }}>{c}</span>}
        </div>
      ))}

      <div style={{ fontFamily: th.mono, fontSize: 9, letterSpacing: '0.12em', textTransform: 'uppercase', color: th.muted, padding: '10px 8px 2px', display: 'flex', alignItems: 'center', gap: 4 }}>
        <Icon name="chevronD" size={9} color={th.muted}/>Work
      </div>
      {['Tasks', 'Inception', 'Timeline', 'Prompts'].map((it) => (
        <div key={it} style={{ padding: '5px 8px 5px 22px', borderRadius: 5, fontSize: 12.5, background: it === 'Tasks' ? th.accentSoft : 'transparent', color: it === 'Tasks' ? th.accent : th.muted, fontWeight: it === 'Tasks' ? 600 : 400, cursor: 'pointer' }}>{it}</div>
      ))}

      <div style={{ fontFamily: th.mono, fontSize: 9, letterSpacing: '0.12em', textTransform: 'uppercase', color: th.muted, padding: '10px 8px 2px', display: 'flex', alignItems: 'center', gap: 4 }}>
        <Icon name="chevron" size={9} color={th.muted}/>Knowledge
      </div>
      <div style={{ fontFamily: th.mono, fontSize: 9, letterSpacing: '0.12em', textTransform: 'uppercase', color: th.muted, padding: '4px 8px 2px', display: 'flex', alignItems: 'center', gap: 4 }}>
        <Icon name="chevron" size={9} color={th.muted}/>Architecture
      </div>
      <div style={{ fontFamily: th.mono, fontSize: 9, letterSpacing: '0.12em', textTransform: 'uppercase', color: th.muted, padding: '4px 8px 2px', display: 'flex', alignItems: 'center', gap: 4 }}>
        <Icon name="chevron" size={9} color={th.muted}/>Govern <span style={{ marginLeft: 'auto', color: th.warn }}>4</span>
      </div>

      <div style={{ flex: 1 }}/>
      <div style={{ paddingTop: 10, borderTop: `1px solid ${th.border}`, display: 'flex', alignItems: 'center', gap: 8, padding: '8px' }}>
        <div style={{ width: 22, height: 22, borderRadius: 999, background: th.accent, color: th.accentInk, fontSize: 10, fontWeight: 600, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>JG</div>
        <span style={{ fontSize: 12, color: th.text, flex: 1 }}>Julian G.</span>
        <Icon name="settings" size={13} color={th.muted}/>
      </div>
    </div>

    {/* content with thin top breadcrumb */}
    <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0, overflow: 'hidden' }}>
      <div style={{ height: 44, display: 'flex', alignItems: 'center', padding: '0 22px', borderBottom: `1px solid ${th.border}`, background: th.surface, gap: 10 }}>
        <Icon name="layers" size={12} color={th.muted}/>
        <span style={{ fontFamily: th.mono, fontSize: 11, color: th.muted }}>Work</span>
        <Icon name="chevron" size={9} color={th.muted}/>
        <span style={{ fontSize: 13, fontWeight: 600, color: th.text }}>Cockpit</span>
        <div style={{ flex: 1 }}/>
        <ThemedCmdK th={th} compact/>
      </div>
      <ThemedAmbient th={th}/>
      <div style={{ flex: 1, overflow: 'hidden', background: th.bg }}>
        {children}
      </div>
    </div>
  </div>
);

const ThemedRailNav = ({ th, children }) => (
  <div style={{ display: 'grid', gridTemplateColumns: '52px 1fr', height: '100%' }}>
    <div style={{ background: th.surface, borderRight: `1px solid ${th.border}`, padding: '12px 0', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
      <div style={{ width: 30, height: 30, borderRadius: 7, background: th.accent, color: th.accentInk, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', marginBottom: 8 }}>
        <WTMark size={16} color={th.accentInk}/>
      </div>
      {[
        { icon: 'list', label: 'Work', active: true },
        { icon: 'layers', label: 'Knowledge' },
        { icon: 'branch', label: 'Architecture' },
        { icon: 'flag', label: 'Govern', badge: 4 },
        { icon: 'activity', label: 'Metrics' },
      ].map((it) => (
        <div key={it.label} style={{
          position: 'relative', width: 36, height: 36, borderRadius: 8,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          background: it.active ? th.accentSoft : 'transparent',
          color: it.active ? th.accent : th.muted, cursor: 'pointer',
        }}>
          <Icon name={it.icon} size={16}/>
          {it.badge && <span style={{ position: 'absolute', top: 4, right: 4, width: 7, height: 7, borderRadius: 999, background: th.danger }}/>}
        </div>
      ))}
      <div style={{ flex: 1 }}/>
      <div style={{ width: 36, height: 36, borderRadius: 8, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', color: th.muted }}>
        <Icon name="settings" size={16}/>
      </div>
    </div>

    <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0, overflow: 'hidden' }}>
      <div style={{ height: 52, padding: '0 22px', display: 'flex', alignItems: 'center', gap: 14, background: th.surface, borderBottom: `1px solid ${th.border}` }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, color: th.muted }}>
          <span style={{ fontFamily: th.mono, fontSize: 11 }}>Work</span>
          <Icon name="chevron" size={10} color={th.muted}/>
          <span style={{ fontWeight: 600, color: th.text }}>Cockpit</span>
          <span style={{ width: 1, height: 14, background: th.border, marginLeft: 6 }}/>
          <span style={{ fontFamily: th.mono, fontSize: 11, color: th.accent, display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="pin" size={10} color={th.accent}/>Pinned
          </span>
        </div>
        <div style={{ flex: 1 }}/>
        <ThemedCmdK th={th} wide/>
        <button style={{ width: 32, height: 32, padding: 0, borderRadius: 6, border: `1px solid ${th.border}`, background: 'transparent', cursor: 'pointer', color: th.muted, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="bell" size={15}/>
        </button>
      </div>
      <ThemedAmbient th={th}/>
      <div style={{ flex: 1, overflow: 'hidden', background: th.bg }}>
        {children}
      </div>
    </div>
  </div>
);

const ThemedCmdK = ({ th, compact, wide }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 8,
    padding: compact ? '5px 9px' : '6px 10px', borderRadius: 6,
    background: th.surface2, border: `1px solid ${th.border}`,
    color: th.muted, minWidth: wide ? 360 : compact ? 220 : 280, cursor: 'pointer',
  }}>
    <Icon name="search" size={13}/>
    <span style={{ fontSize: 12 }}>{wide ? 'Jump to task, learning, arc, command…' : 'Search or jump to…'}</span>
    <span style={{ flex: 1 }}/>
    <span style={{ fontFamily: th.mono, fontSize: 10, color: th.muted, padding: '2px 6px', background: th.surface, border: `1px solid ${th.border}`, borderRadius: 4 }}>⌘K</span>
  </div>
);

const ThemedAmbient = ({ th }) => (
  <div style={{
    height: 28, display: 'flex', alignItems: 'center', padding: '0 22px', gap: 10,
    fontFamily: th.mono, fontSize: 10.5, color: th.muted,
    borderBottom: `1px solid ${th.border}`, background: th.surface2,
  }}>
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
      <span style={{ width: 6, height: 6, borderRadius: 999, background: th.accent }}/>
      Focus · <span style={{ color: th.text, fontWeight: 600 }}>T-1453</span> CSRF refactor
    </span>
    <span style={{ color: th.border }}>·</span>
    <span>Session 23m</span>
    <span style={{ color: th.border }}>·</span>
    <span>Audit <span style={{ color: th.success, fontWeight: 600 }}>PASS</span></span>
    <span style={{ color: th.border }}>·</span>
    <span><span style={{ color: th.text, fontWeight: 600 }}>4</span> need attention</span>
    <span style={{ flex: 1 }}/>
    <span>agentic-framework</span>
  </div>
);

// ── Themed Cockpit body ────────────────────────────────────────────────────

const ThemedCockpitBody = ({ th }) => (
  <div style={{ padding: '18px 22px 22px', display: 'flex', flexDirection: 'column', gap: 14, overflow: 'hidden' }}>
    {/* Top hero row */}
    <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 14 }}>
      {/* Focus */}
      <div style={{ background: th.surface, border: `1px solid ${th.border}`, borderRadius: 10, padding: '14px 18px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontFamily: th.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: th.muted }}>Focus task</span>
            <span style={{ fontFamily: th.mono, fontSize: 11, color: th.accent, fontWeight: 600 }}>T-1453</span>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            <ThPill text="active" c={th.success} bg={th.successSoft} th={th}/>
            <ThPill text="arc · A-014" c={th.info} bg={th.infoSoft} th={th}/>
          </div>
        </div>
        <div>
          <div style={{ fontFamily: th.serif || th.font, fontSize: th.serif ? 22 : 19, fontWeight: 600, letterSpacing: '-0.01em', marginBottom: 4, color: th.text }}>
            CSRF refactor — share with standalone templates
          </div>
          <div style={{ fontSize: 12.5, color: th.muted, lineHeight: 1.55 }}>
            Extract <code style={{ fontFamily: th.mono, fontSize: 11.5, color: th.text }}>fetchWithCsrf</code> into a shared <code style={{ fontFamily: th.mono, fontSize: 11.5, color: th.text }}>csrf-htmx.js</code> so standalone templates can use the same code path.
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, fontSize: 11.5, color: th.muted, paddingTop: 10, borderTop: `1px dashed ${th.border}` }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}><Icon name="branch" size={11}/>2 commits</span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}><Icon name="check" size={11}/>Audit PASS · 2m</span>
          <span style={{ flex: 1 }}/>
          <button style={thBtn(th, 'primary')}>Resume session</button>
          <button style={thBtn(th, 'ghost')}>Detail</button>
        </div>
      </div>

      {/* Needs decision */}
      <div style={{ background: th.surface, border: `1px solid ${th.border}`, borderRadius: 10, padding: '14px 18px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ fontFamily: th.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: th.muted }}>Needs your decision · 4</div>
          <a style={{ fontSize: 11, color: th.accent, fontWeight: 500 }}>View all →</a>
        </div>
        {[
          ['T-1612', 'Approve hook bypass for migration', 'high'],
          ['L-0341', 'Promote learning to pattern?', 'medium'],
          ['R-0089', 'Risk re-classified · review', 'medium'],
          ['T-1605', 'Stale 4d · still active?', 'low'],
        ].map(([id, text, sev]) => (
          <div key={id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 0', borderBottom: `1px solid ${th.border}` }}>
            <span style={{ width: 6, height: 6, borderRadius: 999, background: sev === 'high' ? th.danger : sev === 'medium' ? th.warn : th.muted }}/>
            <span style={{ fontFamily: th.mono, fontSize: 11, color: th.accent, fontWeight: 600, width: 54 }}>{id}</span>
            <span style={{ flex: 1, fontSize: 12.5, color: th.text }}>{text}</span>
            <Icon name="arrow" size={12} color={th.muted}/>
          </div>
        ))}
      </div>
    </div>

    {/* Stat tiles */}
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
      {[
        { label: 'Tasks active', value: '42', delta: '+3', spark: [3,5,4,6,8,7,9,10,9,11,12,10,11,12], c: th.accent },
        { label: 'Approvals pending', value: '4', delta: '−1', spark: [2,3,5,4,5,6,7,5,4,5,4,3,4,4], c: th.warn },
        { label: 'Concerns watching', value: '11', delta: '+2', spark: [6,7,8,7,9,8,10,9,11,10,11,12,11,11], c: th.info },
        { label: 'Traceability', value: '94%', delta: '+1pt', spark: [80,82,85,84,86,88,89,90,91,92,93,93,94,94], c: th.success },
      ].map((s) => (
        <div key={s.label} style={{ background: th.surface, border: `1px solid ${th.border}`, borderRadius: 10, padding: '12px 14px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
            <span style={{ fontFamily: th.mono, fontSize: 9.5, letterSpacing: '0.12em', textTransform: 'uppercase', color: th.muted }}>{s.label}</span>
            <span style={{ fontFamily: th.mono, fontSize: 10, color: s.c }}>{s.delta}</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
            <span style={{ fontFamily: th.mono, fontSize: 26, fontWeight: 600, color: th.text, fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.01em' }}>{s.value}</span>
            <Sparkline values={s.spark} color={s.c} w={70} h={22}/>
          </div>
        </div>
      ))}
    </div>

    {/* Two-col arcs + activity */}
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
      <ThCard title="Arcs in flight · 3" right={<a style={{ fontSize: 11, color: th.accent }}>All arcs →</a>} th={th}>
        {[
          { id: 'A-014', name: 'CSRF & template unification', done: 4, total: 7, focused: true },
          { id: 'A-019', name: 'Approvals mobile + side-panel', done: 1, total: 5 },
          { id: 'A-022', name: 'Learnings → patterns graduation', done: 6, total: 9 },
        ].map((a) => (
          <div key={a.id} style={{ padding: '8px 0', borderBottom: `1px solid ${th.border}`, display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ width: 8, height: 8, borderRadius: 999, background: a.focused ? th.accent : th.muted }}/>
            <span style={{ fontFamily: th.mono, fontSize: 11, color: th.accent, fontWeight: 600, width: 50 }}>{a.id}</span>
            <span style={{ flex: 1, fontSize: 12.5, color: th.text }}>{a.name}</span>
            <div style={{ width: 90, height: 4, background: th.border, borderRadius: 2, overflow: 'hidden' }}>
              <div style={{ width: `${a.done / a.total * 100}%`, height: '100%', background: a.focused ? th.accent : th.muted }}/>
            </div>
            <span style={{ fontFamily: th.mono, fontSize: 11, color: th.muted, width: 32, textAlign: 'right' }}>{a.done}/{a.total}</span>
          </div>
        ))}
      </ThCard>

      <ThCard title="Recent activity" right={<a style={{ fontSize: 11, color: th.accent }}>Timeline →</a>} th={th}>
        {[
          ['12m', 'T-1453', 'merged · CSRF helper extracted', th.success],
          ['38m', 'L-0341', 'learning surfaced from session', th.info],
          ['1h',  'S-218',  'handover written · 12 decisions', th.muted],
          ['2h',  'T-1612', 'reviewer requested hook bypass', th.warn],
          ['3h',  'A-014',  'arc reprioritised · +2 tasks', th.muted],
        ].map(([when, id, text, c], i) => (
          <div key={i} style={{ padding: '8px 0', borderBottom: `1px solid ${th.border}`, display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ fontFamily: th.mono, fontSize: 10.5, color: th.muted, width: 28 }}>{when}</span>
            <span style={{ width: 6, height: 6, borderRadius: 999, background: c, flexShrink: 0 }}/>
            <span style={{ fontFamily: th.mono, fontSize: 11, color: th.accent, fontWeight: 600, width: 52 }}>{id}</span>
            <span style={{ flex: 1, fontSize: 12.5, color: th.text }}>{text}</span>
          </div>
        ))}
      </ThCard>
    </div>
  </div>
);

const ThCard = ({ title, right, children, th }) => (
  <div style={{ background: th.surface, border: `1px solid ${th.border}`, borderRadius: 10, padding: '12px 16px 14px' }}>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 8, borderBottom: `1px solid ${th.border}`, marginBottom: 4 }}>
      <span style={{ fontFamily: th.mono, fontSize: 10.5, letterSpacing: '0.1em', textTransform: 'uppercase', color: th.muted, fontWeight: 600 }}>{title}</span>
      {right}
    </div>
    {children}
  </div>
);

const ThPill = ({ text, c, bg, th }) => (
  <span style={{
    fontFamily: th.mono, fontSize: 10, fontWeight: 600, letterSpacing: '0.04em',
    padding: '2px 8px', borderRadius: 999, color: c, background: bg,
    display: 'inline-flex', alignItems: 'center', gap: 4, whiteSpace: 'nowrap',
  }}>{text}</span>
);

const thBtn = (th, variant = 'ghost') => {
  const base = {
    padding: '6px 12px', borderRadius: 6, fontSize: 12, fontWeight: 500,
    cursor: 'pointer', border: 'none', fontFamily: 'inherit',
    display: 'inline-flex', alignItems: 'center', gap: 5,
  };
  if (variant === 'primary') return { ...base, background: th.accent, color: th.accentInk };
  return { ...base, background: 'transparent', color: th.text, border: `1px solid ${th.border}` };
};

// ── LivePreview ────────────────────────────────────────────────────────────

const LivePreview = ({ typeId, paletteId, navKind, mode = 'light' }) => {
  const pair    = TYPE_PAIRS.find((p) => p.id === typeId) || TYPE_PAIRS[0];
  const palette = PALETTES.find((p) => p.id === paletteId) || PALETTES[0];
  const th      = buildTheme(pair, palette, mode);

  const body = <ThemedCockpitBody th={th}/>;
  return (
    <div className="ab" style={{ background: th.bg, color: th.text, fontFamily: th.font, fontSize: 13, height: '100%', display: 'flex', flexDirection: 'column' }}>
      {navKind === 'sidebar' ? <ThemedSidebarNav th={th}>{body}</ThemedSidebarNav>
       : navKind === 'rail'  ? <ThemedRailNav th={th}>{body}</ThemedRailNav>
       : (<>
          <ThemedTopNav th={th}/>
          <div style={{ flex: 1, overflow: 'hidden' }}>{body}</div>
        </>)}
    </div>
  );
};

Object.assign(window, { LivePreview, buildTheme });
