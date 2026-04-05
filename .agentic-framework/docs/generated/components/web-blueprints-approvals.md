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

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `web/blueprints/core.py` | called_by |
| `web/blueprints/core.py` | registered_by |

## Related

### Tasks
- T-639: Unified /approvals page — Tier 0 + Human ACs + GO decisions in urgency-ordered sections
- T-641: Tier 0 rejection feedback — write rejection reason to resolved YAML, agent reads on retry
- T-669: Approvals page auto-refresh — htmx polling for live Tier 0 and Human AC updates
- T-672: Add priority sorting to approvals page — urgent/stale items first, rubber-stamps last
- T-846: Watchtower /approvals — add 'Complete All Ready' batch action for tasks with all ACs checked

---
*Auto-generated from Component Fabric. Card: `web-blueprints-approvals.yaml`*
*Last verified: 2026-03-27*
