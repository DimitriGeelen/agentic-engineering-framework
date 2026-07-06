---
id: T-100187
name: "Recommendation-claims validator — extractor + verifier + verdict block (T-100186
  GO slice A)"
description: >
  T-100186 GO slice A: lib/reviewer/ module that extracts verifiable evidence
  claims from an inception task's Recommendation/Evidence sections (file path,
  file:line, T-XXX, module.function — reuse ships_in referent grammar T-1984),
  verifies each mechanically read-only, and writes a per-claim
  "## Recommendation Verdict" block (pass/fail/unverifiable per claim + overall
  CONFIRMED/UNVERIFIED/CONTRADICTED) via the reviewer's atomic write path.
  Exposed via fw reviewer T-XXX on inception tasks. Advisory only — no change
  to fw inception decide, no auto-tick.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/reviewer/recommendation_claims.py, lib/reviewer/static_scan.py, tests/unit/test_recommendation_claims.py]
related_tasks: [T-100186]
created: 2026-07-05T00:30:00Z
last_update: 2026-07-06T12:55:41Z
date_finished: 2026-07-06T12:55:41Z
cost_estimate_proposed:
  - ts: '2026-07-04T22:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-04T22:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); audit_severity=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100187: Recommendation-claims validator (T-100186 GO slice A)

## Context

T-100186 (GO, decided 2026-07-05 via Watchtower) authorised a reviewer-side validator that mechanically verifies the evidence claims in an inception recommendation before the operator reads it. Research artifact with scope, invariants and reusable machinery: `docs/reports/T-100186-reviewer-assisted-inception-decides.md`. Slice B (Watchtower render) is T-100188.

## Acceptance Criteria

### Agent
- [x] Claims extractor parses `## Recommendation` + Evidence bullets of an inception task and yields typed claims for: repo file path, file:line, T-XXX task reference, module.function symbol (ships_in grammar reuse)
- [x] Verifier checks each claim read-only (file exists / line in range / task file present in active|completed / symbol greps in lib|agents|bin) and classifies pass/fail/unverifiable
- [x] `## Recommendation Verdict` block written atomically (os.replace, same path as Reviewer Verdict), with per-claim table + overall CONFIRMED/UNVERIFIED/CONTRADICTED; re-runs replace the block idempotently
- [x] Wired into `fw reviewer T-XXX` for workflow_type: inception tasks (flag or auto-run); `completed/` files never mutated
- [x] bats/pytest coverage: one fixture per claim class (pass + fail), CONTRADICTED overall when any claim fails, idempotent re-run
- [x] Invariant pinned by test: running the validator never modifies `## Recommendation`, `## Decision`, or any AC checkbox

## Verification

# Slice landed via worktree flow — origin-based checks (MAIN branch lags origin/master).
git show origin/master:lib/reviewer/recommendation_claims.py > /tmp/.t100187-mod.py && grep -q "CONTRADICTED" /tmp/.t100187-mod.py && grep -q "check_ships_in_reachable" /tmp/.t100187-mod.py
git show origin/master:tests/unit/test_recommendation_claims.py > /tmp/.t100187-test.py && grep -q "test_write_never_touches_recommendation_decision_or_acs" /tmp/.t100187-test.py
git show origin/master:lib/reviewer/static_scan.py > /tmp/.t100187-scan.py && grep -q "recommendation_claims" /tmp/.t100187-scan.py
# Module importable + suite green against the landed tree
rm -rf /tmp/.t100187-tree && git worktree list >/dev/null 2>&1; mkdir -p /tmp/.t100187-tree && git archive origin/master lib tests web policy | tar -x -C /tmp/.t100187-tree && cd /tmp/.t100187-tree && PYTHONPATH=. python3 -m pytest tests/unit/test_recommendation_claims.py -q 2>&1 | grep -q "14 passed"

## RCA

<!-- non-bug build slice — leave empty -->

## Decisions

- **Extraction precision over recall:** path/module claims are extracted from backticked spans only (plus bare T-XXX anywhere); prose tokens like "e.g." can never produce claims. Alternative (scan all prose tokens) rejected — false positives would make CONTRADICTED verdicts noise, killing operator trust in the rail.
- **Auto-run over flag:** the validator fires automatically inside `fw reviewer T-XXX` when `workflow_type: inception` — no new flag to remember; advisory-only exit semantics preserved (Reviewer Verdict FAIL still owns exit 1; standalone CLI `python -m lib.reviewer.recommendation_claims` exits 1 on CONTRADICTED).

## Updates

### 2026-07-04T22:45:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-81ff67b6
- **Timestamp:** 2026-07-06T12:55:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `rm -rf /tmp/.t100187-tree && git worktree list >/dev/null 2>&1; mkdir -p /tmp/.t100187-tree && git archive origin/master lib tests web policy | tar -x -C /tmp/.t100187-tree && cd /tmp/.t100187-tree &&`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-07-06T12:55:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
