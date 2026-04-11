---
id: T-1105
name: "META-META Inception: Chokepoint + Invariant Test discipline as framework governance rule"
description: >
  Inception task — codify the structural-fix discipline 'fix via chokepoint + invariant test, never via manual call-site edit' as a framework governance rule (CLAUDE.md addition + downstream enforcement). This emerged from the structural-fix discipline pass on T-1100..T-1104, where every worker's RCA proposed a tactical patch (one call site, one conditional, one helper) that left the bug class free to recur. The user's question 'can we make the fix more reliable/structural?' is the meta-question this task answers permanently. Investigate: (1) extract the chokepoint+test pattern from the 5 RCAs (T-1100..T-1104) — what's common about the structural upgrades? (2) draft a CLAUDE.md governance section: 'Recurring Bug Class Fix Discipline' — when a bug recurs (3+ times) or is registered as a class (G-XXX), the fix MUST land via (a) a single chokepoint that's the only legal way to perform the operation AND (b) an invariant test that asserts no code bypasses the chokepoint; (3) define the trigger: when does the discipline apply vs when is a tactical fix sufficient? (4) integrate with existing framework process: how does this discipline land in commit gates, fw doctor, code review, task acceptance criteria? (5) recommend GO/DEFER/NO-GO with cited evidence from T-1100..T-1104. Origin: structural-fix discipline pass. Trigger: 5 same-day RCAs all proposed tactical fixes when structural was needed.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-1100, T-1101, T-1102, T-1103, T-1104, T-1093]
created: 2026-04-11T13:11:13Z
last_update: 2026-04-11T13:11:13Z
date_finished: null
---

# T-1105: META-META Inception: Chokepoint + Invariant Test discipline as framework governance rule

## Problem Statement

On 2026-04-11, five inception RCAs (T-1100..T-1104) all surfaced framework bugs. All five workers proposed **tactical** fixes:

| Task | Bug | Worker fix |
|---|---|---|
| T-1101 | `fw inception decide` silent --force bypass | Replace `--force` with `--skip-sovereignty` flag |
| T-1102 | `bin/fw` hardcoded in framework messages | Extract `_fw_cmd_for_user()` helper, replace 3 sites |
| T-1103 | Episodic auto-gen on partial-complete tasks | Add `PARTIAL_COMPLETE` guard at one line |
| T-1100 | Five isolation patterns coexist | Document Pattern 2 canonical, init guard for Pattern 6 |
| T-1104 | CLAUDE.md / fw help / code drift | `fw doctor` doc-drift check + canonical-form comments |

Every fix patches the **current** call site. None prevent the **next** call site from introducing the same bug. The user asked: "can we make the fix more reliable/structural?" — and the answer was the same for all five: **add a chokepoint and an invariant test**.

This is the meta-pattern. Bug-class fixes that don't include a chokepoint+test pair leave the bug class free to recur. The framework already has examples of this discipline (T-559 boundary hook, T-063 task gate hook, T-092 Tier 0 enforcement) but no governance rule that REQUIRES the discipline for new bug-class fixes. Without the rule, agents and humans default to tactical patches, the bug class survives, and the next session re-discovers it.

**For whom:** Every framework contributor (human or agent) writing a fix for a recurring bug class. Every G-XXX gap in `concerns.yaml` whose remediation is being scoped.

**Why now:** Five same-day instances of the tactical-fix default, each one inviting the same "make it structural" intervention from the user. Codifying the rule once eliminates the need to repeat the conversation.

**Severity:** Process gap, not a bug. But it COMPOUNDS every other bug class — every gap in `concerns.yaml` is at risk of being closed with a tactical patch that leaves recurrence open.

## Assumptions

A-1: The chokepoint+test pattern is generalizable across the 5 RCAs — i.e., every structural upgrade in T-1100..T-1104 fits the same template. (Testable by extracting the common shape from the five `## Structural Upgrade` sections.)

A-2: Trigger criteria for "must be structural" can be defined cleanly: (a) bug class registered in `concerns.yaml` as G-XXX, (b) bug recurred 3+ times across tasks/sessions, (c) bug surfaced from a class-mate of an existing G-XXX. Below the threshold, tactical fixes are fine. (Testable by sampling 10 historical bug fixes and classifying each.)

A-3: A CLAUDE.md addition is the right venue — the rule is governance, not code, and it should be visible to every agent at session start. (Alternative: a separate `docs/discipline/chokepoint-test.md` linked from CLAUDE.md.)

A-4: Enforcement mechanism: task acceptance criteria. When a build task descends from a G-XXX gap, its AC list MUST include `[ ] Chokepoint identified and documented` AND `[ ] Invariant test added (link to test file)`. The `fw task verify` flow checks these explicitly. (Testable by sketching the AC template.)

A-5: The discipline does NOT apply to one-off bug fixes (single-incident, no class registered). Demanding chokepoint+test for every bug fix would slow the framework to a crawl. (Testable by reading `## Bug-Fix Learning Checkpoint` rule in CLAUDE.md and confirming it's compatible.)

## Exploration Plan

**Phase 1 — Pattern extraction.** Read the `## Structural Upgrade` section in each of T-1100..T-1104. Distill: what's the chokepoint? what's the test? what's the migration story? Build a template.

**Phase 2 — Historical audit.** Sample 10 closed gaps (G-001..G-024). For each, identify whether the fix was tactical (call-site patch) or structural (chokepoint+test). Count the tactical fixes that have since recurred or expanded.

**Phase 3 — Trigger criteria.** Draft the threshold for when the discipline applies. Test against the 10 sampled gaps: would the rule have caught the recurrences?

**Phase 4 — Governance integration.** Sketch the CLAUDE.md addition (new section: "## Recurring Bug Class Fix Discipline"). Sketch the AC template addition. Sketch the `fw task verify` integration.

**Phase 5 — Recommendation.** GO (codify the discipline + integrate with task verification) / DEFER (the 5 RCAs prove the need, but the governance integration is a bigger lift) / NO-GO (the discipline is wrong abstraction, propose alternative).

## Scope Fence

**IN scope:** Extract the pattern, draft governance text, sketch enforcement integration, recommend GO/DEFER/NO-GO. May read CLAUDE.md, all 5 RCA reports, sampled gap entries. May write findings to `docs/reports/T-1105-chokepoint-test-discipline.md`.

**OUT of scope:** Adding the section to CLAUDE.md (build task downstream). Implementing `fw task verify` integration. Updating any of the 5 child task files beyond the existing `## Structural Upgrade` sections. Build work comes from descendant tasks after GO.

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
