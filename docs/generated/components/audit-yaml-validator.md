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

## Dependencies (5)

| Target | Relationship |
|--------|-------------|
| `F-001` | reads |
| `C-008` | calls |
| `agents/context/check-tier0.sh` | calls |
| `agents/context/error-watchdog.sh` | calls |
| `agents/task-create/update-task.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `cron-audit` | triggers |
| `agents/git/lib/hooks.sh` | called_by |
| `bin/fw` | called_by |

## Related

### Tasks
- T-249: Refine D5 lifecycle anomaly detection to reduce false positive rate
- T-275: Pre-deploy quality gate — audit section + gated fw deploy
- T-301: Add audit grace period for new projects
- T-346: Add bugfix-learning coverage ratio to audit section 5
- T-347: Build fw fix-learned shortcut for fast learning capture

---
*Auto-generated from Component Fabric. Card: `audit-yaml-validator.yaml`*
*Last verified: 2026-02-20*
