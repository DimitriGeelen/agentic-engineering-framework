# generate_article

> Python implementation for AI-assisted subsystem article generation from fabric cards

**Type:** script | **Subsystem:** watchtower | **Location:** `agents/docgen/generate_article.py`

**Tags:** `docs`, `docgen`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-data](/docs/generated/learnings-data) | calls | Persistent store of all project learnings. Read by web UI and audit. Written by add-learning command. |
| [decisions](/docs/generated/context-project-decisions) | calls | Decision log recording architectural and process decisions with rationale and rejected alternatives. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [generate-article](/docs/generated/agents-docgen-generate-article) | calls | Generates AI-assisted subsystem articles from component fabric cards |
| [generate-article](/docs/generated/agents-docgen-generate-article) | called_by | Generates AI-assisted subsystem articles from component fabric cards |

---
*Auto-generated from Component Fabric. Card: `agents-docgen-generate_article.yaml`*
*Last verified: 2026-03-12*
