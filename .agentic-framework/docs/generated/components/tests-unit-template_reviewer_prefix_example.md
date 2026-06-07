# template_reviewer_prefix_example

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/template_reviewer_prefix_example.bats`

## What It Does

T-1895 (T-1878 A): template + CLAUDE.md surface [REVIEWER] as a peer of [REVIEW]
at AC-author time, not just as a post-hoc conversion rule.
T-1878 spike found a 412:7 [REVIEW]:[REVIEWER] adoption gap. The prefix existed
(T-1811) but the author-time nudge didn't — agents reaching for the template
only saw [REVIEW] as the example shape. This test pins both surfaces so the
nudge survives future template edits.
Pair: T-1896 (intervention B — structural catch via reviewer pattern
`human-ac-mechanical-signal`) will fire when this author-time nudge is missed.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-template_reviewer_prefix_example.yaml`*
*Last verified: 2026-05-18*
