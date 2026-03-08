# inception

> Watchtower UI page: Inception

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/inception.html`

## What It Does

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
| `web/blueprints/inception.py` | rendered_by |

---
*Auto-generated from Component Fabric. Card: `web-templates-inception.yaml`*
*Last verified: 2026-02-20*
