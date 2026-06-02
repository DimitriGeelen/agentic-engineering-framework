---
id: T-1484
name: "Reviewer v1.5b — extend fw reviewer audit with --pass-b corpus mode (cron-friendly)"
description: >
  Reviewer v1.5b — extend fw reviewer audit with --pass-b corpus mode (cron-friendly)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [reviewer-agent, drift-detection, worktree, v1.5b, build, audit, cron]
components: [bin/fw, tests/unit/test_reviewer_audit_pass_b.py]
related_tasks: [T-1442, T-1443, T-1483]
created: 2026-04-25T22:31:11Z
last_update: 2026-04-29T08:33:54Z
date_finished: 2026-04-26T07:16:19Z
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
- [x] `lib/reviewer/audit.py` exposes `run_pass_b_reverify(project_root, limit=None, timeout_per_line=30) -> dict`
- [x] `--pass-b` flag in `audit.py main()` selects reverify mode; default behavior unchanged
- [x] `--limit N` caps tasks scanned (cron budget control)
- [x] `--quiet` suppresses per-task output (cron noise control)
- [x] `--timeout N` overrides per-line timeout (default 30s)
- [x] Output YAML written to `.context/audits/reviewer/YYYY-MM-DD-pass-b.yaml` with: scan_date, scan_timestamp, mode=pass-b, tasks_scanned, totals (PASS/FAIL/NO-VERIFICATION/ERROR), per_task list (task_id, sha, overall, n_pass, n_fail, n_skipped, n_error), errors list (verified via test_pass_b_summary_yaml_round_trip)
- [x] Single shared `WorktreePool` reused across all tasks (verified by test_pass_b_reuses_single_worktree — enter_count == 1 across 3 tasks)
- [x] Exit code: 0 if all tasks PASS or NO-VERIFICATION; 1 if any FAIL/ERROR; 3 on catalogue/setup failure
- [x] `bin/fw reviewer audit --help` mentions `--pass-b`, `--limit`, `--quiet`, `--timeout`
- [x] `tests/unit/test_reviewer_audit_pass_b.py` covers: tiny-repo smoke (2 completed tasks, 1 PASS + 1 FAIL → summary correct, exit 1), `--limit` caps tasks, NO-VERIFICATION counted separately, network skip, unknown-SHA error, YAML schema stable, single-pool reuse, no leaked worktree (9 tests)
- [x] All existing reviewer unit tests still pass (145/145 reviewer suite: classifier 25 + drift 17 + reverify 11 + static_scan + overrides + new pass-b 9)
- [x] `bash -n bin/fw` parses cleanly

### Human
- [x] [REVIEW] `fw reviewer audit --pass-b --limit 5 --quiet` is suitable for a daily cron entry (reclassified per T-954 — verified via `bin/fw reviewer audit --pass-b --limit 1 --quiet`: exit 0, YAML schema matches AC#6 exactly (scan_date/timestamp/mode/totals/per_task fields), `git worktree list` shows no leaks after run, /tmp/fw-reviewer-wt-* empty; T-1597 W4 confirm-GO with explicit T-954 classification gripe; user-authorized batch close)
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
# Output YAML pattern produced (AC#6) — at least one .context/audits/reviewer/YYYY-MM-DD-pass-b.yaml exists
test -d .context/audits/reviewer
ls .context/audits/reviewer/*-pass-b.yaml 2>/dev/null | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}-pass-b\.yaml"

## Recommendation

**Recommendation:** GO — Pass B corpus reverify wired into the existing audit cron with opt-in `--pass-b` flag. Default behavior preserved (no surprise to existing cron operators). Worktree-pool reuse from T-1483 means corpus runs are cheap (~3.7s/task on real data, well inside any reasonable cron budget).

**Rationale:** This is the v1.5b deferred-during-T-1483 scope. With this landing, the v1.5 Reviewer drift+reverify story is complete end-to-end: per-task CLIs (`fw reviewer drift|reverify T-XXX`) + corpus cron (`fw reviewer audit --pass-b`). Cron operators who want Pass B can flip the flag; everyone else keeps the v1.0 static-scan re-scan they already had.

**Evidence:**
- 9 new tests in `tests/unit/test_reviewer_audit_pass_b.py` — all green
- Full reviewer regression: 145/145 pass (no regression on v1.0/v1.2/v1.4/v1.5)
- Real-corpus smoke: `--limit 10` scanned newest 10 completed tasks in 37s → 8 PASS / 1 FAIL (T-1480, n_error=1) / 1 NO-VERIFICATION (T-1482 inception). Caught a real signal (T-1480 timeout) on the first run.
- `git worktree list` after run: no leaks
- YAML schema verified by round-trip test
- `bash -n bin/fw` clean

**Out-of-scope (deferred to v1.5c/v1.6+):**
- `fw reviewer audit --pass-a` corpus drift mode (cheap signal pass over all tasks)
- Auto-quarantine of FAIL'd tasks (sovereignty-model dependency)
- Network-stub server for curl-based verifications (current Pass A skipping is acceptable)
- Cron entry registration in `agentic-audit.crontab` (operator-driven; we don't enable cron jobs by default)

## Decisions

### 2026-04-26 — Newest-first numeric task-ID sort
- **Chose:** Sort completed tasks by numeric ID descending so `--limit N` hits recent tasks
- **Why:** Default lexicographic sort puts T-001..T-009 first (pre-Verification-gate era — all NO-VERIFICATION). Cron with `--limit 50` would waste budget on tasks that produce no signal. Numeric-descending hits the work where verification gates exist and drift is most likely.
- **Rejected:** Mtime-based sort (less predictable across re-clones); lexicographic (default — wrong for our task-ID convention).

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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9ba9a034
- **Timestamp:** 2026-06-02T14:57:48Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `ls .context/audits/reviewer/*-pass-b.yaml 2>/dev/null | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}-pass-b\.yaml"`

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#6 (Agent)
### 2026-04-26T07:16:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
