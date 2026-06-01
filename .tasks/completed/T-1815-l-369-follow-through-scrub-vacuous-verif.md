---
id: T-1815
name: "L-369 follow-through: reviewer swallowed-errors detector — exempt canonical && exit 1 || true negative assertion"
description: >
  L-369 named T-1694 and T-341 as real swallowed-errors defects; an across-corpus
  scan found 23 hits total, 14 of which are the canonical negative-assertion pattern
  `grep PATTERN && exit 1 || true` (used to assert *absence*). The current
  static_scan detector flags this as severe — false positives erode reviewer trust.
  Tighten the detector to exempt the negative-assertion pattern while still flagging
  the 9 real vacuous-suffix cases (T-1694, T-341, T-454, T-1356, T-1360, T-415,
  T-1378, T-774, etc.).

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: ["reviewer", "static-scan", "false-positive-precision"]
components: [lib/reviewer/static_scan.py, tools/audit-swallowed-errors.py]
related_tasks: ["T-1812", "T-1809", "T-1443"]
arc_id: dispatch-safety
created: 2026-05-13T19:53:40Z
last_update: 2026-05-13T19:58:53Z
date_finished: 2026-05-13T19:58:53Z
---

# T-1815: L-369 follow-through — reviewer detector exempt for canonical negative-assertion pattern

## Context

T-1812 reviewer-pass on the dispatch-safety arc surfaced one real swallowed-error
defect (T-1809: `bin/fw pause --help 2>&1 | head -3 || true` always passed). L-369
codified the pattern. A subsequent corpus audit (`grep -rn '|| true' .tasks/`)
returned 23 hits across 16 files. 14 of these are the canonical negative-assertion
form `grep PATTERN && exit 1 || true` — "if pattern found, fail; otherwise success".
That form is correct and intentional; flagging it as severe creates noise.

The remaining 9 are real (T-1694, T-341 x2, T-454, T-1356, T-1360, T-415, T-1378,
T-774). These should continue to fire.

Scope: precision-tighten `lib/reviewer/static_scan.py:_SWALLOWED_PATTERNS` so the
canonical negative-assertion form is exempted. Pin with a unit test that proves
both classes (positive: canonical exempt; negative: bare `|| true` still fires).

## Acceptance Criteria

### Agent
- [x] Detector emits zero findings for `grep PATTERN && exit 1 || true` (canonical negative assertion).
- [x] Detector continues to fire for bare `cmd ... || true` (T-1809 pattern).
- [x] Detector continues to fire for `cmd >/dev/null 2>&1 || true` (T-1356 pattern).
- [x] Unit test pins both classes: positive (exempt) and negative (still flagged).
- [x] `python3 -m pytest tests/unit/test_reviewer_static_scan.py -q` passes (78 tests, 6 new).
- [x] Across-corpus run shows finding count drops by ≥12 (canonical FP class eliminated); residual 11 findings cover T-1694, T-341 (x2), T-1356, T-1360, T-1378, T-415, T-454, T-774, plus T-229 (different FP class — `--no-verify` inside JSON string literal piped to a hook; out of scope for this task, candidate for future precision pass).

## Verification

# Shell commands that MUST pass before work-completed.
python3 -m pytest tests/unit/test_reviewer_static_scan.py -q 2>&1 | tail -3 | grep -qE "passed"
python3 -c "from lib.reviewer.static_scan import detect_swallowed_errors; assert detect_swallowed_errors('grep foo && exit 1 || true') == [], 'canonical FP not exempted'; print('FP exempt OK')"
python3 -c "from lib.reviewer.static_scan import detect_swallowed_errors; r=detect_swallowed_errors('bin/fw pause --help 2>&1 | head -3 || true'); assert len(r)==1, f'bare || true not flagged (got {r})'; print('TP still fires OK')"
python3 -c "from lib.reviewer.static_scan import detect_swallowed_errors; r=detect_swallowed_errors('bin/fw doctor >/dev/null 2>&1 || true'); assert len(r)==1, f'redirected || true not flagged (got {r})'; print('redirected TP still fires OK')"
python3 tools/audit-swallowed-errors.py --max 11 --min 9

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

### 2026-05-13 — corpus-residual count: 11, not 9

- **What changed:** Filing assumed 9 real findings would remain after exempting the canonical pattern. Actual residual is 11. The extra 2 come from T-229 — `echo '{"tool_input":{"command":"git commit --no-verify ..."}'  | hook-script` — where `--no-verify` appears inside a JSON literal piped as test input. The `_GREP_LITERAL_RE` only handles grep/awk/sed/jq/rg/ag, not echo/JSON-into-stdin patterns.
- **Plan impact:** AC threshold widened from `== 9` to `>= 9 AND <= 11`. T-229 finding is a different false-positive class (JSON-string-literal containing bypass marker), not in scope for this task — noted as future precision pass candidate.
- **Triggered:** No new task filed (would be a single-incident T-229-class precision pass — not yet a pattern). If a second JSON-literal FP surfaces, file a sibling task.

## Recommendation

- **Recommendation:** GO
- **Rationale:** The canonical `cmd && exit N || true` negative-assertion pattern is now exempted from the reviewer's swallowed-errors detector. 14 corpus false positives eliminated; T-1809-class real defects (`bin/fw pause --help | head -3 || true`) and T-1356-class (`bin/fw doctor >/dev/null 2>&1 || true`) continue to fire. The L-369 audit methodology is now reified as `tools/audit-swallowed-errors.py` with `--min/--max` regression guards (prevents future precision changes from silently breaking either direction). 78 unit tests pass (6 new on the negative-assertion exemption).
- **Evidence:**
  - `lib/reviewer/static_scan.py` line ~273: `_NEGATIVE_ASSERTION_RE` regex + L-369 comment block
  - `lib/reviewer/static_scan.py` line ~298: exemption check in `detect_swallowed_errors` loop
  - `tests/unit/test_reviewer_static_scan.py` lines ~324-365: 6 new tests (3 positive exempt, 3 negative still-fire)
  - `tools/audit-swallowed-errors.py`: corpus audit harness with --min/--max bounds
  - `bin/fw reviewer T-1815` → Overall: PASS, Findings: none (dogfood)
  - Corpus baseline: 11 findings across 9 task files (down from 23 across 16)

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

### 2026-05-13T19:53:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1815-l-369-follow-through-scrub-vacuous-verif.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-81f6cb97
- **Timestamp:** 2026-05-13T19:58:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-13T19:58:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
