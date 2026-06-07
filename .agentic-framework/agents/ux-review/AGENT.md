# UX-Review Agent (T-2002 — approach C of inception T-2000)

A browser-driving review agent for **interactive render surfaces**. It executes the
page's JS in a real headless browser — the coverage the static `fw reviewer`
(T-1443) and a curl/grep check cannot provide. It **informs** the human `[REVIEW]`;
it never replaces the taste call (T-1811).

## Why it exists

arc-007 S1 (T-1988) shipped functionally broken: a JS `SyntaxError` left every
appearance preset button dead, yet it passed every gate because verification was
server-side (curl) and markup-presence (grep) only — no agent ever executed the
page's JS. The text `/review/<task>` page also gives a human *nothing to see* for a
visual redesign. This agent closes both gaps: it drives the page, screenshots every
themed state, scans the console, and checks the result against OUR design system.

## What it checks (per theme state)

1. **Interaction liveness** — clicks the control; if the state never applies, the
   click handler is dead (the exact T-1988 class).
2. **Console + page errors** — any `console.error` or uncaught `pageerror` (a future
   `SyntaxError` shows here directly).
3. **Contrast (WCAG AA)** — text/bg, text/surface, muted/bg, accent-ink/accent
   against AA 4.5:1 (3:1 large). Caught Editorial's 3.83:1 button labels.
4. **Token fidelity** — computed `--wt-*` vs the *declared* tokens parsed from
   `foundations.css` (the preload that makes this specialised, not a generic linter).
5. **Bridge integrity** — on a content page the chrome is Pico-styled, so the palette
   only reaches it via the `--pico-primary: var(--wt-accent)` bridge. If
   `--pico-primary` ≠ `--wt-accent` the bridge is defeated and the app ignores the
   palette (caught the light-mode CSS-specificity bug → bug task filed).
6. **Capture integrity (antifragile self-check)** — two distinct palettes must not
   produce a byte-identical frame; if they do, the tool flags its own capture as
   unreliable rather than silently misleading.

## Preloaded design guides (the differentiator)

- `web/static/css/foundations.css` — palette/type/density token sets
- `web/blueprints/settings.py` — `PALETTES`/`TYPES`/`DENSITIES`/`PRESETS`
- `docs/design/watchtower-redesign-2026-05-13/` — redesign design docs

## Usage

```bash
fw ux-review                       # review /settings/appearance (default), all presets
fw ux-review /cockpit              # review a different page
fw ux-review --content-page /tasks # page screenshotted under each palette
fw ux-review --sweep               # cross-page theme sweep (T-2005): one preset, all 5 arc pages
fw ux-review --content-pages "/,/tasks,/arcs"   # sweep a custom page set
fw ux-review --axes                # T-2004: smoke-test Type/Density axes individually
fw ux-review --base http://host:port
```

**Cross-page theme sweep (`--sweep`, T-2005):** verifies the arc-007 headline
mechanic — pick one preset on the appearance screen, then re-load every page
(Cockpit/Tasks/Approvals/Fabric/Arcs) and confirm the theme stays applied. Per page
it checks the pico-bridge (`--pico-primary` must equal `--wt-accent`, the T-2003
class) and screenshots the page. A broken page tells you which redesign slice
(S2-S6) to prioritize. Tests the real persist→navigate→server-inject path, not a
client-side reapply.

Outputs (under `web/static/ux-review/`, so the gallery is servable over LAN):
- `index.html` — side-by-side gallery, each state annotated with console + contrast;
  a "Cross-page theme fidelity" section when `--sweep`/`--content-pages` is used
- `app-<preset>.png` / `picker-<preset>.png` — the re-themed app + the picker
- `sweep-<page>.png` — each swept page under the sweep preset (`--sweep`)
- `docs/reports/T-2002-ux-review-*.md` — findings report + PASS/CONCERN verdict +
  per-page theme-fidelity table

Exit 0 if the engine ran end-to-end. A CONCERN verdict is still a successful run —
the findings are the product.

## Boundaries

- **Informs, never decides.** The `[REVIEW]` taste call (does the redesign *feel*
  right — tone, rhythm, layout) stays human (T-1811). This agent reports the
  mechanical facts: errors, contrast, fidelity, bridge.
- **One bug = one task.** When the agent finds a defect, file a separate bug task;
  do not fix product code under the review run.
- TermLink-dispatch execution mode (context-isolated, like `fw reviewer --dispatch`)
  is a planned follow-up increment.
