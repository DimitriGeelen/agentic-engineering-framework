# T-1251 — RCA: Bugfix-learning coverage stuck at 0%

**Task:** T-1251
**Type:** Inception (research artifact per C-001)
**Created:** 2026-04-14

## Problem

Audit reports `[FAIL] Bugfix-learning coverage: 0% (1/242)`. T-1178 (inception) and
T-1192 (build, shipped as enhanced bugfix-learning prompt + audit escalation) did not
move the needle. Why?

## Context from prior work

- T-1178: inception — structural bugfix-learning enforcement
- T-1192: build — enhanced bugfix-learning prompt + audit escalation (G-016)
- CLAUDE.md "Bug-Fix Learning Checkpoint": defines *field-discovered* as trigger
- audit.sh:952-990: `fix|bugfix|hotfix|RCA|G-[0-9]` regex against all completed task names

## Spikes

### Spike A — T-1178/T-1192 remediation reconstruction

<!-- Read episodic, check agents/audit/audit.sh and CLAUDE.md for what shipped -->

### Spike B — 10-task sample classification

<!-- Pick 10 recent completed "fix" tasks; check for learning; classify skip reason -->

### Spike C — Bugfix-learning prompt behavior

<!-- Does the prompt fire? What's the typical agent response? -->

### Spike D — False-positive rate

<!-- Of the 242, how many are actually trivial non-bug fixes? -->

## Findings

<!-- Populated as spikes complete. Keep structured so Watchtower can read. -->

## Recommendation

<!-- GO/NO-GO/DEFER with rationale. Finalized at end of exploration. -->

## Dialogue Log

<!-- Human-agent conversation notes. Capture WHY decisions evolved, not just WHAT. -->
