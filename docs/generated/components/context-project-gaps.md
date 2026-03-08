# gaps

> Spec-reality gap register tracking structural flaws between documented behavior and actual implementation.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/gaps.yaml`

**Tags:** `context`, `project-memory`

## What It Does

Gaps Register — Spec-Reality Gaps with Decision Triggers
Purpose: Structural memory for things we chose NOT to build yet.
Each gap has a trigger condition — when the trigger fires, we decide:
build the feature, or simplify the spec.
Checked by: audit agent (Section 8)
Surfaced in: handover documents
Status values:
watching         — gap identified, waiting for trigger
decided-build    — trigger fired, decided to build
decided-simplify — trigger fired, decided to simplify spec

## Related

### Tasks
- T-231: Update git hook messages and register enforcement gaps
- T-232: Fix task-gate completed-task bypass
- T-242: Block built-in EnterPlanMode from bypassing framework governance
- T-329: Write launch article: I built guardrails for Claude Code
- T-345: Add bugfix learning checkpoint practice and G-016 gap

---
*Auto-generated from Component Fabric. Card: `context-project-gaps.yaml`*
*Last verified: 2026-03-04*
