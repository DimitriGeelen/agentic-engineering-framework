---
id: T-1545
name: "Pickup: fw task review exits 1 with empty stdout/stderr when task body lacks
  ## Recommendation section (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-203. Type:
  bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/review.sh]
related_tasks: []
created: 2026-04-27T15:08:01Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T16:39:48Z
source_task_id_in_origin: T-203
source_project_in_origin: "003-NTB-ATC-Plugin"
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 1
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=1 (body:log-or-error-line); 
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1545: Pickup: fw task review exits 1 with empty stdout/stderr when task body lacks ## Recommendation section (from 003-NTB-ATC-Plugin)

## Context

`fw task review T-XXX` exits 1 silently (no stdout, no stderr, no marker file) when an inception task has an empty `## Recommendation` section. Reproduced locally: `WATCHTOWER_URL=http://localhost:3000 PROJECT_ROOT=/tmp/repro bin/fw task review T-9999` → EXIT=1, zero output. Root cause: `lib/review.sh:80-81` uses a `sed|grep -v|grep -v|grep -v|grep -v|head` pipeline. On an empty section every `grep -v` filters every line and exits 1; under `set -e -o pipefail` the regular (non-`local`) assignment then aborts `emit_review` before the WARNING echo can fire and before the review marker is created — so the inception-decide gate also stays locked.

## Acceptance Criteria

### Agent
- [x] `lib/review.sh` no longer uses the fragile pipeline; replaced with `audit_inception_recommendation` (awk-based, pipefail-safe, also handles multi-line HTML-comment placeholders correctly — pickup templates trip the old line-anchored `grep -v '^<!--'` detector).
- [x] Reproducer (`WATCHTOWER_URL=... PROJECT_ROOT=/tmp/T-1545-repro bin/fw task review T-9999`) exits 0, prints WARNING to stderr, prints URL/QR to stdout, creates `.context/working/.reviewed-T-9999`.
- [x] Regression test in `tests/unit/review_pipefail.bats` covers: (a) empty Recommendation → WARNING + exit 0; (b) template-only Recommendation → WARNING + exit 0; (c) substantive Recommendation → no WARNING + exit 0.
- [x] Smoke test: `bin/fw task review T-1538` (substantive Recommendation) and `bin/fw task review T-1544` (template-only) both exit 0; second emits WARNING.

### Human
- [ ] [RUBBER-STAMP] Confirm fix works on a real task
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1545`
  **Expected:** URL, QR, and "Review marker created" all appear; exit 0
  **If not:** Inspect `lib/review.sh` — `audit_inception_recommendation` should be called instead of the old sed/grep pipeline

## Verification

bin/fw task review T-1545 >/dev/null 2>&1
bats tests/unit/review_pipefail.bats

## RCA

**Symptom:** `fw task review` exits 1 with empty stdout/stderr on inception tasks lacking a substantive `## Recommendation` section. Human sees no error, no URL, no QR, and the T-973 review marker is never created — so `fw inception decide` also stays locked. Originally reported on consumer 003-NTB-ATC-Plugin T-203.

**Root cause:** `lib/review.sh:80-81` used `sed -n '/^## Recommendation/,/^## /p' | grep -v '^## ' | grep -v '^<!--' | grep -v '^-->' | grep -v '^$' | head -1`. When the section is empty every `grep -v` filters every line and exits 1. `bin/fw` runs under `set -e -o pipefail`, so the pipeline failure propagated through the regular (non-`local`) variable assignment, aborting `emit_review` before the WARNING echo at line 84 (and before the marker write at line 163).

**Why structurally allowed:** A prior fix in the same file (line 139-140, T-1492) hardened an *adjacent* `grep -m1` extractor against this exact pipefail-trap class — but the line-79 detector predated that fix and was never re-audited even though it has the identical shape. Worse: T-1497 added the awk-based `audit_inception_recommendation` to `lib/task-audit.sh` specifically because line-anchored `grep -v '^<!--'` doesn't recognise multi-line HTML-comment placeholders (template skeletons trip it), but `fw task review` was never retrofitted to call it. So the framework shipped a correct detector and a buggy detector side-by-side, and the buggy one was on the human-visible path.

**Prevention:** (1) Replace fragile pipeline with the awk-based audit helper (this fix). (2) Add regression bats covering empty / template-only / substantive Recommendation cases so any future re-introduction of the pattern fails the suite immediately. (3) Pattern noted: any `grep -v | grep -v | head -1` chain inside `set -e -o pipefail` scope is suspect — should be reviewed across remaining lib/*.sh in a follow-up sweep.

## Recommendation

**Recommendation:** GO

**Rationale:** Bug reproduced from a clean test fixture (`PROJECT_ROOT=/tmp/T-1545-repro` + `WATCHTOWER_URL=…` + empty Recommendation → exit 1, zero output, no marker). Root cause traced to a `sed|grep -v|grep -v|grep -v|grep -v|head` pipeline that exits non-zero when every filter eats every line, which under `set -e -o pipefail` aborts `emit_review` mid-flight. Fix delegates to the existing awk-based `audit_inception_recommendation` helper (added in T-1497, never wired into this path). 4 regression bats added covering empty / template-only / substantive / silent-failure invariants. All 33 review-arc tests green (6 RCA + 4 pipefail + 23 markdown). Smoke tests on real tasks (T-1538 substantive, T-1544 template-only) confirm both behaviors render correctly.

**Evidence:**
- `lib/review.sh:77-101` — old fragile pipeline replaced with `audit_inception_recommendation` call
- `tests/unit/review_pipefail.bats` — 4 new regression cases, 4/4 green
- Smoke: `bin/fw task review T-1538` (substantive) → no warning; `bin/fw task review T-1544` (template-only) → warning + full surface; both exit 0
- Cross-arc check: `tests/unit/rca_gate.bats` 6/6, `tests/unit/test_review_markdown_render.py` 23/23 — no regressions in adjacent T-1550/T-1551/T-1552/T-1553 surfaces
- Pattern noted in RCA → follow-up sweep candidate for `grep -v | grep -v | head -1` chains elsewhere in `lib/*.sh`

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

### 2026-04-27T15:08:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1545-pickup-fw-task-review-exits-1-with-empty.md
- **Context:** Initial task creation

### 2026-04-27T16:29:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a1bd545d
- **Timestamp:** 2026-06-02T14:58:12Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 1
     - evidence: `bin/fw task review T-1545 >/dev/null 2>&1`
### 2026-04-27T16:39:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
