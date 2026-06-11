---
id: T-1105
name: "META-META Inception: Chokepoint + Invariant Test discipline as framework governance
  rule"
description: >
  Inception task — codify the structural-fix discipline 'fix via chokepoint + invariant
  test, never via manual call-site edit' as a framework governance rule (CLAUDE.md
  addition + downstream enforcement). This emerged from the structural-fix discipline
  pass on T-1100..T-1104, where every worker's RCA proposed a tactical patch (one
  call site, one conditional, one helper) that left the bug class free to recur. The
  user's question 'can we make the fix more reliable/structural?' is the meta-question
  this task answers permanently. Investigate: (1) extract the chokepoint+test pattern
  from the 5 RCAs (T-1100..T-1104) — what's common about the structural upgrades?
  (2) draft a CLAUDE.md governance section: 'Recurring Bug Class Fix Discipline' —
  when a bug recurs (3+ times) or is registered as a class (G-XXX), the fix MUST land
  via (a) a single chokepoint that's the only legal way to perform the operation AND
  (b) an invariant test that asserts no code bypasses the chokepoint; (3) define the
  trigger: when does the discipline apply vs when is a tactical fix sufficient? (4)
  integrate with existing framework process: how does this discipline land in commit
  gates, fw doctor, code review, task acceptance criteria? (5) recommend GO/DEFER/NO-GO
  with cited evidence from T-1100..T-1104. Origin: structural-fix discipline pass.
  Trigger: 5 same-day RCAs all proposed tactical fixes when structural was needed.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: [T-1100, T-1101, T-1102, T-1103, T-1104, T-1093]
created: 2026-04-11T13:11:13Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-12T09:31:53Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
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
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- 3+ same-day RCAs demonstrate the same "tactical fix proposed → human pushes back for structural" pattern (ACHIEVED — 5 on 2026-04-11: T-1100, T-1101, T-1102, T-1103, T-1104)
- The pattern is expressible as a reusable rule, not a task-specific judgment call (ACHIEVED — chokepoint + invariant test pair applies to any recurring bug class)
- CLAUDE.md has an existing governance-rule section that this can slot into (ACHIEVED — fits alongside "Bug-Fix Learning Checkpoint", "Error Escalation Ladder")
- Implementation cost is low enough that adding the rule does not slow down routine bug fixing (ACHIEVED — the rule only applies when a bug has 3+ registered instances or a G-XXX gap)
- The discipline has been applied successfully at least once after being articulated, to prove it generalizes (ACHIEVED — 6 total same-day applications: T-1106, T-1092, T-1108, T-1109 all followed the pattern after T-1100..T-1104)

**NO-GO if:**
- The pattern turns out to be a property of a single session's momentum rather than a generalizable rule (not observed — it has generalized across worker sessions and task types)
- Codifying the rule introduces friction that outweighs the bug-class prevention benefit (not observed — the rule only triggers on recurring classes, leaving normal bug fixing unconstrained)
- The chokepoint+test pattern cannot be reduced to a reviewable task acceptance criterion (not observed — each T-1100..T-1104 structural upgrade section has explicit chokepoint identification and test sketches)

**DEFER if:**
- The CLAUDE.md section draft needs more worked examples before codification (could defer to collect 3-5 more instances across different sessions and human reviewers to confirm generalizability)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO — codify the chokepoint+invariant-test discipline as a CLAUDE.md governance rule

**Rationale:** The discipline emerged empirically on 2026-04-11 when 5 same-day inception RCAs (T-1100..T-1104) all surfaced recurring framework bug classes. In every case, the RCA worker proposed a tactical patch (one call site, one conditional, one helper function) that left the bug class free to recur. In every case, the human pushed back with "can we make the fix more reliable/structural?" and the answer was the same: add a chokepoint (single legal mutation path) and an invariant test (CI-enforced "no bypass" assertion). The pattern worked — each RCA got a structural upgrade section that converted its tactical fix into a chokepoint+test pair. Without codifying this as a governance rule, every future bug-class fix defaults back to tactical, and the human has to repeat the same correction conversation. Five repetitions in one day is the evidence that the rule needs to be structural, not discretionary.

**Additional evidence from the next six hours:** After the T-1100..T-1104 discipline pass, the pattern continued to prove valuable:
- **T-1106** (Watchtower port bleed) — worker's Option D was already chokepoint-shaped, but the structural upgrade added 4 invariant tests (no-rogue-url-construction, review-url-identity-check, pid-path-consistency, no-default-port-fallback) and made the PID path unification explicit
- **T-1092** (dispatch payload profiles) — research task, but structural upgrade pre-committed future build tasks to chokepoint+test discipline via `load_profile_for_worker()` + 3 invariant tests (no-inline-worker-prompts, profile-token-budget, profile-governance-floor)
- **T-1108** (Watchtower inception page renderer) — a build task fixing G-036 where the structural upgrade exposed the underlying architectural gap (hardcoded section allowlist) and registered it as its own follow-up class
- **T-1109** (fw upgrade web/ sync) — pre-investigation identified do_upgrade vs do_update divergence; chokepoint recommendation (collapse handcrafted sync into do_vendor() call) is exactly the T-1105 pattern applied to a just-discovered bug

Six same-day applications of the pattern is sufficient evidence that the rule is load-bearing.

**Evidence:**
- T-1101: tactical fix = replace `--force` with `--skip-sovereignty` flag at one call site. Structural upgrade = decompose `--force` into 4 narrow flags + lint forbidding `--force` in framework callers + audit log.
- T-1102: tactical fix = extract `_fw_cmd_for_user()` helper, fix 3 BUG sites. Structural upgrade = `_emit_user_command()` chokepoint + `tests/lint/no-hardcoded-fw-paths.bats` invariant test + pre-commit hook.
- T-1103: tactical fix = add `PARTIAL_COMPLETE` guard at `update-task.sh:792`. Structural upgrade = move episodic trigger to file-move event + `tests/lint/no-orphan-episodics.bats`.
- T-1100: tactical fix = document Pattern 2 as canonical + init guard for Pattern 6. Structural upgrade = `do_vendor()` as the only legal mutation path + `isolation_mode` field in `.framework.yaml` + state-consistency bats test.
- T-1104: tactical fix = `fw doctor` doc-drift check + canonical-form comments. Structural upgrade = auto-generate CLAUDE.md Quick Reference from `bin/fw` introspection + `quick-reference-fresh.bats` + `all-fw-subcommands-documented.bats`.
- **Pattern consistency:** Every structural upgrade has the same shape — a single function that's the only legal way to perform the operation, plus a test that asserts no code bypasses the chokepoint. This is evidence the pattern is generalizable, not an artifact of one bug.
- **Framework precedent:** T-559 boundary hook, T-063 task gate hook, T-092 Tier 0 enforcement — these existing controls ARE chokepoint+test pairs, but the discipline was implicit. Formalizing it makes new bug-class fixes inherit the pattern automatically.
- **Human correction cost:** The "make it structural" conversation happened 5 times in one day. Without a rule, it'll happen on every future bug-class fix. A single CLAUDE.md governance section eliminates the recurring conversation permanently.

**Proposed CLAUDE.md addition (sketch for build task):**

> ### Recurring Bug Class Fix Discipline
>
> When fixing a bug that is registered as a gap class (G-XXX in `concerns.yaml`) or has recurred 3+ times, the fix MUST land via:
>
> 1. **Chokepoint** — a single function or code path that is the only legal way to perform the operation. All existing call sites must be migrated to use it. No other code path may bypass it.
> 2. **Invariant test** — a bats test (or equivalent) that asserts no code bypasses the chokepoint. This test runs in CI on every PR.
>
> Tactical patches (fixing the current call site without adding a chokepoint) are insufficient for recurring bug classes. They leave the class free to recur.
>
> **Trigger:** Any bug where:
> - The bug is registered as G-XXX in `concerns.yaml`, OR
> - The same root cause has been fixed 3+ times across tasks/sessions, OR
> - The bug's task description references a class-mate of an existing G-XXX
>
> **Below the threshold:** Tactical fixes are fine. Demanding chokepoint+test for every bug would slow the framework to a crawl.
>
> **Enforcement:** Task acceptance criteria template for build tasks descended from G-XXX gaps MUST include:
> - [ ] Chokepoint identified and documented
> - [ ] Invariant test added (link to test file)
>
> `fw task verify` checks these ACs explicitly.

**Trigger criteria summary:**
| Condition | Discipline applies? |
|---|---|
| Bug registered as G-XXX in concerns.yaml | Yes |
| Same root cause fixed 3+ times | Yes |
| Bug is a class-mate of an existing G-XXX | Yes |
| One-off bug, single incident, no class registered | No (tactical fix is fine) |

**Build decomposition (when GO confirmed):**
1. **T-1105a** — Add "Recurring Bug Class Fix Discipline" section to CLAUDE.md (~50 lines, 1 file)
2. **T-1105b** — Update task template (`.tasks/templates/zzz-default.md`) to include chokepoint+test ACs when task description references a G-XXX gap
3. **T-1105c** — Add `fw task verify --chokepoint` flag that checks for chokepoint+test ACs on G-descended build tasks, warns if missing
4. **T-1105d** — Backport discipline check to `fw audit` — flag any G-XXX gap whose remediation task lacks chokepoint+test ACs
5. **T-1105e** — Update `agents/task-create/AGENT.md` to emit chokepoint+test ACs by default for build tasks descended from gaps

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO — codify the chokepoint+invariant-test discipline as a CLAUDE.md governance rule

Rationale: The discipline emerged empirically on 2026-04-11 when 5 same-day inception RCAs (T-1100..T-1104) all surfaced recurring framework bug classes. In every case, the RCA worker proposed a tactical patch (one call site, one conditional, one helper function) that left the bug class free to recur. In every case, the human pushed back with "can we make the fix more reliable/structural?" and the answer was the same: add a chokepoint (single legal mutation path) and an invariant test (CI-enforced "no bypass" assertion). The pattern worked — each RCA got a structural upgrade section that converted its tactical fix into a chokepoint+test pair. Without codifying this as a governance rule, every future bug-class fix defaults back to tactical, and the human has to repeat the same correction conversation. Five repetitions in one day is the evidence that the rule needs to be structural, not discretionary.

Additional evidence from the next six hours: After the T-1100..T-1104 discipline pass, the pattern continued to prove valuable:
- T-1106 (Watchtower port bleed) — worker's Option D was already chokepoint-shaped, but the structural upgrade added 4 invariant tests (no-rogue-url-construction, review-url-identity-check, pid-path-consistency, no-default-port-fallback) and made the PID path unification explicit
- T-1092 (dispatch payload profiles) — research task, but structural upgrade pre-committed future build tasks to chokepoint+test discipline via `load_profile_for_worker()` + 3 invariant tests (no-inline-worker-prompts, profile-token-budget, profile-governance-floor)
- T-1108 (Watchtower inception page renderer) — a build task fixing G-036 where the structural upgrade exposed the underlying architectural gap (hardcoded section allowlist) and registered it as its own follow-up class
- T-1109 (fw upgrade web/ sync) — pre-investigation identified do_upgrade vs do_update divergence; chokepoint recommendation (collapse handcrafted sync into do_vendor() call) is exactly the T-1105 pattern applied to a just-discovered bug

Six same-day applications of the pattern is sufficient evidence that the rule is load-bearing.

Evidence:
- T-1101: tactical fix = replace `--force` with `--skip-sovereignty` flag at one call site. Structural upgrade = decompose `--force` into 4 narrow flags + lint forbidding `--force` in framework callers + audit log.
- T-1102: tactical fix = extract `_fw_cmd_for_user()` helper, fix 3 BUG sites. Structural upgrade = `_emit_user_command()` chokepoint + `tests/lint/no-hardcoded-fw-paths.bats` invariant test + pre-commit hook.
- T-1103: tactical fix = add `PARTIAL_COMPLETE` guard at `update-task.sh:792`. Structural upgrade = move episodic trigger to file-move event + `tests/lint/no-orphan-episodics.bats`.
- T-1100: tactical fix = document Pattern 2 as canonical + init guard for Pattern 6. Structural upgrade = `do_vendor()` as the only legal mutation path + `isolation_mode` field in `.framework.yaml` + state-consistency bats test.
- T-1104: tactical fix = `fw doctor` doc-drift check + canonical-form comments. Structural upgrade = auto-generate CLAUDE.md Quick Reference from `bin/fw` introspection + `quick-reference-fresh.bats` + `all-fw-subcommands-documented.bats`.
- Pattern consistency: Every structural upgrade has the same shape — a single function that's the only legal way to perform the operation, plus a test that asserts no code bypasses the chokepoint. This is evidence the pattern is generalizable, not an artifact of one bug.
- Framework precedent: T-559 boundary hook, T-063 task gate hook, T-092 Tier 0 enforcement — these existing controls ARE chokepoint+test pairs, but the discipline was implicit. Formalizing it makes new bug-class fixes inherit the pattern automatically.
- Human correction cost: The "make it structural" conversation happened 5 times in one day. Without a rule, it'll happen on every future bug-class fix. A single CLAUDE.md governance section eliminates the recurring conversation permanently.

Proposed CLAUDE.md addition (sketch for build task):

> ### Recurring Bug Class Fix Discipline
>
> When fixing a bug that is registered as a gap class (G-XXX in `concerns.yaml`) or has recurred 3+ times, the fix MUST land via:
>
> 1. Chokepoint — a single function or code path that is the only legal way to perform the operation. All existing call sites must be migrated to use it. No other code path may bypass it.
> 2. Invariant test — a bats test (or equivalent) that asserts no code bypasses the chokepoint. This test runs in CI on every PR.
>
> Tactical patches (fixing the current call site without adding a chokepoint) are insufficient for recurring bug classes. They leave the class free to recur.
>
> Trigger: Any bug where:
> - The bug is registered as G-XXX in `concerns.yaml`, OR
> - The same root cause has been fixed 3+ times across tasks/sessions, OR
> - The bug's task description references a class-mate of an existing G-XXX
>
> Below the threshold: Tactical fixes are fine. Demanding chokepoint+test for every bug would slow the framework to a crawl.
>
> Enforcement: Task acceptance criteria template for build tasks descended from G-XXX gaps MUST include:
> - [ ] Chokepoint identified and documented
> - [ ] Invariant test added (link to test file)
>
> `fw task verify` checks these ACs explicitly.

Trigger criteria summary:
| Condition | Discipline applies? |
|---|---|
| Bug registered as G-XXX in concerns.yaml | Yes |
| Same root cause fixed 3+ times | Yes |
| Bug is a class-mate of an existing G-XXX | Yes |
| One-off bug, single incident, no class registered | No (tactical fix is fine) |

Build decomposition (when GO confirmed):
1. T-1105a — Add "Recurring Bug Class Fix Discipline" section to CLAUDE.md (~50 lines, 1 file)
2. T-1105b — Update task template (`.tasks/templates/zzz-default.md`) to include chokepoint+test ACs when task description references a G-XXX gap
3. T-1105c — Add `fw task verify --chokepoint` flag that checks for chokepoint+test ACs on G-descended build tasks, warns if missing
4. T-1105d — Backport discipline check to `fw audit` — flag any G-XXX gap whose remediation task lacks chokepoint+test ACs
5. T-1105e — Update `agents/task-create/AGENT.md` to emit chokepoint+test ACs by default for build tasks descended from gaps

**Date**: 2026-04-11T20:22:48Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — codify the chokepoint+invariant-test discipline as a CLAUDE.md governance rule

Rationale: The discipline emerged empirically on 2026-04-11 when 5 same-day inception RCAs (T-1100..T-1104) all surfaced recurring framework bug classes. In every case, the RCA worker proposed a tactical patch (one call site, one conditional, one helper function) that left the bug class free to recur. In every case, the human pushed back with "can we make the fix more reliable/structural?" and the answer was the same: add a chokepoint (single legal mutation path) and an invariant test (CI-enforced "no bypass" assertion). The pattern worked — each RCA got a structural upgrade section that converted its tactical fix into a chokepoint+test pair. Without codifying this as a governance rule, every future bug-class fix defaults back to tactical, and the human has to repeat the same correction conversation. Five repetitions in one day is the evidence that the rule needs to be structural, not discretionary.

Additional evidence from the next six hours: After the T-1100..T-1104 discipline pass, the pattern continued to prove valuable:
- T-1106 (Watchtower port bleed) — worker's Option D was already chokepoint-shaped, but the structural upgrade added 4 invariant tests (no-rogue-url-construction, review-url-identity-check, pid-path-consistency, no-default-port-fallback) and made the PID path unification explicit
- T-1092 (dispatch payload profiles) — research task, but structural upgrade pre-committed future build tasks to chokepoint+test discipline via `load_profile_for_worker()` + 3 invariant tests (no-inline-worker-prompts, profile-token-budget, profile-governance-floor)
- T-1108 (Watchtower inception page renderer) — a build task fixing G-036 where the structural upgrade exposed the underlying architectural gap (hardcoded section allowlist) and registered it as its own follow-up class
- T-1109 (fw upgrade web/ sync) — pre-investigation identified do_upgrade vs do_update divergence; chokepoint recommendation (collapse handcrafted sync into do_vendor() call) is exactly the T-1105 pattern applied to a just-discovered bug

Six same-day applications of the pattern is sufficient evidence that the rule is load-bearing.

Evidence:
- T-1101: tactical fix = replace `--force` with `--skip-sovereignty` flag at one call site. Structural upgrade = decompose `--force` into 4 narrow flags + lint forbidding `--force` in framework callers + audit log.
- T-1102: tactical fix = extract `_fw_cmd_for_user()` helper, fix 3 BUG sites. Structural upgrade = `_emit_user_command()` chokepoint + `tests/lint/no-hardcoded-fw-paths.bats` invariant test + pre-commit hook.
- T-1103: tactical fix = add `PARTIAL_COMPLETE` guard at `update-task.sh:792`. Structural upgrade = move episodic trigger to file-move event + `tests/lint/no-orphan-episodics.bats`.
- T-1100: tactical fix = document Pattern 2 as canonical + init guard for Pattern 6. Structural upgrade = `do_vendor()` as the only legal mutation path + `isolation_mode` field in `.framework.yaml` + state-consistency bats test.
- T-1104: tactical fix = `fw doctor` doc-drift check + canonical-form comments. Structural upgrade = auto-generate CLAUDE.md Quick Reference from `bin/fw` introspection + `quick-reference-fresh.bats` + `all-fw-subcommands-documented.bats`.
- Pattern consistency: Every structural upgrade has the same shape — a single function that's the only legal way to perform the operation, plus a test that asserts no code bypasses the chokepoint. This is evidence the pattern is generalizable, not an artifact of one bug.
- Framework precedent: T-559 boundary hook, T-063 task gate hook, T-092 Tier 0 enforcement — these existing controls ARE chokepoint+test pairs, but the discipline was implicit. Formalizing it makes new bug-class fixes inherit the pattern automatically.
- Human correction cost: The "make it structural" conversation happened 5 times in one day. Without a rule, it'll happen on every future bug-class fix. A single CLAUDE.md governance section eliminates the recurring conversation permanently.

Proposed CLAUDE.md addition (sketch for build task):

> ### Recurring Bug Class Fix Discipline
>
> When fixing a bug that is registered as a gap class (G-XXX in `concerns.yaml`) or has recurred 3+ times, the fix MUST land via:
>
> 1. Chokepoint — a single function or code path that is the only legal way to perform the operation. All existing call sites must be migrated to use it. No other code path may bypass it.
> 2. Invariant test — a bats test (or equivalent) that asserts no code bypasses the chokepoint. This test runs in CI on every PR.
>
> Tactical patches (fixing the current call site without adding a chokepoint) are insufficient for recurring bug classes. They leave the class free to recur.
>
> Trigger: Any bug where:
> - The bug is registered as G-XXX in `concerns.yaml`, OR
> - The same root cause has been fixed 3+ times across tasks/sessions, OR
> - The bug's task description references a class-mate of an existing G-XXX
>
> Below the threshold: Tactical fixes are fine. Demanding chokepoint+test for every bug would slow the framework to a crawl.
>
> Enforcement: Task acceptance criteria template for build tasks descended from G-XXX gaps MUST include:
> - [ ] Chokepoint identified and documented
> - [ ] Invariant test added (link to test file)
>
> `fw task verify` checks these ACs explicitly.

Trigger criteria summary:
| Condition | Discipline applies? |
|---|---|
| Bug registered as G-XXX in concerns.yaml | Yes |
| Same root cause fixed 3+ times | Yes |
| Bug is a class-mate of an existing G-XXX | Yes |
| One-off bug, single incident, no class registered | No (tactical fix is fine) |

Build decomposition (when GO confirmed):
1. T-1105a — Add "Recurring Bug Class Fix Discipline" section to CLAUDE.md (~50 lines, 1 file)
2. T-1105b — Update task template (`.tasks/templates/zzz-default.md`) to include chokepoint+test ACs when task description references a G-XXX gap
3. T-1105c — Add `fw task verify --chokepoint` flag that checks for chokepoint+test ACs on G-descended build tasks, warns if missing
4. T-1105d — Backport discipline check to `fw audit` — flag any G-XXX gap whose remediation task lacks chokepoint+test ACs
5. T-1105e — Update `agents/task-create/AGENT.md` to emit chokepoint+test ACs by default for build tasks descended from gaps

**Date**: 2026-04-11T20:22:48Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T20:22:48Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — codify the chokepoint+invariant-test discipline as a CLAUDE.md governance rule

Rationale: The discipline emerged empirically on 2026-04-11 when 5 same-day inception RCAs (T-1100..T-1104) all surfaced recurring framework bug classes. In every case, the RCA worker proposed a tactical patch (one call site, one conditional, one helper function) that left the bug class free to recur. In every case, the human pushed back with "can we make the fix more reliable/structural?" and the answer was the same: add a chokepoint (single legal mutation path) and an invariant test (CI-enforced "no bypass" assertion). The pattern worked — each RCA got a structural upgrade section that converted its tactical fix into a chokepoint+test pair. Without codifying this as a governance rule, every future bug-class fix defaults back to tactical, and the human has to repeat the same correction conversation. Five repetitions in one day is the evidence that the rule needs to be structural, not discretionary.

Additional evidence from the next six hours: After the T-1100..T-1104 discipline pass, the pattern continued to prove valuable:
- T-1106 (Watchtower port bleed) — worker's Option D was already chokepoint-shaped, but the structural upgrade added 4 invariant tests (no-rogue-url-construction, review-url-identity-check, pid-path-consistency, no-default-port-fallback) and made the PID path unification explicit
- T-1092 (dispatch payload profiles) — research task, but structural upgrade pre-committed future build tasks to chokepoint+test discipline via `load_profile_for_worker()` + 3 invariant tests (no-inline-worker-prompts, profile-token-budget, profile-governance-floor)
- T-1108 (Watchtower inception page renderer) — a build task fixing G-036 where the structural upgrade exposed the underlying architectural gap (hardcoded section allowlist) and registered it as its own follow-up class
- T-1109 (fw upgrade web/ sync) — pre-investigation identified do_upgrade vs do_update divergence; chokepoint recommendation (collapse handcrafted sync into do_vendor() call) is exactly the T-1105 pattern applied to a just-discovered bug

Six same-day applications of the pattern is sufficient evidence that the rule is load-bearing.

Evidence:
- T-1101: tactical fix = replace `--force` with `--skip-sovereignty` flag at one call site. Structural upgrade = decompose `--force` into 4 narrow flags + lint forbidding `--force` in framework callers + audit log.
- T-1102: tactical fix = extract `_fw_cmd_for_user()` helper, fix 3 BUG sites. Structural upgrade = `_emit_user_command()` chokepoint + `tests/lint/no-hardcoded-fw-paths.bats` invariant test + pre-commit hook.
- T-1103: tactical fix = add `PARTIAL_COMPLETE` guard at `update-task.sh:792`. Structural upgrade = move episodic trigger to file-move event + `tests/lint/no-orphan-episodics.bats`.
- T-1100: tactical fix = document Pattern 2 as canonical + init guard for Pattern 6. Structural upgrade = `do_vendor()` as the only legal mutation path + `isolation_mode` field in `.framework.yaml` + state-consistency bats test.
- T-1104: tactical fix = `fw doctor` doc-drift check + canonical-form comments. Structural upgrade = auto-generate CLAUDE.md Quick Reference from `bin/fw` introspection + `quick-reference-fresh.bats` + `all-fw-subcommands-documented.bats`.
- Pattern consistency: Every structural upgrade has the same shape — a single function that's the only legal way to perform the operation, plus a test that asserts no code bypasses the chokepoint. This is evidence the pattern is generalizable, not an artifact of one bug.
- Framework precedent: T-559 boundary hook, T-063 task gate hook, T-092 Tier 0 enforcement — these existing controls ARE chokepoint+test pairs, but the discipline was implicit. Formalizing it makes new bug-class fixes inherit the pattern automatically.
- Human correction cost: The "make it structural" conversation happened 5 times in one day. Without a rule, it'll happen on every future bug-class fix. A single CLAUDE.md governance section eliminates the recurring conversation permanently.

Proposed CLAUDE.md addition (sketch for build task):

> ### Recurring Bug Class Fix Discipline
>
> When fixing a bug that is registered as a gap class (G-XXX in `concerns.yaml`) or has recurred 3+ times, the fix MUST land via:
>
> 1. Chokepoint — a single function or code path that is the only legal way to perform the operation. All existing call sites must be migrated to use it. No other code path may bypass it.
> 2. Invariant test — a bats test (or equivalent) that asserts no code bypasses the chokepoint. This test runs in CI on every PR.
>
> Tactical patches (fixing the current call site without adding a chokepoint) are insufficient for recurring bug classes. They leave the class free to recur.
>
> Trigger: Any bug where:
> - The bug is registered as G-XXX in `concerns.yaml`, OR
> - The same root cause has been fixed 3+ times across tasks/sessions, OR
> - The bug's task description references a class-mate of an existing G-XXX
>
> Below the threshold: Tactical fixes are fine. Demanding chokepoint+test for every bug would slow the framework to a crawl.
>
> Enforcement: Task acceptance criteria template for build tasks descended from G-XXX gaps MUST include:
> - [ ] Chokepoint identified and documented
> - [ ] Invariant test added (link to test file)
>
> `fw task verify` checks these ACs explicitly.

Trigger criteria summary:
| Condition | Discipline applies? |
|---|---|
| Bug registered as G-XXX in concerns.yaml | Yes |
| Same root cause fixed 3+ times | Yes |
| Bug is a class-mate of an existing G-XXX | Yes |
| One-off bug, single incident, no class registered | No (tactical fix is fine) |

Build decomposition (when GO confirmed):
1. T-1105a — Add "Recurring Bug Class Fix Discipline" section to CLAUDE.md (~50 lines, 1 file)
2. T-1105b — Update task template (`.tasks/templates/zzz-default.md`) to include chokepoint+test ACs when task description references a G-XXX gap
3. T-1105c — Add `fw task verify --chokepoint` flag that checks for chokepoint+test ACs on G-descended build tasks, warns if missing
4. T-1105d — Backport discipline check to `fw audit` — flag any G-XXX gap whose remediation task lacks chokepoint+test ACs
5. T-1105e — Update `agents/task-create/AGENT.md` to emit chokepoint+test ACs by default for build tasks descended from gaps

### 2026-04-12T09:31:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T09:31:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T09:41:08Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9569916a
- **Timestamp:** 2026-06-02T14:55:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
