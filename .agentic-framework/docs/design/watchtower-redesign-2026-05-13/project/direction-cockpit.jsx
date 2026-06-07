// Direction C — COCKPIT / CONSOLE
// Palette: near-black + electric green. Dark-first.
// Typography: IBM Plex Sans + IBM Plex Mono (mono prominent).
// Mood: monitoring console, k9s/Grafana, high signal density.

const cp = {
  bg: '#0a0c0e',
  surface: '#101316',
  surface2: '#161a1f',
  surface3: '#1c2128',
  border: '#1f262e',
  borderStrong: '#2a323c',
  borderAccent: '#2c3942',
  text: '#dbe5e0',
  textBright: '#f4f8f6',
  textSoft: '#a8b3ad',
  muted: '#79858c',
  mutedSoft: '#525c66',
  accent: '#3ee07a',
  accentDim: 'rgba(62,224,122,0.16)',
  accentInk: '#06140b',
  accent2: '#67e8f9',
  accent2Dim: 'rgba(103,232,249,0.14)',
  warn: '#f5b73c',
  warnDim: 'rgba(245,183,60,0.16)',
  danger: '#f87171',
  dangerDim: 'rgba(248,113,113,0.18)',
  success: '#3ee07a',
  successDim: 'rgba(62,224,122,0.18)',
  info: '#67e8f9',
  infoDim: 'rgba(103,232,249,0.16)',
  magenta: '#e879f9',
  magentaDim: 'rgba(232,121,249,0.14)',
  font: '"IBM Plex Sans", "Inter", system-ui, sans-serif',
  mono: '"IBM Plex Mono", "JetBrains Mono", ui-monospace, monospace',
};

// ── Top bar ────────────────────────────────────────────────────────────────

const CpTopBar = ({ active = 'WORK', sub, breadcrumb }) => (
  <div style={{ background: cp.surface, borderBottom: `1px solid ${cp.border}` }}>
    {/* Row 1: command-line style header */}
    <div style={{
      height: 44, display: 'flex', alignItems: 'center', padding: '0 16px', gap: 12,
      borderBottom: `1px solid ${cp.border}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: cp.textBright }}>
        <span style={{
          fontFamily: cp.mono, fontSize: 11, color: cp.accent, fontWeight: 600,
          padding: '2px 6px', border: `1px solid ${cp.accent}`, borderRadius: 2,
        }}>WT</span>
        <span style={{ fontWeight: 600, fontSize: 13, letterSpacing: '0.02em' }}>watchtower</span>
        <span style={{ fontFamily: cp.mono, fontSize: 10, color: cp.muted }}>v0.9.4</span>
      </div>
      <span style={{ width: 1, height: 16, background: cp.border }}/>

      {['WORK', 'KNOWLEDGE', 'ARCH', 'GOVERN'].map((g) => (
        <div key={g} style={{
          fontFamily: cp.mono, fontSize: 11, fontWeight: 600, letterSpacing: '0.08em',
          padding: '5px 10px', borderRadius: 3, cursor: 'pointer',
          background: g === active ? cp.accentDim : 'transparent',
          color: g === active ? cp.accent : cp.muted,
          border: `1px solid ${g === active ? cp.accent : 'transparent'}`,
        }}>{g}</div>
      ))}

      <div style={{ flex: 1 }}/>

      {/* Live status pills */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <StatusPill label="AUDIT" value="PASS" tone="success"/>
        <StatusPill label="SESS" value="23m" tone="info"/>
        <StatusPill label="QUEUE" value="4" tone="warn"/>
      </div>

      <span style={{ width: 1, height: 16, background: cp.border }}/>
      {/* ⌘K */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '5px 10px', borderRadius: 3, background: cp.surface2, border: `1px solid ${cp.border}`,
        color: cp.muted, minWidth: 240, cursor: 'pointer',
      }}>
        <Icon name="search" size={12} color={cp.muted}/>
        <span style={{ fontFamily: cp.mono, fontSize: 11 }}>search · jump · run</span>
        <span style={{ flex: 1 }}/>
        <span style={{ fontFamily: cp.mono, fontSize: 9, color: cp.muted, padding: '1px 5px', background: cp.bg, borderRadius: 2, border: `1px solid ${cp.border}` }}>⌘K</span>
      </div>
      <button style={{ width: 28, height: 28, padding: 0, borderRadius: 3, border: `1px solid ${cp.border}`, background: 'transparent', color: cp.muted, cursor: 'pointer', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
        <Icon name="bell" size={13}/>
        <span style={{ position: 'absolute', top: 4, right: 4, width: 6, height: 6, borderRadius: 999, background: cp.warn }}/>
      </button>
    </div>

    {/* Row 2: contextual / breadcrumb */}
    {sub && (
      <div style={{ height: 36, display: 'flex', alignItems: 'center', padding: '0 16px', gap: 6 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginRight: 8, fontFamily: cp.mono, fontSize: 10.5, color: cp.muted }}>
          <Icon name="chevron" size={10} color={cp.muted}/>
          {breadcrumb.map((b, i) => (
            <React.Fragment key={i}>
              {i > 0 && <span style={{ color: cp.mutedSoft }}>/</span>}
              <span style={{ color: i === breadcrumb.length - 1 ? cp.accent : cp.muted, fontWeight: i === breadcrumb.length - 1 ? 600 : 400 }}>{b}</span>
            </React.Fragment>
          ))}
        </div>
        <span style={{ width: 1, height: 12, background: cp.border }}/>
        {sub.tabs.map((t, i) => (
          <div key={t} style={{
            padding: '5px 10px', borderRadius: 3, cursor: 'pointer',
            fontFamily: cp.mono, fontSize: 10.5, fontWeight: 500, letterSpacing: '0.04em',
            background: i === sub.activeTab ? cp.surface2 : 'transparent',
            color: i === sub.activeTab ? cp.text : cp.muted,
            borderBottom: i === sub.activeTab ? `1px solid ${cp.accent}` : '1px solid transparent',
          }}>{t}</div>
        ))}
        <div style={{ flex: 1 }}/>
        {sub.right}
      </div>
    )}
  </div>
);

const StatusPill = ({ label, value, tone = 'info' }) => {
  const toneMap = {
    success: [cp.success, cp.successDim],
    warn: [cp.warn, cp.warnDim],
    danger: [cp.danger, cp.dangerDim],
    info: [cp.info, cp.infoDim],
    accent: [cp.accent, cp.accentDim],
  };
  const [c, bg] = toneMap[tone];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '3px 8px', borderRadius: 2, background: bg, border: `1px solid ${c}33`,
      fontFamily: cp.mono, fontSize: 10, fontWeight: 600,
    }}>
      <span style={{ width: 6, height: 6, borderRadius: 999, background: c, boxShadow: `0 0 6px ${c}` }}/>
      <span style={{ color: cp.muted, letterSpacing: '0.08em' }}>{label}</span>
      <span style={{ color: c, letterSpacing: '0.02em' }}>{value}</span>
    </span>
  );
};

const cpBtn = (variant = 'ghost') => {
  const base = {
    padding: '5px 10px', borderRadius: 3, fontSize: 11, fontWeight: 600,
    cursor: 'pointer', fontFamily: cp.mono, letterSpacing: '0.04em',
    display: 'inline-flex', alignItems: 'center', gap: 5, textTransform: 'uppercase',
  };
  if (variant === 'primary') return { ...base, background: cp.accent, color: cp.accentInk, border: `1px solid ${cp.accent}` };
  if (variant === 'success') return { ...base, background: cp.successDim, color: cp.success, border: `1px solid ${cp.success}77` };
  if (variant === 'danger') return { ...base, background: cp.dangerDim, color: cp.danger, border: `1px solid ${cp.danger}77` };
  if (variant === 'warn') return { ...base, background: cp.warnDim, color: cp.warn, border: `1px solid ${cp.warn}77` };
  return { ...base, background: 'transparent', color: cp.textSoft, border: `1px solid ${cp.border}` };
};

const cpCardTitle = (text, right) => (
  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '7px 12px', borderBottom: `1px solid ${cp.border}`, background: cp.surface2 }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
      <span style={{ width: 5, height: 5, background: cp.accent, boxShadow: `0 0 6px ${cp.accent}` }}/>
      <span style={{ fontFamily: cp.mono, fontSize: 10, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: cp.textSoft }}>{text}</span>
    </div>
    {right}
  </div>
);

// ── Cockpit Dashboard ──────────────────────────────────────────────────────

const ConsoleCockpit = () => (
  <div className="ab" style={{ background: cp.bg, fontFamily: cp.font, fontSize: 12.5, color: cp.text }}>
    <CpTopBar active="WORK" breadcrumb={['watchtower', 'cockpit']} sub={{
      tabs: ['OVERVIEW', 'ACTIVITY', 'HEALTH', 'INBOX'], activeTab: 0,
      right: <span style={{ fontFamily: cp.mono, fontSize: 10, color: cp.muted }}>scan 2m ago · auto-refresh 60s</span>,
    }}/>

    <div style={{ padding: 14, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 10 }}>
      {/* Big metric tiles */}
      {[
        { label: 'Tasks active',        value: '42',  delta: '+3 / 24h', tone: 'accent', spark: [3,5,4,6,8,7,9,10,9,11,12,10,11,12,12,13,12,13,14,14,14,13,12,12] },
        { label: 'Approvals pending',   value: '4',   delta: '−1 / 24h', tone: 'warn',   spark: [2,3,5,4,5,6,7,5,4,5,4,3,4,4,5,6,5,4,5,4,4,5,5,4] },
        { label: 'Audit',               value: 'PASS',delta: '0 fail / 3 warn', tone: 'success', spark: [98,99,98,99,100,100,99,100,99,100,99,99,100,100,99,99,100,100,99,99,100,100,99,100] },
        { label: 'Traceability',        value: '94%', delta: '+1pt', tone: 'info', spark: [80,82,85,84,86,88,89,90,91,92,93,93,94,94,94,94,93,94,94,94,94,94,94,94] },
      ].map((m) => {
        const tones = { accent: cp.accent, warn: cp.warn, success: cp.success, info: cp.info, danger: cp.danger };
        const c = tones[m.tone];
        return (
          <div key={m.label} style={{ background: cp.surface, border: `1px solid ${cp.border}`, borderTop: `2px solid ${c}` }}>
            <div style={{ padding: '10px 14px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ fontFamily: cp.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: cp.muted }}>{m.label}</span>
              <span style={{ fontFamily: cp.mono, fontSize: 10, color: c }}>{m.delta}</span>
            </div>
            <div style={{ padding: '0 14px 8px', display: 'flex', alignItems: 'flex-end', gap: 10 }}>
              <span style={{ fontFamily: cp.mono, fontSize: 28, fontWeight: 600, color: cp.textBright, fontVariantNumeric: 'tabular-nums', lineHeight: 1, letterSpacing: '-0.01em' }}>{m.value}</span>
              <div style={{ flex: 1 }}>
                <Sparkline values={m.spark} color={c} w={110} h={26}/>
              </div>
            </div>
          </div>
        );
      })}
    </div>

    <div style={{ padding: '0 14px 14px', display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 10 }}>
      {/* Focus + Arcs */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {/* Focus */}
        <div style={{ background: cp.surface, border: `1px solid ${cp.border}` }}>
          {cpCardTitle('FOCUS · T-1453', <span style={{ display: 'flex', gap: 5 }}><StatusPill label="" value="ACTIVE" tone="success"/><StatusPill label="" value="ARC · A-014" tone="info"/></span>)}
          <div style={{ padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ fontSize: 16, fontWeight: 600, color: cp.textBright, letterSpacing: '-0.005em' }}>CSRF refactor — share with standalone templates</div>
            <div style={{ fontFamily: cp.mono, fontSize: 11, color: cp.textSoft, lineHeight: 1.55 }}>
              Extract <span style={{ color: cp.accent }}>fetchWithCsrf</span> into shared <span style={{ color: cp.accent }}>csrf-htmx.js</span>. Touches: <span style={{ color: cp.text }}>base.html, review.html</span>.
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, fontFamily: cp.mono, fontSize: 10.5, color: cp.muted, paddingTop: 8, borderTop: `1px dashed ${cp.border}` }}>
              <span style={{ color: cp.text }}>S-218 ·</span><span>2 commits</span>
              <span style={{ color: cp.mutedSoft }}>·</span>
              <span>3 of 4 AC</span>
              <span style={{ color: cp.mutedSoft }}>·</span>
              <span>started 4h ago</span>
              <span style={{ flex: 1 }}/>
              <button style={cpBtn('primary')}>resume ↵</button>
              <button style={cpBtn('ghost')}>detail</button>
            </div>
          </div>
        </div>

        {/* Arcs */}
        <div style={{ background: cp.surface, border: `1px solid ${cp.border}` }}>
          {cpCardTitle('ARCS IN FLIGHT · 3', <a style={{ fontFamily: cp.mono, fontSize: 10, color: cp.accent2 }}>all arcs →</a>)}
          <div style={{ padding: '6px 4px 6px' }}>
            {[
              { id: 'A-014', name: 'CSRF & template unification', done: 4, total: 7, focused: true, vel: '0.8d' },
              { id: 'A-019', name: 'Approvals mobile + side-panel', done: 1, total: 5, vel: '2.1d' },
              { id: 'A-022', name: 'Learnings → patterns graduation', done: 6, total: 9, vel: '0.4d' },
            ].map((a, i) => (
              <div key={a.id} style={{ display: 'grid', gridTemplateColumns: '12px 60px 1fr 140px 50px 50px', alignItems: 'center', gap: 10, padding: '7px 14px', borderBottom: i < 2 ? `1px solid ${cp.border}` : 'none' }}>
                <span style={{ width: 7, height: 7, borderRadius: 999, background: a.focused ? cp.accent : cp.mutedSoft, boxShadow: a.focused ? `0 0 6px ${cp.accent}` : 'none' }}/>
                <span style={{ fontFamily: cp.mono, fontSize: 11, color: cp.accent, fontWeight: 700 }}>{a.id}</span>
                <span style={{ fontSize: 12.5, color: cp.text }}>{a.name}</span>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <div style={{ flex: 1, height: 4, background: cp.surface3, borderRadius: 1 }}>
                    <div style={{ width: `${a.done / a.total * 100}%`, height: '100%', background: a.focused ? cp.accent : cp.info, borderRadius: 1 }}/>
                  </div>
                </div>
                <span style={{ fontFamily: cp.mono, fontSize: 10.5, color: cp.textSoft, textAlign: 'right' }}>{a.done}/{a.total}</span>
                <span style={{ fontFamily: cp.mono, fontSize: 10.5, color: cp.muted, textAlign: 'right' }}>{a.vel}/t</span>
              </div>
            ))}
          </div>
        </div>

        {/* Activity */}
        <div style={{ background: cp.surface, border: `1px solid ${cp.border}` }}>
          {cpCardTitle('LIVE FEED · last 12h', <span style={{ fontFamily: cp.mono, fontSize: 10, color: cp.accent, display: 'inline-flex', alignItems: 'center', gap: 4 }}><span style={{ width: 5, height: 5, borderRadius: 999, background: cp.accent, animation: 'none' }}/>STREAMING</span>)}
          <div>
            {[
              ['12m', 'T-1453', 'COMMIT', 'extract fetchWithCsrf into csrf-htmx.js', cp.success],
              ['38m', 'L-0341', 'LEARN ', 'new learning surfaced from S-218', cp.info],
              ['1h',  'S-218',  'HANDOVER', 'session closed · 12 decisions captured', cp.muted],
              ['2h',  'T-1612', 'REVIEW', 'reviewer requested hook bypass', cp.warn],
              ['3h',  'A-014',  'ARC   ', 'reprioritised · +2 tasks · est +1d', cp.muted],
            ].map(([t, id, kind, msg, c], i) => (
              <div key={i} style={{ display: 'grid', gridTemplateColumns: '32px 14px 60px 60px 1fr', alignItems: 'center', gap: 8, padding: '5px 14px', borderBottom: i < 4 ? `1px solid ${cp.border}` : 'none', fontFamily: cp.mono, fontSize: 11 }}>
                <span style={{ color: cp.muted }}>{t}</span>
                <span style={{ width: 5, height: 5, borderRadius: 999, background: c, boxShadow: `0 0 4px ${c}` }}/>
                <span style={{ color: cp.accent, fontWeight: 700 }}>{id}</span>
                <span style={{ color: cp.muted, letterSpacing: '0.06em' }}>{kind.trim()}</span>
                <span style={{ color: cp.text, fontFamily: cp.font, fontSize: 12 }}>{msg}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Right column: needs decision + system health */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ background: cp.surface, border: `1px solid ${cp.border}` }}>
          {cpCardTitle('NEEDS DECISION · 4', <span style={{ fontFamily: cp.mono, fontSize: 10, color: cp.warn }}>2 HIGH</span>)}
          {[
            ['T-1612', 'Approve hook bypass for migration', 'high'],
            ['L-0341', 'Promote learning to pattern?', 'medium'],
            ['R-0089', 'Risk reclassified · review', 'medium'],
            ['T-1605', 'Stale 4d · still active?', 'low'],
          ].map(([id, text, sev], i) => (
            <div key={id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 14px', borderBottom: i < 3 ? `1px solid ${cp.border}` : 'none', cursor: 'pointer' }}>
              <span style={{
                width: 5, height: 16,
                background: sev === 'high' ? cp.danger : sev === 'medium' ? cp.warn : cp.mutedSoft,
                boxShadow: sev === 'high' ? `0 0 6px ${cp.danger}` : 'none',
              }}/>
              <span style={{ fontFamily: cp.mono, fontSize: 11, color: cp.accent, fontWeight: 700, width: 54 }}>{id}</span>
              <span style={{ flex: 1, fontSize: 12.5, color: cp.text }}>{text}</span>
              <Icon name="arrow" size={11} color={cp.mutedSoft}/>
            </div>
          ))}
        </div>

        <div style={{ background: cp.surface, border: `1px solid ${cp.border}` }}>
          {cpCardTitle('SYSTEM HEALTH', null)}
          <div style={{ padding: '10px 14px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px 14px' }}>
            {[
              ['Cron jobs', '8/8', cp.success],
              ['Hooks', '14/14', cp.success],
              ['Concerns', '11', cp.info],
              ['High-sev risks', '2', cp.warn],
              ['Stale tasks', '3', cp.warn],
              ['LLM cost / day', '$2.41', cp.muted],
              ['Session cache hit', '78%', cp.muted],
              ['Tokens · session', '14k', cp.muted],
            ].map(([k, v, c], i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', paddingBottom: 6, borderBottom: `1px dashed ${cp.border}` }}>
                <span style={{ fontFamily: cp.mono, fontSize: 10.5, color: cp.muted, letterSpacing: '0.06em' }}>{k}</span>
                <span style={{ fontFamily: cp.mono, fontSize: 13, color: c, fontWeight: 600, fontVariantNumeric: 'tabular-nums' }}>{v}</span>
              </div>
            ))}
          </div>
        </div>

        <div style={{ background: cp.surface, border: `1px solid ${cp.border}` }}>
          {cpCardTitle('TOKEN USAGE', <a style={{ fontFamily: cp.mono, fontSize: 10, color: cp.accent2 }}>costs →</a>)}
          <div style={{ padding: 10 }}>
            <div style={{ fontFamily: cp.mono, fontSize: 10, color: cp.muted, marginBottom: 6, display: 'flex', justifyContent: 'space-between' }}>
              <span>session S-218</span><span>78% cache hit</span>
            </div>
            <div style={{ display: 'flex', height: 12, borderRadius: 2, overflow: 'hidden', border: `1px solid ${cp.border}` }}>
              <div style={{ width: '62%', background: cp.accent }} title="input"/>
              <div style={{ width: '24%', background: cp.info }} title="output"/>
              <div style={{ width: '14%', background: cp.warn }} title="thinking"/>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontFamily: cp.mono, fontSize: 10, color: cp.muted }}>
              <span style={{ color: cp.accent }}>14,232 in</span>
              <span style={{ color: cp.info }}>5,521 out</span>
              <span style={{ color: cp.warn }}>3,214 think</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
);

// ── Console Tasks (dense list) ─────────────────────────────────────────────

const ConsoleTasks = () => {
  const rows = [
    { id: 'T-1670', t: 'Sessions list: virtualize > 200 rows', status: 'triage', tags: ['perf'], owner: 'JG', arc: '—', age: '2h', sev: 'low' },
    { id: 'T-1668', t: 'Hook bypass needs reviewer sign-off', status: 'triage', tags: ['govern'], owner: 'AB', arc: '—', age: '4h', sev: 'warn' },
    { id: 'T-1665', t: 'Approvals mobile: persistent URL for QR', status: 'triage', tags: ['mobile'], owner: 'JG', arc: 'A-019', age: '6h', sev: 'low' },
    { id: 'T-1453', t: 'CSRF refactor — share with standalone templates', status: 'active', tags: ['refactor'], owner: 'JG', arc: 'A-014', age: '3d', focus: true },
    { id: 'T-1660', t: 'Fabric explorer: collapse on Esc', status: 'active', tags: ['ux'], owner: 'MC', arc: '—', age: '1d' },
    { id: 'T-1662', t: 'Inbox: surface stale tasks > 3d', status: 'active', tags: ['quality'], owner: 'JG', arc: '—', age: '1d', selected: true },
    { id: 'T-1659', t: 'Decisions: search by tag', status: 'active', tags: ['knowledge'], owner: 'MC', arc: '—', age: '2d' },
    { id: 'T-1612', t: 'Approve hook bypass for migration', status: 'review', tags: ['govern'], owner: 'AB', arc: '—', age: '12h', sev: 'high' },
    { id: 'T-1655', t: 'Patterns: graduate L-0341', status: 'review', tags: ['knowledge'], owner: 'JG', arc: 'A-022', age: '1d' },
    { id: 'T-1659', t: 'Decisions: search by tag', status: 'done', tags: ['knowledge'], owner: 'MC', arc: '—', age: '2d', done: true },
    { id: 'T-1658', t: 'Cockpit: focus task widget', status: 'done', tags: ['ui'], owner: 'JG', arc: '—', age: '3d', done: true },
  ];

  const statusColor = { triage: cp.muted, active: cp.accent, review: cp.warn, done: cp.success };

  return (
    <div className="ab" style={{ background: cp.bg, fontFamily: cp.font, fontSize: 12.5, color: cp.text }}>
      <CpTopBar active="WORK" breadcrumb={['work', 'tasks', 'list']} sub={{
        tabs: ['BOARD', 'LIST', 'TIMELINE', 'INBOX', 'STALE'], activeTab: 1,
        right: (
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <button style={cpBtn('ghost')}><Icon name="filter" size={11}/>filter</button>
            <button style={cpBtn('primary')}><Icon name="plus" size={11}/>new task</button>
          </div>
        ),
      }}/>

      <div style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 8 }}>
        {/* Saved view chips + counts */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontFamily: cp.mono, fontSize: 11, color: cp.muted, letterSpacing: '0.06em' }}>SAVED:</span>
          {[['mine · active', true], ['needs me', false], ['stale > 3d', false], ['arc · A-014', false]].map(([f, on], i) => (
            <div key={i} style={{
              fontFamily: cp.mono, fontSize: 10.5, padding: '4px 9px', borderRadius: 2,
              background: on ? cp.accentDim : 'transparent', border: `1px solid ${on ? cp.accent : cp.border}`,
              color: on ? cp.accent : cp.muted, cursor: 'pointer',
            }}>{f}</div>
          ))}
          <span style={{ flex: 1 }}/>
          <span style={{ fontFamily: cp.mono, fontSize: 10.5, color: cp.muted }}>
            11 rows · <span style={{ color: cp.accent }}>42 total</span> · update 1m ago
          </span>
        </div>

        {/* Table */}
        <div style={{ background: cp.surface, border: `1px solid ${cp.border}` }}>
          <div style={{
            display: 'grid', gridTemplateColumns: '32px 80px 1fr 90px 70px 80px 60px 50px 30px',
            padding: '7px 12px', borderBottom: `1px solid ${cp.borderStrong}`, gap: 10,
            fontFamily: cp.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: cp.muted, alignItems: 'center',
          }}>
            <span/><span>id</span><span>title</span><span>status</span><span>owner</span><span>arc</span><span>age</span><span>sev</span><span/>
          </div>
          {rows.map((r, i) => (
            <div key={`${r.id}-${i}`} style={{
              display: 'grid', gridTemplateColumns: '32px 80px 1fr 90px 70px 80px 60px 50px 30px',
              padding: '6px 12px', alignItems: 'center', gap: 10,
              background: r.selected ? cp.accentDim : 'transparent',
              borderBottom: `1px solid ${cp.border}`,
              opacity: r.done ? 0.55 : 1,
            }}>
              <input type="checkbox" defaultChecked={r.selected} readOnly style={{ accentColor: cp.accent, margin: 0 }}/>
              <span style={{ fontFamily: cp.mono, fontSize: 11, color: r.focus ? cp.accent : cp.textSoft, fontWeight: r.focus ? 700 : 500 }}>{r.id}</span>
              <span style={{ fontSize: 12.5, color: cp.text, display: 'inline-flex', alignItems: 'center', gap: 8, textDecoration: r.done ? 'line-through' : 'none' }}>
                {r.focus && <span style={{ fontFamily: cp.mono, fontSize: 9, color: cp.accent, padding: '1px 5px', background: cp.accentDim, border: `1px solid ${cp.accent}55`, borderRadius: 2, letterSpacing: '0.08em', fontWeight: 700 }}>FOCUS</span>}
                {r.t}
              </span>
              <span style={{ fontFamily: cp.mono, fontSize: 10.5, color: statusColor[r.status], display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                <span style={{ width: 6, height: 6, borderRadius: 999, background: statusColor[r.status], boxShadow: `0 0 4px ${statusColor[r.status]}` }}/>
                {r.status}
              </span>
              <span style={{ fontFamily: cp.mono, fontSize: 10.5, color: cp.text }}>{r.owner}</span>
              <span style={{ fontFamily: cp.mono, fontSize: 10.5, color: r.arc !== '—' ? cp.accent2 : cp.mutedSoft }}>{r.arc}</span>
              <span style={{ fontFamily: cp.mono, fontSize: 10.5, color: cp.muted }}>{r.age}</span>
              <span>
                {r.sev === 'high' && <span style={{ fontFamily: cp.mono, fontSize: 9, color: cp.danger, padding: '1px 5px', background: cp.dangerDim, borderRadius: 2, letterSpacing: '0.08em', fontWeight: 700 }}>HIGH</span>}
                {r.sev === 'warn' && <span style={{ fontFamily: cp.mono, fontSize: 9, color: cp.warn, padding: '1px 5px', background: cp.warnDim, borderRadius: 2, letterSpacing: '0.08em', fontWeight: 700 }}>WARN</span>}
                {r.sev === 'low' && <span style={{ fontFamily: cp.mono, fontSize: 9, color: cp.muted, letterSpacing: '0.08em' }}>low</span>}
              </span>
              <Icon name="chevron" size={11} color={cp.mutedSoft}/>
            </div>
          ))}
        </div>

        {/* Footer-style bulk bar */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 12, padding: '8px 12px',
          background: cp.surface, border: `1px solid ${cp.accent}`, borderRadius: 2,
          boxShadow: `inset 0 0 0 1px ${cp.surface}, 0 0 0 1px ${cp.accent}33`,
        }}>
          <span style={{ fontFamily: cp.mono, fontSize: 11, color: cp.accent, fontWeight: 700 }}>1 SELECTED · T-1662</span>
          <span style={{ width: 1, height: 14, background: cp.border }}/>
          {['MOVE', 'ASSIGN', 'TAG', 'PROMOTE→ARC', 'ARCHIVE'].map((a) => (
            <span key={a} style={{ fontFamily: cp.mono, fontSize: 10.5, color: cp.textSoft, padding: '2px 6px', cursor: 'pointer', border: `1px solid ${cp.border}`, borderRadius: 2 }}>{a}</span>
          ))}
          <span style={{ flex: 1 }}/>
          <span style={{ fontFamily: cp.mono, fontSize: 10, color: cp.muted }}>esc · clear · j/k navigate</span>
        </div>
      </div>
    </div>
  );
};

// ── Console Approvals ──────────────────────────────────────────────────────

const ConsoleApprovals = () => {
  const items = [
    { id: 'A-2391', title: 'Bypass hook · pre-commit secret-scan', risk: 'high',
      command: 'fw hook bypass --hook secret-scan --task T-1612 --justify "migration script"',
      age: '4m', who: 'AB', task: 'T-1612',
      why: 'Migration moves stored secrets to vault; legacy file fails scan.', active: true },
    { id: 'A-2390', title: 'Allow direct push to main · cherry-pick', risk: 'high',
      command: 'fw bypass --rule no-direct-main --reason "cherry-pick from arc"',
      age: '12m', who: 'JG', task: 'T-1612', why: 'Cherry-pick hotfix from A-014.' },
    { id: 'A-2387', title: 'Promote L-0341 to pattern', risk: 'medium',
      command: 'fw learning promote L-0341 --as pattern --kind workflow',
      age: '1h', who: 'JG', task: '—', why: 'Observed 4× across A-014, A-019.' },
    { id: 'A-2384', title: 'Reclassify R-0089 watching → active', risk: 'medium',
      command: 'fw risk update R-0089 --status active --severity medium',
      age: '3h', who: 'MC', task: '—', why: 'Recurred in S-217 + S-218.' },
  ];

  const riskTone = { high: 'danger', medium: 'warn', low: 'info' };

  return (
    <div className="ab" style={{ background: cp.bg, fontFamily: cp.font, fontSize: 12.5, color: cp.text }}>
      <CpTopBar active="GOVERN" breadcrumb={['govern', 'approvals', 'pending']} sub={{
        tabs: ['PENDING · 5', 'MINE', 'RESOLVED', 'ALL'], activeTab: 0,
        right: <span style={{ fontFamily: cp.mono, fontSize: 10, color: cp.muted }}>j/k navigate · a approve · r reject · ?</span>,
      }}/>

      <div style={{ padding: 14 }}>
        {/* header row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
          <h1 style={{ margin: 0, fontFamily: cp.mono, fontSize: 18, fontWeight: 700, letterSpacing: '0.04em', color: cp.textBright }}>APPROVALS QUEUE</h1>
          <StatusPill label="" value="5 PENDING" tone="warn"/>
          <StatusPill label="" value="2 HIGH" tone="danger"/>
          <span style={{ fontFamily: cp.mono, fontSize: 10.5, color: cp.muted }}>· median age 1h 12m</span>
          <span style={{ flex: 1 }}/>
          <button style={cpBtn('ghost')}>QR for mobile</button>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {items.map((it) => (
            <div key={it.id} style={{
              background: it.active ? cp.surface2 : cp.surface,
              border: `1px solid ${it.active ? cp.accent : cp.border}`,
              borderLeft: `3px solid ${it.risk === 'high' ? cp.danger : it.risk === 'medium' ? cp.warn : cp.muted}`,
              boxShadow: it.active ? `0 0 0 1px ${cp.accent}33, inset 0 0 30px ${cp.accent}08` : 'none',
              padding: '10px 14px', display: 'flex', alignItems: 'flex-start', gap: 14,
            }}>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <StatusPill label="" value={`${it.risk.toUpperCase()}-RISK`} tone={riskTone[it.risk]}/>
                  <span style={{ fontFamily: cp.mono, fontSize: 11, color: cp.accent, fontWeight: 700 }}>{it.id}</span>
                  <span style={{ fontSize: 13.5, color: cp.textBright, fontWeight: 600 }}>{it.title}</span>
                  <span style={{ flex: 1 }}/>
                  <span style={{ fontFamily: cp.mono, fontSize: 10, color: cp.muted }}>{it.who} · {it.age} · task <span style={{ color: cp.accent2 }}>{it.task}</span></span>
                </div>
                <div style={{
                  fontFamily: cp.mono, fontSize: 11, color: cp.text,
                  background: cp.bg, padding: '6px 10px', borderRadius: 2,
                  border: `1px solid ${cp.border}`, wordBreak: 'break-all',
                }}>
                  <span style={{ color: cp.accent }}>$</span> {it.command}
                </div>
                <div style={{ fontFamily: cp.mono, fontSize: 10.5, color: cp.muted, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ color: cp.muted, textTransform: 'uppercase', letterSpacing: '0.1em' }}>WHY ›</span>
                  <span style={{ color: cp.textSoft, fontFamily: cp.font, fontSize: 12 }}>{it.why}</span>
                </div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 5, minWidth: 110 }}>
                <button style={{ ...cpBtn('success'), justifyContent: 'center' }}><Icon name="check" size={11}/>APPROVE</button>
                <button style={{ ...cpBtn('danger'), justifyContent: 'center' }}><Icon name="x" size={11}/>REJECT</button>
                <button style={{ ...cpBtn('ghost'), justifyContent: 'center' }}>MORE…</button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// ── Console Fabric / Architecture ──────────────────────────────────────────

const ConsoleFabric = () => {
  // small fake graph
  const nodes = [
    { id: 'app',     label: 'app.py', x: 280, y: 130, kind: 'core' },
    { id: 'csrf',    label: 'csrf-htmx', x: 80, y: 230, kind: 'shared', focus: true },
    { id: 'base',    label: 'base.html', x: 200, y: 280, kind: 'tmpl' },
    { id: 'review',  label: 'review.html', x: 360, y: 290, kind: 'tmpl' },
    { id: 'tasks',   label: 'tasks.html', x: 100, y: 360, kind: 'tmpl' },
    { id: 'approv',  label: 'approvals.html', x: 280, y: 380, kind: 'tmpl' },
    { id: 'shared',  label: 'shared.py', x: 460, y: 180, kind: 'core' },
    { id: 'hooks',   label: 'hooks.py', x: 540, y: 290, kind: 'core' },
    { id: 'risks',   label: 'risks.py', x: 600, y: 380, kind: 'core' },
  ];
  const edges = [
    ['app', 'base'], ['app', 'shared'], ['app', 'hooks'], ['app', 'csrf'], ['base', 'csrf'], ['review', 'csrf'],
    ['base', 'tasks'], ['base', 'approv'], ['shared', 'hooks'], ['hooks', 'approv'], ['hooks', 'risks'],
  ];
  const kindColor = { core: cp.accent2, shared: cp.accent, tmpl: cp.magenta };
  const nodeById = Object.fromEntries(nodes.map((n) => [n.id, n]));

  return (
    <div className="ab" style={{ background: cp.bg, fontFamily: cp.font, fontSize: 12.5, color: cp.text }}>
      <CpTopBar active="ARCH" breadcrumb={['arch', 'fabric', 'graph']} sub={{
        tabs: ['OVERVIEW', 'GRAPH', 'SUBSYSTEMS', 'CROSS-REPO', 'DRIFT'], activeTab: 1,
        right: <span style={{ fontFamily: cp.mono, fontSize: 10, color: cp.muted }}>34 nodes · 89 edges · last scan 2m</span>,
      }}/>

      <div style={{ display: 'grid', gridTemplateColumns: '220px 1fr 280px', height: 'calc(100% - 80px)' }}>
        {/* Left: subsystem list */}
        <div style={{ borderRight: `1px solid ${cp.border}`, background: cp.surface, overflow: 'hidden' }}>
          <div style={{ padding: '8px 12px', borderBottom: `1px solid ${cp.border}`, fontFamily: cp.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: cp.muted }}>SUBSYSTEMS · 6</div>
          {[
            { name: 'Web · Cockpit', files: 32, focus: false },
            { name: 'Web · Tasks', files: 28, focus: false },
            { name: 'Web · CSRF/Forms', files: 11, focus: true },
            { name: 'Context bus', files: 18, focus: false },
            { name: 'Watchtower scanner', files: 14, focus: false },
            { name: 'Terminal adapters', files: 9, focus: false },
          ].map((s) => (
            <div key={s.name} style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '8px 12px',
              borderBottom: `1px solid ${cp.border}`,
              background: s.focus ? cp.accentDim : 'transparent',
              borderLeft: s.focus ? `2px solid ${cp.accent}` : '2px solid transparent',
              cursor: 'pointer',
            }}>
              <span style={{ width: 7, height: 7, borderRadius: 1, background: s.focus ? cp.accent : cp.muted }}/>
              <span style={{ flex: 1, fontSize: 12, color: s.focus ? cp.text : cp.textSoft }}>{s.name}</span>
              <span style={{ fontFamily: cp.mono, fontSize: 10, color: cp.muted }}>{s.files}</span>
            </div>
          ))}

          <div style={{ padding: '10px 12px 6px', fontFamily: cp.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: cp.muted, borderBottom: `1px solid ${cp.border}`, borderTop: `1px solid ${cp.border}`, marginTop: 6 }}>LEGEND</div>
          <div style={{ padding: '8px 12px', display: 'flex', flexDirection: 'column', gap: 5, fontFamily: cp.mono, fontSize: 11 }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}><span style={{ width: 8, height: 8, borderRadius: 999, background: cp.accent2 }}/><span style={{ color: cp.textSoft }}>core module</span></span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}><span style={{ width: 8, height: 8, borderRadius: 999, background: cp.accent }}/><span style={{ color: cp.textSoft }}>shared / extracted</span></span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}><span style={{ width: 8, height: 8, borderRadius: 999, background: cp.magenta }}/><span style={{ color: cp.textSoft }}>template</span></span>
          </div>
        </div>

        {/* Graph canvas */}
        <div style={{ position: 'relative', background: cp.bg, overflow: 'hidden' }}>
          {/* grid bg */}
          <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0 }}>
            <defs>
              <pattern id="cpgrid" width="40" height="40" patternUnits="userSpaceOnUse">
                <path d="M 40 0 L 0 0 0 40" fill="none" stroke={cp.border} strokeWidth="0.5"/>
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#cpgrid)"/>
            {/* edges */}
            {edges.map(([a, b], i) => {
              const A = nodeById[a], B = nodeById[b];
              const isFocus = a === 'csrf' || b === 'csrf';
              return (
                <line key={i}
                  x1={A.x} y1={A.y} x2={B.x} y2={B.y}
                  stroke={isFocus ? cp.accent : cp.borderStrong}
                  strokeWidth={isFocus ? 1.5 : 1}
                  strokeDasharray={isFocus ? 'none' : '3 3'}
                  opacity={isFocus ? 1 : 0.55}
                />
              );
            })}
            {/* nodes */}
            {nodes.map((n) => {
              const c = kindColor[n.kind];
              return (
                <g key={n.id}>
                  {n.focus && <circle cx={n.x} cy={n.y} r="22" fill="none" stroke={c} strokeWidth="1" strokeDasharray="3 3" opacity="0.6"/>}
                  <circle cx={n.x} cy={n.y} r={n.focus ? 11 : 8} fill={cp.surface} stroke={c} strokeWidth="2"/>
                  <text x={n.x} y={n.y + 24} fontFamily={cp.mono.split(',')[0]} fontSize="10" fill={n.focus ? cp.text : cp.textSoft} textAnchor="middle">{n.label}</text>
                </g>
              );
            })}
          </svg>

          {/* Floating cluster of controls */}
          <div style={{ position: 'absolute', top: 10, left: 10, display: 'flex', gap: 5 }}>
            <button style={cpBtn('ghost')}>FIT</button>
            <button style={cpBtn('ghost')}>1:1</button>
            <button style={cpBtn('ghost')}><Icon name="filter" size={10}/>FILTER</button>
          </div>
          <div style={{ position: 'absolute', bottom: 10, right: 10, fontFamily: cp.mono, fontSize: 9.5, color: cp.muted, display: 'flex', gap: 10 }}>
            <span>scroll · pan</span><span>shift+scroll · zoom</span><span>esc · collapse</span>
          </div>
        </div>

        {/* Right: node detail */}
        <div style={{ borderLeft: `1px solid ${cp.border}`, background: cp.surface, display: 'flex', flexDirection: 'column' }}>
          {cpCardTitle('SELECTED · csrf-htmx', <Icon name="x" size={12} color={cp.muted}/>)}
          <div style={{ padding: '10px 14px', display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: cp.textBright }}>csrf-htmx.js</div>
            <div style={{ fontFamily: cp.mono, fontSize: 10.5, color: cp.muted }}>shared · 47 lines · last touch 12m ago</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
              <StatusPill label="" value="ARC · A-014" tone="info"/>
              <StatusPill label="" value="2 IMPORTS" tone="accent"/>
            </div>
          </div>

          <div style={{ padding: '6px 14px', fontFamily: cp.mono, fontSize: 9.5, letterSpacing: '0.12em', textTransform: 'uppercase', color: cp.muted, borderTop: `1px solid ${cp.border}`, borderBottom: `1px solid ${cp.border}`, background: cp.surface2 }}>IMPORTED BY · 2</div>
          {[['base.html', 'web/templates'], ['review.html', 'web/templates']].map(([n, p]) => (
            <div key={n} style={{ padding: '7px 14px', borderBottom: `1px solid ${cp.border}`, display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
              <span style={{ width: 7, height: 7, borderRadius: 999, background: cp.magenta }}/>
              <span style={{ fontFamily: cp.mono, fontSize: 11.5, color: cp.text }}>{n}</span>
              <span style={{ fontFamily: cp.mono, fontSize: 10, color: cp.muted, marginLeft: 'auto' }}>{p}</span>
            </div>
          ))}

          <div style={{ padding: '6px 14px', fontFamily: cp.mono, fontSize: 9.5, letterSpacing: '0.12em', textTransform: 'uppercase', color: cp.muted, borderBottom: `1px solid ${cp.border}`, background: cp.surface2 }}>RECENT</div>
          {[
            ['12m', 'T-1453', 'extracted'],
            ['38m', 'S-218', 'session·refactor'],
            ['1h', 'L-0341', 'learn·spawned'],
          ].map(([t, id, msg], i) => (
            <div key={i} style={{ padding: '6px 14px', borderBottom: `1px solid ${cp.border}`, display: 'flex', alignItems: 'center', gap: 8, fontFamily: cp.mono, fontSize: 11 }}>
              <span style={{ color: cp.muted, width: 28 }}>{t}</span>
              <span style={{ color: cp.accent, width: 50, fontWeight: 700 }}>{id}</span>
              <span style={{ color: cp.text }}>{msg}</span>
            </div>
          ))}

          <div style={{ marginTop: 'auto', padding: 12, borderTop: `1px solid ${cp.border}`, display: 'flex', gap: 5 }}>
            <button style={{ ...cpBtn('primary'), justifyContent: 'center', flex: 1 }}>OPEN FILE</button>
            <button style={{ ...cpBtn('ghost'), justifyContent: 'center' }}>PIN</button>
          </div>
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { ConsoleCockpit, ConsoleTasks, ConsoleApprovals, ConsoleFabric, consolePalette: cp });
