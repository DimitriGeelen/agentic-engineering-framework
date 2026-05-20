---
id: T-1930
name: "BVP T-NEW-13: Watchtower /arcs/<id> extensions — arc-level BVP, coherence warnings,
  proposed_scoped_drivers render with approve buttons"
description: >
  Extend existing /arcs/<id> page with arc-level BVP near top, per-driver coherence
  warnings inline, proposed_scoped_drivers rendered with timestamps and approve action
  buttons (calls fw arc approve-driver via --from-watchtower).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bvp, build, slice-13, web, render-surface]
components: [012-ArcSystem.md, lib/arc.sh]
related_tasks: [T-1915, T-1916, T-1926, T-1927]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-05-19T17:56:35Z'
date_finished: 2026-05-19T17:02:48Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1930: BVP T-NEW-13 — `/arcs/<id>` extensions

## Context

Brings BVP signals into the existing arc detail page. Render-surface, [REVIEW] Human AC required.

**Source:** Handoff §7 T-NEW-13; artefact §6 row 14; §4 D3 (coherence), D7-reframe (`fw arc show-suggestions` discoverable).

## Acceptance Criteria

### Agent
- [x] `/arcs/<id>` shows arc-level BVP near the top — two stat boxes (`Arc BVP_norm`, `Arc BVP_raw`) + `Per-driver breakdown` collapsible (`<details>`) listing every driver from policy with weight/score/contribution. Renders empty-state ("—") when arc has no `bvp_scores:` yet (current arc-006 corpus state). See `web/blueprints/arcs.py:_bvp_signals` + `web/templates/arc_detail.html` `#bvp-signals` block.
- [x] T-1927 coherence WARNs surface inline (per-driver, not aggregated) — `_bvp_coherence_for_arc()` mirrors `agents/audit/audit.sh` BVP coherence check, scoped to one arc; findings render as a `<ul>` with `.badge-warn` per driver; passing state renders an italic muted "No coherence warnings" note so the human sees the section either way.
- [x] `proposed_scoped_drivers:` entries render with their event timestamps (D7) — newest first (sorted by `ts` desc). Probe-tested with 2 synthetic proposals: forensic-detail (ts 12:00) renders above determinism (ts 11:00). See template `bvp_info.proposed_drivers` loop.
- [x] Each proposed driver has an Approve button — form POSTs to `/api/arc/<slug>/approve-driver` which shells `bin/fw arc approve-driver <slug> "<name>" --weight N --rationale "..." --from-watchtower` (see `web/blueprints/arcs.py:arc_approve_driver`). Hidden `name` field carries the proposed driver name; visible `weight` (1-6, M2 cap) and `rationale` inputs default-pop from the proposal.
- [x] "Approve none" form present in collapsible `<details>` — POSTs to `/api/arc/<slug>/approve-none`, requires `<textarea name="justification" minlength="30" required>` (R6 enforced both client-side `minlength` and server-side `len < 30 → 400`). Probe-tested: short justification "too short" returns 400 with "≥30 characters" message.
- [x] After approve/none, the POST route redirects to `/arcs/<slug>` (302) — the next render reflects whatever the underlying `fw arc approve-driver` mutated (scoped_drivers updated + status flipped draft→in-progress per T-1926). The blueprint does NOT short-circuit that flip; it delegates to the existing fw command so all §ACD + M2 guarantees stay in one place.

### Human
- [ ] [REVIEW] Approval flow is unambiguous and the page reads cleanly without competing CTAs
  **Steps:**
  1. Open `/arcs/value-prioritisation` (arc-006 if/when it has proposed drivers)
  2. Verify BVP display, coherence area (may be empty), proposed-drivers section
  3. Try approving one (or `--none`); verify the arc flips to in-progress and reload reflects it
  **Expected:** Single clear approve action per proposal; no surprise state mutations
  **If not:** Note the specific UX issue

## Verification

grep -q "approve-driver\|approve_driver" web/blueprints/arcs.py
grep -q "scoped_drivers\|proposed_scoped" web/blueprints/arcs.py
out=$(curl -sf "$(bin/fw watchtower url)/arcs/value-prioritisation" 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'BVP signals|bvp-signals')" -ge 1 ]
out=$(bin/fw test playwright -- tests/playwright/test_arc_detail_bvp.py 2>&1 || true); grep -qE '[0-9]+ passed' <<<"$out" && ! grep -qE '[0-9]+ failed' <<<"$out"

## Recommendation

**Recommendation:** GO

**Rationale:** The /arcs/<id> page now surfaces every BVP signal the arc
substrate produces: numeric arc-level BVP (norm + raw), per-driver
breakdown (showing the rubric→score→contribution chain that R9 mandates
remain inspectable), per-driver coherence findings (T-1927 R2 detection
inline rather than buried in audit YAML), proposed-drivers list with
timestamps (D7-reframe: persistence not audit), Approve / Approve-none
forms that delegate to `fw arc approve-driver --from-watchtower`. All
sovereignty (§ACD), R6 (≥30 char justification), M2 (3 drivers / weight
≤6) guarantees stay in the existing fw command — the blueprint is glue
only; the page reloads after redirect so the human sees the resulting
arc state from the source-of-truth YAML.

**Evidence:**
- `web/blueprints/arcs.py` — 3 new functions:
  - `_bvp_coherence_for_arc()` (~70 LOC) — same per-driver rule as
    `agents/audit/audit.sh:699` BVP coherence section, scoped to one arc
  - `_bvp_signals()` (~60 LOC) — orchestrates compute + coherence +
    proposed-drivers shape (reuses `web.blueprints.bvp._compute_bvp` so
    math has ONE source despite blueprint duplication)
  - `arc_approve_driver()` + `arc_approve_none()` (~70 LOC) — POST
    routes shelling `fw arc approve-driver ... --from-watchtower`
- `web/templates/arc_detail.html` (+110 lines) — `#bvp-signals` section
  with stat boxes, per-driver `<details>`, coherence ul, scoped-drivers
  table, proposed-drivers articles with approve forms, approve-none
  collapsible. Empty states render so the section is structurally
  consistent across all arcs.
- `tests/playwright/test_arc_detail_bvp.py` — 7/7 PASS:
  - section renders with correct data-arc-bvp attribute
  - h2 heading visible
  - norm + raw stat boxes both render
  - per-driver breakdown collapsible
  - approve-none form has minlength=30 + required
  - approve-none short justification rejected (server-side 400)
  - coherence section renders (warnings OR passing note)
- Live probe with 2 synthetic proposed drivers (`forensic-detail`,
  `determinism`) — both render with approve forms in newest-first order
  (D7), then reverted to clean state.

**Cross-arc compatibility:** The BVP block renders on every arc detail
page, not just value-prioritisation. For arcs without `bvp_scores:`
(every arc except arc-006 today), the stat boxes show "—" and the
per-driver breakdown shows scores as "—" — graceful empty state.
Coherence findings only fire for `status: in-progress` arcs that claim a
driver ≥4 and have scoring constituents (per audit.sh rules).

**Follow-up (not blocking):** The BVP math is now imported from
`web.blueprints.bvp` (`_compute_bvp`, `_driver_weights`, `_load_policy`).
If we extract `lib/bvp_engine.py` later (per T-1928 decision block),
both blueprints + lib/bvp.sh can share one Python source. Current
state: bvp.py is the de-facto blueprint-side engine.

## Decisions

### 2026-05-19 — Coherence finding render: per-driver, not aggregated

**Choice:** Render coherence findings as a flat `<ul>` of `(driver,
claim, n_low, n_total, frac)` tuples, one entry per failing driver.

**Alternatives considered:**
- Aggregate by arc with a single "N coherence warnings" badge → loses
  R2 signal (per-driver patterns indicate rubric bias vs. arc mis-score).
- Inline per-row in the constituent-tasks table → confuses the "task is
  the actor" rendering; the warning is about the arc-vs-corpus mismatch.

**Rationale:** AC text says "per-driver, not aggregated." T-1927's
audit-side message is per-driver too ("arc X claims D_n=N but tasks
don't support it"). The Watchtower surface matches.

### 2026-05-19 — POST route shells fw, doesn't mutate YAML directly

**Choice:** Both approve-driver and approve-none routes shell to
`bin/fw arc approve-driver ... --from-watchtower`, not write the YAML
themselves.

**Why:** The fw command carries §ACD (CLAUDECODE refuse without
--from-watchtower / --i-am-human), M2 cap enforcement (3 drivers /
weight ≤6), R6 justification length, T-1926 draft→in-progress flip, and
the approve-event audit log. Re-implementing any of that in the
blueprint would diverge two enforcement paths.

**Trade-off:** Adds a 30-second timeout subprocess per POST. Acceptable
— approvals are infrequent (M6: human action), not hot-path.

## Updates

### 2026-05-19T16:56:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-6b1343bb
- **Timestamp:** 2026-05-19T17:03:09Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `/arcs/<id>` shows arc-level BVP near the top — two stat boxes (`Arc BVP_norm`, `Arc BVP_raw`) + `Per-driver breakdown` collapsible (`<details>`) listing every driver from policy with weight/score/con
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/arc_detail.html in: `/arcs/<id>` shows arc-level BVP near the top — two stat boxes (`Arc BVP_norm`, `Arc BVP_raw`) + `Per-driver breakdown` collapsible (`<details>`) list`
- **AC#2 (Agent)** — T-1927 coherence WARNs surface inline (per-driver, not aggregated) — `_bvp_coherence_for_arc()` mirrors `agents/audit/audit.sh` BVP coherence check, scoped to one arc; findings render as a `<ul>` with
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/audit.sh in: T-1927 coherence WARNs surface inline (per-driver, not aggregated) — `_bvp_coherence_for_arc()` mirrors `agents/audit/audit.sh` BVP coherence check, s`

### 2026-05-19T17:02:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
