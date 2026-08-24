# bvp-help-parity

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/lint/bvp-help-parity.bats`

## What It Does

T-3069: the bvp verb surface and its documentation must agree.
Two errors pointing opposite ways, both live before this file existed:
`estimate-cost` was fully implemented (lib/bvp.sh, four subverbs, its own --help,
wired into cron) and appeared zero times in `fw bvp --help`; and CLAUDE.md named a
`fw bvp rank` verb that does not exist, so following the documentation produced
`ERROR: unknown verb 'rank'`.
Both cost the same thing. A capability nobody can find is indistinguishable from
one nobody built — our own register had recorded the cost half of BVP as unbuilt,
and a peer project reached the identical wrong conclusion from theirs.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bvp](/docs/generated/lib-bvp) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-lint-bvp-help-parity.yaml`*
*Last verified: 2026-08-17*
