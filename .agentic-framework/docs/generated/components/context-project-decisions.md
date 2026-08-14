# decisions

> Decision log recording architectural and process decisions with rationale and rejected alternatives.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/decisions.yaml`

**Tags:** `context`, `project-memory`

## What It Does

Project Decisions - Architectural choices with rationale
Added via: fw context add-decision "description" --task T-XXX --rationale "why"

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | read_by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | read_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [generate_article](/docs/generated/agents-docgen-generate_article) | called_by | Python implementation for AI-assisted subsystem article generation from fabric cards |
| [test_api_context_capture](/docs/generated/tests-playwright-test_api_context_capture) | called_by | Playwright tests for context capture API endpoints (T-1030). |

---
*Auto-generated from Component Fabric. Card: `context-project-decisions.yaml`*
*Last verified: 2026-03-04*
