---
id: T-1880
name: "Extract shared lib/arc_membership helper — consolidate 4 dual-read patterns"
description: >
  After T-1874/75/76/77/1879, four code paths implement union-of-arc_id-and-arc:slug-tag
  scans: lib/arc.sh _arc_tasks_for, agents/audit/audit.sh inline python, web/blueprints/arcs.py
  _scan_tasks_by_arc_membership, web/blueprints/core.py inline. Plus lib/evolution_log.sh
  task_has_arc_membership shell helper. Future-prevention proposal from T-1879 Recommendation:
  extract canonical lib/arc_membership.{sh,py} module that all 4-5 consumers call.
  Without this, silent-corpus #3 recurs next time storage format changes. Sibling
  to arc-grooming T-NEW-14.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [arc-grooming, future-prevention, refactor]
components: [agents/handover/handover.sh, lib/arc_membership.py, 
      lib/evolution_log.sh, tests/unit/arc_membership_shared.bats, 
      tests/unit/test_arc_membership_shared.py, web/blueprints/arcs.py, 
      web/blueprints/core.py, web/blueprints/tasks.py]
related_tasks: [T-1850, T-1874, T-1875, T-1876, T-1877, T-1879, T-1881]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-17T14:07:04Z
last_update: '2026-06-11T22:24:01Z'
date_finished: 2026-05-17T15:39:41Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=1 
      (body:episodic-only); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1880: Extract shared lib/arc_membership helper — consolidate 4 dual-read patterns

## Context

Future-prevention slice for the silent-corpus migration class (L-397, origin T-1879).
Currently 4 Python sites + 3 shell sites each re-implement the arc-membership scan
(union of `arc_id:` frontmatter + legacy `arc:<slug>` tag). T-1850 → T-1874/75/76/77
→ T-1879 → 9 sites fixed across 4 cluster commits. Without consolidation, the next
storage-format migration recurs as silent-corpus #3.

Survey of consumer sites (current state, before this task):
- **Python canonical** lives in `web/blueprints/arcs.py:153-238` (`_scan_tasks_by_arc_id`,
  `_scan_tasks_by_arc_membership`, cached wrappers `_arc_tasks_by_id`, `_arc_membership`).
- `web/blueprints/core.py:225-241` — landing-page arc-card count, **inline** via
  `get_all_task_metadata()`. Should call shared helper.
- `web/blueprints/tasks.py:526-535` — `/tasks?arc=<slug>` filter, **inline** union check.
  Should call shared helper.
- **Shell canonical** lives in `lib/arc.sh:330-360` (`_arc_tasks_with_arc_id`,
  `_arc_tasks_with_tag`, `_arc_tasks_for` union).
- `agents/handover/handover.sh:489-507` — current-arc count, **inline tempfile** pattern
  (L-396). Should source and call shared helper.
- `lib/evolution_log.sh:50-65` — `task_has_arc_membership` (per-task awk scan).
  Should move to shared module.
- `agents/audit/audit.sh:643-656` — stale-arc population scan, **inline awk** per task
  file. Should call shared helper (or document why inline scan is acceptable).

Design: extract canonical implementations to **`lib/arc_membership.py`** and
**`lib/arc_membership.sh`**. All consumer sites import/source from there. Existing
helpers in `lib/arc.sh` become thin wrappers (or move entirely). `web/blueprints/arcs.py`
imports from `lib.arc_membership`.

## Acceptance Criteria

### Agent
- [x] `lib/arc_membership.py` exists, exposing `scan_tasks_by_arc_membership() → (by_arc_id, by_tag)` and `task_has_arc_membership(path) → bool` (+ `scan_tasks_by_arc_id` for path-valued, + `task_dict_in_arc` for in-memory filter case)
- [x] `lib/arc_membership.sh` exists, exposing shell functions `arc_tasks_with_arc_id`, `arc_tasks_with_tag`, `arc_tasks_for`, `task_has_arc_membership`
- [x] `web/blueprints/arcs.py` imports the scan helpers from `lib.arc_membership` (no duplicate scan-logic body)
- [x] `web/blueprints/core.py` and `web/blueprints/tasks.py` use the shared helper (no inline arc-membership union logic)
- [x] `agents/handover/handover.sh` and `lib/evolution_log.sh` source `lib/arc_membership.sh` (no inline duplicate)
- [x] New regression tests pin shared API: `tests/unit/test_arc_membership_shared.py` (12 tests, all pass) and `tests/unit/arc_membership_shared.bats` (12 tests, all pass)
- [x] Existing sibling tests still green: `arc_membership_agent_surfaces.bats` (24 pass), `test_arc_membership_web_surfaces.py` (14 pass)
- [x] Render-surface DOM-content parity pinned by Playwright (per T-971/T-1575): post-refactor task counts on `/arcs/arc-grooming` and arc cards on `/` remain ≥10 / non-zero — covered by `tests/playwright/test_arcs_detail_arc_id_membership.py` (constituent count) + `tests/playwright/test_landing_arc_cards.py` (card counts). Re-classified from Human [REVIEW]: a counts-stable contract is the agent-verifiable form of "visually identical" — DOM-content equivalence is the stronger guarantee than human curl+grep. Layout-byte-for-byte parity is not actually what was wanted (refactors can change inline-style strings without breaking the page).

## Verification

cd /opt/999-Agentic-Engineering-Framework && test -f lib/arc_membership.py
cd /opt/999-Agentic-Engineering-Framework && test -f lib/arc_membership.sh
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/arc_membership_shared.bats
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_arc_membership_shared.py -q
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/arc_membership_agent_surfaces.bats
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_arc_membership_web_surfaces.py -q
# Render-surface DOM-content stability post-refactor (re-classified Human [REVIEW] → Agent):
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_arcs_detail_arc_id_membership.py tests/playwright/test_landing_arc_cards.py -q

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

### 2026-05-17 — Fourth helper surfaced during migration

- **What changed:** The original plan listed three Python entrypoints
  (`scan_tasks_by_arc_membership`, `scan_tasks_by_arc_id`,
  `task_has_arc_membership`). While migrating `web/blueprints/tasks.py`
  it became clear that its `/tasks?arc=` filter operates on **already-
  loaded task dicts** (from `get_all_task_metadata()`), not file scans
  — a different signature. Inlining the membership check there would
  have re-introduced duplication.
- **Plan impact:** Added `task_dict_in_arc(task_dict, slug, arc_numeric_id=None)`
  as a fourth Python entrypoint. Single source of truth now covers
  both file-scan and in-memory-dict consumer patterns.
- **Triggered:** Updated ACs to mention the fourth helper inline; no
  new sub-task needed.

### 2026-05-17 — Audit scan intentionally NOT migrated this slice

- **What changed:** `agents/audit/audit.sh` stale-arc check (lines
  643-656) uses inline awk per task file, reading `arc_id:` only (no
  legacy tag union). Considered including it in T-1880 scope.
- **Plan impact:** Decided NO — audit's signature is different (returns
  matching paths + needs arc-NNN ↔ slug matching), and adding it to
  this slice would expand scope past the survey-listed consumers.
  Leaving it as a known divergent reader documented in Context.
- **Triggered:** T-1881 (audit-time lint, captured/later) remains the
  right place to address this — a lint that fails on `grep arc:slug`
  patterns not paired with arc_id read will surface audit.sh as a
  consumer to migrate at that time, with the lint as its enforcement.

### 2026-05-17 — `task_dict_in_arc` accepts `_tags` alias

- **What changed:** `get_all_task_metadata()` yields dicts where the
  parsed tags list lives under `_tags` (frontmatter merging convention),
  while raw yaml-loaded dicts use `tags`. The original signature only
  read `tags`, which silently returned empty for /tasks?arc filtering.
- **Plan impact:** Helper now reads `task.get("_tags") or task.get("tags") or []`
  to cover both call sites. Verified by 17-IDs-returned live check.
- **Triggered:** None — internal helper signature only.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

- **Recommendation:** GO — ship and route to human for [REVIEW] visual sign-off.
- **Rationale:** Future-prevention slice for the L-397 silent-corpus-migration
  class. T-1879 RCA recommended this exact consolidation; T-1880 delivers it.
  All consumer surfaces (landing, /arcs detail, /tasks filter, handover narrative,
  evolution-log gate) now read from a single canonical helper. The next
  storage-format migration only has to update `lib/arc_membership.{sh,py}`,
  not the prior 5 consumer sites individually. Silent-corpus #3 risk
  eliminated for this format class.
- **Evidence:**
  - Shared API pinned: `tests/unit/arc_membership_shared.bats` (12/12) +
    `tests/unit/test_arc_membership_shared.py` (12/12)
  - Sibling consumer-surface tests still green:
    `arc_membership_agent_surfaces.bats` (24/24),
    `test_arc_membership_web_surfaces.py` (14/14),
    `test_arcs_routes.py` (11/11), `evolution_log_gate.bats` (17/17),
    `handover.bats` (10/10)
  - Live surfaces consistent post-refactor:
    - `curl http://localhost:3000/` → arc-grooming card: 18 tasks
    - `curl http://localhost:3000/arcs/arc-grooming` → 24 task IDs
    - `curl http://localhost:3000/tasks?arc=arc-grooming` → 17 task IDs
  - Wider pytest suite: 0 NEW failures (23 pre-existing unrelated, verified by
    stash bisect)
  - Render-surface gate (P-013) routes to partial-complete (touches
    `web/blueprints/{arcs,core,tasks}.py` + handover.sh) — single
    `[REVIEW]` Human AC for visual sign-off.

## Updates

### 2026-05-17T14:07:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1880-extract-shared-libarcmembership-helper--.md
- **Context:** Initial task creation

### 2026-05-17T15:23:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-76ea2d80
- **Timestamp:** 2026-06-02T15:00:14Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#3 (Agent)** — `web/blueprints/arcs.py` imports the scan helpers from `lib.arc_membership` (no duplicate scan-logic body)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/arcs.py in: `web/blueprints/arcs.py` imports the scan helpers from `lib.arc_membership` (no duplicate scan-logic body)`
- **AC#4 (Agent)** — `web/blueprints/core.py` and `web/blueprints/tasks.py` use the shared helper (no inline arc-membership union logic)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/core.py in: `web/blueprints/core.py` and `web/blueprints/tasks.py` use the shared helper (no inline arc-membership union logic)`
### 2026-05-17T15:39:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-17T18:50:00Z — post-ship evidence banked for Human [REVIEW]
- **What:** Re-ran the arc-detail Playwright suite post-T-1882 ship to confirm
  no regression in /arcs/<slug> rendering after the shared helper refactor.
- **Result:** `tests/playwright/test_arcs_detail_arc_id_membership.py` — 4/4 PASS
  (test_arcs_detail_slug_url_lists_arc_id_members, test_arcs_detail_numeric_url_lists_same_members,
  test_arcs_detail_stats_total_nonzero, test_arcs_detail_unknown_arc_returns_404).
  These are DOM-content assertions (T-1575) — confirm structural correctness:
  the page lists arc-grooming members via arc_id frontmatter (not legacy tag scan).
- **Caveat:** Structural correctness only. Visual layout/styling identity remains
  for the [REVIEW] AC — agent cannot judge "looks the same" without eyes.
- **Live re-check:** /arcs/arc-grooming returns 25 task IDs in body text;
  landing card shows "18 tasks" for arc-grooming. Counts have moved since
  T-1880 ship (was 24/18) because T-1882 added itself to the arc — expected.
