---
id: T-1750
name: "G-064 closure-readiness mechanical gauge — substrate-aware check + concerns
  text refresh"
description: >
  G-064's status_notes name route_cache.json as the closure precondition artefact
  — that file doesn't exist on disk; the substrate is .context/dispatches.jsonl. T-1727
  cron fires 5:33 UTC daily; we need a mechanical helper that reads dispatches.jsonl,
  distinguishes natural cron firings (around 5:33 UTC) from the manual T-1727 backfill
  (16:26 UTC), and reports readiness for closure on 2026-05-08. Bundles two deliverables:
  (1) tools/g064-readiness.py mechanical check + (2) refresh G-064 status_notes/recommendation
  to point at dispatches.jsonl. Direct orchestrator-arc work — makes the 2026-05-08
  review a paste-and-decide instead of YAML grep.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [governance, observability]
components: [tests/unit/test_g064_readiness.py, tools/g064-readiness.py]
related_tasks: [T-1687, T-1727, T-1749, T-1688]
arc_id: orchestrator-rethink
created: 2026-05-05T19:15:25Z
last_update: '2026-08-16T22:24:43Z'
date_finished: 2026-05-05T19:21:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1750: G-064 closure-readiness mechanical gauge — substrate-aware check + concerns text refresh

## Context

G-064 (orchestrator substrate has zero production consumers) is `watching` with re-evaluation date 2026-05-08. The closure precondition in `.context/project/concerns.yaml` G-064 status_notes (line 1832-1843) names `route_cache.json` as the substrate file to inspect — that file does NOT exist on this host. The actual substrate is `.context/dispatches.jsonl` + `.context/dispatch-outcomes.jsonl` (consolidated post-T-1687/T-1697; surfaced via `fw orchestrator status --outcomes` from T-1749).

Current state (2026-05-05): 191 escalation-triage dispatches in dispatches.jsonl, all from 2026-05-05 (171 manual T-1727 backfill at 16:26Z, 20 live-validation re-run at 18:xx). Zero natural cron firings yet — cron schedule is 5:33 UTC daily (`.context/cron/agentic-audit.crontab`).

This task ships:
1. `tools/g064-readiness.py` — substrate-aware mechanical gauge that reads dispatches.jsonl, distinguishes cron firings (5:33 UTC ± 5 min) from manual runs, reports READY/NOT_READY against the ≥3 distinct cron-firing dates threshold.
2. Refresh of G-064 status_notes/recommendation in concerns.yaml to point at dispatches.jsonl rather than route_cache.json, and reference the gauge script.

Direct orchestrator-arc work — turns the 2026-05-08 review from "human reads YAML and grep dispatches.jsonl by hand" into "human runs one script, sees verdict, decides."

## Acceptance Criteria

### Agent
- [x] `tools/g064-readiness.py` exists, is executable, and runs without error against the live `.context/dispatches.jsonl`
- [x] Default (no flags) emits a human-readable block including: total dispatches, cron-firing count + dates, manual-run count + dates, verdict (READY or NOT_READY), and the threshold rationale
- [x] `--json` flag emits valid JSON with keys: `workflow`, `total_dispatches`, `cron_firings`, `manual_runs`, `cron_firing_dates`, `manual_run_dates`, `ready`, `verdict`, `closure_threshold_dates`
- [x] `--strict` flag exits 1 when `ready=false`, exits 0 when `ready=true`
- [x] Synthetic dispatches (`task_id` starting with `T-stress-`) are excluded from counts (T-1712 contract)
- [x] Today's run reports NOT_READY (zero cron firings yet) with verdict text naming the next-firing window
- [x] `tests/unit/test_g064_readiness.py` exists with ≥6 cases covering: empty input, manual-only, single cron firing, threshold-met (≥3), synthetic skip, malformed timestamps, JSON shape pinning
- [x] `python3 -m pytest tests/unit/test_g064_readiness.py -q` passes 100%
- [x] `.context/project/concerns.yaml` G-064 entry: status_notes appended with reference to the new gauge script + `dispatches.jsonl` substrate path; recommendation #4 updated to mention the script as the closure-decision input
- [x] YAML still parses cleanly: `python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"` exits 0

### Human

(none — this is a tooling task; closure decision on G-064 itself remains human-owned but is a separate event on 2026-05-08)

## Verification

python3 tools/g064-readiness.py >/dev/null
python3 tools/g064-readiness.py --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'verdict' in d and 'cron_firing_dates' in d, d"
python3 -m pytest tests/unit/test_g064_readiness.py -q
python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"
test -x tools/g064-readiness.py

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

### 2026-05-05 — substrate path mismatch surfaced during gauge design

- **What changed:** G-064's status_notes name `route_cache.json` as the closure-precondition artefact. While building the gauge I checked `find .context -name route_cache*` → no matches. The actual substrate is `.context/dispatches.jsonl` (191 escalation-triage rows from T-1727 backfill). The gap text was written before the post-T-1687/T-1697 substrate consolidation that T-1749 now surfaces via `fw orchestrator status --outcomes`.
- **Plan impact:** Original task scope was "build a small helper for the existing closure-precondition wording." Plan changed to **also** refresh G-064's status_notes/recommendation to point at the real substrate. Without the doc fix, the next agent reading G-064 would still hunt for route_cache.json and bounce off the same dead end I did.
- **Triggered:** Doc fix added inline to this task (concerns.yaml AC + verification command). No new sub-task — the two deliverables are coupled (gauge points at substrate path; substrate path is named in the gap text).

### 2026-05-05 — cron window boundary calibration

- **What changed:** Initial gauge used a hard `5:33 UTC` exact match. Recognised this misses cron jitter — kernel scheduling, system load, NTP drift can push actual firing minutes off the scheduled time by ±2-3 min. Widened to `5:33 ±5 min` window (5:28–5:38 UTC inclusive).
- **Plan impact:** Window logic moved into `_is_cron_firing` helper rather than hardcoded equality. Tests expanded: `test_window_edge_cases` pins both edges (5:28 and 5:38 inside, 5:39 outside).
- **Triggered:** No new task — calibration captured in code + test.

## Decisions

### 2026-05-05 — gauge as standalone script, not fw subcommand

- **Chose:** Standalone `tools/g064-readiness.py` (run via `python3 tools/g064-readiness.py`), not a new `fw orchestrator g064-status` subcommand.
- **Why:** Single-purpose closure helper — only relevant for the 2026-05-08 review and one re-evaluation each ~3 months until G-064 closes. Wiring it into bin/fw means another permanent verb in the CLI catalogue with negligible reuse. Keeping it in `tools/` follows the pattern of `tools/escalation-scan-v0.5.py` (T-1727) and `tools/ollama-tool-loop.py` (T-1691).
- **Rejected:** `fw orchestrator g064-status` — too narrow for a global verb, would clutter `fw orchestrator --help`. `fw orchestrator status --g064` — overloads an already-flag-heavy command (T-1749 added `--outcomes`).

### 2026-05-05 — closure threshold `>= 3 distinct cron-firing dates`

- **Chose:** Mechanical threshold = ≥3 distinct dates with at least one cron-window firing each.
- **Why:** Matches G-064 status_notes wording "≥3 consecutive days" while being more lenient on the "consecutive" part — if cron skips one day (host down, network glitch) but recovers, the gap should still be closeable when 3 distinct dates accumulate. Closure decision still rests with the human; the gauge is advisory, not auto-closing.
- **Rejected:** "3 consecutive calendar days" — too brittle to cron skips. "Day count >= 3" without the cron-window filter — wouldn't distinguish manual --force runs from natural firings, defeating the gap's whole point.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO — close T-1750 as work-completed.

**Rationale:** All 9 Agent ACs satisfied. Gauge runs cleanly against live data (191 manual-only dispatches → NOT_READY, expected). Test suite 13/13 green covering the seven contract points called out in the file's docstring. concerns.yaml refreshed with the real substrate path + script reference; YAML parses. The ship moves the 2026-05-08 G-064 review from "manual JSONL grep" to "paste one command and read the verdict." Direct orchestrator-arc work; no Human ACs (closure decision on G-064 itself remains a separate human-owned event on 2026-05-08).

**Evidence:**
- `python3 tools/g064-readiness.py` → READY/NOT_READY block with 191 manual-only dispatches surfaced; `--json` exposes 13-key stable shape
- `python3 -m pytest tests/unit/test_g064_readiness.py -q` → 13 passed (empty input, manual-only, single cron, 3+ cron threshold, window edges 5:28/5:38, synthetic skip, malformed ts, JSON shape, exit codes)
- `.context/project/concerns.yaml` G-064 status_notes line 1834+ now names dispatches.jsonl + the gauge script; YAML parse passes
- All five `## Verification` gates green pre-completion

## Updates

### 2026-05-05T19:15:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1750-g-064-closure-readiness-mechanical-gauge.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dab67ae8
- **Timestamp:** 2026-06-02T14:59:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `tools/g064-readiness.py` exists, is executable, and runs without error against the live `.context/dispatches.jsonl`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/dispatches.jsonl in: `tools/g064-readiness.py` exists, is executable, and runs without error against the live `.context/dispatches.jsonl``

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 1
     - evidence: `python3 tools/g064-readiness.py >/dev/null`
### 2026-05-05T19:21:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
