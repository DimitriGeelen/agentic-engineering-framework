# t2994_gitignore_register

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2994_gitignore_register.bats`

## What It Does

T-2994: .gitignore rules that defer without naming a register entry.
The load-bearing test is `the historical T-2990 block is flagged`. It replays
the exact comment that sat in this repo's .gitignore for three months while
56MB of junk accumulated behind the rules it annotated. If that test passes
and the negative control below also passes, the rail discriminates. If only
the negative control passes, the rail is inert and looks identical to working
— which is precisely how T-2990's first detector shipped green and useless.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [gitignore-register](/docs/generated/lib-gitignore-register) | calls | TODO: describe what this component does |
| [gitignore-register](/docs/generated/lib-gitignore-register) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2994_gitignore_register.yaml`*
*Last verified: 2026-08-14*
