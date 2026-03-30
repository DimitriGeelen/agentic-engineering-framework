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
- T-469: Inception: Structural remediation for pickup-message governance bypass
- T-495: Path isolation — eliminate hardcoded absolute paths from all committed files
- T-559: Project boundary gate — PreToolUse hook blocking writes outside PROJECT_ROOT
- T-614: TermLink consumer project governance bypass investigation — Tier 0 bypass, taskless work, structural regression analysis

---
*Auto-generated from Component Fabric. Card: `context-project-concerns.yaml`*
*Last verified: 2026-03-10*
