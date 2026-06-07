# lib_costs tests

> 26 bats unit tests for lib/costs.sh — path computation, routing, JSONL parsing, edge cases (T-807)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_costs.bats`

**Tags:** `tokens`, `costs`, `testing`

## What It Does

Unit tests for lib/costs.sh — token usage tracking from JSONL transcripts
Tests: _costs_jsonl_dir, costs_main routing, Python JSONL parsing, edge cases

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [costs](/docs/generated/lib-costs) | calls | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |
| [costs](/docs/generated/lib-costs) | tests | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |

## Related

### Tasks
- T-807: Unit tests for lib/costs.sh token tracking

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_costs.yaml`*
*Last verified: 2026-04-03*
