# t3054_watchtower_root_fallback

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3054_watchtower_root_fallback.bats`

## What It Does

T-3054 — the PROJECT_ROOT -> FRAMEWORK_ROOT fallback must be audible, and the
identity check must not compute its expected value from the same expression.
The original defect was not the fallback. It was that the fallback was silent
in two places at once: the launcher used it to decide what to serve, and the
identity check used it to decide what "ours" means — so a server that fell
back matched itself and passed `fw doctor`. Every test below therefore
exercises the UNSET case, which is the only one that could ever have failed.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3054_watchtower_root_fallback.yaml`*
*Last verified: 2026-08-16*
