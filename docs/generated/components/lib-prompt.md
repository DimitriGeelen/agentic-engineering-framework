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

If you can state scope, deliverable, output format and constraints, the work is
**specified**: dispatch it. If writing the prompt requires you to first find out
what is wrong, it is **not specified yet** — localise first, then dispatch the fix.

Writing the prompt *is* the test. If you sit down to write it and cannot, that is
the signal, not a reason to push through.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `prompts/` | reads | — |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | sourced_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [prompts](/docs/generated/web-blueprints-prompts) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-prompt.yaml`*
*Last verified: 2026-04-24*
