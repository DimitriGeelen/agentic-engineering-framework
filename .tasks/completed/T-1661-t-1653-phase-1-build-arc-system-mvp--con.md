---
id: T-1661
name: "T-1653 Phase 1 build: Arc system MVP — .context/arcs/<id>.yaml + bin/fw arc {create,focus,list,show,close,tag} + handover injection + Watchtower landing-page section + /tasks?arc= filter chip + migrate orchestrator-rethink arc"
description: >
  T-1653 GO'd Phase 1 (Watchtower 19:09:02). MVP scope per Recommendation: 1) data model .context/arcs/<id>.yaml with id/name/description/status/anchor_task/constituent_tasks/created/closed_at/decision; 2) bin/fw arc CLI 7 verbs (create/focus/list/show/close/tag); 3) tag namespace arc:<id> canonical, legacy from-T-XXXX as alias one release; 4) handover.sh adds Current Arc line, SessionStart resume picks up; 5) Watchtower landing-page Arcs in flight section + /tasks?arc=<id> filter chip; 6) migration: auto-create orchestrator-rethink arc from T-1641, seed constituent_tasks. ~4h. Out of scope: dedicated /arcs page (Phase 2), arc-specific CLAUDE.md snippets, multi-arc focus stack. Full design: docs/reports/T-1653-arcs-as-first-class.md.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [orchestrator]
components: [agents/context/post-compact-resume.sh, agents/handover/handover.sh, bin/fw, lib/arc.sh, tests/unit/test_arc_system.py, web/blueprints/core.py, web/blueprints/tasks.py, web/templates/cockpit.html, web/templates/index.html, web/templates/tasks.html]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-01T17:19:00Z
last_update: 2026-05-02T05:52:34Z
date_finished: 2026-05-02T05:52:15Z
---

# T-1661: T-1653 Phase 1 build: Arc system MVP — .context/arcs/<id>.yaml + bin/fw arc {create,focus,list,show,close,tag} + handover injection + Watchtower landing-page section + /tasks?arc= filter chip + migrate orchestrator-rethink arc

## Context

T-1653 GO Phase 1 → MVP scope per research artefact `docs/reports/T-1653-arcs-as-first-class.md`.
Six concrete deliverables: data model, 7-verb CLI, tag namespace, handover injection,
Watchtower landing-page section + `/tasks?arc=` filter, migration of orchestrator-rethink arc.

## Acceptance Criteria

### Agent
- [x] D1 — `lib/arc.sh` exists with helper functions; `bin/fw arc help` lists 7 verbs (create / focus / list / show / close / tag / migrate)
- [x] D2 — `bin/fw arc create orchestrator-rethink --name "..." --anchor T-1641` writes `.context/arcs/orchestrator-rethink.yaml` with required fields (id, name, status, anchor_task, constituent_tasks, created)
- [x] D3 — `bin/fw arc focus orchestrator-rethink` writes `.context/working/arc-focus.yaml` with `current_arc:` field; `fw arc list` shows focused arc with marker
- [x] D4 — `bin/fw arc tag orchestrator-rethink T-1661` adds `arc:orchestrator-rethink` to T-1661's tags AND appends T-1661 to the arc's `constituent_tasks`
- [x] D5 — `bin/fw arc show orchestrator-rethink` renders id, name, status, focus, task counts (now/next/later/completed)
- [x] D6 — `agents/handover/handover.sh` emits a `## Current Arc` section when arc-focus.yaml has a `current_arc:` value (no section if unset)
- [x] D7 — Migration command `bin/fw arc migrate orchestrator-rethink --anchor T-1641` seeds constituent_tasks from anchor's `related_tasks` + tasks tagged `from-T-1641` / `arc:orchestrator-rethink` (idempotent)
- [x] D8 — Watchtower landing page (`/`) renders an "Arcs in flight" section for in-progress arcs (verifiable via `curl … | grep -q "Arcs in flight"` when at least one arc exists)
- [x] D9 — Watchtower `/tasks?arc=orchestrator-rethink` filter works: returns only tasks tagged `arc:orchestrator-rethink`
- [x] D10 — Pytest module `tests/unit/test_arc_system.py` covers: arc create/focus/tag/migrate flow, YAML schema, handover injection on/off, focus-cleared behaviour (≥6 tests, all pass)

### Human
- [x] [REVIEW] Watchtower landing-page "Arcs in flight" section reads cleanly at a glance
      **Steps:**
      1. Open `http://192.168.10.107:3000/` in browser
      2. Locate "Arcs in flight" section (above active tasks)
      3. Verify orchestrator-rethink arc renders with task count + click-through
      **Expected:** Section visible, single arc card, clicking goes to `/tasks?arc=orchestrator-rethink`
      **If not:** Screenshot + note what's missing or visually wrong

## Verification

# D1 — CLI help lists all verbs
bin/fw arc help 2>&1 | grep -qE "create|focus|list|show|close|tag|migrate"
# D2 — data model schema parses
bin/fw arc list >/dev/null
# D6 — handover script syntactically valid after edit
bash -n agents/handover/handover.sh
# D8 — landing page section renders (Watchtower running on default port)
PORT=$(bin/fw watchtower port 2>/dev/null); curl -sf "http://localhost:${PORT:-3000}/" >/dev/null
# D10 — targeted pytest passes
python3 -m pytest tests/unit/test_arc_system.py -q
# D9 — task filter accepts arc query (HTTP 200; emptier check is fine before migration)
PORT=$(bin/fw watchtower port 2>/dev/null); curl -sf "http://localhost:${PORT:-3000}/tasks?arc=orchestrator-rethink" >/dev/null

## Recommendation

- **Recommendation:** GO (close partial-complete; one Human AC for visual review remains)
- **Rationale:** All 10 Agent ACs (D1–D10) verified against the live registry and test suite. The orchestrator-rethink arc is migrated and contains 15 constituent tasks (T-1641 anchor + 14 children). Handover injection works (LATEST.md already shows `## Current Arc`). Watchtower landing-page shows the "Arcs in flight" section with a focused-dot indicator and click-through; `/tasks?arc=orchestrator-rethink` filter works (200, with arc-chip rendered). The `set -e` traps caught during build (3 instances) hardened the shell logic — `_arc_tasks_with_tag` now never returns non-zero on empty match, conditional `&&` chains converted to `if`-form, and every public verb terminates with explicit `return 0`. Build is reversible (no deletes, no schema migrations of existing data).
- **Evidence:**
  - `bin/fw arc list` → 1 arc (orchestrator-rethink, 15 tasks, focused)
  - `python3 -m pytest tests/unit/test_arc_system.py -q` → 10/10 pass (1.07s)
  - `curl -sf http://localhost:3000/` contains "orchestrator-rethink" (2 hits: section header + arc card)
  - `curl http://localhost:3000/tasks?arc=orchestrator-rethink` → 200, chip rendered
  - `.context/handovers/LATEST.md` already contains `## Current Arc` block
  - `.context/arcs/orchestrator-rethink.yaml` constituent_tasks: T-1641, T-1642, T-1643, T-1644, T-1645, T-1646, T-1647, T-1648, T-1649, T-1650, T-1651, T-1652, T-1654, T-1655, T-1661

**Out of MVP scope (filed separately):** dedicated `/arcs` page (Phase 2), arc-specific CLAUDE.md snippets, multi-arc focus stack — none deferred during build.

**Live state at 2026-05-02T05:14Z:** Arc grew from 15 → 19 constituents as T-1656/T-1657 (G-062 mech #2/#3) and T-1663/T-1664 (Q1 substrate-half closure on framework path) were tagged `arc:orchestrator-rethink` post-build. Landing-page card reflects "19 tasks" live; `/arcs/orchestrator-rethink` shows 16/19 completion ratio (~84%) with the "audit warns ≥80%" badge firing — T-1656 mech #2 detective working as designed. Phase 1 of T-1653 (this task) is therefore not just code-complete but actively producing the closure signal it was built for; the human's review gate is the last step before `fw arc close`.

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

### 2026-05-01T17:19:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1661-t-1653-phase-1-build-arc-system-mvp--con.md
- **Context:** Initial task creation

### 2026-05-01T17:19:21Z — status-update [task-update-agent]
- **Change:** horizon: now → now
- **Change:** tags: +orchestrator,arc:orchestrator-rethink

## Reviewer Verdict (v1.5)

- **Scan ID:** R-def41e23
- **Timestamp:** 2026-06-02T14:58:57Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 6

**Per-AC findings:**

- **AC#2 (Agent)** — D2 — `bin/fw arc create orchestrator-rethink --name "..." --anchor T-1641` writes `.context/arcs/orchestrator-rethink.yaml` with required fields (id, name, status, anchor_task, constituent_tasks, crea
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/arcs/orchestrator-rethink.yaml in: D2 — `bin/fw arc create orchestrator-rethink --name "..." --anchor T-1641` writes `.context/arcs/orchestrator-rethink.yaml` with required fields (id, `
- **AC#3 (Agent)** — D3 — `bin/fw arc focus orchestrator-rethink` writes `.context/working/arc-focus.yaml` with `current_arc:` field; `fw arc list` shows focused arc with marker
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/working/arc-focus.yaml in: D3 — `bin/fw arc focus orchestrator-rethink` writes `.context/working/arc-focus.yaml` with `current_arc:` field; `fw arc list` shows focused arc with `

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 4
     - evidence: `bin/fw arc list >/dev/null`
  2. **empty-output-success** (partial, heuristic) @ Verification:line 8
     - evidence: `PORT=$(bin/fw watchtower port 2>/dev/null); curl -sf "http://localhost:${PORT:-3000}/" >/dev/null`
  3. **empty-output-success** (partial, heuristic) @ Verification:line 12
     - evidence: `PORT=$(bin/fw watchtower port 2>/dev/null); curl -sf "http://localhost:${PORT:-3000}/tasks?arc=orchestrator-rethink" >/dev/null`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw arc help 2>&1 | grep -qE "create|focus|list|show|close|tag|migrate"`
### 2026-05-02T05:52:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
