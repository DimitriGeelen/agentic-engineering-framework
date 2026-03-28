# Dispatch Templates

> Reusable prompt templates for common sub-agent dispatch patterns.

## Purpose

These templates standardize how the orchestrator dispatches sub-agents via Claude Code's
Task tool. They encode lessons from 96 tasks of framework development, particularly the
T-073 context explosion and the patterns that worked well.

## Usage

When dispatching a sub-agent, read the relevant template and adapt it to your specific task.
The templates are NOT used as-is — they're patterns to follow.

## Available Templates

| Template | Pattern | When to Use |
|----------|---------|-------------|
| `investigate.md` | Parallel research | Exploring a problem across multiple dimensions |
| `enrich.md` | Content generation | Producing files from templates or enriching existing content |
| `audit.md` | Review/compliance | Checking artifacts against standards |
| `develop.md` | Sequential TDD | Implementing a multi-step plan |

## Rules (from CLAUDE.md Sub-Agent Dispatch Protocol)

1. **Max 5 parallel agents** — more risks context explosion
2. **Leave 40K token headroom** — for ingesting results
3. **Content generators write to disk** — return only file path + summary
4. **Investigators return summaries** — not raw file contents
5. **Include token hints** — tell agents to be concise
