# patterns-data

> Stores failure, success, and workflow patterns discovered during project work.

**Type:** data | **Subsystem:** learnings-pipeline | **Location:** `.context/project/patterns.yaml`

**Tags:** `patterns`, `data`, `context`, `learnings`

## What It Does

Project Memory - Patterns
Accumulated patterns from working on this project.
Grows over time as we learn from tasks.

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `learnings-route` | reads | Web UI reads patterns for /learnings page |
| [learnings-route](/docs/generated/learnings-route) | read_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [learnings-route](/docs/generated/learnings-route) | called_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [resolver](/docs/generated/lib-resolver) | called_by | TODO: describe what this component does |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | called_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |

---
*Auto-generated from Component Fabric. Card: `patterns-data.yaml`*
*Last verified: 2026-02-21*
