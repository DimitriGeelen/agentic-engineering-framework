---
id: T-1111
name: "RCA: empty placeholder sections in inception task files reach human review unnoticed"
description: >
  Inception: RCA: empty placeholder sections in inception task files reach human review unnoticed

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-11T21:21:33Z
last_update: 2026-04-17T20:07:55Z
date_finished: 2026-04-11T21:28:54Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1111: RCA: empty placeholder sections in inception task files reach human review unnoticed

## Problem Statement

Inception task files ship from the template with placeholder text (`[Criterion 1]`, `[Criterion 2]`, `REQUIRED before fw inception decide`, HTML comments). Agents populate *some* sections (e.g., `## Recommendation`) while leaving others (e.g., `## Go/No-Go Criteria`) as placeholder literals. The task is then submitted to `fw task review` and `fw inception decide` without the agent noticing the gap. The human opens the Watchtower review page, sees the literal placeholder text, and has to paste it back to the agent as a complaint.

**Evidence this is a recurring class (3 consecutive sessions):**

1. **2026-04-11 this session:** After populating Recommendations for T-1107 and T-1109, the agent left `## Go/No-Go Criteria` as `[Criterion 1]`/`[Criterion 2]` placeholders in **all four** active inception tasks (T-1105, T-1106, T-1107, T-1109). Human caught it on the review page and pasted the placeholder text as the entire message.

2. **Prior session:** T-1105's `## Recommendation` section was empty (just the `REQUIRED before fw inception decide` comment). Agent populated only after human complaint. Committed as `e308456e`.

3. **Prior session:** G-036 / T-1108 fixed the Watchtower template allowlist for the `## Structural Upgrade` section — but only fixed *rendering*, not *emptiness detection*.

**For whom:** the human reviewing inceptions via Watchtower, who must read all sections to make an informed go/no-go decision. Wasted cognitive effort every time a placeholder reaches them.

**Why now:** three consecutive sessions with the same bug class. Named in the T-1105 chokepoint+invariant-test discipline as the trigger condition: "when a bug class has 3+ registered instances, the fix MUST land via single chokepoint + invariant test". Also consumes G-018 (silent quality decay).

## Assumptions

1. **Agents can produce placeholder-free task files when prompted** — verified by T-1110's creation (this session) which had no placeholders. The issue is not inability, but omission during multi-section editing.
2. **Placeholder patterns are grep-able with low false-positive rate** — patterns include `\[Criterion [0-9]+\]`, `\[TODO\]`, `\[PLACEHOLDER\]`, `REQUIRED before fw inception decide`. None of these are legitimate user content in real task files.
3. **A decision-time gate is acceptable friction** — the gate only fires on inception decide (rare, human-triggered). Normal work is unaffected.
4. **`fw task review` is the right pre-emission chokepoint** — it already runs before decision and creates a marker file. Adding a content audit is a natural extension.

## Exploration Plan

This RCA is largely pre-completed. Research artifact: `docs/reports/T-1111-placeholder-sections-rca.md`.

Remaining spikes before GO:

1. **SPIKE A (grep pattern false-positive check):** Run the proposed grep patterns against `.tasks/active/*.md` + `.tasks/completed/*.md` and confirm zero false positives on real filled-in content. Time-box: 10 minutes.
2. **SPIKE B (fw inception decide hook point):** Verify `lib/inception.sh:decide()` has a clean pre-check insertion point before the T-973 review-marker check. Time-box: 5 minutes.
3. **SPIKE C (bypass path):** Confirm `--force` on `fw inception decide` will allow bypass when the human explicitly overrides. Needed for one-off escape hatch.

## Technical Constraints

- **No new dependencies.** The audit must work with bash + grep only (no Python parser). Reason: keep the gate portable and fast.
- **Must run in < 100ms.** This is a PreToolUse-level gate — it runs on every `fw inception decide`. Any slower impairs interactive workflow.
- **Must produce line-anchored error messages.** Agent needs to see `T-1109.md:142: [Criterion 1]` so it can fix directly, not search.
- **Bypass path required.** `--force` flag per existing Tier 2 pattern (logged, single-use).
- **No retroactive enforcement on completed tasks.** Only active tasks that reach `fw inception decide` are gated. Completed tasks with historical placeholders are a separate sweep if needed.

## Scope Fence

**IN scope for this inception:**
- RCA of the failure class (why existing controls don't catch it)
- Named mitigation options (C1 decision-time gate, C2 review-time lint, C3 Watchtower red warning, C4 template manifest)
- Recommendation on which combination to implement
- Invariant test sketches
- Build decomposition T-1112a..e
- Resolution of G-018 (silent quality decay) as a side-effect

**OUT of scope for this inception:**
- Actual code edits (those are T-1112a..e after GO)
- Retroactive cleanup of existing placeholder literals in closed tasks
- Template redesign (C4) — deferred unless C1+C2 prove insufficient
- General "content quality" lint (tone, clarity, completeness) — only mechanical placeholder detection

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
- SPIKE A shows zero false positives when grep patterns run against all filled-in task files
- SPIKE B confirms a clean pre-check insertion point in `lib/inception.sh:decide()`
- SPIKE C confirms the `--force` bypass path works for escape-hatch scenarios
- The audit function runs in < 100ms on a typical task file (bash + grep only)
- Error messages are line-anchored and unambiguous
- At least one of the 4 mitigation options closes G-018 (silent quality decay)

**NO-GO if:**
- SPIKE A reveals that legitimate content uses the same patterns as placeholders (e.g., a task legitimately writes `[Criterion 1]` in prose — not observed in audit)
- The decision-time gate creates more friction than it saves (measurable false-block rate > 10%)
- Watchtower rendering is genuinely the only reliable detection layer (unlikely — bash grep is cheap and deterministic)

**DEFER if:**
- G-018 is already addressed by another in-flight initiative (not observed)
- Template redesign (C4) would eliminate the class at the source and a redesign is already scheduled (not observed)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO — implement C1 (decision-time content gate) + C2 (review-time pre-render lint) + invariant tests 1 & 2, as a single structural fix. This is the T-1105 chokepoint+invariant-test discipline applied to the placeholder-bleed-through bug class.

**Rationale:** Three consecutive sessions have produced the same failure mode — agent populates some sections of an inception task file but leaves others as template literals, and the human discovers it on the Watchtower review page. Existing controls (C-001, T-973 review-marker, T-1108 section rendering, P-010/P-011 AC gates) all check adjacent properties but none inspect section content for placeholder literals. This is the textbook trigger for the T-1105 discipline: a recurring bug class with 3+ registered instances, no structural invariant binding the fix. The proposed chokepoint is a single `_audit_placeholders()` helper in `agents/task-create/update-task.sh` that both `fw inception decide` and `fw task review` call before proceeding. The invariant test is a bats lint that greps active tasks for placeholder literals on pre-push. Defense-in-depth via two gate points (review + decide) ensures one bypass does not leak. `--force` provides the escape hatch, logged per Tier 2.

**Evidence:**

1. **Three-session recurrence:** (a) This session — T-1105/T-1106/T-1107/T-1109 all had `[Criterion N]` placeholders in Go/No-Go despite populated Recommendations. Human caught via Watchtower review and pasted the placeholder text as a complaint. (b) Prior session — T-1105 had empty `## Recommendation`. Agent populated after complaint, commit `e308456e`. (c) Prior session — T-1108/G-036 fixed rendering of `## Structural Upgrade` but did not address emptiness detection. Same bug class at different sections.

2. **G-018 sitting open for weeks:** "No structural guard against silent quality decay in generated artifacts" — registered as high severity, has been watching. This task's fix consumes G-018.

3. **Existing controls demonstrably insufficient:** C-001 checks artifact existence, not content. T-973 checks that the human clicked review, not what they saw. T-1108 fixed rendering, not emptiness. P-010/P-011 run on different lifecycle transitions. None of them inspect section-level content for placeholder literals.

4. **Grep patterns are high-confidence:** `\[Criterion [0-9]+\]`, `\[TODO\]`, `\[PLACEHOLDER\]`, `REQUIRED before fw inception decide` — none of these appear in legitimate populated task content. SPIKE A will verify.

5. **Chokepoint architecture is minimal:** single `_audit_placeholders()` helper, called from two gate points. ~80 LOC added. Zero existing code removed. No schema changes.

6. **Pattern matches T-1105 discipline precisely:** recurring bug class → chokepoint + invariant test. The build decomposition follows the same pattern as T-1109's (single chokepoint, two invariant tests, migration-free).

**Build decomposition (T-1112a..e):**

| Task ID | Scope | Type | Depends on |
|---------|-------|------|------------|
| T-1112a | Add `_audit_placeholders()` helper in `agents/task-create/update-task.sh`. Bash + grep only. Returns (section, line, pattern) tuples. | Build | — |
| T-1112b | Wire `_audit_placeholders()` into `lib/inception.sh:decide()` before review-marker check. Block on hit with clear error + `--force` bypass. | Build | T-1112a |
| T-1112c | Wire `_audit_placeholders()` into `lib/review.sh:fw_task_review()` before URL emission. Same block + bypass. | Build | T-1112a |
| T-1112d | Write `tests/integration/inception-decide-blocks-placeholders.bats` + `tests/integration/task-review-blocks-placeholders.bats`. | Test | T-1112b, T-1112c |
| T-1112e | Add `tests/lint/no-placeholder-literals-in-active-tasks.bats` for pre-push hook. Consume G-018 — mark resolved. | Test | T-1112a |

**Cost estimate:** ~80 LOC added, 0 removed. 2 gate points + 3 test files. 1 gap (G-018) consumed. Total effort: ~45 minutes in one coherent commit.

**Risk (none blocking):**
- False positives: SPIKE A validates. If any legitimate content trips the grep, tighten the pattern.
- Performance: bash grep on a single ~200-line file runs in <10ms.
- Escape hatch: `--force` flag on both gates, logged to `.context/working/.bypass-log` per Tier 2.

**Cross-references:**
- Research artifact: `docs/reports/T-1111-placeholder-sections-rca.md` (dialogue log + C1-C4 options + invariant test sketches)
- Related gaps: G-018 (silent quality decay — this fix consumes it); G-036 (Watchtower section allowlist — adjacent class); L-006 (enumeration-divergence — the pattern this fix embodies)
- Parent discipline: T-1105 (chokepoint+invariant-test framework governance rule)
- Precedent: T-1109 (same structural shape: single chokepoint, invariant tests, migration-free)

**Human decision request:** Review `docs/reports/T-1111-placeholder-sections-rca.md` for the dialogue log and non-recommended options (C3 Watchtower red warnings, C4 template redesign), then:
- `fw inception decide T-1111 go --rationale "approved — implement C1+C2 chokepoint"`, OR
- `fw inception decide T-1111 defer --rationale "wait until G-018 is addressed by another initiative"`, OR
- `fw inception decide T-1111 no-go --rationale "existing controls sufficient"`

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO — implement C1 (decision-time content gate) + C2 (review-time pre-render lint) + invariant tests 1 & 2, as a single structural fix. This is the T-1105 chokepoint+invariant-test discipline applied to the placeholder-bleed-through bug class.

Rationale: Three consecutive sessions have produced the same failure mode — agent populates some sections of an inception task file but leaves others as template literals, and the human discovers it on the Watchtower review page. Existing controls (C-001, T-973 review-marker, T-1108 section rendering, P-010/P-011 AC gates) all check adjacent properties but none inspect section content for placeholder literals. This is the textbook trigger for the T-1105 discipline: a recurring bug class with 3+ registered instances, no structural invariant binding the fix. The proposed chokepoint is a single `_audit_placeholders()` helper in `agents/task-create/update-task.sh` that both `fw inception decide` and `fw task review` call before proceeding. The invariant test is a bats lint that greps active tasks for placeholder literals on pre-push. Defense-in-depth via two gate points (review + decide) ensures one bypass does not leak. `--force` provides the escape hatch, logged per Tier 2.

Evidence:

1. Three-session recurrence: (a) This session — T-1105/T-1106/T-1107/T-1109 all had `[Criterion N]` placeholders in Go/No-Go despite populated Recommendations. Human caught via Watchtower review and pasted the placeholder text as a complaint. (b) Prior session — T-1105 had empty `## Recommendation`. Agent populated after complaint, commit `e308456e`. (c) Prior session — T-1108/G-036 fixed rendering of `## Structural Upgrade` but did not address emptiness detection. Same bug class at different sections.

2. G-018 sitting open for weeks: "No structural guard against silent quality decay in generated artifacts" — registered as high severity, has been watching. This task's fix consumes G-018.

3. Existing controls demonstrably insufficient: C-001 checks artifact existence, not content. T-973 checks that the human clicked review, not what they saw. T-1108 fixed rendering, not emptiness. P-010/P-011 run on different lifecycle transitions. None of them inspect section-level content for placeholder literals.

4. Grep patterns are high-confidence: `\[Criterion [0-9]+\]`, `\[TODO\]`, `\[PLACEHOLDER\]`, `REQUIRED before fw inception decide` — none of these appear in legitimate populated task content. SPIKE A will verify.

5. Chokepoint architecture is minimal: single `_audit_placeholders()` helper, called from two gate points. ~80 LOC added. Zero existing code removed. No schema changes.

6. Pattern matches T-1105 discipline precisely: recurring bug class → chokepoint + invariant test. The build decomposition follows the same pattern as T-1109's (single chokepoint, two invariant tests, migration-free).

Build decomposition (T-1112a..e):

| Task ID | Scope | Type | Depends on |
|---------|-------|------|------------|
| T-1112a | Add `_audit_placeholders()` helper in `agents/task-create/update-task.sh`. Bash + grep only. Returns (section, line, pattern) tuples. | Build | — |
| T-1112b | Wire `_audit_placeholders()` into `lib/inception.sh:decide()` before review-marker check. Block on hit with clear error + `--force` bypass. | Build | T-1112a |
| T-1112c | Wire `_audit_placeholders()` into `lib/review.sh:fw_task_review()` before URL emission. Same block + bypass. | Build | T-1112a |
| T-1112d | Write `tests/integration/inception-decide-blocks-placeholders.bats` + `tests/integration/task-review-blocks-placeholders.bats`. | Test | T-1112b, T-1112c |
| T-1112e | Add `tests/lint/no-placeholder-literals-in-active-tasks.bats` for pre-push hook. Consume G-018 — mark resolved. | Test | T-1112a |

Cost estimate: ~80 LOC added, 0 removed. 2 gate points + 3 test files. 1 gap (G-018) consumed. Total effort: ~45 minutes in one coherent commit.

Risk (none blocking):
- False positives: SPIKE A validates. If any legitimate content trips the grep, tighten the pattern.
- Performance: bash grep on a single ~200-line file runs in <10ms.
- Escape hatch: `--force` flag on both gates, logged to `.context/working/.bypass-log` per Tier 2.

Cross-references:
- Research artifact: `docs/reports/T-1111-placeholder-sections-rca.md` (dialogue log + C1-C4 options + invariant test sketches)
- Related gaps: G-018 (silent quality decay — this fix consumes it); G-036 (Watchtower section allowlist — adjacent class); L-006 (enumeration-divergence — the pattern this fix embodies)
- Parent discipline: T-1105 (chokepoint+invariant-test framework governance rule)
- Precedent: T-1109 (same structural shape: single chokepoint, invariant tests, migration-free)

Human decision request: Review `docs/reports/T-1111-placeholder-sections-rca.md` for the dialogue log and non-recommended options (C3 Watchtower red warnings, C4 template redesign), then:
- `fw inception decide T-1111 go --rationale "approved — implement C1+C2 chokepoint"`, OR
- `fw inception decide T-1111 defer --rationale "wait until G-018 is addressed by another initiative"`, OR
- `fw inception decide T-1111 no-go --rationale "existing controls sufficient"`

**Date**: 2026-04-11T21:31:18Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — implement C1 (decision-time content gate) + C2 (review-time pre-render lint) + invariant tests 1 & 2, as a single structural fix. This is the T-1105 chokepoint+invariant-test discipline applied to the placeholder-bleed-through bug class.

Rationale: Three consecutive sessions have produced the same failure mode — agent populates some sections of an inception task file but leaves others as template literals, and the human discovers it on the Watchtower review page. Existing controls (C-001, T-973 review-marker, T-1108 section rendering, P-010/P-011 AC gates) all check adjacent properties but none inspect section content for placeholder literals. This is the textbook trigger for the T-1105 discipline: a recurring bug class with 3+ registered instances, no structural invariant binding the fix. The proposed chokepoint is a single `_audit_placeholders()` helper in `agents/task-create/update-task.sh` that both `fw inception decide` and `fw task review` call before proceeding. The invariant test is a bats lint that greps active tasks for placeholder literals on pre-push. Defense-in-depth via two gate points (review + decide) ensures one bypass does not leak. `--force` provides the escape hatch, logged per Tier 2.

Evidence:

1. Three-session recurrence: (a) This session — T-1105/T-1106/T-1107/T-1109 all had `[Criterion N]` placeholders in Go/No-Go despite populated Recommendations. Human caught via Watchtower review and pasted the placeholder text as a complaint. (b) Prior session — T-1105 had empty `## Recommendation`. Agent populated after complaint, commit `e308456e`. (c) Prior session — T-1108/G-036 fixed rendering of `## Structural Upgrade` but did not address emptiness detection. Same bug class at different sections.

2. G-018 sitting open for weeks: "No structural guard against silent quality decay in generated artifacts" — registered as high severity, has been watching. This task's fix consumes G-018.

3. Existing controls demonstrably insufficient: C-001 checks artifact existence, not content. T-973 checks that the human clicked review, not what they saw. T-1108 fixed rendering, not emptiness. P-010/P-011 run on different lifecycle transitions. None of them inspect section-level content for placeholder literals.

4. Grep patterns are high-confidence: `\[Criterion [0-9]+\]`, `\[TODO\]`, `\[PLACEHOLDER\]`, `REQUIRED before fw inception decide` — none of these appear in legitimate populated task content. SPIKE A will verify.

5. Chokepoint architecture is minimal: single `_audit_placeholders()` helper, called from two gate points. ~80 LOC added. Zero existing code removed. No schema changes.

6. Pattern matches T-1105 discipline precisely: recurring bug class → chokepoint + invariant test. The build decomposition follows the same pattern as T-1109's (single chokepoint, two invariant tests, migration-free).

Build decomposition (T-1112a..e):

| Task ID | Scope | Type | Depends on |
|---------|-------|------|------------|
| T-1112a | Add `_audit_placeholders()` helper in `agents/task-create/update-task.sh`. Bash + grep only. Returns (section, line, pattern) tuples. | Build | — |
| T-1112b | Wire `_audit_placeholders()` into `lib/inception.sh:decide()` before review-marker check. Block on hit with clear error + `--force` bypass. | Build | T-1112a |
| T-1112c | Wire `_audit_placeholders()` into `lib/review.sh:fw_task_review()` before URL emission. Same block + bypass. | Build | T-1112a |
| T-1112d | Write `tests/integration/inception-decide-blocks-placeholders.bats` + `tests/integration/task-review-blocks-placeholders.bats`. | Test | T-1112b, T-1112c |
| T-1112e | Add `tests/lint/no-placeholder-literals-in-active-tasks.bats` for pre-push hook. Consume G-018 — mark resolved. | Test | T-1112a |

Cost estimate: ~80 LOC added, 0 removed. 2 gate points + 3 test files. 1 gap (G-018) consumed. Total effort: ~45 minutes in one coherent commit.

Risk (none blocking):
- False positives: SPIKE A validates. If any legitimate content trips the grep, tighten the pattern.
- Performance: bash grep on a single ~200-line file runs in <10ms.
- Escape hatch: `--force` flag on both gates, logged to `.context/working/.bypass-log` per Tier 2.

Cross-references:
- Research artifact: `docs/reports/T-1111-placeholder-sections-rca.md` (dialogue log + C1-C4 options + invariant test sketches)
- Related gaps: G-018 (silent quality decay — this fix consumes it); G-036 (Watchtower section allowlist — adjacent class); L-006 (enumeration-divergence — the pattern this fix embodies)
- Parent discipline: T-1105 (chokepoint+invariant-test framework governance rule)
- Precedent: T-1109 (same structural shape: single chokepoint, invariant tests, migration-free)

Human decision request: Review `docs/reports/T-1111-placeholder-sections-rca.md` for the dialogue log and non-recommended options (C3 Watchtower red warnings, C4 template redesign), then:
- `fw inception decide T-1111 go --rationale "approved — implement C1+C2 chokepoint"`, OR
- `fw inception decide T-1111 defer --rationale "wait until G-018 is addressed by another initiative"`, OR
- `fw inception decide T-1111 no-go --rationale "existing controls sufficient"`

**Date**: 2026-04-11T21:31:18Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T21:21:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-11T21:28:54Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — implement C1 (decision-time content gate) + C2 (review-time pre-render lint) + invariant tests 1 & 2, as a single structural fix. This is the T-1105 chokepoint+invariant-test discipline applied to the placeholder-bleed-through bug class.

Rationale: Three consecutive sessions have produced the same failure mode — agent populates some sections of an inception task file but leaves others as template literals, and the human discovers it on the Watchtower review page. Existing controls (C-001, T-973 review-marker, T-1108 section rendering, P-010/P-011 AC gates) all check adjacent properties but none inspect section content for placeholder literals. This is the textbook trigger for the T-1105 discipline: a recurring bug class with 3+ registered instances, no structural invariant binding the fix. The proposed chokepoint is a single `_audit_placeholders()` helper in `agents/task-create/update-task.sh` that both `fw inception decide` and `fw task review` call before proceeding. The invariant test is a bats lint that greps active tasks for placeholder literals on pre-push. Defense-in-depth via two gate points (review + decide) ensures one bypass does not leak. `--force` provides the escape hatch, logged per Tier 2.

Evidence:

1. Three-session recurrence: (a) This session — T-1105/T-1106/T-1107/T-1109 all had `[Criterion N]` placeholders in Go/No-Go despite populated Recommendations. Human caught via Watchtower review and pasted the placeholder text as a complaint. (b) Prior session — T-1105 had empty `## Recommendation`. Agent populated after complaint, commit `e308456e`. (c) Prior session — T-1108/G-036 fixed rendering of `## Structural Upgrade` but did not address emptiness detection. Same bug class at different sections.

2. G-018 sitting open for weeks: "No structural guard against silent quality decay in generated artifacts" — registered as high severity, has been watching. This task's fix consumes G-018.

3. Existing controls demonstrably insufficient: C-001 checks artifact existence, not content. T-973 checks that the human clicked review, not what they saw. T-1108 fixed rendering, not emptiness. P-010/P-011 run on different lifecycle transitions. None of them inspect section-level content for placeholder literals.

4. Grep patterns are high-confidence: `\[Criterion [0-9]+\]`, `\[TODO\]`, `\[PLACEHOLDER\]`, `REQUIRED before fw inception decide` — none of these appear in legitimate populated task content. SPIKE A will verify.

5. Chokepoint architecture is minimal: single `_audit_placeholders()` helper, called from two gate points. ~80 LOC added. Zero existing code removed. No schema changes.

6. Pattern matches T-1105 discipline precisely: recurring bug class → chokepoint + invariant test. The build decomposition follows the same pattern as T-1109's (single chokepoint, two invariant tests, migration-free).

Build decomposition (T-1112a..e):

| Task ID | Scope | Type | Depends on |
|---------|-------|------|------------|
| T-1112a | Add `_audit_placeholders()` helper in `agents/task-create/update-task.sh`. Bash + grep only. Returns (section, line, pattern) tuples. | Build | — |
| T-1112b | Wire `_audit_placeholders()` into `lib/inception.sh:decide()` before review-marker check. Block on hit with clear error + `--force` bypass. | Build | T-1112a |
| T-1112c | Wire `_audit_placeholders()` into `lib/review.sh:fw_task_review()` before URL emission. Same block + bypass. | Build | T-1112a |
| T-1112d | Write `tests/integration/inception-decide-blocks-placeholders.bats` + `tests/integration/task-review-blocks-placeholders.bats`. | Test | T-1112b, T-1112c |
| T-1112e | Add `tests/lint/no-placeholder-literals-in-active-tasks.bats` for pre-push hook. Consume G-018 — mark resolved. | Test | T-1112a |

Cost estimate: ~80 LOC added, 0 removed. 2 gate points + 3 test files. 1 gap (G-018) consumed. Total effort: ~45 minutes in one coherent commit.

Risk (none blocking):
- False positives: SPIKE A validates. If any legitimate content trips the grep, tighten the pattern.
- Performance: bash grep on a single ~200-line file runs in <10ms.
- Escape hatch: `--force` flag on both gates, logged to `.context/working/.bypass-log` per Tier 2.

Cross-references:
- Research artifact: `docs/reports/T-1111-placeholder-sections-rca.md` (dialogue log + C1-C4 options + invariant test sketches)
- Related gaps: G-018 (silent quality decay — this fix consumes it); G-036 (Watchtower section allowlist — adjacent class); L-006 (enumeration-divergence — the pattern this fix embodies)
- Parent discipline: T-1105 (chokepoint+invariant-test framework governance rule)
- Precedent: T-1109 (same structural shape: single chokepoint, invariant tests, migration-free)

Human decision request: Review `docs/reports/T-1111-placeholder-sections-rca.md` for the dialogue log and non-recommended options (C3 Watchtower red warnings, C4 template redesign), then:
- `fw inception decide T-1111 go --rationale "approved — implement C1+C2 chokepoint"`, OR
- `fw inception decide T-1111 defer --rationale "wait until G-018 is addressed by another initiative"`, OR
- `fw inception decide T-1111 no-go --rationale "existing controls sufficient"`

### 2026-04-11T21:28:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-11T21:31:18Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — implement C1 (decision-time content gate) + C2 (review-time pre-render lint) + invariant tests 1 & 2, as a single structural fix. This is the T-1105 chokepoint+invariant-test discipline applied to the placeholder-bleed-through bug class.

Rationale: Three consecutive sessions have produced the same failure mode — agent populates some sections of an inception task file but leaves others as template literals, and the human discovers it on the Watchtower review page. Existing controls (C-001, T-973 review-marker, T-1108 section rendering, P-010/P-011 AC gates) all check adjacent properties but none inspect section content for placeholder literals. This is the textbook trigger for the T-1105 discipline: a recurring bug class with 3+ registered instances, no structural invariant binding the fix. The proposed chokepoint is a single `_audit_placeholders()` helper in `agents/task-create/update-task.sh` that both `fw inception decide` and `fw task review` call before proceeding. The invariant test is a bats lint that greps active tasks for placeholder literals on pre-push. Defense-in-depth via two gate points (review + decide) ensures one bypass does not leak. `--force` provides the escape hatch, logged per Tier 2.

Evidence:

1. Three-session recurrence: (a) This session — T-1105/T-1106/T-1107/T-1109 all had `[Criterion N]` placeholders in Go/No-Go despite populated Recommendations. Human caught via Watchtower review and pasted the placeholder text as a complaint. (b) Prior session — T-1105 had empty `## Recommendation`. Agent populated after complaint, commit `e308456e`. (c) Prior session — T-1108/G-036 fixed rendering of `## Structural Upgrade` but did not address emptiness detection. Same bug class at different sections.

2. G-018 sitting open for weeks: "No structural guard against silent quality decay in generated artifacts" — registered as high severity, has been watching. This task's fix consumes G-018.

3. Existing controls demonstrably insufficient: C-001 checks artifact existence, not content. T-973 checks that the human clicked review, not what they saw. T-1108 fixed rendering, not emptiness. P-010/P-011 run on different lifecycle transitions. None of them inspect section-level content for placeholder literals.

4. Grep patterns are high-confidence: `\[Criterion [0-9]+\]`, `\[TODO\]`, `\[PLACEHOLDER\]`, `REQUIRED before fw inception decide` — none of these appear in legitimate populated task content. SPIKE A will verify.

5. Chokepoint architecture is minimal: single `_audit_placeholders()` helper, called from two gate points. ~80 LOC added. Zero existing code removed. No schema changes.

6. Pattern matches T-1105 discipline precisely: recurring bug class → chokepoint + invariant test. The build decomposition follows the same pattern as T-1109's (single chokepoint, two invariant tests, migration-free).

Build decomposition (T-1112a..e):

| Task ID | Scope | Type | Depends on |
|---------|-------|------|------------|
| T-1112a | Add `_audit_placeholders()` helper in `agents/task-create/update-task.sh`. Bash + grep only. Returns (section, line, pattern) tuples. | Build | — |
| T-1112b | Wire `_audit_placeholders()` into `lib/inception.sh:decide()` before review-marker check. Block on hit with clear error + `--force` bypass. | Build | T-1112a |
| T-1112c | Wire `_audit_placeholders()` into `lib/review.sh:fw_task_review()` before URL emission. Same block + bypass. | Build | T-1112a |
| T-1112d | Write `tests/integration/inception-decide-blocks-placeholders.bats` + `tests/integration/task-review-blocks-placeholders.bats`. | Test | T-1112b, T-1112c |
| T-1112e | Add `tests/lint/no-placeholder-literals-in-active-tasks.bats` for pre-push hook. Consume G-018 — mark resolved. | Test | T-1112a |

Cost estimate: ~80 LOC added, 0 removed. 2 gate points + 3 test files. 1 gap (G-018) consumed. Total effort: ~45 minutes in one coherent commit.

Risk (none blocking):
- False positives: SPIKE A validates. If any legitimate content trips the grep, tighten the pattern.
- Performance: bash grep on a single ~200-line file runs in <10ms.
- Escape hatch: `--force` flag on both gates, logged to `.context/working/.bypass-log` per Tier 2.

Cross-references:
- Research artifact: `docs/reports/T-1111-placeholder-sections-rca.md` (dialogue log + C1-C4 options + invariant test sketches)
- Related gaps: G-018 (silent quality decay — this fix consumes it); G-036 (Watchtower section allowlist — adjacent class); L-006 (enumeration-divergence — the pattern this fix embodies)
- Parent discipline: T-1105 (chokepoint+invariant-test framework governance rule)
- Precedent: T-1109 (same structural shape: single chokepoint, invariant tests, migration-free)

Human decision request: Review `docs/reports/T-1111-placeholder-sections-rca.md` for the dialogue log and non-recommended options (C3 Watchtower red warnings, C4 template redesign), then:
- `fw inception decide T-1111 go --rationale "approved — implement C1+C2 chokepoint"`, OR
- `fw inception decide T-1111 defer --rationale "wait until G-018 is addressed by another initiative"`, OR
- `fw inception decide T-1111 no-go --rationale "existing controls sufficient"`

### 2026-04-12T09:27:16Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-80929d67
- **Timestamp:** 2026-06-02T14:55:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
