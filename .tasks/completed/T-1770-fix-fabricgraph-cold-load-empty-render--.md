---
id: T-1770
name: "fix /fabric/graph cold-load empty render — dimension read before layout settles"
description: >
  fix /fabric/graph cold-load empty render — dimension read before layout settles

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: ["ui", "fabric", "race-condition", "regression-fix", "watchtower"]
components: [tests/playwright/test_fabric_graph_cold_load.py, web/templates/fabric_explorer.html]
related_tasks: ["T-849", "T-865"]
created: 2026-05-06T16:40:41Z
last_update: 2026-05-06T16:52:37Z
date_finished: 2026-05-06T16:52:37Z
---

# T-1770: fix /fabric/graph cold-load empty render — dimension read before layout settles

## Context

`web/templates/fabric_explorer.html:486` reads `graphArea.clientWidth/clientHeight` synchronously while the inline script is parsing. On cold load in Chromium (with stylesheets/fonts still loading), these can return `0` → `viewBox = "0 0 0 0"` → degenerate user-space coordinate system → all SVG content collapses to a point → user sees container but no nodes (symptom (b)). A page refresh works because layout is now cached. Fix: keep dimension reads live (re-read on each render) + defer the initial render to a paint-stable moment + re-render on resize.

## Acceptance Criteria

### Agent
- [x] `web/templates/fabric_explorer.html` no longer caches `W`/`H` as module-level `const`; dimensions are re-read inside each render path
- [x] Initial `buildSubsystemGraph()` is deferred to `requestAnimationFrame` (or equivalent paint-stable callback) so it runs after layout has computed
- [x] A `ResizeObserver` on `#graph-area` re-renders when the container dimensions actually change (covers fonts-loaded layout shifts and window resizes)
- [x] Playwright test asserts the rendered SVG has non-zero viewBox AND contains nodes on cold load: `pytest tests/playwright/test_fabric_graph_cold_load.py` exits 0
- [x] No console errors on `/fabric/graph` cold load (favicon 404 ignored)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

test -f tests/playwright/test_fabric_graph_cold_load.py
grep -q "ResizeObserver" web/templates/fabric_explorer.html
grep -q "requestAnimationFrame" web/templates/fabric_explorer.html
! grep -E "^const W = graphArea\.clientWidth, H = graphArea\.clientHeight;$" web/templates/fabric_explorer.html
fw test playwright tests/playwright/test_fabric_graph_cold_load.py

## RCA

**Symptom:** On cold load of `/fabric/graph` in Chromium, the SVG container is visible (with header/stats/legend chrome) but no nodes render. A page refresh always fixes it. Symptom (b) per user diagnosis: container present, nodes absent.

**Root cause:** `web/templates/fabric_explorer.html:486` did:
```js
const W = graphArea.clientWidth, H = graphArea.clientHeight;
```
synchronously during inline-script execution. In Chromium, when the page is cold (stylesheets/fonts not yet loaded), the layout pass forced by `clientWidth` access can return `0` for a flex child whose ancestors haven't fully resolved their size constraints. The two values were then frozen into `const` and used downstream:
- `viewBox = "0 0 0 0"` → degenerate user-space coordinate system → all SVG content collapses to a point in screen-space.
- `rect.width = 0, height = 0` → no background.
- Grid loops `for (x=0; x<W; ...)` → no iterations.
- `forceCenter(0, 0)` → simulation centers nodes at upper-left of degenerate coord system.

A refresh worked because layout was now cached: the second time the script ran, `clientWidth` already had a settled non-zero value.

**Why structurally allowed:**
1. **No layout-stability barrier on inline-render scripts.** The script ran during HTML parse; nothing required it to wait for `load` or even `DOMContentLoaded`. The `clientWidth` API does force a synchronous layout, but that layout uses whatever styles are applied at that instant — pre-stylesheet-load layout produces partial values.
2. **Const-snapshot anti-pattern.** Caching layout-derived values into `const` at script-init meant any subsequent layout settle was ignored. There was no `ResizeObserver`, no re-read on render, and no fallback when the read returned 0.
3. **No regression test.** UI verification was element-presence-grep style (per L-348-ish family), which can't detect a degenerate viewBox — the SVG element exists, the chrome elements exist, only the visible drawing area is collapsed.

**Prevention:**
1. **Live dim reads.** `W`/`H` are now `let`, with a fallback (`|| 800`/`|| 600`) so initial setup never produces a degenerate viewBox even if the read is 0.
2. **`requestAnimationFrame` deferral.** Initial `buildSubsystemGraph()` runs after the next paint frame, by which point CSS-driven layout has settled.
3. **`ResizeObserver`.** Continuous monitoring of `#graph-area` size triggers `_refreshCanvasDims()` whenever the real dimensions change (font-load shift, window resize, panel toggle).
4. **Regression test (`tests/playwright/test_fabric_graph_cold_load.py`):** asserts (a) viewBox is non-degenerate after cold load, (b) at least one `circle` node renders, (c) no JS errors. This is exactly the "Playwright screenshot OR DOM-content assertion" required by the UI verification rule.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-06T16:40:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1770-fix-fabricgraph-cold-load-empty-render--.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-60037dfd
- **Timestamp:** 2026-06-02T14:59:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-06T16:52:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
