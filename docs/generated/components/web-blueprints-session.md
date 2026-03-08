# session

> Flask blueprint: Session

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/session.py`

## What It Does

Helpers

### Framework Reference

**Location:** `agents/session-capture/`

**When to use:** MANDATORY before ending any session or switching context.

Review the checklist in `agents/session-capture/AGENT.md` and ensure:
- All discussed work has tasks
- All decisions are recorded
- All learnings are captured as practices
- All open questions are tracked

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | called_by |
| `web/app.py` | registered_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-session.yaml`*
*Last verified: 2026-02-20*
