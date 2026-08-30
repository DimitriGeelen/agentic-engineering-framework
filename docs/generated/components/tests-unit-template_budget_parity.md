# template_budget_parity

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/template_budget_parity.bats`

## What It Does

T-3155 — the consumer CLAUDE.md template must not contradict the budget gate.
Origin: 001-CashWeb ran `fw upgrade` and lost their T-085 fix, which had expressed
the context-budget ladder as percentages of CONTEXT_WINDOW. The template replaced it
with hard-coded 120K/150K/170K — numbers from a 200K-window era — so every consumer
was handed a CLAUDE.md telling it to hand over at 170K while its own budget-gate.sh
blocked at 285K. Net value of that upgrade: zero, plus one regression.
THE POINT OF THIS FILE. These tests read the percentages out of BOTH sources and
compare them. They deliberately do NOT assert a literal 75/85/95, because a hardcoded
expectation in the test drifts in exactly the same way the template did — it would
re-create the defect one level up and look green while doing it.

---
*Auto-generated from Component Fabric. Card: `tests-unit-template_budget_parity.yaml`*
*Last verified: 2026-08-26*
