---
id: T-1484
name: "Reviewer v1.5b — extend fw reviewer audit with --pass-b corpus mode (cron-friendly)"
description: >
  Reviewer v1.5b — extend fw reviewer audit with --pass-b corpus mode (cron-friendly)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [reviewer-agent, drift-detection, worktree, v1.5b, build, audit, cron]
components: [lib/reviewer/audit.py, bin/fw]
related_tasks: [T-1442, T-1443, T-1483]
created: 2026-04-25T22:31:11Z
last_update: 2026-04-26T07:05:00Z
date_finished: null
---

# T-1484: Reviewer v1.5b — extend fw reviewer audit with --pass-b corpus mode (cron-friendly)

## Context

Follow-on to T-1483 (Reviewer v1.5 Pass A drift + Pass B worktree-reuse re-execution). T-1483
shipped per-task CLIs (`fw reviewer drift T-XXX`, `fw reviewer reverify T-XXX`) but explicitly
deferred corpus integration. This task wires the v1.5 Pass B re-verify flow into the existing
Layer-3 audit cron so it can run unattended over every completed task and emit a daily summary.

**Terminology note** — the existing `lib/reviewer/audit.py` header uses "Pass B" to mean the
static-scan re-run over completed tasks (the catalogue layer). In the T-1483/v1.5 frame, "Pass B"
means worktree-reuse re-execution of `## Verification` blocks. To resolve the collision:

- Default `fw reviewer audit` behavior is **unchanged** (still runs the static-scan re-scan). This
  preserves the existing cron contract.
- The new `--pass-b` flag selects **v1.5 Pass B** (worktree re-execution corpus mode). Output goes
  to a separate file: `.context/audits/reviewer/YYYY-MM-DD-pass-b.yaml`.
- Header comment and `--help` text are updated to clarify the two axes.

Single shared `WorktreePool` per audit run (Spike 2: 78% latency saving over fresh-per-task).
Network-dependent verifications skipped per Spike 1 classifier (offline-environment safety).

## Acceptance Criteria

### Agent
- [ ] `lib/reviewer/audit.py` exposes `run_pass_b_reverify(project_root, limit=None, timeout_per_line=30) -> dict`
- [ ] `--pass-b` flag in `audit.py main()` selects reverify mode; default behavior unchanged
- [ ] `--limit N` caps tasks scanned (cron budget control)
- [ ] `--quiet` suppresses per-task output (cron noise control)
- [ ] `--timeout N` overrides per-line timeout (default 30s)
- [ ] Output YAML written to `.context/audits/reviewer/YYYY-MM-DD-pass-b.yaml` with: scan_date, scan_timestamp, mode=pass-b, tasks_scanned, totals (PASS/FAIL/NO-VERIFICATION/ERROR), per_task list (task_id, sha, overall, n_pass, n_fail, n_skipped), errors list
- [ ] Single shared `WorktreePool` reused across all tasks (verified: pool.path stable, single `git worktree add` call)
- [ ] Exit code: 0 if all tasks PASS or NO-VERIFICATION; 1 if any FAIL/ERROR; 3 on catalogue/setup failure
- [ ] `bin/fw reviewer audit --help` mentions `--pass-b`, `--limit`, `--quiet`, `--timeout`
- [ ] `tests/unit/test_reviewer_audit_pass_b.py` covers: tiny-repo smoke (2 completed tasks, 1 PASS + 1 FAIL → summary correct, exit 1), `--limit` caps tasks, NO-VERIFICATION counted separately, YAML schema stable, single-pool reuse
- [ ] All existing reviewer unit tests still pass (no regression)
- [ ] `bash -n bin/fw` parses cleanly

### Human
- [ ] [REVIEW] `fw reviewer audit --pass-b --limit 5 --quiet` is suitable for a daily cron entry
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer audit --pass-b --limit 5 --quiet; echo "exit=$?"`
  2. Inspect: `ls -la .context/audits/reviewer/$(date -u +%Y-%m-%d)-pass-b.yaml`
  3. Read the YAML
  **Expected:** Run finishes within ~3 minutes; YAML contains per_task results with sha, exit_codes; no leaked worktrees in `/tmp/fw-reviewer-wt-*` after the run
  **If not:** Capture the offending task IDs and timeout values; drop a note in `.context/working/feedback-stream.yaml` for v1.5c tuning.

## Verification

python3 -m pytest tests/unit/test_reviewer_audit_pass_b.py -q
python3 -m pytest tests/unit/test_reviewer_classifier.py tests/unit/test_reviewer_drift.py tests/unit/test_reviewer_reverify.py -q -m "not slow"
python3 -c "from lib.reviewer.audit import run_pass_b_reverify"
bash -n bin/fw
grep -q "pass-b" bin/fw

## Decisions

### 2026-04-26 — Separate YAML file (`-pass-b.yaml`) instead of merging into existing audit YAML
- **Chose:** Distinct file per mode
- **Why:** Existing `YYYY-MM-DD.yaml` is the static-scan re-scan summary; merging would mix two
  fundamentally different signals (catalogue compliance vs runtime verification) and break
  downstream consumers (Watchtower /reviewer page already reads the static-scan format).
- **Rejected:** Adding a `pass_b` block to the same file (cleaner UI, but breaks cron-time atomicity
  and adds parse-time risk to the existing pass).

### 2026-04-26 — `--pass-b` as opt-in flag, default unchanged
- **Chose:** Opt-in
- **Why:** v1.5 Pass B is heavier (creates a worktree, runs subprocesses); changing default could
  surprise existing cron users. Opt-in lets cron operators enable it explicitly when ready.
- **Rejected:** Auto-running both passes (fine eventually; not appropriate for first ship).

## Updates

### 2026-04-25T22:31:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1484-reviewer-v15b--extend-fw-reviewer-audit-.md
- **Context:** Initial task creation
