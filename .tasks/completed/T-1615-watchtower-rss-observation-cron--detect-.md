---
id: T-1615
name: "Watchtower RSS observation cron — detect memory growth over uptime (T-1611-B)"
description: >
  Watchtower RSS observation cron — detect memory growth over uptime (T-1611-B)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-30T08:09:11Z
last_update: 2026-04-30T08:11:58Z
date_finished: 2026-04-30T08:11:58Z
---

# T-1615: Watchtower RSS observation cron — detect memory growth over uptime (T-1611-B)

## Context

T-1611 inception DEFER recommendation #2 (T-1611-B): "passive RSS observation cron emitting `ps -o rss <watchtower-pid>` every 5min. After 24-48h of normal use, check for monotonic growth." Distinguishes leak-driven re-saturation from queueing — if T-1612's `threaded=True` fix is sufficient, RSS stays bounded; if a leak hides underneath, RSS climbs and T-1611-C (gunicorn) becomes warranted.

## Acceptance Criteria

### Agent
- [x] `agents/monitor/watchtower-rss-sample.sh` exists, follows liveness-check.sh pattern (set -euo pipefail, PROJECT_ROOT default, mkdir -p)
- [x] Script discovers Watchtower PID via `.context/working/watchtower.pid` (triple-file source-of-truth, T-1376)
- [x] Script appends JSONL line to `.context/monitors/watchtower-rss.jsonl` with: timestamp, pid, etime_sec, rss_kb, vsz_kb, pcpu (or "down" if PID file missing/process dead)
- [x] Script writes latest snapshot to `.context/monitors/watchtower-rss-latest.yaml`
- [x] Script enforces retention: keep last 10080 lines (matches liveness-check.sh — 7 days at 1/min, ~840 days at 1/5min)
- [x] Cron job `watchtower-rss-5m` registered in `.context/cron-registry.yaml`, schedule `*/5 * * * *` (visible in `fw cron list`)
- [x] `bash -n agents/monitor/watchtower-rss-sample.sh` succeeds
- [x] First manual run produced valid JSONL entry: pid=1338191, rss_kb=65216, etime_sec=1554, pcpu=6.3 (current healthy baseline post-T-1612 restart)

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

bash -n agents/monitor/watchtower-rss-sample.sh
agents/monitor/watchtower-rss-sample.sh
test -f .context/monitors/watchtower-rss.jsonl
test -f .context/monitors/watchtower-rss-latest.yaml
grep -q "watchtower-rss-5m" .context/cron-registry.yaml

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

### 2026-04-30T08:09:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1615-watchtower-rss-observation-cron--detect-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e5a5594c
- **Timestamp:** 2026-06-02T14:58:40Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — Script discovers Watchtower PID via `.context/working/watchtower.pid` (triple-file source-of-truth, T-1376)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/working/watchtower.pid in: Script discovers Watchtower PID via `.context/working/watchtower.pid` (triple-file source-of-truth, T-1376)`
### 2026-04-30T08:11:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
