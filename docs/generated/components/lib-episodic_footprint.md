# episodic_footprint

> Re-mine an episodic's git footprint AFTER the completion commit exists (T-3130).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/episodic_footprint.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [episodic](/docs/generated/agents-context-lib-episodic) | calls | Context Agent - generate-episodic command |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [episodic_footprint_refresh](/docs/generated/tests-unit-episodic_footprint_refresh) | tests_by | T-3130 — the episodic's git footprint is mined before the commit it describes. |

---
*Auto-generated from Component Fabric. Card: `lib-episodic_footprint.yaml`*
*Last verified: 2026-08-25*
