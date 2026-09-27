# sessions_claude_code_adapter

> T-2417: Claude Code session adapter — verifies canonical-JSONL emission per agents/sessions/SCHEMA.md from a stubbed `claude agents --all --json` response.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/sessions_claude_code_adapter.bats`

## What It Does

T-2417: Claude Code session adapter — verifies canonical-JSONL emission per
agents/sessions/SCHEMA.md from a stubbed `claude agents --all --json` response.
We stub `claude` on PATH with canned JSON that covers the full state matrix
observed in the 2026-06-16 live probe:
- background sessions with `state` ∈ {blocked, done, failed}, `id` field
- interactive sessions with `status` ∈ {busy, idle}, `pid` field
- cwd inside a git repo (project=basename) vs cwd outside (project=loose)
AC mapping:
t1  no claude on PATH → exit 2 with diagnostic
t2  malformed JSON → exit 3

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [list](/docs/generated/agents-sessions-claude-code-list) | calls | Claude Code session adapter for fw sessions (T-2417): reads `claude agents --all --json` and emits canonical JSONL per agents/sessions/SCHEMA.md. |
| [list](/docs/generated/agents-sessions-claude-code-list) | tests | Claude Code session adapter for fw sessions (T-2417): reads `claude agents --all --json` and emits canonical JSONL per agents/sessions/SCHEMA.md. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-sessions_claude_code_adapter.yaml`*
*Last verified: 2026-06-16*
