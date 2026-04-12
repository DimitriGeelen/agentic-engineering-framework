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

| Target | Relationship |
|--------|-------------|
| `agents/docgen/generate_article.py` | calls |
| `lib/paths.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `tests/unit/docgen_article.bats` | tested_by |
| `tests/unit/docgen_article.bats` | called_by |

## Related

### Tasks
- T-798: Shellcheck cleanup: remaining peripheral agent scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-docgen-generate-article.yaml`*
*Last verified: 2026-03-11*
