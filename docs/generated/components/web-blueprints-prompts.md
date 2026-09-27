# prompts

> Prompts blueprint — reusable agent-prompt register UI (T-1283 B3).

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/prompts.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [prompts_list](/docs/generated/web-templates-prompts_list) | renders | Prompt-register listing page, rendered by web/blueprints/prompts.py:prompts_list. |
| [prompt_detail](/docs/generated/web-templates-prompt_detail) | renders | Single prompt-register entry detail view, rendered by web/blueprints/prompts.py:prompt_detail. |
| [prompt](/docs/generated/lib-prompt) | calls | fw prompt — reusable agent-prompt register. Subcommands: create, list, show, copy (with {{var}} substitutions). Prompt files are markdown with YAML frontmatter stored under prompts/. Single source of truth for cross-machine / cross-agent reusable prompts (fleet upgrade+test+fix, audit dispatch, onboarding, etc.). |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-prompts.yaml`*
*Last verified: 2026-04-18*
