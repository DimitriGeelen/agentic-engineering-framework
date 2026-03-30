# governance

> Risk-based governance declarations — machine-readable predictability x blast-radius matrix mapping operations to enforcement levels. Created by T-511.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/governance.yaml`

**Tags:** `context`, `project-memory`, `governance`, `enforcement`

## What It Does

governance.yaml — Risk-based governance declarations
Maps operation classes to enforcement levels based on
predictability × blast-radius dimensions (T-477).
This file is architecture documentation AND a machine-readable
declaration that hooks and agents can consume.
Enforcement levels (derived from matrix position):
free    — no governance beyond audit trail (Q1: deterministic × low)
audit   — action logged, reviewable post-hoc (Q2: stochastic × low)
gate    — PreToolUse hook blocks until condition met (Q3: deterministic × high)
approve — requires human approval per instance (Q4: stochastic × high)

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/audit/audit.sh` | read_by |

---
*Auto-generated from Component Fabric. Card: `context-project-governance.yaml`*
*Last verified: 2026-03-23*
