# context_tokens

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/context_tokens.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [budget-gate](/docs/generated/budget-gate) | calls | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [costs](/docs/generated/lib-costs) | calls | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |
| [costs](/docs/generated/web-blueprints-costs) | calls | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [budget-gate](/docs/generated/budget-gate) | called_by | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [checkpoint](/docs/generated/checkpoint) | called_by | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [costs](/docs/generated/web-blueprints-costs) | called_by | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |

---
*Auto-generated from Component Fabric. Card: `lib-context_tokens.yaml`*
*Last verified: 2026-08-09*
