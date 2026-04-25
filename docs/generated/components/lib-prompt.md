# prompt

> fw prompt — reusable agent-prompt register. Subcommands: create, list, show, copy (with {{var}} substitutions). Prompt files are markdown with YAML frontmatter stored under prompts/. Single source of truth for cross-machine / cross-agent reusable prompts (fleet upgrade+test+fix, audit dispatch, onboarding, etc.).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/prompt.sh`

**Tags:** `cli`, `prompt-register`, `T-1283`

## What It Does

fw prompt — reusable agent-prompt register (T-1283)
Subcommands:
create   Create a new prompt file under prompts/
list     List all prompts
show     Print the body of a prompt (frontmatter stripped)
copy     Print the body with {{var}} substitutions applied
Prompt file schema: markdown with YAML frontmatter.
---
id: <slug>                     # filename stem; unique within this repo
qid: <agent-id>/P-NNN          # cross-fleet stable reference (B2)

### Framework Reference

When dispatching sub-agents, include in the prompt:

1. **Scope**: Exactly what to investigate/produce (one clear deliverable)
2. **Framework context**: Relevant framework structure (task format, episodic template, etc.)
3. **Output format**: How to return results (write to file vs. return summary)
4. **Constraints**: Don't modify files outside scope, don't return raw data
5. **Token hint**: "Keep your response concise — the orchestrator has limited context budget"

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `prompts/` | reads |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | sourced_by |

---
*Auto-generated from Component Fabric. Card: `lib-prompt.yaml`*
*Last verified: 2026-04-24*
