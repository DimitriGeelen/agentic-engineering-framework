# preamble

> Mandatory dispatch preamble — output rules for sub-agents to prevent context explosion (T-073). Requires disk writes, <=5 line responses.

**Type:** template | **Subsystem:** framework-core | **Location:** `agents/dispatch/preamble.md`

**Tags:** `dispatch`, `sub-agent`, `context-budget`, `protocol`

## What It Does

Mandatory Dispatch Preamble

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `agents/context/check-dispatch.sh` | referenced_by |
| `agents/context/check-dispatch.sh` | references_by |
| `agents/context/check-dispatch-pre.sh` | read_by |

## Related

### Tasks
- T-820: Fix TermLink dispatch preamble — workers write to target files
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-dispatch-preamble.yaml`*
*Last verified: 2026-03-01*
