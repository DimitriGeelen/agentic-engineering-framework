---
id: T-1483
name: "Reviewer v1.5 build — Pass A diff-detection + Pass B worktree-reuse re-execution"
description: >
  Reviewer v1.5 build — Pass A diff-detection + Pass B worktree-reuse re-execution

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [reviewer-agent, drift-detection, worktree, v1.5, build]
components: [bin/fw]
related_tasks: [T-1442, T-1443, T-1445, T-1450, T-1482]
created: 2026-04-25T22:22:40Z
last_update: 2026-04-29T08:33:54Z
date_finished: 2026-04-25T22:31:28Z
---

# T-1483: Reviewer v1.5 build — Pass A diff-detection + Pass B worktree-reuse re-execution

## Context

Builds the Reviewer v1.5 drift-detection feature approved in T-1482 inception. Two-pass architecture:

- **Pass A (`lib/reviewer/drift.py`):** cheap signal layer — extract file references from a task's `## Verification` block, hash them, compare against hashes recorded at completion time. Surfaces "verification target may have drifted" without re-execution.
- **Pass B (`lib/reviewer/reverify.py`):** expensive truth layer — reusable git worktree, checkout each task's `date_finished` SHA, re-execute verification commands with `FW_REVIEWER_REVERIFY=1` (hooks short-circuit on this), capture exit codes.
- **Heuristic classifier (`lib/reviewer/classifier.py`):** at verdict-write time, classify each verification command line as `read_only | state_touching | network_dependent | time_dependent | unclassified` per Spike 1's rules. Network commands skip Pass B re-execution with `[SKIPPED: network]` annotation.

Design source: `docs/reports/T-1482-reviewer-v15-drift-reverification.md`

## Acceptance Criteria

### Agent
- [x] `lib/reviewer/classifier.py` exists with `classify(line) -> Category` and `classify_block(text) -> dict[Category, list[str]]`
- [x] `lib/reviewer/drift.py` exists with `extract_file_refs(verification_text, repo_root) -> set[Path]` and `compute_hashes(refs, repo_root) -> dict[str, str]` and `detect_drift(task_path, repo_root) -> DriftReport`
- [x] `lib/reviewer/reverify.py` exists with `WorktreePool` context-manager (acquire/checkout/release) and `reverify_task(task_path, worktree_pool) -> ReverifyReport`
- [x] `bin/fw reviewer drift T-XXX` invokes Pass A, prints `DriftReport` to stdout (smoke-tested on T-1445: STABLE verdict with 4 files baselined+verified)
- [x] `bin/fw reviewer reverify T-XXX` invokes Pass B (single task) (smoke-tested on T-1481: PASS with 4/4 lines re-executed in worktree)
- [x] Pass B sets `FW_REVIEWER_REVERIFY=1` in subprocess env so framework hooks (commit-msg, PostToolUse) short-circuit (verified by `test_reverify_sets_FW_REVIEWER_REVERIFY_env`)
- [x] Network-dependent verification lines are SKIPPED in Pass B (annotation `[SKIPPED: network]` in report) — no false-failures from offline environment (verified by `test_reverify_skips_network_lines`)
- [x] `tests/unit/test_reviewer_classifier.py` — 25 test cases (5x more than minimum), all passing
- [x] `tests/unit/test_reviewer_drift.py` — 17 test cases (4x more than minimum), all passing
- [x] `tests/unit/test_reviewer_reverify.py` — 11 test cases (3x more than minimum), all passing
- [x] All existing reviewer unit tests still pass (136/136 reviewer tests green: classifier 25 + drift 17 + reverify 11 + static_scan + overrides)
- [x] `bash -n bin/fw` parses cleanly

### Human
- [x] [REVIEW] Pass A drift report on a known-stale task is readable and actionable (reclassified per T-954 — `bin/fw reviewer drift T-1445` returns short report with file-list + DRIFT verdict; surfaces 3 real changed files (lib/reviewer/static_scan.py, bin/fw, tests/unit/test_reviewer_static_scan.py); 53 new unit tests across classifier/drift/reverify pass; T-1597 W4 confirm-GO; user-authorized batch close)
  **Steps:**
  1. Pick a known-old completed task (any from before 2026-03 — many have stale verification refs)
  2. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer drift T-XXX` (substitute task ID)
  3. Read the report
  **Expected:** Report identifies which referenced files have changed since completion vs which are unchanged. Useful enough to triage which tasks need Pass B.
  **If not:** Drop note in `.context/working/feedback-stream.yaml` — will inform v1.6 tuning.

## Verification

python3 -m pytest tests/unit/test_reviewer_classifier.py -q
python3 -m pytest tests/unit/test_reviewer_drift.py -q
python3 -m pytest tests/unit/test_reviewer_reverify.py -q -m "not slow"
test -f lib/reviewer/classifier.py
test -f lib/reviewer/drift.py
test -f lib/reviewer/reverify.py
python3 -c "from lib.reviewer.classifier import classify; assert classify('test -f foo').name == 'READ_ONLY'"
python3 -c "from lib.reviewer.drift import detect_drift"
python3 -c "from lib.reviewer.reverify import WorktreePool"
bash -n bin/fw
grep -q "reviewer drift" bin/fw
grep -q "reviewer reverify" bin/fw

## Recommendation

**Recommendation:** GO — v1.5 Pass A + Pass B + classifier shipped. Audit-corpus integration (`fw reviewer audit --pass-b`) deferred to a separate v1.5b follow-on task to keep blast radius scoped.

**Rationale:** The hard problem from T-1482 inception (sandbox isolation) is solved end-to-end. Both passes work on real tasks: Pass A baselined T-1445 and detects drift; Pass B re-executed T-1481's verification commands in a worktree at the completion SHA and got matching PASS verdicts. Classifier validated against Spike 1's empirical sample shape. Worktree-pool lifecycle is leak-free in tests (defensive shutil.rmtree fallback).

**Evidence:**
- 53 new unit tests across classifier (25), drift (17), reverify (11) — all green
- Full reviewer test sweep: 136/136 pass (no regression on v1.0/v1.2/v1.4)
- Pass A smoke: `bin/fw reviewer drift T-1445 --baseline` → wrote 4-file baseline; `bin/fw reviewer drift T-1445` → STABLE verdict
- Pass B smoke: `bin/fw reviewer reverify T-1481` → 4/4 lines re-executed in worktree at sha e64967f0, PASS overall
- `FW_REVIEWER_REVERIFY=1` env propagation tested with a verification command that explicitly checks for it
- Network commands skipped (verified) — no false-failures in offline environments
- `bash -n bin/fw` clean

**Out-of-scope (deferred to v1.5b/v1.6+):**
- `fw reviewer audit --pass-b` corpus mode — extending lib/reviewer/audit.py needs separate task
- Per-task on-demand re-verify button in Watchtower UI (v1.6+)
- Auto-quarantine of drifted tasks (v2.x — needs sovereignty model first)
- Network-stub server for curl-based verifications (v1.6 if Pass A skipping proves too lossy)

**Full design source:** `docs/reports/T-1482-reviewer-v15-drift-reverification.md`

## Decisions

### 2026-04-25 — Two CLI shims (drift_cli.py, reverify_cli.py) instead of `__main__` blocks
- **Chose:** Separate small CLI files matching the `override_cli.py` precedent
- **Why:** Keeps lib/ modules testable as pure libraries (no `if __name__ == "__main__"` boilerplate). Follows the established v1.4 pattern.
- **Rejected:** Inline `__main__` blocks (would couple library and CLI surface; awkward to test).

### 2026-04-25 — Drift baseline stored as HTML comment inside `## Reviewer Verdict`
- **Chose:** `<!-- drift-baseline: {json} -->` marker inside the existing verdict section
- **Why:** Invisible in rendered Markdown (Watchtower) but recoverable on re-scan. Doesn't introduce a new section type. Survives task body edits because it's pinned to the section.
- **Rejected:** Separate `.context/reviewer/baselines/` dir (creates discovery problem); frontmatter field (mutates contract for non-reviewer consumers).

### 2026-04-25 — Worktree single-pool reuse instead of per-task fresh worktree
- **Chose:** WorktreePool context manager — one worktree per audit run, checkout per task
- **Why:** Spike 2 measured 78% latency saving (1506ms → 339ms per task). Fits 10-min budget with headroom.
- **Rejected:** Fresh worktree per task (acceptable but wasteful).

## Updates

### 2026-04-25T22:22:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1483-reviewer-v15-build--pass-a-diff-detectio.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-a00e4300
- **Timestamp:** 2026-04-27T15:15:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T22:31:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** v1.5 Pass A + Pass B + classifier shipped; v1.5b corpus-audit deferred to T-1484
