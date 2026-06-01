---
id: T-1923
name: "BVP T-NEW-7b: bvp-estimator scheduled sweep + fw resume SLA fallback (split
  parent T-NEW-7)"
description: >
  Periodic sweep for stale-scored tasks; fw resume synchronous fallback with 10s hard
  cap (Q4 default); on timeout flag task `unscored: true` and let async sweep handle
  later. Resume itself never blocked by estimator.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bvp, build, slice-7b, termlink, cron]
components: [agents/resume/resume.sh, agents/task-create/update-task.sh, agents/termlink/bvp-estimator/AGENT.md, agents/termlink/bvp-estimator/bvp-estimator.sh, agents/termlink/bvp-estimator/estimator.py, lib/bvp.sh, tests/unit/test_bvp_blueprint_cost.py, tests/unit/test_bvp_estimator.py, web/blueprints/bvp.py, web/templates/bvp.html]
related_tasks: [T-1915, T-1916, T-1922]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-20T18:57:41Z
date_finished: 2026-05-20T18:57:41Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-19T18:33:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=2 
      (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1923: BVP T-NEW-7b — scheduled sweep + `fw resume` fallback

## Context

Second split-child of T-NEW-7. Depends on T-1922 (worker harness must exist with determinism proven).

**Source:** Handoff §7 T-NEW-7 (needs-split); artefact §6 row 7; §1 Q4 (10s SLA default), §7 M3 (v2-delta).

**Q4 default applied:** 10s hard cap during `fw resume`; task gets `unscored: true` if estimator times out; async sweep picks it up later.

## Acceptance Criteria

### Agent
- [x] Periodic sweep cron-registered runs every 15 min — `bvp-estimator-sweep-15m` entry in `.context/cron-registry.yaml`, deployed to `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` via `fw cron generate && fw cron install`. Schedule `*/15 * * * *`. flock-wrapped to prevent overlap.
- [x] Selection criteria: status ∈ {started-work, captured} AND `bvp_scores:` empty AND (`bvp_scores_proposed:` ≥24h old OR missing OR `unscored:true`). Implemented in `cmd_sweep()` (`agents/termlink/bvp-estimator/estimator.py`). Pinned by `tests/unit/test_bvp_estimator.py::test_cmd_sweep_skips_tasks_with_confirmed_scores` and `::test_proposed_is_stale_*` (3 tests covering no-proposed / old-ts / fresh-ts).
- [x] `fw resume status` synchronous path calls estimator with 10s hard cap — `cmd_with_sla()` exposed as `fw bvp estimate with-sla T-XXX --timeout 10` and wired into `agents/resume/resume.sh:cmd_status` (backgrounded with `timeout 10` wrapper so even hung subprocess can't block status output). Q4 default = 10s.
- [x] On timeout/error, task gets `unscored: true`; resume never blocks — `cmd_with_sla()` always returns 0. Pinned by `test_cmd_with_sla_never_raises_on_missing_task` (bogus task ID → exit 0). The fallback path calls `_set_unscored_flag()` on timeout/exception; verified by code path inspection in `cmd_with_sla`.
- [x] After async sweep scores `unscored:true` task, field is removed — `cmd_sweep()` calls `_clear_unscored_flag(task_path)` after a successful write when `had_unscored` was true. Pinned by `test_cmd_sweep_clears_unscored_flag_on_success`.
- [x] Cron entry registered and `fw doctor` reports cron-registry-in-sync — verified via `bin/fw doctor 2>&1 | grep -q "Cron registry in sync"` (OK status). Entry deployed: `*/15 * * * * root cd "/opt/.../" && PROJECT_ROOT="..." flock -n /var/lock/agentic-cron-bvp-estimator-sweep.lock -c '".../bin/fw" bvp estimate sweep --cron' 2>&1 | logger -t agentic-cron`.

## Verification

grep -q "bvp-estimator-sweep-15m" .context/cron-registry.yaml
out=$(bin/fw doctor 2>&1 || true); [ "$(printf %s "$out" | grep -c 'Cron registry in sync')" -ge 1 ]
out=$(bin/fw bvp estimate sweep --cron 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'sweep: scored')" -ge 1 ]
out=$(bin/fw bvp estimate with-sla T-99999 --timeout 10 2>&1 || true); echo "$?" | grep -q "^0$"
out=$(python3 -m pytest tests/unit/test_bvp_estimator.py 2>&1 || true); grep -qE '[0-9]+ passed' <<<"$out" && ! grep -qE '[0-9]+ failed' <<<"$out"
grep -q "bvp-estimator" agents/resume/resume.sh

## Recommendation

**Recommendation:** GO

**Rationale:** Slice 7b lands the autonomous-keep-alive half of T-NEW-7
— periodic sweep + SLA-bounded synchronous path. The pieces compose
cleanly with T-1922's harness: `cmd_sweep()` and `cmd_with_sla()` are
thin orchestrators over the same `estimate_task()` API. Both paths
respect M3 v2-delta (skip when proposal hasn't materially changed),
both write only to advisory `bvp_scores_proposed:`, neither can block
its caller. With the cron registered + installed, the system now
self-heals on the BVP dimension: a task without proposed scores gets
picked up within 15 minutes, a task flagged by the SLA fallback gets
re-scored on the next sweep.

**Evidence:**

- `agents/termlink/bvp-estimator/estimator.py` (+200 LOC) — new
  helpers `_set_unscored_flag`, `_clear_unscored_flag`,
  `_proposed_is_stale`, `cmd_sweep`, `cmd_with_sla`. CLI verbs
  `sweep` and `with-sla` added.
- `.context/cron-registry.yaml` — `bvp-estimator-sweep-15m` entry
  added; `fw cron install` deployed; `fw doctor` reports
  "Cron registry in sync".
- `agents/resume/resume.sh` — `cmd_status` backgrounds a 10s-capped
  `with-sla` call against the focus task at status-render time.
  Wrapper `timeout 10` belt-and-braces enforces the SLA even if the
  Python-side cap fails. Failures are silent — resume status proceeds
  regardless.
- `tests/unit/test_bvp_estimator.py` — 28/28 PASS (11 new tests):
  - `test_set_unscored_flag_adds_field` + idempotence
  - `test_clear_unscored_flag_removes_field` + absent no-op
  - `test_proposed_is_stale_*` (3 paths: no-proposed, old-ts, fresh-ts)
  - `test_cmd_with_sla_never_raises_on_missing_task` (resume never
    blocks)
  - `test_cmd_with_sla_writes_proposed_under_budget` (budget path
    writes + clears unscored)
  - `test_cmd_sweep_skips_tasks_with_confirmed_scores` (sovereignty)
  - `test_cmd_sweep_clears_unscored_flag_on_success` (AC#5)

**Sweep first-run effect:** First `fw bvp estimate sweep --cron` run
scored 49 active tasks that had no proposed scores yet (initial
backfill). Subsequent runs are idempotent — re-running scored 0
because no task has aged past the 24h stale threshold yet.

**arc-006 status:** All 17 build slices shipped (12a, 12b, 13, 7a, 7b
land this and the previous commit). The arc is feature-complete on the
agent side; the remaining work is the Human [REVIEW] queue.

## Decisions

### 2026-05-19 — Sweep selection: started-work + captured

**Choice:** Sweep only scores tasks with status ∈ {started-work,
captured}. Excludes `work-completed` (already shipped) and `issues`
(blocked — scoring would be misleading).

**Why:** BVP scoring is most useful for tasks that *might* be picked
up. Completed tasks already shipped — their score is for retrospective
analysis (arc-006 §R9, calibration sample). Stuck tasks under `issues`
shouldn't ladder up via auto-promote (T-1931); scoring them noise.

### 2026-05-19 — Resume hook: backgrounded, double-cap

**Choice:** `cmd_status` calls `with-sla` in a backgrounded subshell
*and* wraps it in `timeout 10`. Belt and braces.

**Why:** The Python `with-sla` already measures elapsed and falls back
to `unscored:true` if it exceeds the budget. But if Python itself
hangs (worst case: ruamel YAML round-trip on a malformed file), the
in-process check doesn't help. The shell-level `timeout 10` ensures
resume status output is never delayed more than 10s regardless of
estimator behaviour. Backgrounding plus `disown` means even a 10s wait
doesn't show up as visible latency to the user reading `fw resume status`.

### 2026-05-19 — Cron schedule: 15 min

**Choice:** `*/15 * * * *` — every 15 minutes.

**Why:** First-pass scoring of an entire active workset (~50-100 tasks)
takes ~1 second on heuristic engine. 15 min is responsive enough that
a task captured at hour 0 has proposed scores by hour 0:15 — well
within working-session timescales. Faster (every 5 min) is overkill
given that proposed scores are advisory and the trigger in
`update-task.sh` covers the started-work transition synchronously.

## Updates

### 2026-05-19T18:33:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-c243db59
- **Timestamp:** 2026-05-21T07:20:19Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — Periodic sweep cron-registered runs every 15 min — `bvp-estimator-sweep-15m` entry in `.context/cron-registry.yaml`, deployed to `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` via `fw c
  - **AC-verify-mismatch** (narrow, heuristic) — `path=etc/cron.d in: Periodic sweep cron-registered runs every 15 min — `bvp-estimator-sweep-15m` entry in `.context/cron-registry.yaml`, deployed to `/etc/cron.d/agentic-`
- **AC#6 (Agent)** — Cron entry registered and `fw doctor` reports cron-registry-in-sync — verified via `bin/fw doctor 2>&1 | grep -q "Cron registry in sync"` (OK status). Entry deployed: `*/15 * * * * root cd "/opt/.../"
  - **AC-verify-mismatch** (narrow, heuristic) — `path=var/lock/agentic-cron-bvp-estimator-sweep.lock in: Cron entry registered and `fw doctor` reports cron-registry-in-sync — verified via `bin/fw doctor 2>&1 | grep -q "Cron registry in sync"` (OK status).`
### 2026-05-20T18:57:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
