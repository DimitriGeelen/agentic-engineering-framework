# inception

> fw inception - Inception phase workflow

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/inception.sh`

## What It Does

fw inception - Inception phase workflow
Manages exploration-phase work: problem definition, assumptions, go/no-go

### Framework Reference

When the active task has `workflow_type: inception`:
1. **State the phase** — Say "This is an inception/exploration task" before doing any work
2. **Present the filled template** for review before executing any spikes or prototypes
3. **Do not write build artifacts** (production code, full apps) before `fw inception decide T-XXX go`
4. **The commit-msg hook enforces this** — after 2 exploration commits, further commits are blocked until a decision is recorded
5. After a GO decision, **create separate build tasks** for implementation — do not continue building under the inception task ID
6. **R

*(truncated — see CLAUDE.md for full section)*

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-inception.yaml`*
*Last verified: 2026-02-20*
