// Three navigation patterns, presented as full-width chrome strips with
// a hint of the content area below so you can judge each in context.

const NAV_GROUPS = [
  { name: 'Work', items: ['Tasks', 'Inception', 'Assumptions', 'Timeline', 'Prompts'], current: 'Tasks' },
  { name: 'Knowledge', items: ['Learnings', 'Graduation', 'Patterns', 'Decisions'] },
  { name: 'Architecture', items: ['Fabric', 'Explorer', 'Arcs', 'Terminal', 'Sessions'] },
  { name: 'Govern', items: ['Approvals', 'Directives', 'Enforcement', 'Hooks', 'Risks', 'Gaps', 'Quality', 'Metrics', 'Costs', 'Config', 'Cron'] },
];

// ── Pattern 1: Top-bar primary + contextual sub-nav ────────────────────────

const NavPatternTopBar = ({ selected, onSelect }) => {
  const baseFont = 'Inter, system-ui, sans-serif';
  return (
    <div className="ab" onClick={onSelect} style={{
      background: '#fafaf8', fontFamily: baseFont, fontSize: 13, color: '#1a1715',
      cursor: 'pointer',
      boxShadow: selected ? 'inset 0 0 0 3px #1a1715' : 'none',
      transition: 'box-shadow .15s', position: 'relative',
    }}>
      {selected && (
        <div style={{ position: 'absolute', top: 10, right: 10, zIndex: 5, width: 22, height: 22, borderRadius: 999, background: '#1a1715', color: '#fff', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 1px 3px rgba(0,0,0,0.2)' }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </div>
      )}
      {/* Primary nav */}
      <div style={{
        height: 48, display: 'flex', alignItems: 'center', padding: '0 20px', gap: 4,
        background: '#fff', borderBottom: '1px solid #ececec',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginRight: 22, fontWeight: 600, color: '#1a1715' }}>
          <WTMark size={16}/>
          <span style={{ letterSpacing: '-0.005em' }}>Watchtower</span>
          <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#9ea0a6', marginLeft: 6 }}>v0.9.4</span>
        </div>

        {NAV_GROUPS.map((g) => (
          <div key={g.name} style={{
            padding: '6px 12px', borderRadius: 6,
            background: g.current ? '#f2f2ef' : 'transparent',
            color: g.current ? '#1a1715' : '#5a5750',
            fontWeight: g.current ? 600 : 500, display: 'flex', alignItems: 'center', gap: 4, cursor: 'pointer',
          }}>
            {g.name}
            <Icon name="chevronD" size={11} color="#9ea0a6"/>
          </div>
        ))}

        <div style={{ flex: 1 }}/>

        {/* Search / palette trigger */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          padding: '5px 10px', borderRadius: 6, background: '#f4f3ef',
          color: '#7a766c', minWidth: 220, cursor: 'pointer',
        }}>
          <Icon name="search" size={13} color="#7a766c"/>
          <span style={{ fontSize: 12 }}>Search or jump to…</span>
          <span style={{ flex: 1 }}/>
          <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#9b9789', padding: '2px 6px', background: '#eae8e2', borderRadius: 4 }}>⌘K</span>
        </div>

        <button style={{ width: 32, height: 32, marginLeft: 8, padding: 0, borderRadius: 6, border: 'none', background: 'transparent', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', color: '#5a5750' }}>
          <Icon name="bell" size={15}/>
        </button>
      </div>

      {/* Contextual sub-nav */}
      <div style={{
        height: 40, display: 'flex', alignItems: 'center', padding: '0 20px', gap: 2,
        background: '#fff', borderBottom: '1px solid #ececec',
      }}>
        {/* Breadcrumb */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginRight: 14, fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#6e6a60' }}>
          <span>Work</span>
          <Icon name="chevron" size={9} color="#bcb8ad"/>
          <span style={{ color: '#1a1715' }}>Tasks</span>
        </div>

        {/* Tabs */}
        {['Board', 'List', 'Timeline', 'Inbox', 'Stale'].map((t, i) => (
          <div key={t} style={{
            padding: '7px 12px', borderRadius: 6,
            background: i === 0 ? '#f2f2ef' : 'transparent',
            color: i === 0 ? '#1a1715' : '#6e6a60',
            fontWeight: i === 0 ? 600 : 500, fontSize: 12.5, cursor: 'pointer',
          }}>{t}</div>
        ))}

        <div style={{ flex: 1 }}/>

        <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: '#6e6a60', fontSize: 11 }}>
          <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>42 active</span>
          <span style={{ width: 1, height: 12, background: '#e0ddd2' }}/>
          <span>Pinned · Recent</span>
        </div>
      </div>

      {/* Content stripe (hint) */}
      <div style={{ padding: 24, color: '#9b9789', fontSize: 12 }}>
        <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>Pattern 1</div>
        <div style={{ fontSize: 22, fontWeight: 600, color: '#1a1715', letterSpacing: '-0.01em', marginBottom: 4 }}>Top-bar primary · contextual tabs · breadcrumb</div>
        <div style={{ fontSize: 13, color: '#6e6a60', maxWidth: 760, lineHeight: 1.55 }}>
          Stays close to today's nav. Primary groups in the top bar; a second strip carries breadcrumb + section tabs (Board/List/Timeline). ⌘K is the escape hatch for everything else — pinned pages and recents live in the palette.
        </div>
      </div>
    </div>
  );
};

// ── Pattern 2: Sidebar grouped (collapsible) ───────────────────────────────

const NavPatternSidebar = ({ selected, onSelect }) => {
  const baseFont = 'Inter, system-ui, sans-serif';
  return (
    <div className="ab" onClick={onSelect} style={{
      background: '#fafaf8', fontFamily: baseFont, fontSize: 13, color: '#1a1715',
      display: 'grid', gridTemplateColumns: '232px 1fr',
      cursor: 'pointer', boxShadow: selected ? 'inset 0 0 0 3px #1a1715' : 'none',
      transition: 'box-shadow .15s', position: 'relative',
    }}>
      {selected && (
        <div style={{ position: 'absolute', top: 10, right: 10, zIndex: 5, width: 22, height: 22, borderRadius: 999, background: '#1a1715', color: '#fff', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 1px 3px rgba(0,0,0,0.2)' }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </div>
      )}
      {/* Sidebar */}
      <div style={{ background: '#fff', borderRight: '1px solid #ececec', padding: '14px 12px', display: 'flex', flexDirection: 'column', gap: 4 }}>
        {/* brand */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px 10px', borderBottom: '1px solid #f0eee8', marginBottom: 8 }}>
          <WTMark size={16}/>
          <span style={{ fontWeight: 600 }}>Watchtower</span>
          <span style={{ flex: 1 }}/>
          <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 9, color: '#a5a194', padding: '2px 5px', background: '#f4f3ef', borderRadius: 3 }}>0.9.4</span>
        </div>

        {/* search */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '6px 8px', borderRadius: 6, background: '#f4f3ef', color: '#7a766c', marginBottom: 6 }}>
          <Icon name="search" size={12} color="#7a766c"/>
          <span style={{ fontSize: 11.5, flex: 1 }}>Search…</span>
          <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 9, color: '#9b9789', padding: '1px 5px', background: '#eae8e2', borderRadius: 3 }}>⌘K</span>
        </div>

        {/* pinned */}
        <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 9, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#a5a194', padding: '8px 8px 2px' }}>Pinned</div>
        {[
          ['Approvals', 4], ['Tasks', null], ['Fabric · Auth', null],
        ].map(([label, count]) => (
          <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '5px 8px', borderRadius: 5, fontSize: 12.5, color: '#1a1715', cursor: 'pointer' }}>
            <Icon name="pin" size={11} color="#b87a17"/>
            <span style={{ flex: 1 }}>{label}</span>
            {count != null && <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#a8551a', background: '#fdf2dc', padding: '1px 5px', borderRadius: 3 }}>{count}</span>}
          </div>
        ))}

        {NAV_GROUPS.slice(0, 2).map((g, i) => (
          <React.Fragment key={g.name}>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 9, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#a5a194', padding: '10px 8px 2px', display: 'flex', alignItems: 'center', gap: 4 }}>
              <Icon name="chevronD" size={9} color="#a5a194"/>
              {g.name}
            </div>
            {g.items.slice(0, i === 0 ? 5 : 3).map((it) => (
              <div key={it} style={{
                padding: '5px 8px 5px 22px', borderRadius: 5, fontSize: 12.5,
                background: it === 'Tasks' ? '#f2f2ef' : 'transparent',
                color: it === 'Tasks' ? '#1a1715' : '#5a5750',
                fontWeight: it === 'Tasks' ? 600 : 400,
                cursor: 'pointer',
              }}>{it}</div>
            ))}
          </React.Fragment>
        ))}
      </div>

      {/* Content stripe */}
      <div>
        {/* Top thin context bar */}
        <div style={{ height: 40, display: 'flex', alignItems: 'center', padding: '0 20px', borderBottom: '1px solid #ececec', background: '#fff', gap: 8, color: '#6e6a60', fontSize: 11.5 }}>
          <Icon name="layers" size={12} color="#9b9789"/>
          <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>Work</span>
          <Icon name="chevron" size={9} color="#bcb8ad"/>
          <span style={{ color: '#1a1715', fontWeight: 500 }}>Tasks</span>
          <Icon name="chevron" size={9} color="#bcb8ad"/>
          <span style={{ color: '#1a1715', fontWeight: 500 }}>Board</span>
          <div style={{ flex: 1 }}/>
          <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>42 active · audit PASS</span>
        </div>

        <div style={{ padding: 24, color: '#9b9789' }}>
          <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>Pattern 2</div>
          <div style={{ fontSize: 22, fontWeight: 600, color: '#1a1715', letterSpacing: '-0.01em', marginBottom: 4 }}>Persistent left sidebar with grouped + pinned</div>
          <div style={{ fontSize: 13, color: '#6e6a60', maxWidth: 720, lineHeight: 1.55 }}>
            Best for power users who live in the tool. Pinned section at top, then collapsible groups (Work / Knowledge / Architecture / Govern). The 16-item Govern problem disappears — it collapses unless expanded.
          </div>
        </div>
      </div>
    </div>
  );
};

// ── Pattern 3: Slim icon rail + ⌘K-primary ─────────────────────────────────

const NavPatternRail = ({ selected, onSelect }) => {
  const baseFont = 'Inter, system-ui, sans-serif';
  return (
    <div className="ab" onClick={onSelect} style={{
      background: '#fafaf8', fontFamily: baseFont, fontSize: 13, color: '#1a1715',
      display: 'grid', gridTemplateColumns: '52px 1fr',
      cursor: 'pointer', boxShadow: selected ? 'inset 0 0 0 3px #1a1715' : 'none',
      transition: 'box-shadow .15s', position: 'relative',
    }}>
      {selected && (
        <div style={{ position: 'absolute', top: 10, right: 10, zIndex: 5, width: 22, height: 22, borderRadius: 999, background: '#1a1715', color: '#fff', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 1px 3px rgba(0,0,0,0.2)' }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </div>
      )}
      {/* Icon rail */}
      <div style={{ background: '#fff', borderRight: '1px solid #ececec', padding: '12px 0', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
        <div style={{ width: 30, height: 30, borderRadius: 7, background: '#1a1715', color: '#fff', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', marginBottom: 8 }}>
          <WTMark size={16} color="#fff"/>
        </div>
        {[
          { icon: 'list', label: 'Work', active: true },
          { icon: 'layers', label: 'Knowledge' },
          { icon: 'branch', label: 'Architecture' },
          { icon: 'flag', label: 'Govern', badge: 4 },
          { icon: 'activity', label: 'Metrics' },
        ].map((it) => (
          <div key={it.label} style={{
            position: 'relative',
            width: 36, height: 36, borderRadius: 8,
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            background: it.active ? '#f2f2ef' : 'transparent',
            color: it.active ? '#1a1715' : '#7a766c',
            cursor: 'pointer',
          }}>
            <Icon name={it.icon} size={16}/>
            {it.badge && (
              <span style={{
                position: 'absolute', top: 4, right: 4,
                width: 7, height: 7, borderRadius: 999, background: '#c4623f',
              }}/>
            )}
          </div>
        ))}
        <div style={{ flex: 1 }}/>
        <div style={{ width: 36, height: 36, borderRadius: 8, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', color: '#7a766c' }}>
          <Icon name="settings" size={16}/>
        </div>
      </div>

      <div>
        {/* Top header with breadcrumb + ⌘K */}
        <div style={{
          height: 52, display: 'flex', alignItems: 'center', padding: '0 22px', gap: 14,
          background: '#fff', borderBottom: '1px solid #ececec',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, color: '#5a5750' }}>
            <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#9b9789' }}>Work</span>
            <Icon name="chevron" size={10} color="#bcb8ad"/>
            <span style={{ fontWeight: 600, color: '#1a1715' }}>Tasks</span>
            <Icon name="chevron" size={10} color="#bcb8ad"/>
            <span style={{ color: '#5a5750' }}>Board</span>
            <span style={{ width: 1, height: 14, background: '#e0ddd2', marginLeft: 6 }}/>
            <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#b87a17', display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <Icon name="pin" size={10} color="#b87a17"/>Pinned
            </span>
          </div>
          <div style={{ flex: 1 }}/>
          {/* Big ⌘K bar */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 10,
            padding: '7px 14px', borderRadius: 8, background: '#f4f3ef',
            color: '#7a766c', minWidth: 360, cursor: 'pointer',
          }}>
            <Icon name="search" size={13} color="#7a766c"/>
            <span style={{ fontSize: 12.5 }}>Jump to task, learning, arc, command…</span>
            <span style={{ flex: 1 }}/>
            <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#9b9789', padding: '2px 6px', background: '#eae8e2', borderRadius: 4 }}>⌘K</span>
          </div>
        </div>

        <div style={{ padding: 24, color: '#9b9789' }}>
          <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>Pattern 3</div>
          <div style={{ fontSize: 22, fontWeight: 600, color: '#1a1715', letterSpacing: '-0.01em', marginBottom: 4 }}>Slim icon rail · ⌘K is the navigator</div>
          <div style={{ fontSize: 13, color: '#6e6a60', maxWidth: 720, lineHeight: 1.55 }}>
            Minimal visual weight; content gets the room. Five rail icons are the only persistent nav — every page is reached by ⌘K, pinned items, or breadcrumb back-up. Best for very keyboard-driven users.
          </div>
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { NavPatternTopBar, NavPatternSidebar, NavPatternRail });
