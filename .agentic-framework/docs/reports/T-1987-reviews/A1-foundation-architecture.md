# T-1987 review-A1 — Foundation tokens + CSS architecture

**Reviewer:** isolated TermLink worker (reviewer-A1-foundation)
**Dimension:** S0 (T-1991) — foundation token layer (6 palettes × light+dark, 6 type pairings, 3 density tiers)
**Scope:** analysis only, no source edits.
**Verdict in one line:** **ADJUST** — S0's core is sound, but A6 is mis-framed (no Cytoscape exists), A7 needs the *bridge pattern* not pure coexistence, and font-vendoring must move into S0.

---

## How the current style stack actually works (baseline)

Established by reading the live source, not the inception's description:

| Fact | Evidence |
|------|----------|
| There is **no `web/static/css/` directory**. All app CSS is an inline `<style>` block in `base.html` (lines 19-324, 439-462) plus the vendored `web/static/pico.min.css`. | `find web/static`, `web/templates/base.html:19` |
| Pico is **v2.0.6**, the conditional/classless build. Theme switching is already CSS-var-based: `[data-theme=dark]` / `[data-theme=light]` selector blocks redefine `--pico-*`. | `web/static/pico.min.css` header; 6 dark + 2 light `[data-theme]` blocks |
| Runtime theme swap is **already in production**: `wtToggleTheme()` flips `data-theme` on `<html>`; the whole page re-themes with no reload and no flash. | `base.html:597-603` |
| FOUC for dark-mode is pre-empted by an inline head script that reads `localStorage('wt-theme')` and sets `data-theme` **before** the stylesheet loads. | `base.html:8-10` |
| `--pico-*` vars are used **heavily** in templates: 194× `--pico-muted-color`, 135× `--pico-muted-border-color`, 73× `--pico-primary`, etc. | `grep -ho '--pico-[a-z-]*' web/templates` |
| But there are also **704 hardcoded hex literals** across **32 templates that carry their own `<style>` blocks**. These are theme-blind today. | `grep -rhoE '#[0-9a-fA-F]{6}' web/templates \| wc -l` |
| `/fabric` graph is **D3 v7 SVG — NOT Cytoscape** (Cytoscape appears nowhere in `web/`). | `grep -rln cytoscape web/` → empty; `fabric_explorer.html:6` loads `d3.v7.min.js` |
| No per-user-preference infrastructure exists yet (`load_user_preferences` count = 0; no `.context/user-preferences/`). S1 builds it. | `grep -c user_preferences web/shared.py` |

The single most important architectural fact: **Watchtower already does live root-attribute → CSS-var → repaint theming.** S0 is not introducing a new mechanism; it is generalising the proven `data-theme` mechanism to a `data-palette` × `data-type` × `data-density` matrix.

---

## 1. Verdict on A3 — CSS custom-property palette swap without visible flash

**Verdict: PASS (colour) / CONCERN (typography).**

**Colour swap — PASS, with direct in-production evidence.** Toggling `data-theme` today swaps *every* `--pico-*` colour var and repaints `/cockpit`, `/tasks`, `/approvals` instantly without reload or flash (`base.html:597`). A `--wt-*` palette swap is the identical operation: CSS custom-property resolution is a **paint-only** operation when the var feeds a paint property (`color`, `background`, `border-color`, `fill`). No layout is invalidated, so there is no thrash. A full P1→P6 palette swap touches more vars than dark/light but is the *same cost class*.

**Flash elimination is actually easier than today.** The current localStorage approach (`base.html:8-10`) has a brief flash window — the script runs after HTML parse-start. Because S1 moves persistence to **server-side YAML**, the server can emit `<html data-theme="dark" data-palette="console" data-density="compact" data-type="plex">` at render time (`render_page`, `web/shared.py:774`). The chosen theme is correct in the *first* byte of HTML → **zero flash, strictly better than the localStorage path**. This requires editing the `<html>` tag in `base.html` to interpolate the resolved preset (S0/S1 boundary; flag it).

**Typography swap — CONCERN.** A type-pairing change swaps `font-family`, which **does** invalidate layout (font metrics differ → reflow) and, if the font isn't already loaded, produces FOUT/FOIT. This is the real flash risk in the foundation layer, *not* colour. Mitigation belongs in the font strategy (§5): preload the active preset's fonts, accept FOUT (`font-display: swap`) for the rest. The A3 spike must measure **layout shift on type swap** separately from colour swap.

**What `--wt-*` swap would trigger, concretely:** setting `:root[data-palette=X]` redefines the 11 core tokens; any element whose CSS reads `var(--wt-bg)` (or a Pico var bridged to it — see §3) repaints. Elements with **inline** `style="...#hex"` or hex inside template `<style>` blocks (704 + 32 surfaces) do **not** repaint — that is migration debt, not an A3 failure.

---

## 2. Verdict on A6 — graph reads CSS custom properties

**Verdict: CONCERN — the assumption's premise is wrong, and the literal D3 path needs a rewrite.**

**There is no Cytoscape.** `/fabric` renders with **D3 v7** (`fabric_explorer.html:6`). Node/edge colours are bound from data: `.attr('fill', d => d.color)` (lines 545-790), where `d.color` traces back to a **server-side Python hex palette** (`web/blueprints/fabric.py:323-326`) injected via `{{ layers | tojson }}` and resolved by `getColor(sub)` (`fabric_explorer.html:440`).

**The literal current path will NOT read CSS vars.** `.attr('fill', 'var(--wt-x)')` writes a presentation *attribute* `fill="var(--wt-x)"`; SVG presentation attributes do **not** resolve `var()` → the browser discards it and falls back to default (black). So a naive "swap hex for var()" does not work with the existing code.

**Two working paths (the fallback you asked for):**

1. **Inline-style path (cleanest):** change `.attr('fill', d => d.color)` → `.style('fill', d => d.color)` and make `d.color` a `var(--wt-graph-N)` string. Inline `style="fill:var(...)"` *does* resolve CSS vars and *does* repaint live on a `:root` swap. ~12 call-sites in `fabric_explorer.html` (lines 545-790).
2. **Computed-read path (no D3 rewrite, but no auto-repaint):** keep server hex, but at init read `getComputedStyle(document.documentElement).getPropertyValue('--wt-graph-N')` into the palette, and re-run the read + `cytoscape-equivalent` re-color on a theme-change event. More JS, and requires an explicit re-color hook on palette swap.

**Bigger A6 finding — `/fabric` is a hardcoded-dark island.** The explorer is fully namespaced under `.fabric-explorer-scope` with ~80 hardcoded hex values (`#0a0a1a` canvas, `#e2e8f0` text, `#818cf8`/`#c084fc` accents, lines 13-274) and the SVG background `#0a0a1a` (line 509). It does **not** respect even the *existing* `data-theme` light/dark toggle. So S5 (T-1994) is not "migrate graph colours to tokens" — it is "make `/fabric` theme-aware at all." That is a scope reality the inception's risk table understates (it rates A6 "Low / fallback is computed style reads").

**For S0 specifically:** A6 is *out of S0's render scope* (fabric is S5), but S0 should still ship the **spike** that proves path #1 (`.style()` + live `:root` swap repaints an SVG node) so S5 commits against a proven pattern. Reword the assumption from "Cytoscape" → "D3 SVG".

---

## 3. Verdict on A7 — PicoCSS coexistence with `--wt-*`

**Verdict: PASS only via the BRIDGE pattern. Pure side-by-side coexistence FAILS the re-theme goal.**

**Variable-name level: clean.** `--wt-*` and `--pico-*` are different namespaces; no token-name collision. The inception's forward-reference (`--wt-*` to avoid `--pico-*` collision, research artifact line 151) is correct *as far as it goes*.

**Cascade level: this is where "coexistence" is misleading.** Pico styles classless elements (`<button>`, `<table>`, `<input>`, `<article>` cards, `<nav>`, `<details>`) by reading `--pico-*`. If `--wt-*` simply *exists alongside* Pico, those elements keep reading `--pico-*` and **ignore the palette** — picking a new palette would re-colour only the handful of elements you explicitly wrote `var(--wt-*)` on, leaving every Pico-styled control on the old colours. That visibly fails the arc's headline mechanic ("pick a preset → everything re-themes").

**The fix is the bridge pattern:** make `--wt-*` the source of truth, then **re-point Pico's vars at the `--wt-*` tokens** in a `:root` block that loads *after* `pico.min.css`:

```css
/* foundations.css — loaded AFTER pico.min.css */
:root {
  --pico-background-color:        var(--wt-bg);
  --pico-card-background-color:   var(--wt-surface);
  --pico-muted-border-color:      var(--wt-border);
  --pico-color:                   var(--wt-text);
  --pico-muted-color:             var(--wt-muted);
  --pico-primary:                 var(--wt-accent);
  --pico-primary-inverse:         var(--wt-accent-ink);
  --pico-primary-background:      var(--wt-accent);
  /* derived shades — see collision #5 below */
}
```

This makes all 194 `--pico-muted-color` / 135 `--pico-muted-border-color` / 73 `--pico-primary` usages follow the palette **for free**, with zero template edits. It is the highest-leverage decision in S0.

**Five concrete collision/override cases (what S0 must handle):**

1. **`body { background: var(--pico-background-color) }`** (Pico built-in) — bridging `--pico-background-color → --wt-bg` is what actually changes the page background. Without the bridge, setting `--wt-bg` does nothing visible.
2. **`--pico-primary-focus` / `-hover` / `-inverse`** are *separate* Pico vars, not derived live from `--pico-primary`. Bridging only `--pico-primary` leaves focus rings / hover states / button text on Pico's default indigo. You must bridge the whole primary family (`primary`, `primary-hover`, `primary-focus`, `primary-inverse`, `primary-background`) — and `accentInk` varies per palette (white for slate/paper/console, but **dark `#1b1814` for bone**, `#06140b` for console) → `--pico-primary-inverse: var(--wt-accent-ink)` is mandatory or buttons get unreadable text.
3. **`[data-theme=dark]` precedence.** Pico's dark block redefines `--pico-*`. Your bridge `:root` block has equal specificity but loads later, so it wins — *good* — but it means the bridge must itself be palette×theme aware: `:root[data-palette=X]` (light) and `:root[data-palette=X][data-theme=dark]` define the `--wt-*` values, and the bridge reads whatever `--wt-*` resolved to. Order matters: bridge file last in `<head>`.
4. **704 hardcoded hex literals in 32 template `<style>` blocks** (audit-pass `#2e7d32`, audit-warn `#e8a317`, audit-fail `#c62828` at `base.html:130-132`; toast `#1b5e20`/`#c62828` at `base.html:450-451`; all of `fabric_explorer.html`). These ignore both Pico and `--wt-*`. They are the migration debt that *defines the size of S3-S5*. S0 cannot fix them; S0 should **count and inventory** them so downstream slices are scoped.
5. **`highlight-github-dark.min.css`** (always loaded, `base.html:15`) is a fixed dark code-block theme. Under a light palette, code blocks stay dark. Out of S0 scope but a known coexistence gap to log.

**Conclusion:** A7 passes, but reclassify the assumption from "Pico can coexist" to "Pico is *bridged* to `--wt-*`." Pico is not removed (correctly out of arc scope) — it is subordinated.

---

## 4. Concrete `--wt-*` token scheme

**Naming: short, foundations.jsx-aligned, two-tier.** Use the exact keys the design already uses (`foundations.jsx:131-211`): `bg, surface, border, text, muted, accent, accentInk, success, warn, danger, info`. Short names (`--wt-bg`, not `--wt-color-bg`) — they map 1:1 to the design tokens and keep the bridge readable. Reserve a `--wt-color-*` longhand only if a future primitive/semantic split is needed; not now (YAGNI).

```css
/* Tier 1 — palette tokens, set per palette×theme */
:root[data-palette=slate] {
  --wt-bg:#fafafa; --wt-surface:#ffffff; --wt-border:#e5e7eb;
  --wt-text:#0f172a; --wt-muted:#64748b;
  --wt-accent:#4f46e5; --wt-accent-ink:#ffffff;
  --wt-success:#10b981; --wt-warn:#f59e0b; --wt-danger:#ef4444; --wt-info:#0ea5e9;
}
:root[data-palette=slate][data-theme=dark] {
  --wt-bg:#0b0f17; --wt-surface:#11161f; --wt-border:#1f2937;
  --wt-text:#e5e7eb; --wt-muted:#94a3b8;
  /* accent + semantics inherit from light unless palette overrides */
}
/* …5 more palettes × 2 modes = 12 blocks total, values lifted verbatim
   from foundations.jsx PALETTES[].{bg,surface,border,text,muted,accent,
   accentInk,success,warn,danger,info} + dark* keys */

/* Tier 2 — bridge (see §3), loaded after pico.min.css */
```

- **Palette → `data-palette` attribute** on `<html>` (matches the proven `data-theme` mechanism). 6 palettes × 2 modes = 12 selector blocks. Values come **verbatim** from `foundations.jsx` — no re-derivation, no drift.
- **Density → attribute, NOT colour tokens.** Density changes spacing/type scale, which colour tokens can't express. Use `[data-density=compact|cozy|comfortable]` blocks that redefine spacing/scale tokens AND bridge Pico's spacing:
  ```css
  :root[data-density=compact]    { --wt-space:0.35rem; --wt-row-pad:0.25rem 0.5rem; --pico-spacing:0.5rem; --pico-font-size:90%; }
  :root[data-density=cozy]       { --wt-space:0.5rem;  --wt-row-pad:0.4rem 0.6rem;  --pico-spacing:0.75rem; }
  :root[data-density=comfortable]{ --wt-space:0.75rem; --wt-row-pad:0.6rem 0.9rem;  --pico-spacing:1rem; }
  ```
  The chat selected **compact** as default (research artifact, Phase 2 table). Density must bridge `--pico-spacing`/`--pico-font-size` or Pico's built-in spacing won't budge.
- **Type pairing → attribute + bridge, application is CSS-only; loading needs JS/conditional `<link>`.**
  ```css
  :root[data-type=plex] { --wt-font-sans:'IBM Plex Sans',system-ui; --wt-font-mono:'IBM Plex Mono',ui-monospace; }
  :root { --pico-font-family-sans-serif:var(--wt-font-sans); --pico-font-family-monospace:var(--wt-font-mono); }
  ```
  Six pairings from `foundations.jsx:6-57`. Application is pure CSS; *loading* the right WOFF2 is the only JS need (§5). Pairing E (Newsreader serif headlines) additionally needs a heading-scoped `--wt-font-head` since it splits serif H1 / sans body.
- **Cascade order (strict):** `<head>` loads `pico.min.css` **first**, then `foundations.css` **last**. `foundations.css` contains: (a) Tier-1 palette×theme×density×type blocks, (b) the Tier-2 bridge `:root` that re-points `--pico-*`. Later-loading equal-specificity wins → bridge overrides Pico defaults and Pico's `[data-theme]` blocks. **Move the inline `<style>` out of base.html into `foundations.css`** as part of S0 so there's a single token home (the inception's Scope Fence already names `web/static/css/foundations.css`).
- **`<html>` attribute emission:** S0 must update `base.html:2` from `<html lang="en" data-theme="light">` to interpolate the resolved preset server-side (`data-theme`, `data-palette`, `data-density`, `data-type`). Until S1's YAML loader exists, default these to the chat-selected preset (compact / a default palette). This is the S0↔S1 seam — call it out in T-1991's ACs.

---

## 5. Font loading strategy

**Current reality:** Watchtower loads **zero web fonts** today — Pico v2 uses the system stack. The design wants **6 families** (Inter, JetBrains Mono, IBM Plex Sans/Mono, Geist/Geist Mono, Manrope/DM Mono, Newsreader; `foundations.jsx:6-57`). Pairing F is system-only (zero load).

**Recommendation: vendor subset WOFF2 in `web/static/fonts/`, self-hosted, `font-display: swap`.**

- **Self-host, do not use Google Fonts CDN.** The inception's own Technical Constraint says "No network at theme-pick" (T-1987 body line 86). A CDN dependency violates that and adds a privacy/offline failure mode. Vendor the WOFF2s; `@font-face` points at `url_for('static', ...)`.
- **Subset to Latin + numerals + punctuation.** The design leans on **tabular numerals** (`foundations.jsx:111` `fontVariantNumeric:'tabular-nums'`); ensure the subset keeps `tnum`. Latin-basic + digits + the quote/dash glyphs shown in the spec footnote (`foundations.jsx:123`). ~20-40 KB per weight subset vs ~150 KB full.
- **FOUT, not FOIT.** `font-display: swap` — render immediately in the system fallback, swap when the web font arrives. FOIT (invisible text) is worse for a dense control plane. Pair each `--wt-font-sans` with a metric-similar system fallback to minimise the swap reflow (e.g. Inter → system-ui).
- **Load policy: preload active preset, lazy-load the rest.** Inject `<link rel="preload" as="font">` only for the *resolved* preset's families (server knows the preset at render). The other five pairings' fonts are fetched on-demand when the user previews/picks them in `/settings/appearance` (S1). This keeps the initial payload to one pairing's worth (~2 families) instead of all 6. Trade-off: a one-time swap flash when previewing a not-yet-loaded pairing — acceptable inside the Appearance screen where the user expects a preview to "load in."
- **Weights:** the spec uses 500/600/700 + body 400. Vendor 400/500/600/700 for sans, 400/500 for mono. Don't ship every weight.

**S0 deliverable:** `web/static/fonts/` + `@font-face` declarations in `foundations.css` + preload wiring in `base.html`. This **cannot** be deferred to S1 — the no-network constraint makes vendoring a foundation concern, and type-pairing tokens (§4) are inert without the fonts behind them.

---

## 6. S0 spike test list (for T-1991 `## Verification`)

Binary pass/fail. Colour/layout claims are visual → Playwright; structural claims → shell.

**Shell (Tier 1) — structural, run first:**
```sh
# foundations.css exists and is valid CSS (no unclosed blocks)
test -f web/static/css/foundations.css
python3 -c "import re,sys; s=open('web/static/css/foundations.css').read(); assert s.count('{')==s.count('}'), 'brace mismatch'"
# all 6 palettes present as data-palette blocks
for p in slate linen stone paper bone console; do grep -q "data-palette=$p" web/static/css/foundations.css || { echo "missing palette $p"; exit 1; }; done
# bridge re-points the core Pico vars at --wt-* (not left unbridged)
for v in background-color color primary primary-inverse muted-color muted-border-color; do grep -q "\-\-pico-$v:[[:space:]]*var(--wt-" web/static/css/foundations.css || { echo "unbridged --pico-$v"; exit 1; }; done
# 3 density tiers present
for d in compact cozy comfortable; do grep -q "data-density=$d" web/static/css/foundations.css || exit 1; done
# fonts vendored, not CDN
test -d web/static/fonts && ! grep -q "fonts.googleapis.com" web/templates/base.html web/static/css/foundations.css
# foundations.css loads AFTER pico in base.html (cascade order)
python3 -c "s=open('web/templates/base.html').read(); assert s.index('pico.min.css')<s.index('foundations.css'), 'cascade order wrong'"
```

**Playwright (Tier 3) — A3 colour swap, no flash, no layout thrash:**
```python
# A3: palette swap is paint-only — no layout shift
page.goto(f"{base}/cockpit")
box_before = page.locator("main").bounding_box()
page.evaluate("document.documentElement.setAttribute('data-palette','console')")
page.wait_for_timeout(50)
box_after = page.locator("main").bounding_box()
assert box_before == box_after, "layout shifted on colour swap"          # no thrash
bg = page.evaluate("getComputedStyle(document.body).backgroundColor")
assert bg != "", "body bg did not resolve via bridge"                     # bridge works
```

**Playwright (Tier 3) — A3 typography swap reflow is bounded (separate from colour):**
```python
page.goto(f"{base}/cockpit")
page.evaluate("document.documentElement.setAttribute('data-type','newsreader')")
page.wait_for_timeout(100)
ff = page.evaluate("getComputedStyle(document.querySelector('h1')).fontFamily")
assert "Newsreader" in ff, "type pairing did not apply"                   # CSS-only application works
```

**Playwright (Tier 3) — A6 D3 SVG reads vars via `.style()`:**
```python
# spike harness: a minimal SVG circle with style="fill:var(--wt-accent)"
page.goto(f"{base}/__spike_svg")   # or evaluate-injected node
fill_before = page.evaluate("getComputedStyle(document.querySelector('circle.spike')).fill")
page.evaluate("document.documentElement.setAttribute('data-palette','linen')")
fill_after = page.evaluate("getComputedStyle(document.querySelector('circle.spike')).fill")
assert fill_before != fill_after, "SVG fill did not follow --wt-* on palette swap"
```

**Playwright (Tier 3) — A7 Pico elements follow the palette:**
```python
page.goto(f"{base}/tasks")   # untouched Pico-styled page
btn_before = page.evaluate("getComputedStyle(document.querySelector('button,[role=button]')).backgroundColor")
page.evaluate("document.documentElement.setAttribute('data-palette','bone')")
btn_after  = page.evaluate("getComputedStyle(document.querySelector('button,[role=button]')).backgroundColor")
assert btn_before != btn_after, "Pico button ignored palette — bridge missing"
```

Per CLAUDE.md §T-1575 / §T-971: these Tier-3 checks must become persistent tests under `tests/playwright/` when S0 lands, not one-shot ACs. Element-presence grep alone is **forbidden** for these render claims.

---

## 7. Risks not captured in the inception's risk table

1. **704 hex literals × 32 template `<style>` blocks are theme-blind.** The inception risk table has no row for "hardcoded colours don't follow the palette." This is the single biggest determinant of S3-S5 effort — every per-page slice is partly a hex→token migration. S0 should ship an inventory count so the slices are honestly scoped.
2. **`/fabric` is a hardcoded-dark island that ignores even the existing light/dark toggle.** A6's "Low likelihood / computed-style fallback" rating understates this: S5 is "make fabric theme-aware from scratch," not "swap hex for var()." ~80 hex values + `.fabric-explorer-scope` namespace + SVG `#0a0a1a` background (`fabric_explorer.html:13-509`).
3. **Inline-styled HTMX fragments don't pick up tokens.** The inception claims "HTMX present — no extra work needed if scoped to `:root`" (body line 83). True for *CSS-styled* elements (vars inherit through innerHTML swaps), but **false for inline `style="color:#hex"` fragments** — and base.html ships several (toast container line 418, ambient-strip inline colours line 423, theme-toggle inline style line 387). Those need migration too.
4. **FOUC on first paint must be solved server-side, not client-side.** The current localStorage approach has a flash window. With server-side YAML, the `<html>` attributes must be emitted at render (`base.html:2` + `render_page`) — otherwise the page paints the default palette then snaps to the user's. This is a *new* requirement the inception doesn't name; it's the S0↔S1 seam.
5. **Pico derived-shade vars don't auto-follow a single bridge.** Bridging `--pico-primary` alone leaves `--pico-primary-focus/-hover/-inverse` on Pico defaults (collision #2, §3). And per-palette `accentInk` (dark for bone/console) makes `--pico-primary-inverse` bridging mandatory for button legibility.
6. **`highlight-github-dark.min.css` is a fixed dark code theme, always loaded** (`base.html:15`). Code blocks stay dark under light palettes. Out of S0 scope but a coexistence gap to log for a later slice.
7. **`accentInk` contrast is not WCAG-verified per palette.** The design's `accentInk` choices (e.g. bone `#1b1814` on amber `#b87a17`) should get a contrast check; a spike assertion or a one-time audit avoids shipping unreadable primary buttons.

---

## 8. Recommendation

**ADJUST.** Keep S0's spine — additive token layer + the three spikes gating downstream slices — but make four changes before T-1991 starts:

1. **Re-frame A6 from "Cytoscape" to "D3 SVG."** No Cytoscape exists. The spike is `.style('fill', var(--wt-*))` + live `:root` swap (path #1, §2), with the computed-read pattern (path #2) as the documented fallback. Update the assumption text in T-1987 and the open-questions list in the research artifact.
2. **Adopt the bridge pattern explicitly as an S0 decision** (§3). Pure coexistence fails the arc's headline mechanic; re-pointing `--pico-*` at `--wt-*` is what makes "pick a preset → everything re-themes" true for 400+ existing Pico-var usages at zero template cost. This is the highest-leverage call in the whole arc.
3. **Pull font-vendoring into S0** (§5). The "no network at theme-pick" constraint makes self-hosted WOFF2 a *foundation* concern; type-pairing tokens are inert without it. Don't let it drift to S1.
4. **Add a theme-blindness inventory to S0's output** (§7.1): count hex literals + inline-styled fragments + the fabric island, so S3-S5 are scoped against real numbers rather than "low/medium" guesses.

Net effect on the inception's GO/NO-GO: **none of A3/A6/A7 is a NO-GO trigger.** A3 is already proven in production (dark-mode toggle); A7 passes via the bridge; A6's only surprise (D3 not Cytoscape) makes the integration *more* explicit, not impossible. The adjustments sharpen S0's scope and move two concerns (fonts, theme-blindness inventory) to where they belong. **S0 should proceed as ADJUSTED.**

---

### Appendix — file/line evidence index

- Current CSS home: `web/templates/base.html:19-324, 439-462` (inline `<style>`); `web/static/pico.min.css` (Pico v2.0.6)
- Proven runtime theme swap: `base.html:597-603` (`wtToggleTheme`), FOUC script `base.html:8-10`, `[data-theme]` blocks in `pico.min.css`
- Pico var usage: 194 `--pico-muted-color`, 135 `--pico-muted-border-color`, 73 `--pico-primary` (`grep -ho '--pico-[a-z-]*' web/templates`)
- Theme-blind debt: 704 hex literals across 32 `<style>`-bearing templates; hardcoded status colours `base.html:130-132`, toast `base.html:450-451`
- `/fabric` = D3 not Cytoscape: `fabric_explorer.html:6` (d3.v7), node colours `fabric_explorer.html:545-790` (`.attr('fill', d=>d.color)`), `getColor` line 440, server palette `web/blueprints/fabric.py:323-348`
- Fabric island hardcoding: `fabric_explorer.html:13` (`#e2e8f0`/`#0a0a1a`), `:509` (SVG bg), `.fabric-explorer-scope` namespace throughout
- Foundation token source: `foundations.jsx:6-57` (6 type pairings), `:131-211` (6 palettes × light+dark), tabular-nums `:111`
- No prefs infra yet: `grep -c user_preferences web/shared.py` = 0; `render_page` at `web/shared.py:774`
