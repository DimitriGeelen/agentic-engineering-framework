---
id: T-1880
name: "Extract shared lib/arc_membership helper — consolidate 4 dual-read patterns"
description: >
  After T-1874/75/76/77/1879, four code paths implement union-of-arc_id-and-arc:slug-tag scans: lib/arc.sh _arc_tasks_for, agents/audit/audit.sh inline python, web/blueprints/arcs.py _scan_tasks_by_arc_membership, web/blueprints/core.py inline. Plus lib/evolution_log.sh task_has_arc_membership shell helper. Future-prevention proposal from T-1879 Recommendation: extract canonical lib/arc_membership.{sh,py} module that all 4-5 consumers call. Without this, silent-corpus #3 recurs next time storage format changes. Sibling to arc-grooming T-NEW-14.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-grooming, future-prevention, refactor]
components: []
related_tasks: [T-1850, T-1874, T-1875, T-1876, T-1877, T-1879, T-1881]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-17T14:07:04Z
last_update: 2026-05-17T15:23:05Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
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
- [ ] `lib/arc_membership.py` exists, exposing `scan_tasks_by_arc_membership() → (by_arc_id, by_tag)` and `task_has_arc_membership(path) → bool`
- [ ] `lib/arc_membership.sh` exists, exposing shell functions `arc_tasks_with_arc_id`, `arc_tasks_with_tag`, `arc_tasks_for`, `task_has_arc_membership`
- [ ] `web/blueprints/arcs.py` imports the scan helpers from `lib.arc_membership` (no duplicate scan-logic body)
- [ ] `web/blueprints/core.py` and `web/blueprints/tasks.py` use the shared helper (no inline arc-membership union logic)
- [ ] `agents/handover/handover.sh` and `lib/evolution_log.sh` source `lib/arc_membership.sh` (no inline duplicate)
- [ ] New regression tests pin shared API: `tests/unit/test_arc_membership_shared.py` (python) and `tests/unit/arc_membership_shared.bats` (shell)
- [ ] Existing sibling tests still green: `arc_membership_agent_surfaces.bats`, `test_arc_membership_web_surfaces.py`

### Human
- [ ] [REVIEW] Watchtower arc surfaces remain visually identical after refactor
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && curl -sf http://localhost:3000/arcs/arc-grooming | grep -c 'T-'` — verify task count unchanged
  2. Open http://localhost:3000/ (landing) and visually confirm arc cards still show task counts
  3. Open http://localhost:3000/tasks?arc=arc-grooming and visually confirm rows still filtered
  **Expected:** Same counts, same rows, same layout as before this task shipped.
  **If not:** screenshot diff + note in task body.

## Verification

cd /opt/999-Agentic-Engineering-Framework && test -f lib/arc_membership.py
cd /opt/999-Agentic-Engineering-Framework && test -f lib/arc_membership.sh
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/arc_membership_shared.bats
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_arc_membership_shared.py -q
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/arc_membership_agent_surfaces.bats
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_arc_membership_web_surfaces.py -q

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-17T14:07:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1880-extract-shared-libarcmembership-helper--.md
- **Context:** Initial task creation

### 2026-05-17T15:23:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now
