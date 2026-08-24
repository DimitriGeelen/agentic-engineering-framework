# t2945_default_template_recommendation

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2945_default_template_recommendation.bats`

## What It Does

T-2945 — default.md shipped no `## Recommendation`, so the section the review
gate demands existed in only one of the two templates that reach it.
lib/review.sh:205-211 (T-2421) BLOCKS `fw task review` emission for
build/refactor/test/decommission tasks in the partial-complete state (Agent ACs
done, >=1 `### Human` AC unticked) whose `## Recommendation` block is empty.
inception.md carried the block; default.md did not. Reported by 832 as T-455.
These tests drive the REAL `fw task review` against a sandbox PROJECT_ROOT and
build every fixture FROM THE SHIPPED TEMPLATE — so the tests stay coupled to
the template rather than to a copy of it. Delete the section and legs 2/3 go
red; make the section self-satisfying and leg 1 goes red.

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [task-audit](/docs/generated/lib-task-audit) | calls | Scans task files for literal placeholder content that should have been replaced during authoring, blocking review and inception decisions until resolved |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [review](/docs/generated/lib-review) | tests | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [task-audit](/docs/generated/lib-task-audit) | tests | Scans task files for literal placeholder content that should have been replaced during authoring, blocking review and inception decisions until resolved |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2945_default_template_recommendation.yaml`*
*Last verified: 2026-08-12*
