# exec-bit-drift

> lib/exec-bit-drift.sh — T-3317 (OBS-336): exec-bit drift detector.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/exec-bit-drift.sh`

## What It Does

lib/exec-bit-drift.sh — T-3317 (OBS-336): exec-bit drift detector.
Origin. A worker's rewrite of agents/audit/audit.sh dropped the executable
bit (git index 100755, on-disk 664). `bin/fw audit` then died with exit 126
"Permission denied" — the ENTIRE audit rail silently disabled by a mode
change no gate watched. Nothing in doctor, audit, or the pre-push hooks
compared on-disk mode against the git index. This is the T-3105 class one
level up: the audit that reports on everything else had no check that it can
itself run.
The predicate is deliberately cheap — one `git ls-files -s` plus a stat-class
test per candidate. No test-suite invocation, no network, no corpus walk —

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [cron_exec_bit](/docs/generated/lib-cron_exec_bit) | called_by | T-3380: scripts a deployed crontab invokes DIRECTLY must be executable. |

---
*Auto-generated from Component Fabric. Card: `lib-exec-bit-drift.yaml`*
*Last verified: 2026-09-07*
