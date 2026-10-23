# template_budget_parity

> T-3155 — the consumer CLAUDE.md template must not contradict the budget gate.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/template_budget_parity.bats`

## What It Does

T-3155 — the consumer CLAUDE.md template must not contradict the budget gate.
T-4226 — the template states the ladder as absolute used-token figures, so the
parity check now reads those figures and compares them with lib/budget_ladder.py.
Origin: 001-CashWeb ran `fw upgrade` and lost their T-085 fix, which had expressed
the context-budget ladder as percentages of CONTEXT_WINDOW. The template replaced it
with hard-coded 120K/150K/170K — numbers from a 200K-window era — so every consumer
was handed a CLAUDE.md telling it to hand over at 170K while its own budget-gate.sh
blocked at 285K. Net value of that upgrade: zero, plus one regression.
THE POINT OF THIS FILE. The template's numbers must be the ladder's numbers, read
from both sources and compared. They deliberately do NOT assert literal figures

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [budget-gate](/docs/generated/budget-gate) | tests | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-template_budget_parity.yaml`*
*Last verified: 2026-08-26*
