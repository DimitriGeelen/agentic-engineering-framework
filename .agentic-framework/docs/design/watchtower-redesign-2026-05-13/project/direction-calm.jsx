// Direction A — CALM
// Palette: stone neutrals + olive accent. Light theme.
// Typography: Inter + JetBrains Mono.
// Mood: structured ops dashboard. Vercel/Linear-quiet.
//
// Exposes: CalmCockpit, CalmTasks, CalmApprovals, CalmSidePanel,
//          CalmCmdK, CalmShortcuts.

const calm = {
  bg: '#f5f4f0',
  surface: '#ffffff',
  surface2: '#fafaf6',
  border: '#e8e6dd',
  borderStrong: '#d8d5c8',
  text: '#1a1a17',
  textSoft: '#3a3a35',
  muted: '#6b685e',
  mutedSoft: '#a09c8e',
  accent: '#5a6b3a',
  accentSoft: '#eef0e3',
  accentInk: '#ffffff',
  success: '#5a8a3a',
  warn: '#c08418',
  danger: '#a44a2d',
  info: '#36647a',
  successSoft: '#e8f1de',
  warnSoft: '#fbeed1',
  dangerSoft: '#f6dfd5',
  infoSoft: '#dde9ee',
  font: '"Inter", system-ui, sans-serif',
  mono: '"JetBrains Mono", ui-monospace, monospace',
};

// ── Shared chrome (calm) ───────────────────────────────────────────────────

const CalmTopBar = ({ active = 'Work', sub, breadcrumb }) => (
  <div style={{ background: calm.surface }}>
    <div style={{
      height: 48, display: 'flex', alignItems: 'center', padding: '0 20px', gap: 4,
      borderBottom: `1px solid ${calm.border}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginRight: 22, fontWeight: 600, color: calm.text }}>
        <WTMark size={16} color={calm.accent}/>
        <span style={{ letterSpacing: '-0.005em' }}>Watchtower</span>
      </div>
      {['Work', 'Knowledge', 'Architecture', 'Govern'].map((g) => (
        <div key={g} style={{
          padding: '6px 12px', borderRadius: 6, cursor: 'pointer',
          background: g === active ? calm.accentSoft : 'transparent',
          color: g === active ? calm.accent : calm.muted,
          fontWeight: g === active ? 600 : 500, fontSize: 13,
          display: 'flex', alignItems: 'center', gap: 4,
        }}>
          {g}
          <Icon name="chevronD" size={11} color={g === active ? calm.accent : calm.mutedSoft}/>
        </div>
      ))}
      <div style={{ flex: 1 }}/>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '6px 10px', borderRadius: 6, background: calm.surface2, border: `1px solid ${calm.border}`,
        color: calm.muted, minWidth: 280, cursor: 'pointer',
      }}>
        <Icon name="search" size={13}/>
        <span style={{ fontSize: 12 }}>Search or jump to…</span>
        <span style={{ flex: 1 }}/>
        <span style={{ fontFamily: calm.mono, fontSize: 10, color: calm.muted, padding: '2px 6px', background: calm.surface, border: `1px solid ${calm.border}`, borderRadius: 4 }}>⌘K</span>
      </div>
      <button style={{ width: 32, height: 32, marginLeft: 8, padding: 0, borderRadius: 6, border: 'none', background: 'transparent', cursor: 'pointer', color: calm.muted, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
        <Icon name="bell" size={15}/>
        <span style={{ position: 'absolute', top: 6, right: 6, width: 7, height: 7, borderRadius: 999, background: calm.danger }}/>
      </button>
      <div style={{ width: 28, height: 28, marginLeft: 6, borderRadius: 999, background: calm.accent, color: calm.accentInk, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 600 }}>JG</div>
    </div>

    {/* Contextual sub-nav */}
    {sub && (
      <div style={{ height: 40, display: 'flex', alignItems: 'center', padding: '0 20px', gap: 2, borderBottom: `1px solid ${calm.border}` }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginRight: 14, fontFamily: calm.mono, fontSize: 11, color: calm.muted }}>
          {breadcrumb.map((b, i) => (
            <React.Fragment key={i}>
              {i > 0 && <Icon name="chevron" size={9} color={calm.mutedSoft}/>}
              <span style={{ color: i === breadcrumb.length - 1 ? calm.text : calm.muted }}>{b}</span>
            </React.Fragment>
          ))}
        </div>
        {sub.tabs.map((t, i) => (
          <div key={t} style={{
            padding: '7px 12px', borderRadius: 6, cursor: 'pointer',
            background: i === sub.activeTab ? calm.accentSoft : 'transparent',
            color: i === sub.activeTab ? calm.accent : calm.muted,
            fontWeight: i === sub.activeTab ? 600 : 500, fontSize: 12.5,
          }}>{t}</div>
        ))}
        <div style={{ flex: 1 }}/>
        {sub.right}
      </div>
    )}

    {/* Ambient status strip - quieter, sits under sub-nav */}
    <div style={{
      height: 28, display: 'flex', alignItems: 'center', padding: '0 20px', gap: 10,
      fontFamily: calm.mono, fontSize: 10.5, color: calm.muted,
      borderBottom: `1px solid ${calm.border}`, background: calm.surface2,
    }}>
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
        <span style={{ width: 6, height: 6, borderRadius: 999, background: calm.accent }}/>
        Focus · <span style={{ color: calm.text, fontWeight: 600 }}>T-1453</span> CSRF refactor
      </span>
      <span style={{ color: calm.mutedSoft }}>·</span>
      <span>Session 23m</span>
      <span style={{ color: calm.mutedSoft }}>·</span>
      <span>Audit <span style={{ color: calm.success, fontWeight: 600 }}>PASS</span></span>
      <span style={{ color: calm.mutedSoft }}>·</span>
      <span><span style={{ color: calm.text, fontWeight: 600 }}>4</span> need attention</span>
      <span style={{ flex: 1 }}/>
      <span>geelen-monorepo</span>
    </div>
  </div>
);

// ── Calm Cockpit ───────────────────────────────────────────────────────────

const CalmCockpit = () => (
  <div className="ab" style={{ background: calm.bg, fontFamily: calm.font, fontSize: 13, color: calm.text }}>
    <CalmTopBar active="Work" sub={{ tabs: ['Overview', 'Activity', 'Health', 'Inbox'], activeTab: 0, right: (
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <button style={{ ...btn(calm, 'ghost'), display: 'inline-flex', alignItems: 'center', gap: 5 }}><Icon name="activity" size={12}/>Refresh</button>
        <span style={{ fontFamily: calm.mono, fontSize: 10.5, color: calm.muted }}>Scan 2m ago</span>
      </div>
    ) }} breadcrumb={['Watchtower', 'Cockpit']}/>

    <div style={{ padding: '18px 22px 22px', display: 'flex', flexDirection: 'column', gap: 14 }}>
      {/* Top hero: focus + needs decision */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 14 }}>
        {/* Focus card */}
        <div style={{ background: calm.surface, border: `1px solid ${calm.border}`, borderRadius: 10, padding: '14px 18px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ fontFamily: calm.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: calm.muted }}>Focus task</span>
              <span style={{ fontFamily: calm.mono, fontSize: 11, color: calm.accent, fontWeight: 600 }}>T-1453</span>
            </div>
            <div style={{ display: 'flex', gap: 6 }}>
              <Pill text="active" color={calm.success} bg={calm.successSoft}/>
              <Pill text="arc · refactor" color={calm.info} bg={calm.infoSoft}/>
            </div>
          </div>
          <div>
            <div style={{ fontSize: 19, fontWeight: 600, letterSpacing: '-0.01em', marginBottom: 4 }}>CSRF refactor — share with standalone templates</div>
            <div style={{ fontSize: 12.5, color: calm.muted, lineHeight: 1.55 }}>Extract fetchWithCsrf into <code style={{ fontFamily: calm.mono, fontSize: 11.5, color: calm.text }}>csrf-htmx.js</code> so review.html can share the same code path. Touches base.html, review.html.</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, fontSize: 11.5, color: calm.muted, paddingTop: 10, borderTop: `1px dashed ${calm.border}` }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}><Icon name="branch" size={11}/>2 commits on branch</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}><Icon name="check" size={11}/>Audit PASS · 2m</span>
            <span style={{ flex: 1 }}/>
            <button style={btn(calm, 'primary')}>Resume session</button>
            <button style={btn(calm, 'ghost')}>Detail</button>
          </div>
        </div>

        {/* Needs decision card */}
        <div style={{ background: calm.surface, border: `1px solid ${calm.border}`, borderRadius: 10, padding: '14px 18px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ fontFamily: calm.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: calm.muted }}>Needs your decision · 4</div>
            <a style={{ fontSize: 11, color: calm.accent, fontWeight: 500 }}>View all →</a>
          </div>
          {[
            ['T-1612', 'Approve hook bypass for migration', 'high'],
            ['L-0341', 'Promote learning to pattern?', 'medium'],
            ['R-0089', 'Risk re-classified · review', 'medium'],
            ['T-1605', 'Stale 4d · still active?', 'low'],
          ].map(([id, text, sev]) => (
            <div key={id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 0', borderBottom: `1px solid ${calm.border}` }}>
              <span style={{
                width: 6, height: 6, borderRadius: 999,
                background: sev === 'high' ? calm.danger : sev === 'medium' ? calm.warn : calm.mutedSoft,
              }}/>
              <span style={{ fontFamily: calm.mono, fontSize: 11, color: calm.accent, fontWeight: 600, width: 54 }}>{id}</span>
              <span style={{ flex: 1, fontSize: 12.5, color: calm.text }}>{text}</span>
              <Icon name="arrow" size={12} color={calm.mutedSoft}/>
            </div>
          ))}
        </div>
      </div>

      {/* Three stat tiles */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
        {[
          { label: 'Tasks active', value: '42', delta: '+3', tone: 'up', spark: [3,5,4,6,8,7,9,10,9,11,12,10,11,12], color: calm.accent },
          { label: 'Approvals pending', value: '4', delta: '−1', tone: 'down', spark: [2,3,5,4,5,6,7,5,4,5,4,3,4,4], color: calm.warn },
          { label: 'Concerns watching', value: '11', delta: '+2', tone: 'up', spark: [6,7,8,7,9,8,10,9,11,10,11,12,11,11], color: calm.info },
          { label: 'Traceability', value: '94%', delta: '+1pt', tone: 'up', spark: [80,82,85,84,86,88,89,90,91,92,93,93,94,94], color: calm.success },
        ].map((s) => (
          <div key={s.label} style={{ background: calm.surface, border: `1px solid ${calm.border}`, borderRadius: 10, padding: '12px 14px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
              <span style={{ fontFamily: calm.mono, fontSize: 9.5, letterSpacing: '0.12em', textTransform: 'uppercase', color: calm.muted }}>{s.label}</span>
              <span style={{ fontFamily: calm.mono, fontSize: 10, color: s.tone === 'up' ? calm.success : calm.muted }}>{s.delta}</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
              <span style={{ fontFamily: calm.mono, fontSize: 26, fontWeight: 600, color: calm.text, fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.01em' }}>{s.value}</span>
              <Sparkline values={s.spark} color={s.color} w={70} h={22}/>
            </div>
          </div>
        ))}
      </div>

      {/* Two-column: Attention + Activity */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
        <Card title="Arcs in flight · 3" right={<a style={{ fontSize: 11, color: calm.accent }}>All arcs →</a>} c={calm}>
          {[
            { id: 'A-014', name: 'CSRF & template unification', tasks: 7, done: 4, focused: true },
            { id: 'A-019', name: 'Approvals mobile QR + side-panel', tasks: 5, done: 1, focused: false },
            { id: 'A-022', name: 'Learnings → patterns graduation', tasks: 9, done: 6, focused: false },
          ].map((a) => (
            <div key={a.id} style={{ padding: '8px 0', borderBottom: `1px solid ${calm.border}`, display: 'flex', alignItems: 'center', gap: 12 }}>
              <span style={{ width: 8, height: 8, borderRadius: 999, background: a.focused ? calm.accent : calm.mutedSoft }}/>
              <span style={{ fontFamily: calm.mono, fontSize: 11, color: calm.accent, fontWeight: 600, width: 50 }}>{a.id}</span>
              <span style={{ flex: 1, fontSize: 12.5 }}>{a.name}</span>
              <div style={{ width: 90, height: 4, background: calm.border, borderRadius: 2, overflow: 'hidden' }}>
                <div style={{ width: `${a.done / a.tasks * 100}%`, height: '100%', background: a.focused ? calm.accent : calm.muted }}/>
              </div>
              <span style={{ fontFamily: calm.mono, fontSize: 11, color: calm.muted, width: 32, textAlign: 'right' }}>{a.done}/{a.tasks}</span>
            </div>
          ))}
        </Card>

        <Card title="Recent activity" right={<a style={{ fontSize: 11, color: calm.accent }}>Timeline →</a>} c={calm}>
          {[
            ['12m', 'T-1453', 'merged · CSRF helper extracted', calm.success],
            ['38m', 'L-0341', 'learning surfaced from session', calm.info],
            ['1h',  'S-218',  'handover written · 12 decisions', calm.muted],
            ['2h',  'T-1612', 'reviewer requested hook bypass', calm.warn],
            ['3h',  'A-014',  'arc reprioritised · +2 tasks', calm.muted],
          ].map(([when, id, text, c], i) => (
            <div key={i} style={{ padding: '8px 0', borderBottom: `1px solid ${calm.border}`, display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ fontFamily: calm.mono, fontSize: 10.5, color: calm.muted, width: 28 }}>{when}</span>
              <span style={{ width: 6, height: 6, borderRadius: 999, background: c, flexShrink: 0 }}/>
              <span style={{ fontFamily: calm.mono, fontSize: 11, color: calm.accent, fontWeight: 600, width: 52 }}>{id}</span>
              <span style={{ flex: 1, fontSize: 12.5, color: calm.textSoft }}>{text}</span>
            </div>
          ))}
        </Card>
      </div>
    </div>
  </div>
);

// ── Helpers (scoped) ───────────────────────────────────────────────────────

const Card = ({ title, right, children, c }) => (
  <div style={{ background: c.surface, border: `1px solid ${c.border}`, borderRadius: 10, padding: '12px 16px 14px' }}>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 8, borderBottom: `1px solid ${c.border}`, marginBottom: 4 }}>
      <span style={{ fontFamily: c.mono, fontSize: 10.5, letterSpacing: '0.1em', textTransform: 'uppercase', color: c.muted, fontWeight: 600 }}>{title}</span>
      {right}
    </div>
    {children}
  </div>
);

const Pill = ({ text, color, bg, mono = true }) => (
  <span style={{
    fontFamily: mono ? '"JetBrains Mono", monospace' : 'inherit',
    fontSize: 10, fontWeight: 600, letterSpacing: '0.04em',
    padding: '2px 8px', borderRadius: 999, color, background: bg,
    display: 'inline-flex', alignItems: 'center', gap: 4, whiteSpace: 'nowrap',
  }}>{text}</span>
);

const btn = (c, variant = 'ghost') => {
  const base = {
    padding: '6px 12px', borderRadius: 6, fontSize: 12, fontWeight: 500,
    cursor: 'pointer', border: 'none', fontFamily: 'inherit',
    display: 'inline-flex', alignItems: 'center', gap: 5,
  };
  if (variant === 'primary') return { ...base, background: c.accent, color: c.accentInk };
  if (variant === 'danger') return { ...base, background: 'transparent', color: c.danger, border: `1px solid ${c.danger}` };
  if (variant === 'success') return { ...base, background: c.success, color: '#fff' };
  return { ...base, background: 'transparent', color: c.text, border: `1px solid ${c.border}` };
};

// ── Calm Tasks (board) ─────────────────────────────────────────────────────

const CalmTasks = () => {
  const cols = [
    { name: 'Triage', count: 6, tone: calm.muted, tasks: [
      { id: 'T-1670', title: 'Sessions list: virtualize > 200 rows', tags: ['perf'], owner: 'JG' },
      { id: 'T-1668', title: 'Hook bypass needs reviewer sign-off', tags: ['govern'], owner: 'AB', flag: 'warn' },
      { id: 'T-1665', title: 'Approvals mobile: persistent URL', tags: ['mobile'], owner: 'JG' },
    ]},
    { name: 'Active', count: 12, tone: calm.accent, tasks: [
      { id: 'T-1453', title: 'CSRF refactor — share with standalone templates', tags: ['refactor', 'arc·A-014'], owner: 'JG', focus: true },
      { id: 'T-1660', title: 'Fabric explorer: collapse on Esc', tags: ['ux'], owner: 'MC' },
      { id: 'T-1662', title: 'Inbox: surface stale tasks > 3d', tags: ['quality'], owner: 'JG', selected: true },
    ]},
    { name: 'Review', count: 5, tone: calm.warn, tasks: [
      { id: 'T-1612', title: 'Approve hook bypass for migration', tags: ['govern'], owner: 'AB', flag: 'high' },
      { id: 'T-1655', title: 'Patterns: graduate L-0341', tags: ['knowledge'], owner: 'JG' },
    ]},
    { name: 'Done · 7d', count: 19, tone: calm.success, tasks: [
      { id: 'T-1659', title: 'Decisions: search by tag', tags: ['knowledge'], owner: 'MC', done: true },
      { id: 'T-1658', title: 'Cockpit: focus task widget', tags: ['ui'], owner: 'JG', done: true },
    ]},
  ];

  return (
    <div className="ab" style={{ background: calm.bg, fontFamily: calm.font, fontSize: 13, color: calm.text, display: 'flex', flexDirection: 'column' }}>
      <CalmTopBar active="Work" sub={{
        tabs: ['Board', 'List', 'Timeline', 'Inbox', 'Stale'], activeTab: 0,
        right: (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '4px 10px', borderRadius: 999, background: calm.surface, border: `1px solid ${calm.border}`, fontSize: 11, color: calm.muted }}>
              <Icon name="filter" size={11}/> arc · A-014
              <Icon name="x" size={10}/>
            </div>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '4px 10px', borderRadius: 999, background: calm.surface, border: `1px solid ${calm.border}`, fontSize: 11, color: calm.muted }}>
              <Icon name="filter" size={11}/> owner · me
              <Icon name="x" size={10}/>
            </div>
            <button style={btn(calm, 'ghost')}><Icon name="plus" size={11}/>Filter</button>
            <button style={btn(calm, 'primary')}><Icon name="plus" size={11}/>New task</button>
          </div>
        ),
      }} breadcrumb={['Work', 'Tasks', 'Board']}/>

      {/* Board */}
      <div style={{ flex: 1, padding: '14px 18px', display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, overflow: 'hidden' }}>
        {cols.map((col) => (
          <div key={col.name} style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '0 4px 8px', borderBottom: `2px solid ${col.tone}`, marginBottom: 10 }}>
              <span style={{ fontWeight: 600, fontSize: 12.5 }}>{col.name}</span>
              <span style={{ fontFamily: calm.mono, fontSize: 10.5, color: calm.muted }}>{col.count}</span>
              <div style={{ flex: 1 }}/>
              <Icon name="plus" size={12} color={calm.muted}/>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {col.tasks.map((t) => (
                <div key={t.id} style={{
                  background: calm.surface,
                  border: `1px solid ${t.selected ? calm.accent : calm.border}`,
                  borderRadius: 8, padding: '10px 12px',
                  boxShadow: t.selected ? `0 0 0 3px ${calm.accentSoft}` : 'none',
                  display: 'flex', flexDirection: 'column', gap: 6,
                  opacity: t.done ? 0.65 : 1,
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    {t.selected && <input type="checkbox" checked readOnly style={{ accentColor: calm.accent, margin: 0 }}/>}
                    <span style={{ fontFamily: calm.mono, fontSize: 10.5, color: t.focus ? calm.accent : calm.muted, fontWeight: t.focus ? 700 : 500 }}>{t.id}</span>
                    {t.focus && <Pill text="focus" color={calm.accent} bg={calm.accentSoft}/>}
                    {t.flag === 'high' && <Pill text="high" color={calm.danger} bg={calm.dangerSoft}/>}
                    {t.flag === 'warn' && <Pill text="review" color={calm.warn} bg={calm.warnSoft}/>}
                  </div>
                  <div style={{ fontSize: 12.5, lineHeight: 1.35, color: t.done ? calm.muted : calm.text, textDecoration: t.done ? 'line-through' : 'none' }}>{t.title}</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                    {t.tags.map((tag) => (
                      <span key={tag} style={{ fontFamily: calm.mono, fontSize: 9.5, color: calm.muted, padding: '1px 6px', background: calm.bg, borderRadius: 3 }}>{tag}</span>
                    ))}
                    <div style={{ flex: 1 }}/>
                    <span style={{ width: 18, height: 18, borderRadius: 999, background: calm.accentSoft, color: calm.accent, fontFamily: calm.mono, fontSize: 9, fontWeight: 700, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>{t.owner}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* Bulk-action bar (floating) */}
      <div style={{
        position: 'absolute', bottom: 18, left: '50%', transform: 'translateX(-50%)',
        display: 'flex', alignItems: 'center', gap: 10,
        background: calm.text, color: calm.bg, borderRadius: 10,
        padding: '8px 12px', boxShadow: '0 12px 30px rgba(0,0,0,0.18)',
      }}>
        <span style={{ fontFamily: calm.mono, fontSize: 11.5, fontWeight: 600 }}>1 selected</span>
        <span style={{ width: 1, height: 14, background: 'rgba(255,255,255,0.18)' }}/>
        <button style={{ ...btn(calm), background: 'transparent', color: calm.bg, border: 'none', padding: '4px 8px' }}>Move to…</button>
        <button style={{ ...btn(calm), background: 'transparent', color: calm.bg, border: 'none', padding: '4px 8px' }}>Assign…</button>
        <button style={{ ...btn(calm), background: 'transparent', color: calm.bg, border: 'none', padding: '4px 8px' }}>Tag</button>
        <span style={{ width: 1, height: 14, background: 'rgba(255,255,255,0.18)' }}/>
        <button style={{ ...btn(calm), background: 'transparent', color: '#f9d2c4', border: 'none', padding: '4px 8px' }}>Archive</button>
        <span style={{ fontFamily: calm.mono, fontSize: 9.5, color: 'rgba(255,255,255,0.5)', marginLeft: 4 }}>esc · clear</span>
      </div>
    </div>
  );
};

// ── Calm Approvals ─────────────────────────────────────────────────────────

const CalmApprovals = () => {
  const items = [
    { id: 'A-2391', title: 'Bypass hook · pre-commit secret-scan', risk: 'high',
      command: 'fw hook bypass --hook secret-scan --task T-1612 --justify "migration script"', age: '4m',
      who: 'AB', task: 'T-1612', why: 'migration moves stored secrets to vault; legacy file fails scan' },
    { id: 'A-2390', title: 'Allow direct push to main · cherry-pick', risk: 'high',
      command: 'fw bypass --rule no-direct-main --reason "cherry-pick from arc"', age: '12m',
      who: 'JG', task: 'T-1612', why: 'rollback hotfix from A-014 branch' },
    { id: 'A-2387', title: 'Promote L-0341 to pattern', risk: 'medium',
      command: 'fw learning promote L-0341 --as pattern --kind workflow', age: '1h',
      who: 'JG', task: '—', why: 'observed 4x across A-014, A-019' },
    { id: 'A-2384', title: 'Reclassify R-0089 from "watching" → "active"', risk: 'medium',
      command: 'fw risk update R-0089 --status active --severity medium', age: '3h',
      who: 'MC', task: '—', why: 'recurred in S-217 + S-218 sessions' },
    { id: 'A-2382', title: 'Approve cron schedule change · daily-audit', risk: 'low',
      command: 'fw cron update daily-audit --at "0 7 * * *"', age: '5h',
      who: 'JG', task: '—', why: 'shift earlier so morning standup has fresh data' },
  ];

  const riskMap = { high: [calm.danger, calm.dangerSoft], medium: [calm.warn, calm.warnSoft], low: [calm.muted, calm.bg] };

  return (
    <div className="ab" style={{ background: calm.bg, fontFamily: calm.font, fontSize: 13, color: calm.text }}>
      <CalmTopBar active="Govern" sub={{
        tabs: ['Pending · 5', 'Mine', 'Resolved', 'All'], activeTab: 0,
        right: (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '4px 10px', borderRadius: 999, background: calm.surface, border: `1px solid ${calm.border}`, fontSize: 11, color: calm.muted }}>
              <Icon name="filter" size={11}/> risk · high+
              <Icon name="x" size={10}/>
            </div>
            <button style={btn(calm, 'ghost')}>Saved views</button>
            <button style={btn(calm, 'ghost')}>QR for mobile</button>
          </div>
        ),
      }} breadcrumb={['Govern', 'Approvals']}/>

      <div style={{ padding: '14px 22px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {/* Header strip */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '4px 2px 8px' }}>
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 600, letterSpacing: '-0.01em' }}>Approvals</h1>
          <span style={{ fontFamily: calm.mono, fontSize: 11, color: calm.muted }}>5 pending · 2 high-risk · median age 1h 12m</span>
          <span style={{ flex: 1 }}/>
          <span style={{ fontFamily: calm.mono, fontSize: 10.5, color: calm.muted }}>j / k navigate · a approve · r reject · ?</span>
        </div>

        {items.map((it, i) => (
          <div key={it.id} style={{
            background: calm.surface, border: `1px solid ${i === 0 ? calm.accent : calm.border}`, borderRadius: 10,
            padding: '12px 14px 14px', display: 'flex', gap: 14,
            boxShadow: i === 0 ? `0 0 0 3px ${calm.accentSoft}` : 'none',
          }}>
            {/* Left: risk strip */}
            <div style={{ width: 6, borderRadius: 3, background: riskMap[it.risk][0], alignSelf: 'stretch' }}/>

            {/* Body */}
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <Pill text={it.risk} color={riskMap[it.risk][0]} bg={riskMap[it.risk][1]}/>
                <span style={{ fontFamily: calm.mono, fontSize: 11, color: calm.accent, fontWeight: 600 }}>{it.id}</span>
                <span style={{ fontSize: 14, fontWeight: 600 }}>{it.title}</span>
                <span style={{ flex: 1 }}/>
                <span style={{ fontFamily: calm.mono, fontSize: 10.5, color: calm.muted }}>{it.who} · {it.age} · task {it.task}</span>
              </div>
              <div style={{
                fontFamily: calm.mono, fontSize: 11.5, color: calm.text,
                background: calm.bg, padding: '8px 10px', borderRadius: 6,
                border: `1px solid ${calm.border}`, wordBreak: 'break-all',
              }}>$ {it.command}</div>
              <div style={{ fontSize: 12, color: calm.muted }}>
                <span style={{ fontFamily: calm.mono, fontSize: 10, textTransform: 'uppercase', letterSpacing: '0.1em', marginRight: 6 }}>Why</span>
                {it.why}
              </div>
            </div>

            {/* Right: inline actions */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'stretch', minWidth: 130 }}>
              <button style={{ ...btn(calm, 'success'), justifyContent: 'center' }}><Icon name="check" size={12}/>Approve</button>
              <button style={{ ...btn(calm, 'danger'), justifyContent: 'center' }}>Reject</button>
              <button style={{ ...btn(calm, 'ghost'), justifyContent: 'center', fontSize: 11 }}>More…</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ── Calm Task Detail (side panel) ──────────────────────────────────────────

const CalmSidePanel = () => (
  <div className="ab" style={{ background: calm.bg, fontFamily: calm.font, fontSize: 13, color: calm.text, position: 'relative' }}>
    {/* Background: tasks list dimmed */}
    <div style={{ filter: 'blur(0px)', opacity: 0.55, pointerEvents: 'none' }}>
      <CalmTasks/>
    </div>

    {/* Dim layer */}
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,18,12,0.18)' }}/>

    {/* Right panel */}
    <div style={{
      position: 'absolute', right: 0, top: 0, bottom: 0, width: 520,
      background: calm.surface, borderLeft: `1px solid ${calm.borderStrong}`,
      boxShadow: '-16px 0 40px rgba(0,0,0,0.10)',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Panel header */}
      <div style={{ padding: '14px 18px', borderBottom: `1px solid ${calm.border}`, display: 'flex', alignItems: 'center', gap: 8 }}>
        <Pill text="active" color={calm.success} bg={calm.successSoft}/>
        <span style={{ fontFamily: calm.mono, fontSize: 11, color: calm.accent, fontWeight: 600 }}>T-1453</span>
        <span style={{ fontFamily: calm.mono, fontSize: 10, color: calm.muted }}>arc · A-014</span>
        <div style={{ flex: 1 }}/>
        <button style={{ width: 26, height: 26, padding: 0, borderRadius: 5, border: `1px solid ${calm.border}`, background: 'transparent', color: calm.muted, cursor: 'pointer' }} title="Dock to bottom"><Icon name="layers" size={12}/></button>
        <button style={{ width: 26, height: 26, padding: 0, borderRadius: 5, border: `1px solid ${calm.border}`, background: 'transparent', color: calm.muted, cursor: 'pointer' }} title="Dock to left"><Icon name="arrowL" size={12}/></button>
        <button style={{ width: 26, height: 26, padding: 0, borderRadius: 5, border: `1px solid ${calm.border}`, background: 'transparent', color: calm.muted, cursor: 'pointer' }} title="Fullscreen"><Icon name="arrow" size={12}/></button>
        <button style={{ width: 26, height: 26, padding: 0, borderRadius: 5, border: 'none', background: 'transparent', color: calm.muted, cursor: 'pointer' }} title="Close"><Icon name="x" size={13}/></button>
      </div>

      {/* Title block */}
      <div style={{ padding: '14px 18px 8px' }}>
        <div style={{ fontSize: 18, fontWeight: 600, letterSpacing: '-0.01em', lineHeight: 1.3, marginBottom: 8 }}>CSRF refactor — share with standalone templates</div>

        {/* Inline-edit fields (compact) */}
        <div style={{ display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '6px 16px', fontSize: 12 }}>
          {[
            ['Status', <Pill key="s" text="active" color={calm.success} bg={calm.successSoft}/>, true],
            ['Owner', <span key="o" style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}><span style={{ width: 16, height: 16, borderRadius: 999, background: calm.accentSoft, color: calm.accent, fontFamily: calm.mono, fontSize: 8, fontWeight: 700, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>JG</span>Julian Geelen</span>, true],
            ['Arc', <span key="a" style={{ fontFamily: calm.mono, fontSize: 11.5, color: calm.accent }}>A-014 · CSRF & template unification</span>, false],
            ['Tags', <span key="t" style={{ display: 'inline-flex', gap: 4 }}>{['refactor', 'ui', 'arc·A-014'].map((tag) => <span key={tag} style={{ fontFamily: calm.mono, fontSize: 10, color: calm.muted, padding: '1px 6px', background: calm.bg, borderRadius: 3 }}>{tag}</span>)}</span>, true],
            ['Spawned', <span key="sp" style={{ fontFamily: calm.mono, fontSize: 11.5, color: calm.muted }}>S-217 · 38m ago</span>, false],
          ].map(([k, v, editable]) => (
            <React.Fragment key={k}>
              <span style={{ fontFamily: calm.mono, fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: calm.muted, paddingTop: 3 }}>{k}</span>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, cursor: editable ? 'pointer' : 'default' }}>
                {v}
                {editable && <Icon name="chevronD" size={9} color={calm.mutedSoft}/>}
              </span>
            </React.Fragment>
          ))}
        </div>
      </div>

      {/* Tabs */}
      <div style={{ padding: '6px 18px 0', display: 'flex', gap: 14, borderBottom: `1px solid ${calm.border}` }}>
        {['Overview', 'Activity · 12', 'Files · 3', 'Discussions · 4'].map((t, i) => (
          <div key={t} style={{
            padding: '6px 2px 8px', fontSize: 12, color: i === 0 ? calm.text : calm.muted,
            fontWeight: i === 0 ? 600 : 500,
            borderBottom: i === 0 ? `2px solid ${calm.accent}` : '2px solid transparent',
            cursor: 'pointer',
          }}>{t}</div>
        ))}
      </div>

      {/* Body */}
      <div style={{ padding: '12px 18px', flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div>
          <div style={{ fontFamily: calm.mono, fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: calm.muted, marginBottom: 6 }}>Description</div>
          <div style={{ fontSize: 12.5, lineHeight: 1.55, color: calm.textSoft }}>
            Extract <code style={{ fontFamily: calm.mono, fontSize: 11.5, color: calm.text }}>fetchWithCsrf</code> from <code style={{ fontFamily: calm.mono, fontSize: 11.5, color: calm.text }}>base.html</code> into a shared <code style={{ fontFamily: calm.mono, fontSize: 11.5, color: calm.text }}>csrf-htmx.js</code> so standalone templates like <code style={{ fontFamily: calm.mono, fontSize: 11.5, color: calm.text }}>review.html</code> can use the same code path. Add htmx event listener for CSRF header injection.
          </div>
        </div>

        <div>
          <div style={{ fontFamily: calm.mono, fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: calm.muted, marginBottom: 6 }}>Acceptance criteria · 3 of 4</div>
          {[
            ['Shared file checked in', true],
            ['base.html uses it', true],
            ['review.html uses it', true],
            ['Browser test passes for both', false],
          ].map(([t, done]) => (
            <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0', fontSize: 12.5 }}>
              <span style={{ width: 14, height: 14, borderRadius: 3, border: `1.5px solid ${done ? calm.success : calm.borderStrong}`, background: done ? calm.success : 'transparent', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
                {done && <Icon name="check" size={9} color="#fff" strokeWidth={3}/>}
              </span>
              <span style={{ color: done ? calm.muted : calm.text, textDecoration: done ? 'line-through' : 'none' }}>{t}</span>
            </div>
          ))}
        </div>

        <div>
          <div style={{ fontFamily: calm.mono, fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: calm.muted, marginBottom: 6 }}>Activity</div>
          {[
            ['12m', 'commit ·', 'extract fetchWithCsrf into module', calm.success],
            ['38m', 'session ·', 'S-218 spawned', calm.info],
            ['1h',  'comment ·', 'JG: also tested in review.html', calm.muted],
          ].map(([t, kind, msg, c], i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0', fontSize: 12 }}>
              <span style={{ fontFamily: calm.mono, fontSize: 10.5, color: calm.muted, width: 28 }}>{t}</span>
              <span style={{ width: 6, height: 6, borderRadius: 999, background: c }}/>
              <span style={{ color: calm.muted }}>{kind}</span>
              <span style={{ color: calm.text }}>{msg}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Footer */}
      <div style={{ padding: '10px 18px', borderTop: `1px solid ${calm.border}`, display: 'flex', alignItems: 'center', gap: 8 }}>
        <input placeholder="Add a comment, link, or run / commands…" style={{
          flex: 1, padding: '7px 10px', borderRadius: 6, border: `1px solid ${calm.border}`,
          background: calm.surface2, fontSize: 12, fontFamily: 'inherit', outline: 'none', color: calm.text,
        }}/>
        <button style={btn(calm, 'primary')}>Send</button>
      </div>
    </div>
  </div>
);

// ── ⌘K command palette ─────────────────────────────────────────────────────

const CalmCmdK = () => (
  <div className="ab" style={{ background: 'rgba(20,18,12,0.45)', fontFamily: calm.font, color: calm.text, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 30 }}>
    <div style={{
      width: 540, background: calm.surface, borderRadius: 12,
      boxShadow: '0 30px 80px rgba(0,0,0,0.22), 0 2px 6px rgba(0,0,0,0.08)',
      overflow: 'hidden', display: 'flex', flexDirection: 'column',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '14px 16px', borderBottom: `1px solid ${calm.border}` }}>
        <Icon name="search" size={15} color={calm.muted}/>
        <input defaultValue="appr" style={{ flex: 1, border: 'none', outline: 'none', fontSize: 14, fontFamily: 'inherit', background: 'transparent', color: calm.text }}/>
        <span style={{ fontFamily: calm.mono, fontSize: 10, color: calm.muted, padding: '2px 6px', background: calm.bg, border: `1px solid ${calm.border}`, borderRadius: 4 }}>esc</span>
      </div>

      <div style={{ padding: '8px 0', maxHeight: 360, overflow: 'hidden' }}>
        {/* Group: pinned */}
        <CmdGroup title="Pinned">
          <CmdItem icon="pin" mono="apr" text="Approvals" hint="5 pending · Govern" active/>
          <CmdItem icon="pin" mono="tsk" text="Tasks · Board" hint="Work"/>
        </CmdGroup>
        <CmdGroup title="Pages">
          <CmdItem icon="layers" text="Approvals · Mine" hint="Govern"/>
          <CmdItem icon="layers" text="Approvals · Resolved" hint="Govern"/>
          <CmdItem icon="layers" text="Quality gate" hint="Govern"/>
        </CmdGroup>
        <CmdGroup title="Entities">
          <CmdItem icon="dot" mono="A-2391" text="Bypass hook · pre-commit secret-scan" hint="approval"/>
          <CmdItem icon="dot" mono="T-1612" text="Approve hook bypass for migration" hint="task · review"/>
        </CmdGroup>
        <CmdGroup title="Commands">
          <CmdItem icon="cmd" text="Approve all low-risk in queue" hint="bulk action"/>
          <CmdItem icon="cmd" text="Toggle dark mode" hint="theme"/>
        </CmdGroup>
      </div>

      <div style={{ padding: '8px 14px', borderTop: `1px solid ${calm.border}`, display: 'flex', alignItems: 'center', gap: 14, fontFamily: calm.mono, fontSize: 10.5, color: calm.muted }}>
        <span>↑↓ navigate</span><span>↩ select</span><span>⌘P pin</span><span style={{ flex: 1 }}/><span>{'Watchtower ⌘K · v0.9.4'}</span>
      </div>
    </div>
  </div>
);

const CmdGroup = ({ title, children }) => (
  <div style={{ padding: '4px 0 6px' }}>
    <div style={{ fontFamily: calm.mono, fontSize: 9.5, color: calm.muted, letterSpacing: '0.12em', textTransform: 'uppercase', padding: '6px 16px 4px' }}>{title}</div>
    {children}
  </div>
);
const CmdItem = ({ icon, text, hint, mono, active }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 10, padding: '6px 16px',
    background: active ? calm.accentSoft : 'transparent', cursor: 'pointer',
  }}>
    <Icon name={icon} size={13} color={active ? calm.accent : calm.muted}/>
    {mono && <span style={{ fontFamily: calm.mono, fontSize: 10.5, color: active ? calm.accent : calm.muted, fontWeight: 600, width: 50 }}>{mono}</span>}
    <span style={{ flex: 1, fontSize: 13, color: calm.text }}>{text}</span>
    <span style={{ fontFamily: calm.mono, fontSize: 10, color: calm.muted }}>{hint}</span>
  </div>
);

// ── Keyboard shortcuts overlay ─────────────────────────────────────────────

const CalmShortcuts = () => (
  <div className="ab" style={{ background: 'rgba(20,18,12,0.45)', fontFamily: calm.font, color: calm.text, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 30 }}>
    <div style={{
      width: 580, background: calm.surface, borderRadius: 12,
      boxShadow: '0 30px 80px rgba(0,0,0,0.22)', padding: '20px 24px',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
        <h3 style={{ margin: 0, fontSize: 16, fontWeight: 600, letterSpacing: '-0.01em' }}>Keyboard</h3>
        <span style={{ fontFamily: calm.mono, fontSize: 10, color: calm.muted, padding: '2px 6px', background: calm.bg, border: `1px solid ${calm.border}`, borderRadius: 4 }}>?</span>
      </div>

      {[
        ['Navigate', [['⌘K', 'Open command palette'], ['g t', 'Go to tasks'], ['g a', 'Go to approvals'], ['g c', 'Go to cockpit'], ['[ / ]', 'Prev / next page in section']]],
        ['Selection', [['j / k', 'Down / up'], ['x', 'Select'], ['shift+x', 'Range select'], ['esc', 'Clear'], ['↩', 'Open detail panel']]],
        ['Actions', [['a', 'Approve'], ['r', 'Reject'], ['e', 'Edit inline'], ['f', 'Focus task'], ['shift+p', 'Pin page'], ['⌘.', 'Dock side panel']]],
      ].map(([section, rows]) => (
        <div key={section} style={{ marginBottom: 14 }}>
          <div style={{ fontFamily: calm.mono, fontSize: 9.5, letterSpacing: '0.12em', textTransform: 'uppercase', color: calm.muted, marginBottom: 6 }}>{section}</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '6px 14px' }}>
            {rows.map(([k, d]) => (
              <React.Fragment key={k}>
                <span style={{ fontFamily: calm.mono, fontSize: 11, color: calm.muted, padding: '2px 6px', background: calm.bg, border: `1px solid ${calm.border}`, borderRadius: 4, justifySelf: 'start' }}>{k}</span>
                <span style={{ fontSize: 12.5, paddingTop: 3 }}>{d}</span>
              </React.Fragment>
            ))}
          </div>
        </div>
      ))}
    </div>
  </div>
);

Object.assign(window, { CalmCockpit, CalmTasks, CalmApprovals, CalmSidePanel, CalmCmdK, CalmShortcuts, calmPalette: calm });
