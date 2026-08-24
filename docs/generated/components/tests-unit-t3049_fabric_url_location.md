# t3049_fabric_url_location

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3049_fabric_url_location.bats`

## What It Does

T-3049 — a card's `location:` is not always a filesystem path.
Two checks ask "is this card's file still there" and both joined a URL onto
PROJECT_ROOT, producing $PROJECT_ROOT/https://host/path, which never exists:
agents/fabric/lib/drift.sh:59-64   (the `fw fabric drift` CLI)
agents/audit/audit.sh:~1664        (the daily orphan count)
A hosted service has no file to be missing, so the check declines the question
instead of answering no.
Zero cards in THIS repo carry a URL location, which is exactly why it survived:
the framework repo is where the check runs daily and the one place it cannot
fire. Consumers registering saas-account cards saw it permanently.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [drift](/docs/generated/agents-fabric-lib-drift) | calls | Fabric Agent - drift detection commands |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [drift](/docs/generated/agents-fabric-lib-drift) | tests | Fabric Agent - drift detection commands |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3049_fabric_url_location.yaml`*
*Last verified: 2026-08-17*
