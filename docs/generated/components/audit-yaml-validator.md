# audit-yaml-validator

> Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption.

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/audit.sh`

**Tags:** `audit`, `yaml`, `validation`, `regression`, `structure`

## What It Does

Audit Agent - Mechanical Compliance Checks
Evaluates framework compliance against specifications
Usage:
audit.sh                              # Full audit with terminal output
audit.sh --section structure,quality   # Run only specified sections
audit.sh --output /path/to/dir        # Write YAML report to custom dir
audit.sh --quiet                      # Suppress terminal output (cron-friendly)
audit.sh --cron                       # Shorthand for --output .context/audits/cron --quiet
audit.sh schedule install|remove|status  # Manage cron schedule
Sections: structure, compliance, quality, traceability, enforcement,

## Dependencies (6)

| Target | Relationship |
|--------|-------------|
| `F-001` | reads |
| `C-008` | calls |
| `agents/context/check-tier0.sh` | calls |
| `agents/context/error-watchdog.sh` | calls |
| `agents/task-create/update-task.sh` | calls |
| `lib/paths.sh` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `cron-audit` | triggers |
| `agents/git/lib/hooks.sh` | called_by |
| `bin/fw` | called_by |
| `agents/onboarding-test/test-onboarding.sh` | called_by |

## Related

### Tasks
- T-709: Wire ntfy notifications into framework hooks — Tier 0, task complete, audit, handover
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `audit-yaml-validator.yaml`*
*Last verified: 2026-02-20*
