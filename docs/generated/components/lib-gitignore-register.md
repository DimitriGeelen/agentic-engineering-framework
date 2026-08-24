# gitignore-register

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/gitignore-register.sh`

## What It Does

T-2994 (build slice of T-2992) — .gitignore rules that defer without a register.
THE ASYMMETRY THIS EXISTS FOR. Every suppression mechanism the framework uses
announces itself when it fires, except one:
skip "reason"      prints its reason on every suite run
allowlist entry    echoed by whichever scanner consults it
.gitignore rule    emits nothing, ever
A gitignore rule is the only one that removes a signal silently AND
permanently. There is no run, no report, and no moment at which it says "I am
suppressing something".
That is not a general worry, it is a measured incident. T-2990: two rules

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [t2994_gitignore_register](/docs/generated/tests-unit-t2994_gitignore_register) | called_by | TODO: describe what this component does |
| [t2994_gitignore_register](/docs/generated/tests-unit-t2994_gitignore_register) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-gitignore-register.yaml`*
*Last verified: 2026-08-14*
