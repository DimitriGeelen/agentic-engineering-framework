# approvals

> Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/approvals.py`

## What It Does

Approvals older than this are considered expired (seconds)

## Dependencies (6)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/blueprints/inception.py` | calls |
| `web/blueprints/tasks.py` | calls |
| `web/templates/approvals.html` | renders |
| `web/blueprints/inception.py` | registers |
| `web/blueprints/tasks.py` | registers |

## Used By (7)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `web/blueprints/core.py` | called_by |
| `web/blueprints/core.py` | registered_by |
| `tests/playwright/test_inception.py` | called_by |
| `tests/playwright/test_inception.py` | registered_by |

## Related

### Tasks
- T-846: Watchtower /approvals — add 'Complete All Ready' batch action for tasks with all ACs checked
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `web-blueprints-approvals.yaml`*
*Last verified: 2026-03-27*
