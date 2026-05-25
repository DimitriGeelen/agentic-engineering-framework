# review

> fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/review.sh`

## What It Does

Shared human review output — deterministic review info at every layer (T-634)
Emits: Watchtower URL, QR code, research artifacts, Human AC count.
Called by: fw task review, update-task.sh (partial-complete), inception.sh (decide).
Usage:
source "$FRAMEWORK_ROOT/lib/review.sh"
emit_review T-XXX [task_file]

### Framework Reference

When agent ACs are complete and human ACs remain:

1. **Write your recommendation into the task file** — Add a `## Recommendation` section (Watchtower reads this) with:
   - **Recommendation:** GO / NO-GO / DEFER
   - **Rationale:** Why (cite evidence: what was fixed, what was proven, what remains)
   - **Evidence:** Bullet list of concrete proof (test results, file paths, metrics)
   You are the advisory. The human is the decision-maker. Never present a blank decision for them to fill in — always tell them what you recommend and why.

*(truncated — see CLAUDE.md for full section)*

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [inception](/docs/generated/lib-inception) | called_by | fw inception - Inception phase workflow |
| [lib_review](/docs/generated/tests-unit-lib_review) | called-by | Unit tests for review (10 tests) |
| [lib_review](/docs/generated/tests-unit-lib_review) | called_by | Unit tests for review (10 tests) |
| [lib_review](/docs/generated/tests-unit-lib_review) | tests_by | Unit tests for review (10 tests) |
| [test_arc_parent_review_gate](/docs/generated/tests-unit-test_arc_parent_review_gate) | called_by | TODO: describe what this component does |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-973: Review-before-decide gate — fw inception decide requires fw task review first

---
*Auto-generated from Component Fabric. Card: `lib-review.yaml`*
*Last verified: 2026-03-27*
