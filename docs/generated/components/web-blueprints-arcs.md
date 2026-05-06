# arcs

> Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/arcs.py`

**Tags:** `arcs`, `watchtower`, `t-1662`

## What It Does

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/arcs_index.html` | renders |
| `web/templates/arc_detail.html` | renders |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-arcs.yaml`*
*Last verified: 2026-05-01*
