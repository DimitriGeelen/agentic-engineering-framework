---
id: T-100187
name: "Recommendation-claims validator — extractor + verifier + verdict block (T-100186 GO slice A)"
description: >
  T-100186 GO slice A: lib/reviewer/ module that extracts verifiable evidence
  claims from an inception task's Recommendation/Evidence sections (file path,
  file:line, T-XXX, module.function — reuse ships_in referent grammar T-1984),
  verifies each mechanically read-only, and writes a per-claim
  "## Recommendation Verdict" block (pass/fail/unverifiable per claim + overall
  CONFIRMED/UNVERIFIED/CONTRADICTED) via the reviewer's atomic write path.
  Exposed via fw reviewer T-XXX on inception tasks. Advisory only — no change
  to fw inception decide, no auto-tick.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-100186]
created: 2026-07-05T00:30:00Z
last_update: '2026-07-05T00:30:00Z'
date_finished:
---

# T-100187: Recommendation-claims validator (T-100186 GO slice A)

## Context

T-100186 (GO, decided 2026-07-05 via Watchtower) authorised a reviewer-side validator that mechanically verifies the evidence claims in an inception recommendation before the operator reads it. Research artifact with scope, invariants and reusable machinery: `docs/reports/T-100186-reviewer-assisted-inception-decides.md`. Slice B (Watchtower render) is T-100188.

## Acceptance Criteria

### Agent
- [ ] Claims extractor parses `## Recommendation` + Evidence bullets of an inception task and yields typed claims for: repo file path, file:line, T-XXX task reference, module.function symbol (ships_in grammar reuse)
- [ ] Verifier checks each claim read-only (file exists / line in range / task file present in active|completed / symbol greps in lib|agents|bin) and classifies pass/fail/unverifiable
- [ ] `## Recommendation Verdict` block written atomically (os.replace, same path as Reviewer Verdict), with per-claim table + overall CONFIRMED/UNVERIFIED/CONTRADICTED; re-runs replace the block idempotently
- [ ] Wired into `fw reviewer T-XXX` for workflow_type: inception tasks (flag or auto-run); `completed/` files never mutated
- [ ] bats/pytest coverage: one fixture per claim class (pass + fail), CONTRADICTED overall when any claim fails, idempotent re-run
- [ ] Invariant pinned by test: running the validator never modifies `## Recommendation`, `## Decision`, or any AC checkbox

## Verification

# Slice lands via worktree flow — use origin-based checks per the established pattern.
# Fill concrete commands while building (P-011).

## RCA

<!-- non-bug build slice — leave empty -->

## Decisions

## Updates
