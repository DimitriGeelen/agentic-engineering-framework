---
id: T-1319
name: "Pickup: fw fabric drift and scan miss recursive glob matches — bash ** needs
  shopt -s globstar (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1130. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-18T22:01:09Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-18T22:50:21Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1319: Pickup: fw fabric drift and scan miss recursive glob matches — bash ** needs shopt -s globstar (from termlink)

## Problem Statement

`fw fabric drift` and `fw fabric scan` silently miss files matched by recursive glob patterns (`crates/*/src/**/*.rs`) in `.fabric/watch-patterns.yaml`. Meanwhile `fw audit` flags them via Python's `glob(recursive=True)` — producing a divergence loop where audit warns, the operator runs `fw fabric scan` (as audit suggests), nothing changes, the warning persists.

Root cause: `agents/fabric/lib/drift.sh:26` and `agents/fabric/lib/register.sh:292` both use `for file in $glob_pattern` without enabling `shopt -s globstar`. Bash defaults treat `**` as single-level `*`, so recursive patterns under-match.

Source: termlink T-1130 pickup (P-037).

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated (line numbers verified: drift.sh:26, register.sh:292)
- [x] Assumptions tested (no other glob loops in agents/fabric/lib/ found via grep)
- [x] Recommendation written with rationale (GO — build sibling T-1320)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Concrete divergence between two enforcement paths (audit Python glob vs fabric.sh bash glob). Fix is two-line — add `shopt -s globstar nullglob 2>/dev/null || true` at the top of each affected function. Termlink provided live evidence (14 vs 68 file count). Risk near zero — `globstar` is opt-in per-shell, and `nullglob` only changes behavior for unmatched globs (today the loop body uses `[ -f "$file" ] || continue`, so nullglob is a strict improvement).

**Evidence:**
- Confirmed bug sites: `agents/fabric/lib/drift.sh:26`, `agents/fabric/lib/register.sh:292`
- Live count proof from termlink: `**/*.rs` matches 14 entries without globstar, 68 with
- No conflicting bats tests on these globs today (tests/unit/fabric.bats does not exercise recursive patterns)
- Build sibling T-1320 ships fix + bats regression covering recursive globs

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Concrete divergence between two enforcement paths (audit Python glob vs fabric.sh bash glob). Fix is two-line — add `shopt -s globstar nullglob 2>/dev/null || true` at the top of each affected function. Termlink provided live evidence (14 vs 68 file count). Risk near zero — `globstar` is opt-in per-shell, and `nullglob` only changes behavior for unmatched globs (today the loop body uses `[ -f "$file" ] || continue`, so nullglob is a strict improvement).

Evidence:
- Confirmed bug sites: `agents/fabric/lib/drift.sh:26`, `agents/fabric/lib/register.sh:292`
- Live count proof from termlink: `/.rs` matches 14 entries without globstar, 68 with
- No conflicting bats tests on these globs today (tests/unit/fabric.bats does not exercise recursive patterns)
- Build sibling T-1320 ships fix + bats regression covering recursive globs

**Date**: 2026-04-18T22:50:47Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T22:03:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:50:21Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Concrete divergence between two enforcement paths (audit Python glob vs fabric.sh bash glob). Fix is two-line — add `shopt -s globstar nullglob 2>/dev/null || true` at the top of each affected function. Termlink provided live evidence (14 vs 68 file count). Risk near zero — `globstar` is opt-in per-shell, and `nullglob` only changes behavior for unmatched globs (today the loop body uses `[ -f "$file" ] || continue`, so nullglob is a strict improvement).

Evidence:
- Confirmed bug sites: `agents/fabric/lib/drift.sh:26`, `agents/fabric/lib/register.sh:292`
- Live count proof from termlink: `/.rs` matches 14 entries without globstar, 68 with
- No conflicting bats tests on these globs today (tests/unit/fabric.bats does not exercise recursive patterns)
- Build sibling T-1320 ships fix + bats regression covering recursive globs

### 2026-04-18T22:50:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:50:47Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Concrete divergence between two enforcement paths (audit Python glob vs fabric.sh bash glob). Fix is two-line — add `shopt -s globstar nullglob 2>/dev/null || true` at the top of each affected function. Termlink provided live evidence (14 vs 68 file count). Risk near zero — `globstar` is opt-in per-shell, and `nullglob` only changes behavior for unmatched globs (today the loop body uses `[ -f "$file" ] || continue`, so nullglob is a strict improvement).

Evidence:
- Confirmed bug sites: `agents/fabric/lib/drift.sh:26`, `agents/fabric/lib/register.sh:292`
- Live count proof from termlink: `/.rs` matches 14 entries without globstar, 68 with
- No conflicting bats tests on these globs today (tests/unit/fabric.bats does not exercise recursive patterns)
- Build sibling T-1320 ships fix + bats regression covering recursive globs

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ca61864f
- **Timestamp:** 2026-06-02T14:56:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
