---
id: T-1807
name: "Workflow schema lint — pause_threshold, allow_pause, pause_preamble (dispatch-safety
  slice 3)"
description: >
  Workflow schema lint — pause_threshold, allow_pause, pause_preamble (dispatch-safety
  slice 3)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [slice-3]
components: [bin/fw, lib/workflow_lint.py, 
      tests/unit/test_workflow_schema_pause_lint.py]
related_tasks: [T-1805, T-1806]
arc_id: dispatch-safety
created: 2026-05-13T15:49:53Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-13T16:00:21Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1807: Workflow schema lint — pause_threshold, allow_pause, pause_preamble (dispatch-safety slice 3)

## Context

Slice 3/5 of the dispatch-safety arc. Slice 2 ([T-1806](T-1806)) taught the Resolver to inject the risk-policy preamble when `allow_pause: true` is set on a workflow, with optional `pause_threshold` and `pause_preamble` overrides. The Resolver tolerates anything in those fields — `allow_pause: "yes"` silently fails (string, not bool, so the `is True` check returns False); `pause_threshold: catastrophic` substitutes literally into the preamble without complaint; `pause_preamble: prompts/missing.md` emits a stderr warning at dispatch time but the operator only sees it if they're watching the dispatch live. The workflow linter in `bin/fw doctor` already validates the v1 schema (T-1694) — extending it to lint the three pause fields catches typos at audit time instead of at dispatch time. Cron-driven `fw audit` runs the same linter, so misconfigured workflows surface in Watchtower without a human running `fw doctor` manually.

Builds on [T-1805](T-1805) (substrate recognition) and [T-1806](T-1806) (preamble injection). Unblocks slice 4 (Watchtower `[PAUSE]` surface).

## Acceptance Criteria

### Agent
- [x] `bin/fw doctor` workflow lint validates `allow_pause` — when present, must be a Python boolean (`true` or `false`). String values (`"true"`, `"yes"`) → ERROR with message naming the file and the invalid value.
- [x] `bin/fw doctor` workflow lint validates `pause_threshold` — when present, must be in `{low, medium, high}`. Invalid values → ERROR.
- [x] `bin/fw doctor` workflow lint validates `pause_preamble` — when present, must be a path (string) AND must resolve to an existing file relative to PROJECT_ROOT. Missing file → ERROR (parity with `prompt_template` handling).
- [x] Dead-config detection: if `pause_threshold` or `pause_preamble` is set but `allow_pause` is not `true`, lint emits a WARN (the field is dead — Resolver won't read it). Not an ERROR because the workflow still runs; just unused config.
- [x] Inline workflows (`inline: true`) MUST NOT carry any of the three pause fields — extends the existing INLINE_FORBIDDEN set in the linter. Validates parity with ADR-0003 (inline workflows have no dispatch envelope).
- [x] Unit test (`tests/unit/test_workflow_schema_pause_lint.py`): each rule above has at least one positive case (valid → 0 errors) and one negative case (invalid → ERROR with expected substring). 5 rules × 2 cases = 10+ assertions.
- [x] Unit test: dead-config WARN fires only when `allow_pause` is unset or `false`; when `allow_pause: true`, valid threshold/preamble combos produce 0 warnings.
- [x] Unit test: existing 8 workflow files in `.context/project/workflows/` continue to lint clean — no regression on `cheap-research.yaml`, `default.yaml`, `escalation-triage.yaml`, etc.
- [x] Integration check: `bin/fw doctor 2>&1 | grep -q "Workflow schema"` returns 0 (i.e. the existing schema-check still runs and reports).

### Human
- [ ] [REVIEW] Confirm the WARN-vs-ERROR split is right — typos in threshold/preamble are ERRORs (lint must block), but dead config (set without allow_pause) is a WARN (workflow still functions, just unused field).
  **Steps:**
  1. Read the new lint cases in `bin/fw` around the `INLINE_FORBIDDEN` / `DISPATCH_REQUIRED` block
  2. Consider: would an operator be annoyed by a WARN that fires every time they comment out `allow_pause` for testing?
  3. Consider: would an operator be confused if a typo in `pause_threshold: hi` silently passed?
  **Expected:** The split matches intent — typos block, dead config nudges.
  **If not:** Note which rules feel wrong and the right error level.

## Verification

# Shell commands that MUST pass before work-completed.

python3 -m pytest tests/unit/test_workflow_schema_pause_lint.py -q 2>&1 | tail -5
out=$(bin/fw doctor 2>&1 || true); echo "$out" | grep -q "Workflow schema" || (echo "FAIL: doctor schema check missing"; exit 1)
out=$(bin/fw doctor 2>&1 || true); echo "$out" | grep "Workflow schema:" | grep -qE "lint clean|warning" || (echo "FAIL: existing workflows must remain clean"; exit 1)

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

### 2026-05-13 — extracted lint heredoc into lib/workflow_lint.py
- **What changed:** Originally the slice was "extend the existing python heredoc in `bin/fw doctor` with three new rules." But adding 3 new rule classes (type, value, path) plus dead-config and inline-forbidden cases to an in-shell heredoc would have made the heredoc ~150 lines and untestable without subprocess fixtures. Extracted to `lib/workflow_lint.py` first — pure refactor, then added the new rules on top.
- **Plan impact:** New file in scope (`lib/workflow_lint.py`). Test surface is unit tests against the helper, not subprocess invocations of `fw doctor`. Faster (0.12s for 24 tests).
- **Triggered:** Worker-kinds parity check (T-1735) had to be updated — it was reading the literal from `bin/fw` heredoc, which no longer exists. Now compares two python modules directly, which is the actually-correct shape anyway (the heredoc reference was always a workaround).

### 2026-05-13 — dead-config WARN suppressed when allow_pause has wrong type
- **What changed:** First draft fired both the ERROR (type) and the WARN (dead config) when `allow_pause: "true"` was set with a threshold. The double-fire is noisy — the ERROR already tells the operator the field is broken; the WARN piles on a second, partially-misleading message (the threshold isn't actually dead, the operator probably intended allow_pause to be active). Added `suppress_dead_warn` guard.
- **Plan impact:** None to ACs — added a dedicated test (`test_invalid_allow_pause_suppresses_dead_warn`) to pin the behavior.
- **Triggered:** None.

## Decisions

### 2026-05-13 — extract lint to standalone module, not extend heredoc
- **Chose:** Refactor `bin/fw doctor`'s embedded python heredoc into `lib/workflow_lint.py`. `bin/fw` now invokes it via a one-line subprocess.
- **Why:** Three new rule classes plus inline-forbidden cases would make the heredoc unmaintainable. Standalone module is unit-testable in 0.12s instead of via subprocess fixtures.
- **Rejected:** Inline extension of the heredoc — would have shipped 3 rules untested at the python level (only via end-to-end `fw doctor` runs against the live workflows directory, which can't exercise negative cases).

### 2026-05-13 — dead-config is WARN, typos are ERROR
- **Chose:** Invalid values for `allow_pause`/`pause_threshold`/`pause_preamble` are ERROR (the workflow won't behave as the operator expects). Setting threshold/preamble without `allow_pause: true` is WARN (the workflow still runs, the field is just unused).
- **Why:** Typos are silent failures — `pause_threshold: hi` substitutes literally and the preamble says "your pause_threshold is: hi" which is meaningless. Dead config is intentional during testing (comment out `allow_pause`, leave threshold for later) — should nudge, not block.
- **Rejected:** All four as ERROR (over-blocks operators iterating on configs). All four as WARN (lets silent failures slip through audit).

## Recommendation

**Recommendation:** GO

**Rationale:** Slice 3 closes the audit-time gap on pause-field misconfiguration. Before this change the Resolver tolerated `allow_pause: "true"` (string, silently ignored), `pause_threshold: catastrophic` (literal substitution into the preamble), and `pause_preamble: prompts/nowhere.md` (warning at dispatch-time only). Now `fw doctor` and the cron-driven audit catch all three at workflow-author time. The lint logic moved from `bin/fw` heredoc to `lib/workflow_lint.py` — testable in 0.12s without subprocess fixtures. Backward-compatible: no existing workflow opts in, so nothing changes for current dispatches; the 8 in-repo workflows continue to lint clean.

**Evidence:**
- `lib/workflow_lint.py` (new): `lint_workflows(project_root)` returning `(level, msg)` tuples. Pause-field rules in `_lint_pause_fields`. Worker-kinds set + lint heredoc logic preserved verbatim from `bin/fw`.
- `bin/fw` doctor section now invokes the helper via a one-liner; Worker-kinds parity check updated to compare `workflow_lint.py` ↔ `resolver.py` (both pure python modules, the actually-correct shape).
- 24 new tests in `tests/unit/test_workflow_schema_pause_lint.py`: existing-workflows clean, type rules (bool/string/int), value rules (low/medium/high/invalid), path rules (existing/missing/non-string), dead-config WARN (threshold-only/preamble-with-false/suppression-on-type-error), inline forbids, count/default WARN.
- 104 existing resolver+spawn+outcome tests still pass — no regression.
- `bin/fw doctor` output: `OK  Workflow schema: 8 file(s) lint clean` + `OK  Worker-kinds parity (lib/workflow_lint.py ↔ lib/resolver.py)`.

**Next steps (slice 4):** Watchtower `[PAUSE]` prefix on review queue + "live awaiting resolution" state. When an outcome row has `status: paused`, surface it as a distinct class in `fw review-queue` and the Watchtower review page.

## Updates

### 2026-05-13T15:49:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1807-workflow-schema-lint--pausethreshold-all.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c7eed71d
- **Timestamp:** 2026-06-11T11:49:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_workflow_schema_pause_lint.py -q 2>&1 | tail -5`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 5
     - evidence: `out=$(bin/fw doctor 2>&1 || true); echo "$out" | grep "Workflow schema:" | grep -qE "lint clean|warning" || (echo "FAIL: existing workflows must remain clean"; exit 1)`
### 2026-05-13T16:00:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
