# inception

> Blueprint 'inception' — routes: /inception

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/inception.py`

## What It Does

Ensure blank line before lists so markdown parser recognizes them

### Framework Reference

When the active task has `workflow_type: inception`:
1. **State the phase** — Say "This is an inception/exploration task" before doing any work
2. **Present the filled template** for review before executing any spikes or prototypes
3. **Do not write build artifacts** (production code, full apps) before `fw inception decide T-XXX go`
4. **The commit-msg hook enforces this** — after 2 exploration commits, further commits are blocked until a decision is recorded
5. After a GO decision, **create separate build tasks** for implementation — do not continue building under the inception task ID
6. **R

*(truncated — see CLAUDE.md for full section)*

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/inception.html` | renders |
| `web/templates/inception_detail.html` | renders |
| `web/templates/assumptions.html` | renders |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | called_by |
| `web/app.py` | registered_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-inception.yaml`*
*Last verified: 2026-02-20*
