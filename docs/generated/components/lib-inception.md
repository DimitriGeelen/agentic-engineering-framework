# inception

> fw inception - Inception phase workflow

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/inception.sh`

## What It Does

fw inception - Inception phase workflow
Manages exploration-phase work: problem definition, assumptions, go/no-go

### Framework Reference

When the active task has `workflow_type: inception`:
1. **State the phase** — Say "This is an inception/exploration task" before doing any work
2. **Present the filled template** for review before executing any spikes or prototypes
3. **Do not write build artifacts** (production code, full apps) before `fw inception decide T-XXX go`
4. **The commit-msg hook enforces this** — after 2 exploration commits, further commits are blocked until a decision is recorded
5. After a GO decision, **create separate build tasks** for implementation — do not continue building under the inception task ID
6. **R

*(truncated — see CLAUDE.md for full section)*

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [review](/docs/generated/lib-review) | calls | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [task-audit](/docs/generated/lib-task-audit) | calls | Scans task files for literal placeholder content that should have been replaced during authoring, blocking review and inception decisions until resolved |
| [inception_recommendation](/docs/generated/lib-inception_recommendation) | calls | TODO: describe what this component does |

## Used By (21)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_inception](/docs/generated/tests-unit-lib_inception) | called-by | Unit tests for inception (12 tests) |
| [lib_inception](/docs/generated/tests-unit-lib_inception) | called_by | Unit tests for inception (12 tests) |
| [T-1125-termlink-send-file-delivery-semantics](/docs/generated/docs-reports-T-1125-termlink-send-file-delivery-semantics) | produced-by_by | GO — TermLink send-file hub acceptance vs delivery semantics |
| [T-1129-termlink-session-learnings](/docs/generated/docs-reports-T-1129-termlink-session-learnings) | produced-by_by | 4 learnings from TermLink session — subagent scope, format, stale gaps, dog-food |
| [T-1136-session-init-concerns-check](/docs/generated/docs-reports-T-1136-session-init-concerns-check) | produced-by_by | GO — upstream session-init concerns check from 010-termlink |
| [T-1212-consumer-watchtower-rca](/docs/generated/docs-reports-T-1212-consumer-watchtower-rca) | produced-by_by | NO-GO RCA — consumer Watchtower pages misscoped, superseded by T-1213 |
| [T-607-correction-refinement-loop](/docs/generated/docs-reports-T-607-correction-refinement-loop) | produced-by_by | Correction and refinement loop research — absorbed into framework |
| [inception_decide_ac_tick](/docs/generated/tests-unit-inception_decide_ac_tick) | called_by | Unit tests for T-1324 — tick_inception_decide_acs auto-ticks the templated [REVIEW]/[RUBBER-STAMP] Human AC after fw inception decide writes the Decision block, so the work-completed gate does not leave the task in partial-complete forever (G-008; P-039). |
| [inception-decision-exact-match](/docs/generated/tests-lint-inception-decision-exact-match) | tests_by | TODO: describe what this component does |
| [inception_decide_ac_tick](/docs/generated/tests-unit-inception_decide_ac_tick) | tests_by | Unit tests for T-1324 — tick_inception_decide_acs auto-ticks the templated [REVIEW]/[RUBBER-STAMP] Human AC after fw inception decide writes the Decision block, so the work-completed gate does not leave the task in partial-complete forever (G-008; P-039). |
| [inception_decide_atomicity](/docs/generated/tests-unit-inception_decide_atomicity) | called_by | TODO: describe what this component does |
| [inception_decide_atomicity](/docs/generated/tests-unit-inception_decide_atomicity) | tests_by | TODO: describe what this component does |
| [inception_tick_decision_recorded](/docs/generated/tests-unit-inception_tick_decision_recorded) | called_by | TODO: describe what this component does |
| [inception_tick_decision_recorded](/docs/generated/tests-unit-inception_tick_decision_recorded) | tests_by | TODO: describe what this component does |
| [inception_tick_marker](/docs/generated/tests-unit-inception_tick_marker) | called_by | TODO: describe what this component does |
| [inception_tick_marker](/docs/generated/tests-unit-inception_tick_marker) | tests_by | TODO: describe what this component does |
| [lib_inception](/docs/generated/tests-unit-lib_inception) | tests_by | Unit tests for inception (12 tests) |
| [inception](/docs/generated/web-blueprints-inception) | called_by | Blueprint 'inception' — routes: /inception |
| [audit_d10_html_comment_blindness](/docs/generated/tests-unit-audit_d10_html_comment_blindness) | tests_by | Bats unit tests pinning D10 audit ("Decision-without-Dialogue") behaviour against HTML-comment-blindness false positives (T-1889). 4 cases verify: template-stub-only Human section is silent, real unchecked AC outside comments fires, checked AC is silent, mixed comments+real AC doesn't double-count. Forward-pins the strip-comments call added to audit.sh D10 block — future refactors that remove it fail test #1. |

## Related

### Tasks
- T-973: Review-before-decide gate — fw inception decide requires fw task review first
- T-974: Inception recommendation gate — require ## Recommendation before fw inception decide

---
*Auto-generated from Component Fabric. Card: `lib-inception.yaml`*
*Last verified: 2026-02-20*
