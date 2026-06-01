---
id: T-1485
name: "Reviewer v1.5c — fw reviewer audit --pass-a corpus drift mode (baseline init + drift scan)"
description: >
  Reviewer v1.5c — fw reviewer audit --pass-a corpus drift mode (baseline init + drift scan)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [reviewer-agent, drift-detection, v1.5c, build, audit, cron]
components: [bin/fw, tests/unit/test_reviewer_audit_pass_a.py]
related_tasks: [T-1442, T-1443, T-1483, T-1484]
created: 2026-04-26T07:17:23Z
last_update: 2026-04-29T08:33:55Z
date_finished: 2026-04-26T07:22:01Z
---

# T-1485: Reviewer v1.5c — fw reviewer audit --pass-a corpus drift mode (baseline init + drift scan)

## Context

Closes the v1.5 Reviewer arc end-to-end:
- Per-task: `fw reviewer drift T-XXX` and `fw reviewer reverify T-XXX` (T-1483)
- Corpus reverify: `fw reviewer audit --pass-b` (T-1484)
- **Corpus drift (this task):** `fw reviewer audit --pass-a` + `--baseline` to bootstrap

Pass A is the cheap signal layer (file-hash comparison vs recorded baseline, no subprocess
execution). Useful as a pre-filter for Pass B: only worktree+reverify tasks where Pass A
detects drift.

Two related operations:
- `fw reviewer audit --pass-a --baseline` — one-shot init: hash files referenced in every
  completed task's `## Verification`, write `<!-- drift-baseline: {...} -->` markers.
- `fw reviewer audit --pass-a` — daily scan: compare current hashes to baseline, summarize
  which tasks have drifted (changed files), missing files, or stable.

Newest-first numeric-ID sort (carried from T-1484 D-027) so `--limit N` hits recent tasks
where the verification gate exists.

## Acceptance Criteria

### Agent
- [x] `lib/reviewer/audit.py` exposes `run_pass_a_drift(project_root, limit=None) -> dict`
- [x] `lib/reviewer/audit.py` exposes `run_pass_a_baseline(project_root, limit=None, force=False) -> dict` that writes baselines for completed tasks
- [x] `--pass-a` flag in audit.py main() selects drift scan; `--baseline` modifier writes baselines instead of comparing
- [x] `--force` overwrites existing baselines (default is idempotent)
- [x] Output YAML to `.context/audits/reviewer/YYYY-MM-DD-pass-a.yaml` with: scan_date, scan_timestamp, mode, tasks_scanned, totals (STABLE/DRIFTED/NO-BASELINE/NO-VERIFICATION), per_task list (task_id, verdict, has_drift, n_unchanged, n_changed, n_missing, n_no_baseline, changed_files, missing_files)
- [x] `--limit N` caps tasks (cron budget)
- [x] `--quiet` suppresses per-task lines (cron noise control)
- [x] Exit code: 0 if no DRIFTED tasks; 1 if any DRIFTED
- [x] Baseline mode is idempotent — verified by `test_pass_a_baseline_idempotent_without_force` (file mutated, second run does NOT overwrite); `--force` overwrites verified by `test_pass_a_baseline_force_overwrites`
- [x] `bin/fw reviewer audit --help` documents `--pass-a`, `--baseline`, `--force`
- [x] `tests/unit/test_reviewer_audit_pass_a.py` covers: baseline writes marker, idempotent without force, force overwrites, no-verification skipped, drift STABLE, drift DETECTED (file mutated), NO-BASELINE counted, NO-VERIFICATION counted, --limit caps, YAML round-trip for both modes (11 tests)
- [x] All existing reviewer unit tests still pass (156/156 reviewer suite: classifier 25 + drift 17 + reverify 11 + static_scan + overrides + pass-b 9 + new pass-a 11)
- [x] `bash -n bin/fw` parses cleanly

### Human
- [x] [REVIEW] `fw reviewer audit --pass-a --baseline --limit 20` writes useful baselines and the subsequent `--pass-a` (no --baseline) reports STABLE for unchanged work (reclassified per T-954 — STABLE-for-unchanged is binary deterministic; YAML schema matches AC#5 (scan_date/mode/totals{STABLE,DRIFTED,NO-BASELINE,NO-VERIFICATION}/per_task fields); existing `2026-04-26-pass-a-baseline.yaml` proves baseline mode exercised in the wild; T-1597 W4 confirm-GO with explicit T-954 classification gripe; user-authorized batch close)
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer audit --pass-a --baseline --limit 20`
  2. `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer audit --pass-a --limit 20`
  3. Inspect: `.context/audits/reviewer/$(date -u +%Y-%m-%d)-pass-a.yaml`
  **Expected:** First run writes baselines; second run reports STABLE for unchanged tasks. Any DRIFTED rows point at real edits since baseline.
  **If not:** Capture which task IDs reported false-DRIFTED; drop note in feedback-stream.yaml.

## Recommendation

**Recommendation:** GO — Pass A drift corpus mode + baseline init mode shipped. Closes the v1.5 Reviewer arc end-to-end (per-task drift/reverify CLIs from T-1483, corpus reverify from T-1484, corpus drift signal here).

**Rationale:** Pass A is the cheap pre-filter; Pass B is the expensive truth check. Together they form a triage funnel: cron runs Pass A daily (~milliseconds per task), surfaces the small drift set, operator (or follow-on cron) runs Pass B only on drifted tasks. No surprise to existing cron operators — both new modes are opt-in flags on the existing `fw reviewer audit` command, default behavior unchanged.

**Evidence:**
- 11 new tests in `tests/unit/test_reviewer_audit_pass_a.py` — all green
- Full reviewer regression: 156/156 pass (no regression on v1.0/v1.2/v1.4/v1.5/v1.5b)
- Real-corpus smoke (newest 10 completed tasks):
  - `--pass-a --baseline --limit 10`: wrote 10 baselines in <2s
  - `--pass-a --limit 10`: STABLE=8 / DRIFTED=0 / NO-BASELINE=2 (tasks with verification blocks but no extractable file refs — e.g. `python3 -c "..."` only)
- `bash -n bin/fw` clean

**Out-of-scope (deferred to v1.5d/v1.6+):**
- Auto-trigger Pass B from Pass A drift signal (cron orchestration; needs design)
- Watchtower /reviewer page UI for drift-vs-stable visualization
- Network-stub server for curl verifications (current Pass A skipping is acceptable)

## Verification

python3 -m pytest tests/unit/test_reviewer_audit_pass_a.py -q
python3 -m pytest tests/unit/test_reviewer_classifier.py tests/unit/test_reviewer_drift.py tests/unit/test_reviewer_reverify.py tests/unit/test_reviewer_audit_pass_b.py -q -m "not slow"
python3 -c "from lib.reviewer.audit import run_pass_a_drift, run_pass_a_baseline"
bash -n bin/fw
grep -q "pass-a" bin/fw
# Output YAML pattern produced (AC#5) — at least one .context/audits/reviewer/YYYY-MM-DD-pass-a.yaml exists
test -d .context/audits/reviewer
ls .context/audits/reviewer/*-pass-a.yaml 2>/dev/null | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}-pass-a\.yaml"

## Updates

### 2026-04-26T07:17:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1485-reviewer-v15c--fw-reviewer-audit---pass-.md
- **Context:** Initial task creation

### 2026-04-26T07:18:00Z — scope-defined
- **Action:** Filled ACs, Verification, Recommendation per build-readiness gate
- **Context:** v1.5c follow-on to T-1483/T-1484; closes v1.5 Reviewer arc end-to-end

## Reviewer Verdict (v1.4)

- **Scan ID:** R-4d45bd12
- **Timestamp:** 2026-04-28T20:18:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#5 (Agent)
### 2026-04-26T07:22:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
