# generate-article

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/docgen/generate-article.sh`

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

## Related

### Tasks
- T-366: Layer 2: AI-assisted subsystem article generator

---
*Auto-generated from Component Fabric. Card: `agents-docgen-generate-article.yaml`*
*Last verified: 2026-03-09*
