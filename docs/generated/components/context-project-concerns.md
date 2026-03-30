# concerns

> Unified concerns register (gaps + risks) tracking spec-reality gaps, identified risks, severity, mitigation plans, and resolution status. Consolidated from gaps.yaml, issues.yaml, and risks.yaml by T-397.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/concerns.yaml`

**Tags:** `context`, `project-memory`, `governance`

## What It Does

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/risks.py` | read_by |
| `agents/audit/audit.sh` | read_by |
| `agents/handover/handover.sh` | read_by |

## Related

### Tasks
- T-559: Project boundary gate — PreToolUse hook blocking writes outside PROJECT_ROOT
- T-614: TermLink consumer project governance bypass investigation — Tier 0 bypass, taskless work, structural regression analysis
- T-693: Fix learning prompt false positive — match task names starting with Fix, not containing fix anywhere

---
*Auto-generated from Component Fabric. Card: `context-project-concerns.yaml`*
*Last verified: 2026-03-10*
