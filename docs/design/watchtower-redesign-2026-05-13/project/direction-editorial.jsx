// Direction B — EDITORIAL
// Palette: warm linen + terracotta. Light theme.
// Typography: Newsreader (serif) for headings + Inter body + JetBrains Mono.
// Mood: editorial, calm, text-forward. Quiet authority.

const ed = {
  bg: '#f4efe5',
  surface: '#fbf8f1',
  surface2: '#f7f2e7',
  border: '#e1d8c4',
  borderStrong: '#cdc1a8',
  text: '#1f1b16',
  textSoft: '#3d362c',
  muted: '#7a7163',
  mutedSoft: '#a8a08e',
  accent: '#bd5b3a',
  accentDeep: '#9a4426',
  accentSoft: '#f5dcc9',
  accentInk: '#fbf8f1',
  rule: '#1f1b16',
  success: '#5b8a5a',
  warn: '#c98a2b',
  danger: '#b1503e',
  info: '#3a7088',
  successSoft: '#dceac9',
  warnSoft: '#f2dca0',
  dangerSoft: '#ecccc0',
  infoSoft: '#cfdee5',
  font: '"Inter", system-ui, sans-serif',
  serif: '"Newsreader", "Source Serif 4", Georgia, serif',
  mono: '"JetBrains Mono", ui-monospace, monospace',
};

// ── Top bar ────────────────────────────────────────────────────────────────

const EdTopBar = ({ active = 'Work', sub, breadcrumb, issueLabel = 'Issue 42 · April 2026' }) => (
  <div style={{ background: ed.surface, borderBottom: `1px solid ${ed.borderStrong}` }}>
    {/* Masthead (serif brand) */}
    <div style={{
      display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between',
      padding: '14px 28px 8px', borderBottom: `2px solid ${ed.rule}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 12 }}>
        <span style={{
          fontFamily: ed.serif, fontStyle: 'italic', fontWeight: 600,
          fontSize: 28, letterSpacing: '-0.015em', color: ed.text, lineHeight: 1,
        }}>Watchtower</span>
        <span style={{ fontFamily: ed.mono, fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: ed.muted }}>
          The Agentic Engineering Daily
        </span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, fontFamily: ed.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: ed.muted }}>
        <span>{issueLabel}</span>
        <span style={{ width: 1, height: 12, background: ed.borderStrong }}/>
        <span>geelen-monorepo</span>
        <button style={{ width: 28, height: 28, padding: 0, border: 'none', background: 'transparent', cursor: 'pointer', color: ed.text }}>
          <Icon name="search" size={14}/>
        </button>
      </div>
    </div>

    {/* Section bar */}
    <div style={{ display: 'flex', alignItems: 'center', padding: '0 28px', gap: 22, height: 38 }}>
      {['Work', 'Knowledge', 'Architecture', 'Govern'].map((g) => (
        <div key={g} style={{
          fontFamily: ed.serif, fontSize: 14, fontWeight: g === active ? 600 : 500,
          color: g === active ? ed.accent : ed.text,
          borderBottom: g === active ? `2px solid ${ed.accent}` : '2px solid transparent',
          padding: '8px 0 6px', cursor: 'pointer',
        }}>{g}</div>
      ))}
      <div style={{ flex: 1 }}/>

      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '5px 10px', borderRadius: 4, background: ed.surface2, border: `1px solid ${ed.border}`,
        color: ed.muted, minWidth: 240, cursor: 'pointer',
      }}>
        <Icon name="search" size={12}/>
        <span style={{ fontSize: 11.5, fontStyle: 'italic' }}>Search the wire…</span>
        <span style={{ flex: 1 }}/>
        <span style={{ fontFamily: ed.mono, fontSize: 9.5, color: ed.muted, padding: '1px 5px', background: ed.surface, border: `1px solid ${ed.border}`, borderRadius: 2 }}>⌘K</span>
      </div>
    </div>

    {/* Contextual sub + breadcrumb */}
    {sub && (
      <div style={{ borderTop: `1px solid ${ed.border}`, padding: '6px 28px 8px', display: 'flex', alignItems: 'center', gap: 14 }}>
        <div style={{ fontFamily: ed.mono, fontSize: 10, color: ed.muted, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
          {breadcrumb.map((b, i) => (
            <React.Fragment key={i}>
              {i > 0 && <span style={{ margin: '0 6px', color: ed.mutedSoft }}>/</span>}
              <span style={{ color: i === breadcrumb.length - 1 ? ed.text : ed.muted }}>{b}</span>
            </React.Fragment>
          ))}
        </div>
        <span style={{ width: 1, height: 12, background: ed.borderStrong }}/>
        <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
          {sub.tabs.map((t, i) => (
            <div key={t} style={{
              fontFamily: ed.serif, fontSize: 13, fontStyle: 'italic',
              color: i === sub.activeTab ? ed.accent : ed.muted,
              fontWeight: i === sub.activeTab ? 700 : 500,
              cursor: 'pointer',
            }}>{t}</div>
          ))}
        </div>
        <div style={{ flex: 1 }}/>
        {sub.right}
      </div>
    )}
  </div>
);

const EdRule = ({ char = '§', label }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 10, color: ed.muted, margin: '6px 0 10px' }}>
    <span style={{ fontFamily: ed.serif, fontStyle: 'italic', fontSize: 14, color: ed.accent }}>{char}</span>
    <span style={{ fontFamily: ed.mono, fontSize: 10, letterSpacing: '0.14em', textTransform: 'uppercase', color: ed.muted }}>{label}</span>
    <span style={{ flex: 1, height: 1, background: ed.borderStrong }}/>
  </div>
);

// ── Editorial Cockpit ──────────────────────────────────────────────────────

const EditorialCockpit = () => (
  <div className="ab" style={{ background: ed.bg, fontFamily: ed.font, fontSize: 13, color: ed.text }}>
    <EdTopBar active="Work" breadcrumb={['Watchtower', 'Cockpit']} sub={{
      tabs: ['Front page', 'Activity', 'Health', 'Inbox'], activeTab: 0,
      right: <span style={{ fontFamily: ed.mono, fontSize: 10, color: ed.muted }}>Filed 2 minutes ago · Audit PASS</span>,
    }}/>

    <div style={{ padding: '20px 28px 24px', display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 28 }}>

      {/* MAIN COLUMN */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        {/* Lead story = focus task */}
        <div style={{ paddingBottom: 14, borderBottom: `1px solid ${ed.borderStrong}` }}>
          <div style={{ fontFamily: ed.mono, fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: ed.accent, marginBottom: 6 }}>
            Lead · Focus task
          </div>
          <h1 style={{
            fontFamily: ed.serif, fontWeight: 600, fontSize: 34, lineHeight: 1.1,
            letterSpacing: '-0.015em', margin: '0 0 6px',
          }}>
            CSRF refactor lands today — standalone templates finally share one helper.
          </h1>
          <div style={{ fontFamily: ed.serif, fontStyle: 'italic', fontSize: 15, color: ed.muted, marginBottom: 12, lineHeight: 1.5 }}>
            After three sessions, T-1453 consolidates fetchWithCsrf into <code style={{ fontFamily: ed.mono, fontStyle: 'normal', fontSize: 13, color: ed.text }}>csrf-htmx.js</code>. base.html and review.html now share the same code path. Arc <code style={{ fontFamily: ed.mono, fontStyle: 'normal', fontSize: 13, color: ed.accent }}>A-014</code> is 4 of 7 tasks complete.
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, fontFamily: ed.mono, fontSize: 11, color: ed.muted }}>
            <span style={{ fontWeight: 600, color: ed.text }}>T-1453</span>
            <span>·</span><span>Active · session S-218</span>
            <span>·</span><span>2 commits</span>
            <span style={{ flex: 1 }}/>
            <button style={btnEd('primary')}>Resume session</button>
            <button style={btnEd('ghost')}>Open detail</button>
          </div>
        </div>

        {/* Needs decision section */}
        <div>
          <EdRule char="¶" label="Needs your decision · 4"/>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px 28px' }}>
            {[
              { id: 'T-1612', kind: 'Approval', title: 'Approve hook bypass for migration', body: 'Pre-commit secret-scan blocks a legitimate migration script. AB requests bypass with vault rotation in same PR.', sev: 'high' },
              { id: 'L-0341', kind: 'Learning', title: 'Promote to pattern?', body: 'Observed 4× across A-014 and A-019 — “extract before share”. Reviewer wants a quick read.', sev: 'medium' },
              { id: 'R-0089', kind: 'Risk', title: 'Re-classified · review needed', body: 'Recurred in S-217 and S-218. Was “watching”; severity bump proposed by MC.', sev: 'medium' },
              { id: 'T-1605', kind: 'Stale', title: 'Active 4 days · still warm?', body: 'Last touched in S-211. Either close, kick the owner, or archive.', sev: 'low' },
            ].map((it) => (
              <div key={it.id} style={{ borderLeft: `2px solid ${it.sev === 'high' ? ed.danger : it.sev === 'medium' ? ed.warn : ed.borderStrong}`, paddingLeft: 12 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                  <span style={{ fontFamily: ed.mono, fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: ed.muted }}>{it.kind}</span>
                  <span style={{ fontFamily: ed.mono, fontSize: 11, color: ed.accent, fontWeight: 700 }}>{it.id}</span>
                </div>
                <div style={{ fontFamily: ed.serif, fontSize: 16, fontWeight: 600, lineHeight: 1.3, marginBottom: 4 }}>{it.title}</div>
                <div style={{ fontSize: 12.5, color: ed.textSoft, lineHeight: 1.55 }}>{it.body}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Recent activity as feed */}
        <div>
          <EdRule char="◊" label="Wire · last 12 hours"/>
          <div style={{ borderTop: `1px solid ${ed.border}` }}>
            {[
              ['12m', 'T-1453', 'Merged. CSRF helper now lives in csrf-htmx.js. base.html updated.', ed.success],
              ['38m', 'L-0341', 'New learning surfaced from session S-218. “Extract before share.”', ed.info],
              ['1h',  'S-218',  'Handover written. 12 decisions captured; 2 spawned new tasks.', ed.muted],
              ['2h',  'T-1612', 'Reviewer requested hook bypass; high-risk approval pending.', ed.warn],
              ['3h',  'A-014',  'Arc reprioritised. Two tasks added to the back; estimate +1d.', ed.muted],
            ].map(([t, id, msg, c], i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'baseline', gap: 12, padding: '8px 0', borderBottom: `1px solid ${ed.border}` }}>
                <span style={{ fontFamily: ed.mono, fontSize: 10.5, color: ed.muted, width: 32 }}>{t}</span>
                <span style={{ width: 6, height: 6, borderRadius: 999, background: c, alignSelf: 'center' }}/>
                <span style={{ fontFamily: ed.mono, fontSize: 11, color: ed.accent, fontWeight: 700, width: 56 }}>{id}</span>
                <span style={{ flex: 1, fontFamily: ed.serif, fontSize: 13.5, color: ed.textSoft, lineHeight: 1.45 }}>{msg}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* SIDEBAR COLUMN */}
      <aside style={{ display: 'flex', flexDirection: 'column', gap: 18, paddingLeft: 22, borderLeft: `1px solid ${ed.borderStrong}` }}>
        <div>
          <EdRule char="§" label="Project Pulse"/>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {[
              ['Tasks active', '42', '+3 this week', ed.accent, [3,5,4,6,8,7,9,10,9,11,12,10,11,12]],
              ['Approvals pending', '4', '−1 since yesterday', ed.warn, [2,3,5,4,5,6,7,5,4,5,4,3,4,4]],
              ['Concerns watching', '11', '2 high-severity', ed.danger, [6,7,8,7,9,8,10,9,11,10,11,12,11,11]],
              ['Traceability', '94%', '+1 point this sprint', ed.success, [80,82,85,84,86,88,89,90,91,92,93,93,94,94]],
            ].map(([label, value, delta, c, spark]) => (
              <div key={label} style={{ display: 'flex', alignItems: 'baseline', gap: 8, paddingBottom: 8, borderBottom: `1px dotted ${ed.borderStrong}` }}>
                <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 1 }}>
                  <span style={{ fontFamily: ed.mono, fontSize: 9.5, letterSpacing: '0.14em', textTransform: 'uppercase', color: ed.muted }}>{label}</span>
                  <span style={{ fontFamily: ed.serif, fontSize: 22, fontWeight: 600, fontVariantNumeric: 'tabular-nums', color: ed.text, lineHeight: 1.1 }}>{value}</span>
                  <span style={{ fontFamily: ed.serif, fontStyle: 'italic', fontSize: 11, color: ed.muted }}>{delta}</span>
                </div>
                <Sparkline values={spark} color={c} w={70} h={26}/>
              </div>
            ))}
          </div>
        </div>

        <div>
          <EdRule char="◆" label="Arcs in flight · 3"/>
          {[
            { id: 'A-014', name: 'CSRF & template unification', done: 4, total: 7, focused: true },
            { id: 'A-019', name: 'Approvals mobile + side-panel', done: 1, total: 5 },
            { id: 'A-022', name: 'Learnings → patterns graduation', done: 6, total: 9 },
          ].map((a) => (
            <div key={a.id} style={{ padding: '8px 0', borderBottom: `1px solid ${ed.border}`, display: 'flex', flexDirection: 'column', gap: 4 }}>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
                <span style={{ fontFamily: ed.mono, fontSize: 11, color: a.focused ? ed.accent : ed.muted, fontWeight: 700 }}>{a.id}</span>
                <span style={{ fontFamily: ed.serif, fontSize: 13.5, fontWeight: 500, flex: 1 }}>{a.name}</span>
                <span style={{ fontFamily: ed.mono, fontSize: 10.5, color: ed.muted }}>{a.done}/{a.total}</span>
              </div>
              <div style={{ height: 3, background: ed.border, borderRadius: 2 }}>
                <div style={{ width: `${a.done / a.total * 100}%`, height: '100%', background: a.focused ? ed.accent : ed.muted, borderRadius: 2 }}/>
              </div>
            </div>
          ))}
        </div>

        <div>
          <EdRule char="✦" label="On the wires"/>
          <div style={{ fontFamily: ed.serif, fontSize: 13, lineHeight: 1.55, color: ed.textSoft }}>
            Session <code style={{ fontFamily: ed.mono, fontSize: 12, color: ed.text }}>S-218</code> closed 38 minutes ago and produced <em>twelve decisions, three spawned tasks, and one new learning</em>. The next session opens against arc A-014 unless re-pointed.
          </div>
        </div>
      </aside>
    </div>
  </div>
);

const btnEd = (variant = 'ghost') => {
  const base = { padding: '5px 12px', borderRadius: 3, fontSize: 11.5, fontWeight: 600, cursor: 'pointer', border: 'none', fontFamily: ed.font, display: 'inline-flex', alignItems: 'center', gap: 5, letterSpacing: '0.04em', textTransform: 'uppercase' };
  if (variant === 'primary') return { ...base, background: ed.accent, color: ed.accentInk };
  if (variant === 'success') return { ...base, background: ed.success, color: '#fff' };
  if (variant === 'danger') return { ...base, background: 'transparent', color: ed.danger, border: `1px solid ${ed.danger}` };
  return { ...base, background: 'transparent', color: ed.text, border: `1px solid ${ed.borderStrong}` };
};

// ── Editorial Tasks (list-oriented) ────────────────────────────────────────

const EditorialTasks = () => {
  const rows = [
    { id: 'T-1670', t: 'Sessions list: virtualize > 200 rows', status: 'triage', tags: ['perf'], owner: 'JG', arc: '—', age: '2h' },
    { id: 'T-1668', t: 'Hook bypass needs reviewer sign-off', status: 'triage', tags: ['govern'], owner: 'AB', arc: '—', age: '4h', flag: 'warn' },
    { id: 'T-1665', t: 'Approvals mobile: persistent URL for QR', status: 'triage', tags: ['mobile'], owner: 'JG', arc: 'A-019', age: '6h' },
    { id: 'T-1453', t: 'CSRF refactor — share with standalone templates', status: 'active', tags: ['refactor'], owner: 'JG', arc: 'A-014', age: '3d', focus: true },
    { id: 'T-1660', t: 'Fabric explorer: collapse on Esc', status: 'active', tags: ['ux'], owner: 'MC', arc: '—', age: '1d' },
    { id: 'T-1662', t: 'Inbox: surface stale tasks > 3d', status: 'active', tags: ['quality'], owner: 'JG', arc: '—', age: '1d', selected: true },
    { id: 'T-1659', t: 'Decisions: search by tag', status: 'active', tags: ['knowledge'], owner: 'MC', arc: '—', age: '2d' },
    { id: 'T-1612', t: 'Approve hook bypass for migration', status: 'review', tags: ['govern'], owner: 'AB', arc: '—', age: '12h', flag: 'high' },
    { id: 'T-1655', t: 'Patterns: graduate L-0341', status: 'review', tags: ['knowledge'], owner: 'JG', arc: 'A-022', age: '1d' },
  ];

  const statusColor = { triage: ed.muted, active: ed.accent, review: ed.warn, done: ed.success };

  return (
    <div className="ab" style={{ background: ed.bg, fontFamily: ed.font, fontSize: 13, color: ed.text }}>
      <EdTopBar active="Work" breadcrumb={['Work', 'Tasks', 'Front page']} sub={{
        tabs: ['Front page', 'Board', 'List', 'Timeline', 'Stale'], activeTab: 2,
        right: (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <button style={btnEd('ghost')}><Icon name="filter" size={11}/>Filter</button>
            <button style={btnEd('primary')}><Icon name="plus" size={11}/>New task</button>
          </div>
        ),
      }}/>

      <div style={{ padding: '20px 28px' }}>
        {/* Headline */}
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', borderBottom: `2px solid ${ed.rule}`, paddingBottom: 10, marginBottom: 14 }}>
          <div>
            <div style={{ fontFamily: ed.mono, fontSize: 10, letterSpacing: '0.14em', textTransform: 'uppercase', color: ed.muted, marginBottom: 4 }}>Section · Work</div>
            <h1 style={{ fontFamily: ed.serif, margin: 0, fontWeight: 600, fontSize: 30, letterSpacing: '-0.015em' }}>Tasks · List</h1>
          </div>
          <div style={{ fontFamily: ed.serif, fontStyle: 'italic', fontSize: 13, color: ed.muted }}>42 active · 5 review · 7 done this week</div>
        </div>

        {/* Filter chips */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
          {[['arc · A-014', true], ['owner · me', true], ['status · ≠ done', false]].map(([f, on], i) => (
            <div key={i} style={{
              display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 10px', borderRadius: 2,
              background: on ? ed.accentSoft : 'transparent', border: `1px solid ${on ? ed.accent : ed.borderStrong}`,
              fontFamily: ed.mono, fontSize: 10.5, color: on ? ed.accentDeep : ed.muted,
            }}>
              <Icon name="filter" size={10}/>{f}{on && <Icon name="x" size={9}/>}
            </div>
          ))}
          <span style={{ fontFamily: ed.serif, fontStyle: 'italic', fontSize: 11, color: ed.muted }}>9 of 42 shown</span>
          <span style={{ flex: 1 }}/>
          <span style={{ fontFamily: ed.mono, fontSize: 10, color: ed.muted, padding: '2px 6px', background: ed.surface, border: `1px solid ${ed.border}`, borderRadius: 2 }}>Save view</span>
        </div>

        {/* Table */}
        <div style={{ border: `1px solid ${ed.borderStrong}`, background: ed.surface }}>
          <div style={{
            display: 'grid', gridTemplateColumns: '28px 90px 1fr 90px 90px 90px 60px 50px',
            padding: '8px 12px', borderBottom: `1px solid ${ed.borderStrong}`,
            fontFamily: ed.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: ed.muted, alignItems: 'center', gap: 12,
          }}>
            <span/><span>ID</span><span>Headline</span><span>Status</span><span>Owner</span><span>Arc</span><span>Age</span><span/>
          </div>
          {rows.map((r, i) => (
            <div key={r.id} style={{
              display: 'grid', gridTemplateColumns: '28px 90px 1fr 90px 90px 90px 60px 50px',
              padding: '8px 12px', alignItems: 'center', gap: 12,
              background: r.selected ? ed.accentSoft : (i % 2 === 1 ? ed.surface2 : 'transparent'),
              borderBottom: `1px solid ${ed.border}`,
            }}>
              <input type="checkbox" defaultChecked={r.selected} readOnly style={{ accentColor: ed.accent, margin: 0 }}/>
              <span style={{ fontFamily: ed.mono, fontSize: 11, color: r.focus ? ed.accent : ed.muted, fontWeight: r.focus ? 700 : 500 }}>{r.id}</span>
              <span style={{ fontFamily: ed.serif, fontSize: 14, fontWeight: 500, color: ed.text, display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                {r.focus && <span style={{ fontFamily: ed.mono, fontSize: 9, color: ed.accent, fontWeight: 700, letterSpacing: '0.1em' }}>FOCUS ·</span>}
                {r.t}
                {r.flag === 'high' && <span style={{ fontFamily: ed.mono, fontSize: 9, color: ed.danger, padding: '1px 5px', background: ed.dangerSoft, borderRadius: 2, letterSpacing: '0.08em' }}>HIGH</span>}
                {r.flag === 'warn' && <span style={{ fontFamily: ed.mono, fontSize: 9, color: ed.warn, padding: '1px 5px', background: ed.warnSoft, borderRadius: 2, letterSpacing: '0.08em' }}>REVIEW</span>}
              </span>
              <span style={{ fontFamily: ed.mono, fontSize: 10.5, color: statusColor[r.status], display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                <span style={{ width: 6, height: 6, borderRadius: 999, background: statusColor[r.status] }}/>
                {r.status}
              </span>
              <span style={{ fontFamily: ed.serif, fontStyle: 'italic', fontSize: 12.5, color: ed.text }}>{r.owner}</span>
              <span style={{ fontFamily: ed.mono, fontSize: 10.5, color: r.arc !== '—' ? ed.accent : ed.muted }}>{r.arc}</span>
              <span style={{ fontFamily: ed.mono, fontSize: 10.5, color: ed.muted }}>{r.age}</span>
              <Icon name="chevron" size={12} color={ed.mutedSoft}/>
            </div>
          ))}
        </div>

        {/* Bulk bar (subtle, footer-style) */}
        <div style={{
          marginTop: 12, padding: '8px 14px', display: 'flex', alignItems: 'center', gap: 12,
          background: ed.text, color: ed.bg, borderRadius: 3,
        }}>
          <span style={{ fontFamily: ed.mono, fontSize: 11, fontWeight: 600 }}>1 selected · T-1662</span>
          <span style={{ width: 1, height: 12, background: 'rgba(255,255,255,0.18)' }}/>
          {['Move to…', 'Assign…', 'Add tag', 'Promote to arc'].map((a) => (
            <span key={a} style={{ fontFamily: ed.serif, fontSize: 12.5, fontStyle: 'italic', cursor: 'pointer' }}>{a}</span>
          ))}
          <span style={{ flex: 1 }}/>
          <span style={{ fontFamily: ed.mono, fontSize: 10, color: 'rgba(255,255,255,0.55)' }}>esc · clear</span>
        </div>
      </div>
    </div>
  );
};

// ── Editorial Approvals ────────────────────────────────────────────────────

const EditorialApprovals = () => {
  const items = [
    { id: 'A-2391', title: 'Bypass hook · pre-commit secret-scan', risk: 'high',
      command: 'fw hook bypass --hook secret-scan --task T-1612 --justify "migration script"',
      age: '4 minutes ago', who: 'AB', task: 'T-1612',
      why: 'Migration script moves stored secrets to vault; legacy file fails the scan in the meantime. Bypass is bracketed by the rotation in the same PR.' },
    { id: 'A-2390', title: 'Allow direct push to main', risk: 'high',
      command: 'fw bypass --rule no-direct-main --reason "cherry-pick from arc"',
      age: '12 minutes ago', who: 'JG', task: 'T-1612',
      why: 'Cherry-pick hotfix from A-014 branch. Will be reverted by automated PR within 30 minutes.' },
    { id: 'A-2387', title: 'Promote L-0341 to pattern', risk: 'medium',
      command: 'fw learning promote L-0341 --as pattern --kind workflow',
      age: '1 hour ago', who: 'JG', task: '—',
      why: 'Observed 4× across A-014 and A-019. Reviewer recommends graduation to pattern of kind "workflow".' },
  ];
  const riskColor = { high: ed.danger, medium: ed.warn, low: ed.muted };

  return (
    <div className="ab" style={{ background: ed.bg, fontFamily: ed.font, fontSize: 13, color: ed.text }}>
      <EdTopBar active="Govern" breadcrumb={['Govern', 'Approvals', 'Pending']} sub={{
        tabs: ['Pending · 5', 'Mine', 'Resolved', 'All'], activeTab: 0,
        right: <span style={{ fontFamily: ed.mono, fontSize: 10, color: ed.muted }}>j/k navigate · a approve · r reject · ?</span>,
      }}/>

      <div style={{ padding: '20px 28px' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', borderBottom: `2px solid ${ed.rule}`, paddingBottom: 10, marginBottom: 6 }}>
          <div>
            <div style={{ fontFamily: ed.mono, fontSize: 10, letterSpacing: '0.14em', textTransform: 'uppercase', color: ed.muted, marginBottom: 4 }}>Editorial · Govern</div>
            <h1 style={{ fontFamily: ed.serif, margin: 0, fontWeight: 600, fontSize: 30, letterSpacing: '-0.015em' }}>Approvals desk</h1>
          </div>
          <div style={{ fontFamily: ed.serif, fontStyle: 'italic', fontSize: 13, color: ed.muted }}>
            5 pending · 2 high-risk · median age 1h 12m
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 12, marginBottom: 16 }}>
          {[['risk · high+', true], ['mine', false], ['needs me', false]].map(([f, on], i) => (
            <div key={i} style={{
              display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 10px', borderRadius: 2,
              background: on ? ed.accentSoft : 'transparent', border: `1px solid ${on ? ed.accent : ed.borderStrong}`,
              fontFamily: ed.mono, fontSize: 10.5, color: on ? ed.accentDeep : ed.muted,
            }}>
              <Icon name="filter" size={10}/>{f}{on && <Icon name="x" size={9}/>}
            </div>
          ))}
        </div>

        {items.map((it, i) => (
          <article key={it.id} style={{ paddingBottom: 18, marginBottom: 18, borderBottom: `1px solid ${ed.borderStrong}` }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 6 }}>
              <span style={{ fontFamily: ed.mono, fontSize: 10, color: riskColor[it.risk], letterSpacing: '0.14em', textTransform: 'uppercase', fontWeight: 700 }}>{it.risk}-risk</span>
              <span style={{ fontFamily: ed.mono, fontSize: 11, color: ed.accent, fontWeight: 700 }}>{it.id}</span>
              <span style={{ flex: 1 }}/>
              <span style={{ fontFamily: ed.serif, fontStyle: 'italic', fontSize: 12, color: ed.muted }}>By <strong style={{ fontStyle: 'normal' }}>{it.who}</strong>, {it.age} · ref task <code style={{ fontFamily: ed.mono, fontStyle: 'normal', fontSize: 11, color: ed.accent }}>{it.task}</code></span>
            </div>

            <h2 style={{ fontFamily: ed.serif, fontWeight: 600, fontSize: 22, letterSpacing: '-0.01em', margin: '0 0 8px', lineHeight: 1.2 }}>{it.title}</h2>

            <div style={{
              fontFamily: ed.mono, fontSize: 11.5, color: ed.text,
              background: ed.surface2, padding: '8px 12px',
              borderLeft: `3px solid ${riskColor[it.risk]}`,
              marginBottom: 10, wordBreak: 'break-all',
            }}>$ {it.command}</div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr auto', gap: 24, alignItems: 'start' }}>
              <p style={{ fontFamily: ed.serif, fontSize: 14.5, lineHeight: 1.55, color: ed.textSoft, margin: 0 }}>
                <span style={{ fontFamily: ed.mono, fontStyle: 'normal', fontSize: 10, letterSpacing: '0.14em', textTransform: 'uppercase', color: ed.muted, marginRight: 8 }}>Why</span>
                {it.why}
              </p>

              <div style={{ display: 'flex', gap: 8 }}>
                <button style={btnEd('success')}><Icon name="check" size={11}/>Approve</button>
                <button style={btnEd('danger')}>Reject</button>
                <button style={btnEd('ghost')}>More…</button>
              </div>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
};

Object.assign(window, { EditorialCockpit, EditorialTasks, EditorialApprovals, edPalette: ed });
