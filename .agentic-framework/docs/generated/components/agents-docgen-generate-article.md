# generate-article

> Generates AI-assisted subsystem articles from component fabric cards

**Type:** script | **Subsystem:** watchtower | **Location:** `agents/docgen/generate-article.sh`

**Tags:** `docs`, `docgen`

## What It Does

Subsystem Article Generator
T-366: Assembles context from fabric + source + episodic, then generates
a deep-dive article via Ollama or outputs a prompt file.
Usage:
fw docs article <subsystem>              # prompt file only
fw docs article <subsystem> --generate   # call Ollama
fw docs article --list                   # list subsystems
Output:
Prompt: docs/generated/articles/{subsystem}-prompt.md
Article: docs/articles/deep-dives/{NN}-{subsystem}.md

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [generate_article](/docs/generated/agents-docgen-generate_article) | calls | Python implementation for AI-assisted subsystem article generation from fabric cards |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [docgen_article](/docs/generated/tests-unit-docgen_article) | tested_by | Unit tests for agents/docgen/generate-article.sh (5 tests) |
| [docgen_article](/docs/generated/tests-unit-docgen_article) | called_by | Unit tests for agents/docgen/generate-article.sh (5 tests) |
| [docgen_article](/docs/generated/tests-unit-docgen_article) | tests_by | Unit tests for agents/docgen/generate-article.sh (5 tests) |

## Related

### Tasks
- T-798: Shellcheck cleanup: remaining peripheral agent scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-docgen-generate-article.yaml`*
*Last verified: 2026-03-11*
