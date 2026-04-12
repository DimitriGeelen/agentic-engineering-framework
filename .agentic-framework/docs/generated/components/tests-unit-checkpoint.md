# checkpoint

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/checkpoint.bats`

## What It Does

Unit tests for agents/context/checkpoint.sh
Tests transcript discovery scoping (T-791) and status output

### Framework Reference

When fixing a bug discovered through real-world usage (user testing, production incident, cross-platform failure):
1. **Classify the bug** — Is this a new failure class, or a repeat of a known pattern?
2. **Check learnings.yaml** — Does a learning already exist for this class?
3. If new class: `fw context add-learning "description" --task T-XXX --source P-001`
4. If systemic (same class hit 2+ times): register in `concerns.yaml`, consider tooling fix (Level C/D)

*(truncated — see CLAUDE.md for full section)*

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/context/checkpoint.sh` | calls |

## Related

### Tasks
- T-791: Fix checkpoint.sh cross-project transcript leak — scope find_transcript to current project

---
*Auto-generated from Component Fabric. Card: `tests-unit-checkpoint.yaml`*
*Last verified: 2026-03-30*
