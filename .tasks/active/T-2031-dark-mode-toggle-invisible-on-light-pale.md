---
id: T-2031
name: "dark-mode toggle invisible on light palettes (button --pico-color = accent-ink)"
description: >
  The .theme-toggle button icon is invisible on light palettes (white-on-white in paper
  light) because Pico styles buttons by setting --pico-color to the button text colour
  (accent-ink/inverse=white); with background:none the white icon lands on the page
  surface. Fix: use var(--wt-text) which always contrasts the surface.

status: started-work
workflow_type: build
owner: agent
horizon: now
arc_id: watchtower-redesign
tags: [arc:watchtower-redesign, ui, watchtower, bug, nav]
components: []
related_tasks: [T-1987, T-2003, T-1991]
created: 2026-05-24T14:40:20Z
last_update: 2026-05-24T14:40:20Z
date_finished: null
---

# T-2031: dark-mode toggle invisible on light palettes

## Context

User-reported (2026-05-24): "the toggle darkmode becomes invisible in certain color
schemes." Reproduced and root-caused **empirically** (browser computed-style measurement,
not CSS reasoning — the first CSS-only diagnosis was wrong).

The fix is `base.html:545`: change the toggle's inline `color:var(--pico-color)` →
`color:var(--wt-text)`.

## Acceptance Criteria

### Agent
- [x] base.html `.theme-toggle` uses `color:var(--wt-text)` (not `var(--pico-color)`)
- [x] Unit test `tests/unit/test_theme_toggle_contrast.py` passes (toggle inline style references `--wt-text`, not `--pico-color`)
- [x] Playwright test `tests/playwright/test_theme_toggle_contrast.py` passes: in the previously-broken case (`paper` palette + `light` mode) the toggle's computed colour ≠ its background colour (was white-on-white)
- [x] base.html still compiles (jinja `get_template`)

### Human
- [ ] [REVIEW] The dark-mode toggle icon is clearly visible in the top bar on every palette × light/dark mode
  **Steps:**
  1. Open http://192.168.10.107:3000/ (cockpit)
  2. Open http://192.168.10.107:3000/settings/appearance and switch palette to **Paper**, mode **Light** (the previously-broken combo)
  3. Look at the ☾/☀ icon in the top-right of the bar; click it to flip mode
  **Expected:** the icon is clearly visible (dark icon on the light bar; light icon on the dark bar) in Paper-light and every other palette/mode
  **If not:** note the palette+mode where it's faint/invisible — `--wt-text` may need a contrast tweak for that palette in foundations.css

## Verification

out=$(cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_theme_toggle_contrast.py -q 2>&1); echo "$out" | tail -3; echo "$out" | grep -q "passed"
python3 -c "import sys; sys.path.insert(0,'.'); from web.app import app; app.jinja_env.get_template('base.html'); print('compiles')"

## RCA

**Symptom:** the dark-mode toggle icon (☾/☀) in the top bar is invisible on light palettes —
white-on-white in the `paper` palette + light mode.

**Root cause:** `.theme-toggle` is a `<button>`. Pico v2's button styling sets
`--pico-color` *on the button* to the button text colour (`--pico-primary-inverse` →
`--wt-accent-ink`, which is `#ffffff` for the paper palette). The toggle's inline style is
`background:none; color:var(--pico-color)`, so it picks up that white button-text colour and
paints a white icon directly on the page surface (`--wt-surface` = `#ffffff` in paper light)
→ invisible. Empirically localised: at `.theme-toggle`, `--pico-color`=`#ffffff` while
`body`/`nav`/`main p` all correctly resolve `--pico-color`=`#111111` (the T-2003 bridge
remap `--pico-color: var(--wt-text)` is correct everywhere *except* on buttons, where Pico's
own rule wins). `--wt-text` is `#111111` at the toggle (correct) — it is set at the
palette/:root level and Pico's button rule does not touch it.

**Why structurally allowed:** no test asserts top-bar chrome contrast across palettes; the
T-2003 palette-bridge work validated content-page chrome but not the `<button>`-based
toggle, where Pico re-derives `--pico-color`. Element-presence/grep checks (forbidden as
sole UI checks per T-1575) would never have caught a white-on-white icon. The bug shipped
because nothing measures computed contrast of nav chrome.

**Prevention:** the Playwright AC measures the toggle's computed colour ≠ its background in
the exact failing case (paper+light), guarding the regression forever; the unit test pins
the `--wt-text` token so a future edit can't silently revert to `--pico-color`. Broader
class (any `background:none` button using `--pico-color` for icon colour) noted: the toggle
is currently the only instance in base.html (the other 13 `--pico-color` uses are non-button
elements where the bridge maps correctly).

## Evolution

### 2026-05-24 — measure-don't-reason (twice corrected)
- **What changed:** First diagnosis ("toggle uses --pico-color which doesn't follow the palette") was wrong — the T-2003 bridge *does* remap `--pico-color`→`--wt-text`. Only browser measurement revealed the real mechanism: Pico's `<button>` rule overrides `--pico-color` with the white accent-ink, scoped to the toggle. Same "assert-without-checking" failure class as the `/appearance` route error earlier this session (T-2030 F2).
- **Plan impact:** The fix token (`--wt-text`) happened to be the same, but the RCA and the regression test target the real cause (button-scoped override), not the imagined one.
- **Triggered:** reinforces T-2030 (tooling/measurement over agent assertion) and the need for computed-contrast checks on nav chrome.

## Recommendation

**Recommendation:** GO
**Rationale:** Single-line fix at the empirically-verified root; regression pinned by a computed-contrast Playwright test in the exact failing palette/mode.
**Evidence:**
- Measured: paper-light toggle was `rgb(255,255,255)` on `rgb(255,255,255)`; `--wt-text`=`#111111` at the toggle.
- Localised: only `.theme-toggle` had `--pico-color`=white; body/nav/content correct.

## Updates

### 2026-05-24T14:40:20Z — task-created
- **Action:** Created task; root-caused via browser computed-style measurement.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e142f770
- **Timestamp:** 2026-05-24T14:42:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
