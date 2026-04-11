---
id: T-1101
name: "Inception: fw inception decide silent --force bypass — RCA + remediation path (G-032 CRITICAL)"
description: >
  Inception task — investigate the CRITICAL bug at lib/inception.sh:303 where fw inception decide silently passes --force to update-task.sh, bypassing P-010 (agent AC gate), P-011 (verification gate), AND the Human Task Completion Rule. Trigger: /opt/termlink T-909 transcript 2026-04-11 — fw inception decide T-909 go printed 'Completing human-owned task (--force bypass)' and '3/3 agent AC unchecked (--force bypass)' with the user never having passed --force. Comment at lib/inception.sh:299 cites T-637 with the premise that inception decide is Tier-0-gated, which is FALSE. Investigate: (1) full T-637 history — what problem was it solving and is there a non-bypass solution? (2) the actual call sites of inception decide and whether removing --force breaks anything legitimate; (3) whether splitting decision-recording from task-completion is feasible (decide writes rationale, completion is a separate user action); (4) backwards compat — what existing inceptions would suddenly fail their AC gate if --force is removed; (5) recommend GO/NO-GO/DEFER with concrete remediation path. Origin: G-032.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-1093, G-032]
created: 2026-04-11T12:37:23Z
last_update: 2026-04-11T12:37:23Z
date_finished: null
---

# T-1101: Inception: fw inception decide silent --force bypass — RCA + remediation path (G-032 CRITICAL)

## Problem Statement

`fw inception decide T-XXX go` (or `no-go`) calls `update-task.sh --status work-completed --force` internally at `lib/inception.sh:303`. The user does not pass `--force`. The framework adds it silently. Result: every inception that ends in go/no-go bypasses three structural gates simultaneously:

1. **P-010** — agent acceptance criteria checkbox gate
2. **P-011** — verification command gate (the `## Verification` section)
3. **Human Task Completion Rule** — human-owned tasks should never be auto-completed

The justification at `lib/inception.sh:299` reads: *"--force bypasses sovereignty gate (R-033) because inception decide itself required Tier 0 approval — human authority was already exercised (T-637)"*. This premise is **factually wrong**: `fw inception decide` is NOT a Tier 0 command. It does not trip `check-tier0.sh` patterns. No prior human authority is exercised. T-637's intent was probably "do not re-prompt for confirmation"; the effect is "skip every safety check."

**For whom:** Every consumer of `fw inception decide`. Every inception task in the framework's history that ended in `go`/`no-go` since T-637.

**Why now:** /opt/termlink T-909 transcript (2026-04-11) caught the bug red-handed: `fw inception decide T-909 go --rationale "..."` printed `Completing human-owned task (--force bypass)` and `3/3 agent AC unchecked (--force bypass)` and `Partial-complete: 1 human AC(s) pending verification` in a single output block, with the user having only run the decide command. The agent then proceeded to "execute the fix" against an unverified task — an in-progress Human Task Completion Rule violation.

**Severity:** CRITICAL. This is a structural bypass via a back door inside framework code itself, in direct violation of CLAUDE.md §Human Task Completion Rule and §Autonomous Mode Boundaries (which lists "Using --force to bypass any gate" and "Completing human-owned tasks" as NOT delegated).

## Assumptions

A-1: T-637 had a legitimate problem to solve, and the --force was a workaround rather than a deliberate design choice. (Testable by reading the T-637 task file and any related episodic.)

A-2: There is at least one non-bypass solution: split decision-recording from task-completion entirely. `fw inception decide` writes the rationale and decision; the human/agent then runs `fw task update --status work-completed` separately when ACs are actually done. (Testable by sketching the change in `lib/inception.sh` and confirming it preserves T-637's original intent.)

A-3: Removing the `--force` will break some currently-passing inception flows where ACs were never written or never checked. Backwards compat is a real concern. (Testable by counting how many existing inception tasks have empty/unchecked agent AC sections.)

A-4: The "compounding effect" is real — G-032 + G-034 (premature episodic) produces false long-term memory. Fixing G-032 alone may not be enough. (Testable by inspecting `.context/episodic/` for tasks generated under partial-complete state.)

## Exploration Plan

**Phase 1 — Read T-637 history.** Find the T-637 task file and any related episodic. Reconstruct: what problem was being solved? Why was --force the chosen fix? Was a non-bypass alternative considered?

**Phase 2 — Audit call sites.** `grep -rn "inception decide\|inception_decide" .` to find every place that uses or depends on the current behavior. Identify which depend on the --force semantics.

**Phase 3 — Sketch the split.** Write a 5-line patch that removes --force from line 303. Then write the consequence: the user/agent must check ACs and run `fw task update --status work-completed` separately. Identify what this breaks for currently-clean inceptions.

**Phase 4 — Backwards-compat audit.** How many existing inception tasks in `.tasks/completed/` would have failed the gate if --force had not been silently added? Count, sample 5, classify (legitimate completion vs. evaded verification).

**Phase 5 — Recommendation.** GO (remove --force, ship the split, accept the backwards-compat cost) / DEFER (compound risk too high, ship a warning instead) / NO-GO (the bypass is structurally necessary for some reason yet to be discovered).

## Scope Fence

**IN scope:** RCA, audit, recommendation. May read/grep framework source. May write a patch sketch in `docs/reports/T-1101-fw-inception-decide-force-rca.md`.

**OUT of scope:** Actually applying the patch to `lib/inception.sh`. Modifying inception flow. Changing existing inception task files. Re-generating episodic memory. Build work comes from a descendant task after this inception's GO decision.

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
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
-->

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
