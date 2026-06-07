// Settings → Appearance — the actual screen in Watchtower where each user
// personalises their theme. Uses all three foundation choices + mode + density.
// Built as a themed mockup that responds to its own internal state.

const { useState: useStateA } = React;

function AppearanceSettings() {
  const [typeId, setTypeId] = useStateA('inter');
  const [paletteId, setPaletteId] = useStateA('stone');
  const [navKind, setNavKind] = useStateA('topbar');
  const [mode, setMode] = useStateA('light');
  const [density, setDensity] = useStateA('compact');
  const [accentOverride, setAccentOverride] = useStateA(null);
  const [activePreset, setActivePreset] = useStateA('calm');

  // Apply a preset = a curated combo of every setting at once.
  const applyPreset = (preset) => {
    setActivePreset(preset.id);
    setTypeId(preset.typeId);
    setPaletteId(preset.paletteId);
    setNavKind(preset.navKind);
    setMode(preset.mode);
    setDensity(preset.density);
    setAccentOverride(null);
  };

  const pair = TYPE_PAIRS.find((p) => p.id === typeId);
  const baseP = PALETTES.find((p) => p.id === paletteId);
  const palette = accentOverride
    ? { ...baseP, accent: accentOverride, accentInk: pickInk(accentOverride) }
    : baseP;
  const th = buildTheme(pair, palette, mode);

  return (
    <div className="ab" style={{ background: th.bg, fontFamily: th.font, color: th.text, fontSize: 13, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Watchtower chrome around the settings page */}
      <div style={{ background: th.surface, borderBottom: `1px solid ${th.border}` }}>
        <div style={{ height: 48, padding: '0 22px', display: 'flex', alignItems: 'center', gap: 4, borderBottom: `1px solid ${th.border}` }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginRight: 22, fontWeight: 600, color: th.text, fontFamily: th.serif || th.font, fontSize: th.serif ? 17 : 14 }}>
            <WTMark size={16} color={th.accent}/>Watchtower
          </div>
          {['Work', 'Knowledge', 'Architecture', 'Govern'].map((g) => (
            <div key={g} style={{ padding: '6px 12px', borderRadius: 6, color: th.muted, fontSize: 13 }}>{g}</div>
          ))}
          <div style={{ flex: 1 }}/>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', borderRadius: 6, background: th.surface2, border: `1px solid ${th.border}`, color: th.muted, minWidth: 220 }}>
            <Icon name="search" size={13}/>
            <span style={{ fontSize: 12 }}>Search or jump to…</span>
            <span style={{ flex: 1 }}/>
            <span style={{ fontFamily: th.mono, fontSize: 10, color: th.muted, padding: '2px 6px', background: th.surface, border: `1px solid ${th.border}`, borderRadius: 4 }}>⌘K</span>
          </div>
          <div style={{ width: 28, height: 28, marginLeft: 10, borderRadius: 999, background: th.accent, color: th.accentInk, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 600 }}>JG</div>
        </div>
        <div style={{ height: 40, padding: '0 22px', display: 'flex', alignItems: 'center', gap: 2, borderBottom: `1px solid ${th.border}` }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginRight: 14, fontFamily: th.mono, fontSize: 11, color: th.muted }}>
            <span>Settings</span>
            <Icon name="chevron" size={9} color={th.muted}/>
            <span style={{ color: th.text }}>Appearance</span>
          </div>
          {['Profile', 'Appearance', 'Notifications', 'Keyboard', 'Integrations', 'Advanced'].map((t, i) => (
            <div key={t} style={{ padding: '7px 12px', borderRadius: 6, fontSize: 12.5, background: i === 1 ? th.accentSoft : 'transparent', color: i === 1 ? th.accent : th.muted, fontWeight: i === 1 ? 600 : 500 }}>{t}</div>
          ))}
        </div>
      </div>

      {/* Page body — single column, sticky preview at top, form below */}
      <div style={{ flex: 1, overflow: 'hidden auto', background: th.bg }}>
        {/* Sticky preview header */}
        <div style={{
          position: 'sticky', top: 0, zIndex: 10,
          background: th.bg, borderBottom: `1px solid ${th.border}`,
          padding: '14px 32px 16px',
          boxShadow: th.isDark ? '0 4px 12px rgba(0,0,0,0.3)' : '0 2px 8px rgba(0,0,0,0.04)',
        }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 8 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
              <span style={{ fontFamily: th.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: th.muted }}>Live preview</span>
              <span style={{ fontSize: 13, color: th.text, fontWeight: 600 }}>Cockpit</span>
              <span style={{ fontFamily: th.mono, fontSize: 10.5, color: th.muted }}>updates as you change settings ↓</span>
            </div>
            <span style={{ fontFamily: th.mono, fontSize: 10.5, color: th.muted }}>
              {pair.sans.split(',')[0]} · {baseP.id} · {navKind} · {mode}
            </span>
          </div>
          <div style={{
            border: `1px solid ${th.border}`, borderRadius: 8, overflow: 'hidden',
            boxShadow: th.isDark ? '0 8px 24px rgba(0,0,0,0.4)' : '0 6px 18px rgba(0,0,0,0.08)',
            height: 360,
          }}>
            <div style={{
              transform: 'scale(0.45)', transformOrigin: 'top left',
              width: `${100 / 0.45}%`, height: `${100 / 0.45}%`,
            }}>
              <LivePreview typeId={typeId} paletteId={paletteId} navKind={navKind} mode={mode}/>
            </div>
          </div>
        </div>

        {/* Form below */}
        <div style={{ padding: '24px 32px 32px', display: 'flex', flexDirection: 'column', gap: 22, maxWidth: 980 }}>
          {/* Header */}
          <div>
            <h1 style={{ margin: 0, fontFamily: th.serif || th.font, fontSize: th.serif ? 30 : 24, fontWeight: 600, letterSpacing: '-0.01em' }}>Appearance</h1>
            <p style={{ margin: '4px 0 0', fontSize: 13, color: th.muted, lineHeight: 1.5 }}>
              Personalise how Watchtower looks for you. Saved to your profile and synced across devices.
            </p>
          </div>

          {/* Presets — one-click curated combinations */}
          <SettingRow title="Preset" desc="Curated combinations of type, palette, navigation and mode. A starting point — every choice below is still tweakable." th={th}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
              {PRESETS.map((preset) => {
                const isActive = activePreset === preset.id
                  && preset.typeId === typeId && preset.paletteId === paletteId
                  && preset.navKind === navKind && preset.mode === mode;
                return <PresetCard key={preset.id} preset={preset} active={isActive} onClick={() => applyPreset(preset)} th={th}/>;
              })}
            </div>
          </SettingRow>

          {/* Theme mode */}
          <SettingRow title="Theme" desc="System matches your OS appearance." th={th}>
            <SegSeg th={th} value={mode} onChange={setMode} options={[
              { value: 'light', label: 'Light', icon: 'sun' },
              { value: 'dark', label: 'Dark', icon: 'moon' },
              { value: 'system', label: 'System', icon: 'eye' },
            ]}/>
          </SettingRow>

          {/* Typography */}
          <SettingRow title="Typography" desc="Sans + monospace pairing. Affects all UI text." th={th}>
            <ChoiceGrid cols={3}>
              {TYPE_PAIRS.map((p) => (
                <ChoiceCard key={p.id} th={th} selected={p.id === typeId} onClick={() => setTypeId(p.id)}>
                  <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 6 }}>
                    <span style={{ fontFamily: p.serifHead ? 'Newsreader' : p.sans, fontSize: p.serifHead ? 20 : 17, fontWeight: 600, color: th.text, letterSpacing: '-0.01em' }}>Watchtower</span>
                    <span style={{ fontFamily: p.mono, fontSize: 11, color: th.muted, fontVariantNumeric: 'tabular-nums' }}>1284</span>
                  </div>
                  <div style={{ fontFamily: p.bodySans || p.sans, fontSize: 12, color: th.muted }}>{p.sans.split(',')[0]} · {p.mono.split(',')[0]}</div>
                </ChoiceCard>
              ))}
            </ChoiceGrid>
          </SettingRow>

          {/* Color palette */}
          <SettingRow title="Palette" desc="Core surfaces, text and accent. Light + dark stay coordinated." th={th}>
            <ChoiceGrid cols={3}>
              {PALETTES.map((p) => (
                <ChoiceCard key={p.id} th={th} selected={p.id === paletteId} onClick={() => setPaletteId(p.id)}>
                  <div style={{ display: 'flex', gap: 4, marginBottom: 6 }}>
                    {[p.bg, p.surface, p.border, p.text, p.muted, p.accent].map((c, i) => (
                      <div key={i} style={{ width: 18, height: 18, borderRadius: 3, background: c, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.05)' }}/>
                    ))}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <span style={{ fontSize: 12.5, fontWeight: 600 }}>{p.label.split('·')[1]?.trim() || p.label}</span>
                    <span style={{ fontFamily: th.mono, fontSize: 10, color: th.muted }}>{p.accent}</span>
                  </div>
                </ChoiceCard>
              ))}
            </ChoiceGrid>
          </SettingRow>

          {/* Accent override */}
          <SettingRow title="Accent override" desc="Replace just the palette's accent — useful for color-blind users or personal preference." th={th}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              {[null, '#5a6b3a', '#bd5b3a', '#1f4ed8', '#22c55e', '#a855f7', '#b87a17'].map((c) => (
                <div key={c || 'none'} onClick={() => setAccentOverride(c)} style={{
                  width: 32, height: 32, borderRadius: 8, cursor: 'pointer',
                  background: c || `linear-gradient(135deg, ${th.muted} 0%, ${th.muted} 49%, ${th.surface} 49%, ${th.surface} 51%, ${th.muted} 51%)`,
                  boxShadow: accentOverride === c ? `0 0 0 2px ${th.bg}, 0 0 0 4px ${c || th.text}` : `inset 0 0 0 1px ${th.border}`,
                  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  {c === null && <span style={{ fontFamily: th.mono, fontSize: 9, color: th.text }}>auto</span>}
                </div>
              ))}
              <span style={{ fontSize: 11, color: th.muted, marginLeft: 6 }}>{accentOverride ? 'Override on — reset to use palette default' : 'Using palette default'}</span>
            </div>
          </SettingRow>

          {/* Navigation layout */}
          <SettingRow title="Navigation layout" desc="How the primary navigation is presented." th={th}>
            <ChoiceGrid cols={3}>
              {[
                { id: 'topbar',  name: 'Top bar',  desc: 'Groups in a horizontal bar + contextual tabs',  preview: 'topbar' },
                { id: 'sidebar', name: 'Sidebar',  desc: 'Persistent left rail with pinned + groups',     preview: 'sidebar' },
                { id: 'rail',    name: 'Icon rail',desc: 'Minimal 52px rail · ⌘K is the navigator',       preview: 'rail' },
              ].map((n) => (
                <ChoiceCard key={n.id} th={th} selected={n.id === navKind} onClick={() => setNavKind(n.id)}>
                  <NavMicro kind={n.id} th={th}/>
                  <div style={{ marginTop: 8 }}>
                    <div style={{ fontSize: 12.5, fontWeight: 600 }}>{n.name}</div>
                    <div style={{ fontSize: 11, color: th.muted, marginTop: 2, lineHeight: 1.4 }}>{n.desc}</div>
                  </div>
                </ChoiceCard>
              ))}
            </ChoiceGrid>
          </SettingRow>

          {/* Density */}
          <SettingRow title="Density" desc="Row height, padding and font scale." th={th}>
            <SegSeg th={th} value={density} onChange={setDensity} options={[
              { value: 'compact', label: 'Compact' },
              { value: 'cozy',    label: 'Cozy' },
              { value: 'spacious',label: 'Spacious' },
            ]}/>
          </SettingRow>

          {/* Extras */}
          <SettingRow title="Other" th={th}>
            <CheckRow th={th} label="Reduce motion · disable animations and transitions"/>
            <CheckRow th={th} label="Higher contrast borders and focus rings" defaultChecked/>
            <CheckRow th={th} label="Use monospace numerals everywhere" defaultChecked/>
            <CheckRow th={th} label="Show breadcrumb in tab title"/>
          </SettingRow>

          {/* Footer actions */}
          <div style={{
            position: 'sticky', bottom: 0, marginTop: 'auto', padding: '12px 0',
            background: `linear-gradient(${hexA(th.bg, 0)} 0%, ${th.bg} 30%)`,
            display: 'flex', alignItems: 'center', gap: 10,
          }}>
            <span style={{ fontFamily: th.mono, fontSize: 11, color: th.muted }}>● unsaved changes</span>
            <span style={{ flex: 1 }}/>
            <button style={thBtnA(th, 'ghost')}>Reset to default</button>
            <button style={thBtnA(th, 'ghost')}>Share preset…</button>
            <button style={thBtnA(th, 'primary')}>Save preferences</button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Small helpers (settings-only, suffixed -A to avoid collisions) ────────

function SettingRow({ title, desc, children, th }) {
  return (
    <section style={{ display: 'grid', gridTemplateColumns: '180px 1fr', gap: 24, alignItems: 'flex-start', paddingBottom: 20, borderBottom: `1px solid ${th.border}` }}>
      <div>
        <div style={{ fontWeight: 600, fontSize: 13.5, color: th.text }}>{title}</div>
        {desc && <div style={{ fontSize: 12, color: th.muted, marginTop: 3, lineHeight: 1.5 }}>{desc}</div>}
      </div>
      <div style={{ minWidth: 0 }}>{children}</div>
    </section>
  );
}

function ChoiceGrid({ cols = 3, children }) {
  return <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, 1fr)`, gap: 10 }}>{children}</div>;
}

function ChoiceCard({ selected, onClick, children, th }) {
  return (
    <div onClick={onClick} style={{
      cursor: 'pointer',
      background: th.surface,
      border: `1px solid ${selected ? th.accent : th.border}`,
      boxShadow: selected ? `0 0 0 3px ${th.accentSoft}` : 'none',
      borderRadius: 8, padding: '10px 12px',
      transition: 'border-color .12s, box-shadow .12s',
      position: 'relative',
    }}>
      {selected && (
        <div style={{
          position: 'absolute', top: 8, right: 8,
          width: 16, height: 16, borderRadius: 999, background: th.accent, color: th.accentInk,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </div>
      )}
      {children}
    </div>
  );
}

function SegSeg({ value, onChange, options, th }) {
  return (
    <div style={{ display: 'inline-flex', padding: 3, background: th.surface, border: `1px solid ${th.border}`, borderRadius: 8, gap: 2 }}>
      {options.map((o) => (
        <button key={o.value} onClick={() => onChange(o.value)} style={{
          padding: '6px 12px', border: 'none', cursor: 'pointer', fontFamily: 'inherit', fontSize: 12,
          background: o.value === value ? th.accent : 'transparent',
          color: o.value === value ? th.accentInk : th.text,
          borderRadius: 5, fontWeight: 500, display: 'inline-flex', alignItems: 'center', gap: 5,
        }}>
          {o.icon && <Icon name={o.icon} size={12}/>}
          {o.label}
        </button>
      ))}
    </div>
  );
}

function CheckRow({ label, defaultChecked, th }) {
  const [on, set] = useStateA(!!defaultChecked);
  return (
    <label style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '7px 0', cursor: 'pointer', fontSize: 12.5 }}>
      <span onClick={() => set(!on)} style={{
        width: 32, height: 18, borderRadius: 999, padding: 2,
        background: on ? th.accent : th.border,
        transition: 'background .15s', flexShrink: 0,
        display: 'inline-flex', alignItems: 'center',
      }}>
        <span style={{
          width: 14, height: 14, borderRadius: 999, background: th.surface,
          transform: on ? 'translateX(14px)' : 'translateX(0)',
          transition: 'transform .15s', boxShadow: '0 1px 2px rgba(0,0,0,0.15)',
        }}/>
      </span>
      <span style={{ color: th.text }}>{label}</span>
    </label>
  );
}

function NavMicro({ kind, th }) {
  // Tiny abstract preview, 28px high.
  const c = th.muted, a = th.accent, bg = th.surface, line = th.border;
  if (kind === 'topbar') {
    return (
      <div style={{ height: 44, background: th.bg, borderRadius: 4, border: `1px solid ${line}`, overflow: 'hidden' }}>
        <div style={{ height: 14, background: bg, borderBottom: `1px solid ${line}`, display: 'flex', alignItems: 'center', padding: '0 4px', gap: 3 }}>
          <span style={{ width: 8, height: 4, background: a, borderRadius: 1 }}/>
          {[c, c, c].map((cc, i) => <span key={i} style={{ width: 12, height: 3, background: cc, borderRadius: 1, opacity: 0.4 }}/>)}
        </div>
        <div style={{ height: 10, background: bg, borderBottom: `1px solid ${line}`, display: 'flex', alignItems: 'center', padding: '0 4px', gap: 3 }}>
          <span style={{ width: 10, height: 2, background: a, borderRadius: 1 }}/>
          <span style={{ width: 8, height: 2, background: c, borderRadius: 1, opacity: 0.4 }}/>
        </div>
        <div style={{ height: 18, padding: 3 }}>
          <span style={{ display: 'block', width: '40%', height: 3, background: c, borderRadius: 1, opacity: 0.3, marginBottom: 2 }}/>
          <span style={{ display: 'block', width: '70%', height: 3, background: c, borderRadius: 1, opacity: 0.3 }}/>
        </div>
      </div>
    );
  }
  if (kind === 'sidebar') {
    return (
      <div style={{ height: 44, background: th.bg, borderRadius: 4, border: `1px solid ${line}`, display: 'flex', overflow: 'hidden' }}>
        <div style={{ width: 30, background: bg, borderRight: `1px solid ${line}`, padding: 3, display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span style={{ width: 12, height: 3, background: a, borderRadius: 1 }}/>
          {[c, c, c, c].map((cc, i) => <span key={i} style={{ width: '100%', height: 2, background: cc, opacity: 0.35, borderRadius: 1 }}/>)}
        </div>
        <div style={{ flex: 1, padding: 3 }}>
          <span style={{ display: 'block', width: '50%', height: 3, background: c, borderRadius: 1, opacity: 0.3, marginBottom: 2 }}/>
          <span style={{ display: 'block', width: '80%', height: 3, background: c, borderRadius: 1, opacity: 0.3 }}/>
        </div>
      </div>
    );
  }
  // rail
  return (
    <div style={{ height: 44, background: th.bg, borderRadius: 4, border: `1px solid ${line}`, display: 'flex', overflow: 'hidden' }}>
      <div style={{ width: 12, background: bg, borderRight: `1px solid ${line}`, padding: '3px 1px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
        <span style={{ width: 6, height: 6, borderRadius: 2, background: a }}/>
        {[c, c, c].map((cc, i) => <span key={i} style={{ width: 4, height: 4, background: cc, borderRadius: 999, opacity: 0.4 }}/>)}
      </div>
      <div style={{ flex: 1, padding: 3 }}>
        <span style={{ display: 'block', width: '60%', height: 3, background: c, borderRadius: 1, opacity: 0.3, marginBottom: 2 }}/>
        <span style={{ display: 'block', width: '85%', height: 3, background: c, borderRadius: 1, opacity: 0.3 }}/>
      </div>
    </div>
  );
}

function pickInk(hex) {
  if (!hex || hex[0] !== '#') return '#fff';
  let h = hex.slice(1);
  if (h.length === 3) h = h.split('').map((c) => c + c).join('');
  const r = parseInt(h.slice(0,2), 16);
  const g = parseInt(h.slice(2,4), 16);
  const b = parseInt(h.slice(4,6), 16);
  const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return lum > 0.55 ? '#1a1715' : '#ffffff';
}

const thBtnA = (th, variant = 'ghost') => {
  const base = { padding: '7px 14px', borderRadius: 6, fontSize: 12.5, fontWeight: 500, cursor: 'pointer', border: 'none', fontFamily: 'inherit' };
  if (variant === 'primary') return { ...base, background: th.accent, color: th.accentInk };
  return { ...base, background: 'transparent', color: th.text, border: `1px solid ${th.border}` };
};

// ── Presets — curated direction combos ────────────────────────────────────

const PRESETS = [
  {
    id: 'calm',
    name: 'Calm',
    tagline: 'Quiet ops · the day-to-day',
    typeId: 'inter', paletteId: 'stone', navKind: 'topbar', mode: 'light', density: 'compact',
  },
  {
    id: 'editorial',
    name: 'Editorial',
    tagline: 'Text-forward · for reading & deciding',
    typeId: 'newsreader', paletteId: 'linen', navKind: 'topbar', mode: 'light', density: 'cozy',
  },
  {
    id: 'console',
    name: 'Console',
    tagline: 'Dense monitoring · keyboard-driven',
    typeId: 'plex', paletteId: 'console', navKind: 'sidebar', mode: 'dark', density: 'compact',
  },
  {
    id: 'paper',
    name: 'Paper',
    tagline: 'Crisp light · cobalt accent',
    typeId: 'geist', paletteId: 'paper', navKind: 'topbar', mode: 'light', density: 'compact',
  },
  {
    id: 'bone',
    name: 'Bone',
    tagline: 'Warm amber · invites focus',
    typeId: 'manrope', paletteId: 'bone', navKind: 'sidebar', mode: 'light', density: 'cozy',
  },
  {
    id: 'midnight',
    name: 'Midnight',
    tagline: 'Slate dark · rail-driven',
    typeId: 'inter', paletteId: 'slate', navKind: 'rail', mode: 'dark', density: 'compact',
  },
];

function PresetCard({ preset, active, onClick, th }) {
  const pair = TYPE_PAIRS.find((p) => p.id === preset.typeId);
  const palette = PALETTES.find((p) => p.id === preset.paletteId);
  const isDark = preset.mode === 'dark';
  const swatchBg      = isDark ? palette.darkBg      : palette.bg;
  const swatchSurface = isDark ? palette.darkSurface : palette.surface;
  const swatchText    = isDark ? palette.darkText    : palette.text;
  const swatchMuted   = isDark ? palette.darkMuted   : palette.muted;
  const swatchBorder  = isDark ? palette.darkBorder  : palette.border;

  return (
    <div onClick={onClick} style={{
      cursor: 'pointer',
      borderRadius: 10, padding: 0, overflow: 'hidden',
      border: `1px solid ${active ? th.accent : th.border}`,
      boxShadow: active ? `0 0 0 3px ${th.accentSoft}` : 'none',
      transition: 'border-color .12s, box-shadow .12s',
      background: th.surface,
      position: 'relative',
    }}>
      {active && (
        <div style={{
          position: 'absolute', top: 8, right: 8, zIndex: 2,
          width: 18, height: 18, borderRadius: 999, background: th.accent, color: th.accentInk,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </div>
      )}

      {/* Mini cockpit preview rendered with this preset's tokens */}
      <div style={{ background: swatchBg, padding: '10px 12px 8px', borderBottom: `1px solid ${swatchBorder}` }}>
        {/* tiny top bar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
          <span style={{ width: 8, height: 8, borderRadius: 2, background: palette.accent }}/>
          <span style={{ fontFamily: pair.serifHead ? 'Newsreader' : pair.sans, fontSize: 10.5, fontWeight: 600, color: swatchText, letterSpacing: pair.serifHead ? '-0.005em' : '-0.01em' }}>
            Watchtower
          </span>
          <span style={{ flex: 1 }}/>
          <span style={{ display: 'inline-flex', gap: 3 }}>
            {[0,1,2].map((i) => <span key={i} style={{ width: 12, height: 2, background: swatchMuted, opacity: 0.4 }}/>)}
          </span>
        </div>
        {/* tiny heading row + chip */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
          <span style={{ fontFamily: pair.mono, fontSize: 8, color: palette.accent, fontWeight: 700 }}>T-1453</span>
          <span style={{ fontSize: 9, padding: '1px 5px', borderRadius: 999, background: hexA(palette.success, 0.18), color: palette.success, fontWeight: 600, fontFamily: pair.mono, letterSpacing: '0.04em' }}>active</span>
        </div>
        <div style={{
          fontFamily: pair.serifHead ? 'Newsreader' : pair.sans,
          fontSize: pair.serifHead ? 15 : 13, fontWeight: 600,
          color: swatchText, letterSpacing: '-0.01em', lineHeight: 1.2, marginBottom: 4,
        }}>
          CSRF refactor lands
        </div>
        {/* sparkline-ish row */}
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 18 }}>
          <Sparkline values={[3,5,4,6,8,7,9,10,9,11,12,10,11,12]} color={palette.accent} w={70} h={16}/>
          <span style={{ fontFamily: pair.mono, fontSize: 12, fontWeight: 600, color: swatchText, fontVariantNumeric: 'tabular-nums' }}>42</span>
          <span style={{ fontFamily: pair.mono, fontSize: 9, color: swatchMuted }}>tasks</span>
        </div>
      </div>

      {/* Preset name + tagline */}
      <div style={{ padding: '10px 12px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 4 }}>
          <span style={{ fontSize: 13.5, fontWeight: 600, color: th.text }}>{preset.name}</span>
          <span style={{ fontFamily: th.mono, fontSize: 9.5, letterSpacing: '0.06em', color: th.muted, textTransform: 'uppercase' }}>{preset.mode}</span>
        </div>
        <div style={{ fontSize: 11.5, color: th.muted, lineHeight: 1.4, marginBottom: 8 }}>{preset.tagline}</div>
        {/* meta row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontFamily: th.mono, fontSize: 9.5, color: th.muted, letterSpacing: '0.04em' }}>
          <span>{pair.sans.split(',')[0]}</span>
          <span style={{ color: th.border }}>·</span>
          <span>{palette.id}</span>
          <span style={{ color: th.border }}>·</span>
          <span>{preset.navKind}</span>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { AppearanceSettings });
