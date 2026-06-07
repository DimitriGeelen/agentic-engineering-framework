// Main canvas assembly.
// Foundations are clickable → live preview re-themes.
// Plus a fully-mocked "Settings → Appearance" screen showing how this lives
// in the actual product.

const { useState, useEffect } = React;

// Sizes
const W_TYPE = 540, H_TYPE = 360;
const W_PAL = 540, H_PAL = 360;
const W_NAV = 1280, H_NAV = 280;
const W_SCREEN = 1480, H_SCREEN = 920;
const W_PREVIEW = 1480, H_PREVIEW = 920;
const W_PANEL = 1480, H_PANEL = 920;
const W_CMDK = 800, H_CMDK = 580;
const W_KBD = 660, H_KBD = 480;

const STORAGE_KEY = 'wt-design-explore-v1';

function App() {
  // Foundation selections — drive the LivePreview artboard.
  const [typeId, setTypeId] = useState('inter');
  const [paletteId, setPaletteId] = useState('stone');
  const [navKind, setNavKind] = useState('topbar');
  const [mode, setMode] = useState('light');

  // Restore from localStorage on first render.
  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const s = JSON.parse(raw);
        if (s.typeId) setTypeId(s.typeId);
        if (s.paletteId) setPaletteId(s.paletteId);
        if (s.navKind) setNavKind(s.navKind);
        if (s.mode) setMode(s.mode);
      }
    } catch {}
  }, []);

  // Persist on change.
  useEffect(() => {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify({ typeId, paletteId, navKind, mode })); } catch {}
  }, [typeId, paletteId, navKind, mode]);

  const pair = TYPE_PAIRS.find((p) => p.id === typeId);
  const palette = PALETTES.find((p) => p.id === paletteId);

  return (
    <DesignCanvas>
      {/* ── HERO · The actual product surface ──────────────────────────── */}
      <DCSection id="settings" title="Settings → Appearance · in Watchtower" subtitle="The picker as it would live in the real app — every option below is exposed here, with a live cockpit preview on the right.">
        <DCArtboard id="appearance" label="Settings · Appearance · live preview" width={W_SCREEN} height={H_SCREEN}>
          <AppearanceSettings/>
        </DCArtboard>
      </DCSection>

      {/* ── 1. Type ─────────────────────────────────────────────────────── */}
      <DCSection
        id="type"
        title={`Foundations · Type — selected: ${pair.sans.split(',')[0]}`}
        subtitle="Click a card to apply it to the live preview below"
      >
        {TYPE_PAIRS.map((p) => (
          <DCArtboard key={p.id} id={`type-${p.id}`} label={p.label} width={W_TYPE} height={H_TYPE}>
            <TypePairCard pair={p} selected={p.id === typeId} onSelect={() => setTypeId(p.id)}/>
          </DCArtboard>
        ))}
      </DCSection>

      {/* ── 2. Palette ─────────────────────────────────────────────────── */}
      <DCSection
        id="color"
        title={`Foundations · Color — selected: ${palette.label.split('·')[1]?.trim() || palette.label}`}
        subtitle="Click a card to apply it"
      >
        {PALETTES.map((p) => (
          <DCArtboard key={p.id} id={`pal-${p.id}`} label={p.label} width={W_PAL} height={H_PAL}>
            <PalettePreviewCard palette={p} selected={p.id === paletteId} onSelect={() => setPaletteId(p.id)}/>
          </DCArtboard>
        ))}
      </DCSection>

      {/* ── 3. Nav patterns ────────────────────────────────────────────── */}
      <DCSection id="nav" title={`Navigation pattern — selected: ${navKind}`} subtitle="Click a card to apply it">
        <DCArtboard id="nav-topbar" label="1 · Top bar + contextual sub-nav" width={W_NAV} height={H_NAV}>
          <NavPatternTopBar selected={navKind === 'topbar'} onSelect={() => setNavKind('topbar')}/>
        </DCArtboard>
        <DCArtboard id="nav-sidebar" label="2 · Persistent left sidebar + pinned" width={W_NAV} height={H_NAV}>
          <NavPatternSidebar selected={navKind === 'sidebar'} onSelect={() => setNavKind('sidebar')}/>
        </DCArtboard>
        <DCArtboard id="nav-rail" label="3 · Slim icon rail · ⌘K-primary" width={W_NAV} height={H_NAV}>
          <NavPatternRail selected={navKind === 'rail'} onSelect={() => setNavKind('rail')}/>
        </DCArtboard>
      </DCSection>

      {/* ── 4. Live composed preview ───────────────────────────────────── */}
      <DCSection
        id="preview"
        title="Your composition · live"
        subtitle="The Cockpit themed from your current selections. Use the Tweaks panel to toggle dark mode."
      >
        <DCArtboard id="live-preview" label={`Cockpit · ${pair.sans.split(',')[0]} · ${palette.id} · ${navKind} · ${mode}`} width={W_PREVIEW} height={H_PREVIEW}>
          <LivePreview typeId={typeId} paletteId={paletteId} navKind={navKind} mode={mode}/>
        </DCArtboard>
      </DCSection>

      {/* ── 5. Direction A — Calm ──────────────────────────────────────── */}
      <DCSection id="calm" title="Direction A — Calm (reference)" subtitle="Full set of interactions: bulk actions, side-panel detail, ⌘K, shortcuts">
        <DCArtboard id="calm-cockpit" label="Cockpit" width={W_SCREEN} height={H_SCREEN}>
          <CalmCockpit/>
        </DCArtboard>
        <DCArtboard id="calm-tasks" label="Tasks · Board · 1 selected (bulk bar)" width={W_SCREEN} height={H_SCREEN}>
          <CalmTasks/>
        </DCArtboard>
        <DCArtboard id="calm-panel" label="Tasks · Side-panel detail (dockable)" width={W_PANEL} height={H_PANEL}>
          <CalmSidePanel/>
        </DCArtboard>
        <DCArtboard id="calm-approvals" label="Approvals queue · inline approve / reject" width={W_SCREEN} height={H_SCREEN}>
          <CalmApprovals/>
        </DCArtboard>
        <DCArtboard id="calm-cmdk" label="⌘K command palette" width={W_CMDK} height={H_CMDK}>
          <CalmCmdK/>
        </DCArtboard>
        <DCArtboard id="calm-kbd" label="Keyboard shortcuts (? to open)" width={W_KBD} height={H_KBD}>
          <CalmShortcuts/>
        </DCArtboard>
      </DCSection>

      {/* ── 6. Direction B — Editorial ─────────────────────────────────── */}
      <DCSection id="editorial" title="Direction B — Editorial (reference)" subtitle="Warm linen + terracotta · Newsreader serif">
        <DCArtboard id="ed-cockpit" label="Cockpit · front page" width={W_SCREEN} height={H_SCREEN}>
          <EditorialCockpit/>
        </DCArtboard>
        <DCArtboard id="ed-tasks" label="Tasks · list · saved filter chips" width={W_SCREEN} height={H_SCREEN}>
          <EditorialTasks/>
        </DCArtboard>
        <DCArtboard id="ed-approvals" label="Approvals desk" width={W_SCREEN} height={H_SCREEN}>
          <EditorialApprovals/>
        </DCArtboard>
      </DCSection>

      {/* ── 7. Direction C — Console ───────────────────────────────────── */}
      <DCSection id="console" title="Direction C — Console (reference)" subtitle="Near-black + neon · IBM Plex · dark-first">
        <DCArtboard id="cp-cockpit" label="Cockpit · monitoring view" width={W_SCREEN} height={H_SCREEN}>
          <ConsoleCockpit/>
        </DCArtboard>
        <DCArtboard id="cp-tasks" label="Tasks · dense list" width={W_SCREEN} height={H_SCREEN}>
          <ConsoleTasks/>
        </DCArtboard>
        <DCArtboard id="cp-approvals" label="Approvals queue" width={W_SCREEN} height={H_SCREEN}>
          <ConsoleApprovals/>
        </DCArtboard>
        <DCArtboard id="cp-fabric" label="Fabric · architecture graph + node detail" width={W_SCREEN} height={H_SCREEN}>
          <ConsoleFabric/>
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

// ── Tweaks ───────────────────────────────────────────────────────────────

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "mode": "light"
}/*EDITMODE-END*/;

function TweaksContainer({ mode, setMode }) {
  return (
    <TweaksPanel title="Tweaks">
      <TweakSection title="Theme mode">
        <TweakRadio
          value={mode}
          onChange={setMode}
          options={[
            { value: 'light', label: 'Light' },
            { value: 'dark', label: 'Dark' },
          ]}
        />
        <p style={{ fontSize: 11, color: 'rgba(0,0,0,0.55)', margin: 0, lineHeight: 1.45 }}>
          Applies to the live composition preview. Reference directions stay as designed.
        </p>
      </TweakSection>

      <TweakSection title="How to use">
        <p style={{ fontSize: 12, color: 'rgba(0,0,0,0.7)', lineHeight: 1.5, margin: 0 }}>
          The top section shows <strong>Settings → Appearance</strong> — the actual screen where users will pick their theme.
        </p>
        <p style={{ fontSize: 12, color: 'rgba(0,0,0,0.7)', lineHeight: 1.5, margin: 0 }}>
          Below it, click any <strong>type</strong>, <strong>palette</strong> or <strong>nav pattern</strong> card to apply it to the live composition cockpit further down. Choices are saved locally.
        </p>
      </TweakSection>
    </TweaksPanel>
  );
}

// Mount — root component holds the shared mode state so Tweaks can toggle it
function Root() {
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);
  // Bridge: TweaksContainer needs mode passed in; we mirror in localStorage
  // via the App component's own state. App reads its own state for previews;
  // we override App's `mode` from Tweaks via a tiny shared ref.
  return <RootInner tweaks={tweaks} setTweak={setTweak}/>;
}

function RootInner({ tweaks, setTweak }) {
  // useState here so App below can read mode; but App also persists its own.
  // To stay simple: App reads mode from Tweaks via window event.
  // Cleaner: inline App and pass mode through. Do that.
  const [mode, setMode] = useState(tweaks.mode || 'light');
  useEffect(() => { setMode(tweaks.mode || 'light'); }, [tweaks.mode]);

  return (
    <>
      <AppShell mode={mode}/>
      <TweaksContainer mode={mode} setMode={(v) => setTweak('mode', v)}/>
    </>
  );
}

// Refactor App slightly so we can pass mode through.
function AppShell({ mode }) {
  return <AppWithMode mode={mode}/>;
}

function AppWithMode({ mode: tweakMode }) {
  const [typeId, setTypeId] = useState('inter');
  const [paletteId, setPaletteId] = useState('stone');
  const [navKind, setNavKind] = useState('topbar');
  const mode = tweakMode || 'light';

  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const s = JSON.parse(raw);
        if (s.typeId) setTypeId(s.typeId);
        if (s.paletteId) setPaletteId(s.paletteId);
        if (s.navKind) setNavKind(s.navKind);
      }
    } catch {}
  }, []);
  useEffect(() => {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify({ typeId, paletteId, navKind })); } catch {}
  }, [typeId, paletteId, navKind]);

  const pair = TYPE_PAIRS.find((p) => p.id === typeId);
  const palette = PALETTES.find((p) => p.id === paletteId);

  return (
    <DesignCanvas>
      <DCSection id="settings" title="Settings → Appearance · in Watchtower" subtitle="The picker as it would live in the real app — every foundation option is exposed here, with a live cockpit preview on the right of the screen.">
        <DCArtboard id="appearance" label="Settings · Appearance · with live preview" width={W_SCREEN} height={H_SCREEN}>
          <AppearanceSettings/>
        </DCArtboard>
      </DCSection>

      <DCSection
        id="type"
        title={`Foundations · Type — selected: ${pair.sans.split(',')[0]}`}
        subtitle="Click a card to apply it to the live composition further down"
      >
        {TYPE_PAIRS.map((p) => (
          <DCArtboard key={p.id} id={`type-${p.id}`} label={p.label} width={W_TYPE} height={H_TYPE}>
            <TypePairCard pair={p} selected={p.id === typeId} onSelect={() => setTypeId(p.id)}/>
          </DCArtboard>
        ))}
      </DCSection>

      <DCSection
        id="color"
        title={`Foundations · Color — selected: ${(palette.label.split('·')[1] || palette.label).trim()}`}
        subtitle="Click a card to apply it"
      >
        {PALETTES.map((p) => (
          <DCArtboard key={p.id} id={`pal-${p.id}`} label={p.label} width={W_PAL} height={H_PAL}>
            <PalettePreviewCard palette={p} selected={p.id === paletteId} onSelect={() => setPaletteId(p.id)}/>
          </DCArtboard>
        ))}
      </DCSection>

      <DCSection id="nav" title={`Navigation pattern — selected: ${navKind}`} subtitle="Click a card to apply it">
        <DCArtboard id="nav-topbar" label="1 · Top bar + contextual sub-nav" width={W_NAV} height={H_NAV}>
          <NavPatternTopBar selected={navKind === 'topbar'} onSelect={() => setNavKind('topbar')}/>
        </DCArtboard>
        <DCArtboard id="nav-sidebar" label="2 · Persistent left sidebar + pinned" width={W_NAV} height={H_NAV}>
          <NavPatternSidebar selected={navKind === 'sidebar'} onSelect={() => setNavKind('sidebar')}/>
        </DCArtboard>
        <DCArtboard id="nav-rail" label="3 · Slim icon rail · ⌘K-primary" width={W_NAV} height={H_NAV}>
          <NavPatternRail selected={navKind === 'rail'} onSelect={() => setNavKind('rail')}/>
        </DCArtboard>
      </DCSection>

      <DCSection
        id="preview"
        title="Your composition · live"
        subtitle="The Cockpit themed from your current selections. Toggle dark mode in the Tweaks panel."
      >
        <DCArtboard id="live-preview" label={`Cockpit · ${pair.sans.split(',')[0]} · ${palette.id} · ${navKind} · ${mode}`} width={W_PREVIEW} height={H_PREVIEW}>
          <LivePreview typeId={typeId} paletteId={paletteId} navKind={navKind} mode={mode}/>
        </DCArtboard>
      </DCSection>

      <DCSection id="calm" title="Direction A — Calm (reference)" subtitle="Full set of interactions: bulk actions, side-panel detail, ⌘K, shortcuts">
        <DCArtboard id="calm-cockpit" label="Cockpit" width={W_SCREEN} height={H_SCREEN}><CalmCockpit/></DCArtboard>
        <DCArtboard id="calm-tasks" label="Tasks · Board · 1 selected (bulk bar)" width={W_SCREEN} height={H_SCREEN}><CalmTasks/></DCArtboard>
        <DCArtboard id="calm-panel" label="Tasks · Side-panel detail (dockable)" width={W_PANEL} height={H_PANEL}><CalmSidePanel/></DCArtboard>
        <DCArtboard id="calm-approvals" label="Approvals queue · inline approve / reject" width={W_SCREEN} height={H_SCREEN}><CalmApprovals/></DCArtboard>
        <DCArtboard id="calm-cmdk" label="⌘K command palette" width={W_CMDK} height={H_CMDK}><CalmCmdK/></DCArtboard>
        <DCArtboard id="calm-kbd" label="Keyboard shortcuts (? to open)" width={W_KBD} height={H_KBD}><CalmShortcuts/></DCArtboard>
      </DCSection>

      <DCSection id="editorial" title="Direction B — Editorial (reference)" subtitle="Warm linen + terracotta · Newsreader serif">
        <DCArtboard id="ed-cockpit" label="Cockpit · front page" width={W_SCREEN} height={H_SCREEN}><EditorialCockpit/></DCArtboard>
        <DCArtboard id="ed-tasks" label="Tasks · list · saved filter chips" width={W_SCREEN} height={H_SCREEN}><EditorialTasks/></DCArtboard>
        <DCArtboard id="ed-approvals" label="Approvals desk" width={W_SCREEN} height={H_SCREEN}><EditorialApprovals/></DCArtboard>
      </DCSection>

      <DCSection id="console" title="Direction C — Console (reference)" subtitle="Near-black + neon · IBM Plex · dark-first">
        <DCArtboard id="cp-cockpit" label="Cockpit · monitoring view" width={W_SCREEN} height={H_SCREEN}><ConsoleCockpit/></DCArtboard>
        <DCArtboard id="cp-tasks" label="Tasks · dense list" width={W_SCREEN} height={H_SCREEN}><ConsoleTasks/></DCArtboard>
        <DCArtboard id="cp-approvals" label="Approvals queue" width={W_SCREEN} height={H_SCREEN}><ConsoleApprovals/></DCArtboard>
        <DCArtboard id="cp-fabric" label="Fabric · architecture graph + node detail" width={W_SCREEN} height={H_SCREEN}><ConsoleFabric/></DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<Root/>);
