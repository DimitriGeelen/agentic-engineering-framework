# t2176-corpus-rescan

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/t2176-corpus-rescan.sh`

## What It Does

T-2176: Fresh fw reviewer scan over .tasks/completed/ to refresh stale verdict cache.
Writes back ## Reviewer Verdict block per task; logs JSON per task; aggregates FAIL list.
Output:
.context/working/t2176-rescan-progress.log  — running progress (one line per task)
.context/working/t2176-rescan-verdicts.jsonl — one JSON per task (--no-write JSON dump)
.context/working/t2176-rescan-summary.yaml  — aggregate totals + per-pattern counts
Runs reviewer twice per task in --no-write mode:
- Pass A: JSON capture for analysis
- Pass B: write-back so AC#1 (1900+ Scan ID lines) is satisfied
The two passes are necessary because --no-write skips file mutation entirely.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tools-t2176-corpus-rescan.yaml`*
*Last verified: 2026-09-03*
