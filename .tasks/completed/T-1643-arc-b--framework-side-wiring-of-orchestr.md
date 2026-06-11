---
id: T-1643
name: "Arc B — Framework-side wiring of orchestrator substrate (T-1061 follow-up)"
description: >
  Make /opt/999 actually USE the substrate it built. W04 confirmed the framework has
  zero call-sites passing task_type or --model, builds no task-type:X tags, never
  reads model_used/fallback_used. Six discrete wirings: (1) fw termlink dispatch derives
  --task-type from active task workflow_type and tags worker; (2) tag long-lived specialist
  sessions task-type:X; (3) wire --model defaults via .framework.yaml + per-task-type
  overrides; (4) surface model_used/fallback_used in dispatch result manifest; (5)
  Watchtower /orchestrator panel subscribing to Governance frames 0x8; (6) update
  agents/dispatch/preamble.md. Co-arc with /opt/termlink-side hardening: gate the
  71 ungated MCP mutators (W03), wire run_with_governance, ship best_model_for min-sample
  guard (Wilson lower-bound), add fw termlink route CLI verb, surface fallback/breaker
  state in route response, decide tenancy scope of route-cache, extend audit schema
  with route/breaker/governance fields. Blocked on Arc A (T-1642) policy decisions.
  Source: docs/reports/T-1641-worker-04-framework-usage.md, docs/reports/T-1641-worker-03-termlink-current-state.md.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [from-T-1641, t-1061-followup, wiring, orchestrator, termlink, 
      framework-integration]
components: [agents/dispatch/preamble.md, agents/termlink/termlink.sh, 
      lib/config.sh, tests/unit/test_arcs_routes.py, 
      tests/unit/test_termlink_dispatch_task_type.py, web/blueprints/arcs.py, 
      web/blueprints/__init__.py, web/blueprints/orchestrator.py, 
      web/templates/arc_detail.html, web/templates/orchestrator.html]
related_tasks: [T-1641, T-1642, T-1063, T-1064, T-1065, T-1066]
arc_id: orchestrator-rethink
created: 2026-05-01T11:54:52Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-02T05:51:46Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 0
      F-RECALL: 2
      F-ORCH: 1
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=1 
      (body:hand-wired-dispatch); F3=1 (body/components:prompt-incidental); F1=0
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1643: Arc B — Framework-side wiring of orchestrator substrate (T-1061 follow-up)

## Context

Closes Q3 of §Arc Completion Discipline for orchestrator-rethink: "Does the framework that built the arc actually USE the arc?" W04 worker (docs/reports/T-1641-worker-04-framework-usage.md) confirmed framework has zero call-sites passing task_type, builds no `task-type:X` tags, never reads `model_used`/`fallback_used`. Six wirings make /opt/999 actually consume what /opt/termlink built.

T-1643 is a multi-part umbrella; each AC ships independently with `T-1643/Wn:` commit prefix.

## Acceptance Criteria

### Agent
- [x] **W6 (preamble docs):** `agents/dispatch/preamble.md` has a "TermLink Dispatch — Orchestrator-Aware Workers" section telling agents to (a) pass `--task-type` derived from active task `workflow_type`, (b) check `model_used`/`fallback_used` in the dispatch result manifest, (c) tag long-lived specialist sessions with `task-type:X`. Verifiable via grep.
- [x] **W1 (task-type derivation):** `fw termlink dispatch` accepts `--task-type` and, when omitted, auto-derives it from `.context/working/focus.yaml` → active task's `workflow_type`. Worker meta.json gets `task_type` field. Backward compatible — no `--task-type` and no focus → no derivation.
- [x] **W3 (model defaults):** `fw config get DISPATCH_MODEL_DEFAULT` and per-task-type overrides (`DISPATCH_MODEL_FOR_BUILD`, `..._INCEPTION`, etc.) resolved by `cmd_dispatch` when `--model` not passed. Documented in `fw config list`.
- [x] **W2 (specialist session tagging):** `fw termlink spawn --task-type X` tags the long-lived session `task-type:X` for `termlink discover --tag` filtering. Same auto-derivation as W1.
- [x] **W4 (manifest fields):** `cmd_dispatch` worker meta.json includes `task_type`, `model_used`, `fallback_used` keys (initially empty/null until /opt/termlink populates them via governance frame 0x8). `fw termlink result` surfaces them in `--json` output.
- [x] **W5 (Watchtower /orchestrator panel):** `/orchestrator` page renders a "Recent dispatches" panel showing the last N dispatches with `task_type`, `model_used`, `fallback_used` derived from `meta.json` files in `/tmp/tl-dispatch/`. Empty state if no recent dispatches.

### Human
- [x] [REVIEW] Dispatch a test worker and confirm task_type derivation + W6 docs read coherently
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw context focus T-1643`
  2. `bin/fw termlink dispatch --task T-1643 --name w1-test --prompt "echo task-type works"`
  3. `cat /tmp/tl-dispatch/w1-test/meta.json | python3 -c "import json,sys; m=json.load(sys.stdin); print(m.get('task_type'))"`
  4. `sed -n '/Orchestrator-Aware/,/^## /p' agents/dispatch/preamble.md`
  **Expected:** Step 3 prints `build` (T-1643 is workflow_type=build). Step 4 shows the new section.
  **If not:** Note which W (1-6) didn't land.

## Verification

# W6 — preamble doc landed
grep -q "Orchestrator-Aware Workers" agents/dispatch/preamble.md
grep -q "task-type:" agents/dispatch/preamble.md
# W1 — --task-type accepted by dispatch
grep -q -- "--task-type" agents/termlink/termlink.sh
# W3 — model defaults documented
grep -q "DISPATCH_MODEL_DEFAULT" lib/config.sh
# W2 — spawn accepts --task-type
grep -qE 'cmd_spawn\b.*task.type|--task-type' agents/termlink/termlink.sh
# W4 — manifest has task_type / model_used / fallback_used
grep -qE '"(task_type|model_used|fallback_used)"' agents/termlink/termlink.sh
# W5 — Watchtower panel
grep -q "Recent dispatches" web/templates/orchestrator.html
# Tests
python3 -m pytest tests/unit/test_termlink_dispatch_task_type.py -q 2>&1 | tail -3

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

## Recommendation

**Recommendation:** GO

**Rationale:** All six framework-side wirings landed: dispatch + spawn accept `--task-type` with auto-derivation from `focus.yaml`; `cmd_dispatch` resolves model via `DISPATCH_MODEL_FOR_<TYPE>` → `DISPATCH_MODEL_DEFAULT`; worker `meta.json` carries `task_type`/`model_used`/`fallback_used`; Watchtower `/orchestrator` renders the new "Recent dispatches" panel; `agents/dispatch/preamble.md` documents the orchestrator-aware dispatch contract. Closes Q3 of §Arc Completion Discipline ("Does the framework that built the arc actually USE the arc?") — answer is now YES on the framework side. Q1 (end-to-end on fresh substrate) still NO until /opt/termlink populates `model_used`/`fallback_used` via governance frame 0x8.

**Evidence:**
- Tests: `tests/unit/test_termlink_dispatch_task_type.py` 11/11 pass (helpers + static schema pins).
- E2E spot-check: `bash -c 'source agents/termlink/termlink.sh; _derive_task_type'` returns `build` (current focus T-1643).
- Visual: Playwright snapshot of `/orchestrator` shows "Recent dispatches" panel with empty state and the existing "Live Sessions / By task-type" panel still calling out the gap (which will close as soon as a worker dispatches with focus set).
- Backward compatibility: when no focus.yaml exists or `current_task: null`, `_derive_task_type` returns empty — no behaviour change for callers without the new flag.

**Post-T-1664 production evidence (2026-05-02T05:09Z):** A real dispatch via this path with `FW_DISPATCH_MODEL_DEFAULT=haiku` produced a live `meta.json` at `/tmp/tl-dispatch/q1-wire-evidence/meta.json` with `task_type: "build"`, `model: "haiku"`, `model_used: "haiku"`, `fallback_used: true` — all four orchestrator-aware fields populated at dispatch time. Session `q1-wire-evidence` carried canonical tags `task:T-1643, task-type:build` (no legacy `task=` prefix). Watchtower `/orchestrator` "Recent dispatches" panel renders the live entry with task link, `build` task-type pill, and populated values. Result round-tripped (`exit_code=0`, `result.md = "confirmed."`) in under 15s via T-1663 stream-json. Full observation in `docs/reports/T-1643-Q1-wire-evidence.md` (2026-05-02T05:09Z section). **Q1 of §Arc Completion Discipline is now answered with observable artefacts on both framework and /opt/termlink CLI paths** — the rationale's earlier "Q1 still NO" caveat is superseded.

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

### 2026-05-01T11:54:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1643-arc-b--framework-side-wiring-of-orchestr.md
- **Context:** Initial task creation

### 2026-05-01T18:57:17Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-01T19:42:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-39d31d42
- **Timestamp:** 2026-06-02T14:58:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — **W1 (task-type derivation):** `fw termlink dispatch` accepts `--task-type` and, when omitted, auto-derives it from `.context/working/focus.yaml` → active task's `workflow_type`. Worker meta.json gets
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/working/focus.yaml in: **W1 (task-type derivation):** `fw termlink dispatch` accepts `--task-type` and, when omitted, auto-derives it from `.context/working/focus.yaml` → ac`
### 2026-05-02T05:51:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
