# extract_decisions

> Extract the `## Decisions` section of a task file as YAML — T-3015.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/extract_decisions.py`

## What It Does

Field label -> emitted YAML key. Order is not significant; membership is, since
an unrecognised bolded label terminates the value being accumulated.

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [episodic_yaml_decision_escape](/docs/generated/tests-unit-episodic_yaml_decision_escape) | called_by | T-1871 — episodic generator must emit valid YAML when ## Decisions content contains YAML-double-quote-hostile characters (backticks, backslashes, embedded quotes, escape sequences). |
| [episodic_yaml_decision_escape](/docs/generated/tests-unit-episodic_yaml_decision_escape) | tests_by | T-1871 — episodic generator must emit valid YAML when ## Decisions content contains YAML-double-quote-hostile characters (backticks, backslashes, embedded quotes, escape sequences). |

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-extract_decisions.yaml`*
*Last verified: 2026-08-15*
