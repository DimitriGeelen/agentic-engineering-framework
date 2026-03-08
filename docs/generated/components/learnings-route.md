# learnings-route

> Serve the /learnings page showing all project learnings, patterns, and practices.

**Type:** route | **Subsystem:** learnings-pipeline | **Location:** `web/blueprints/discovery.py`

**Tags:** `learning`, `web`, `watchtower`, `discovery`

## What It Does

## Dependencies (9)

| Target | Relationship |
|--------|-------------|
| `F-001` | reads |
| `F-002` | reads |
| `C-006` | renders |
| `web/shared.py` | calls |
| `web/templates/decisions.html` | renders |
| `web/templates/gaps.html` | renders |
| `web/templates/search.html` | renders |
| `web/templates/patterns.html` | renders |
| `web/templates/graduation.html` | renders |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `C-006` | htmx |
| `web/app.py` | called_by |
| `web/app.py` | registered_by |
| `C-006` | rendered_by |

## Related

### Tasks
- T-245: sqlite-vec embedding layer — semantic search for project knowledge
- T-256: Ask endpoint — /search/ask with ollama SSE streaming
- T-265: Saved answers — curated Q&A for retrieval flywheel
- T-267: User feedback — thumbs up/down on Q&A answers
- T-268: Multi-turn Q&A conversation

---
*Auto-generated from Component Fabric. Card: `learnings-route.yaml`*
*Last verified: 2026-02-20*
