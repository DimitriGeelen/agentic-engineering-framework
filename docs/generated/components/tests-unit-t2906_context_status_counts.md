# t2906_context_status_counts

> T-2906: fw context status counted learnings with grep "^ - id: L-", which matches nothing once learnings.yaml is in PyYAML's flat serialisation ("- application: …" / " id: L-NNN").

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2906_context_status_counts.bats`

## What It Does

T-2906: fw context status counted learnings with grep "^  - id: L-", which
matches nothing once learnings.yaml is in PyYAML's flat serialisation
("- application: …" / "  id: L-NNN"). Counts must come from the data, not
from one textual layout of it, and an unparseable file must not read as 0.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2906_context_status_counts.yaml`*
*Last verified: 2026-10-20*
