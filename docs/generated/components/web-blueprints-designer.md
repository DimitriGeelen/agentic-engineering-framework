# designer

> TODO: describe what this component does

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/designer.py`

## What It Does

T-2648 (OBS-097): pin + fw binary are FRAMEWORK-owned (vendored for
consumers) — PROJECT_ROOT resolution breaks split-root installs.

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [designer_api](/docs/generated/web-blueprints-designer_api) | calls | TODO: describe what this component does |
| [designer_registry](/docs/generated/web-designer_registry) | calls | TODO: describe what this component does |
| [designer_ghosts](/docs/generated/web-templates-designer_ghosts) | renders | TODO: describe what this component does |
| [designer_api](/docs/generated/web-blueprints-designer_api) | registers | TODO: describe what this component does |
| [designer_landing](/docs/generated/web-templates-designer_landing) | renders | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [corpus_overlay](/docs/generated/tools-corpus_overlay) | calls | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-designer.yaml`*
*Last verified: 2026-07-10*
