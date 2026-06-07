# costs

> Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/costs.sh`

## What It Does

costs.sh — Token usage tracking from JSONL transcripts (T-801)
Parses Claude Code session JSONL transcripts to report token usage.
Subscription model: cost measured in tokens consumed, not dollars.
Data source: ~/.claude/projects/<project-dir>/*.jsonl
Usage (via bin/fw):
fw costs              # Project summary
fw costs session      # Per-session breakdown
fw costs session ID   # Detailed session view
fw costs help         # Show usage
Follows T-799 (GO) and T-800 (GO) inception decisions.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [costs](/docs/generated/web-blueprints-costs) | calls | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [lib_costs tests](/docs/generated/tests-unit-lib_costs) | called-by | 26 bats unit tests for lib/costs.sh — path computation, routing, JSONL parsing, edge cases (T-807) |
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_costs tests](/docs/generated/tests-unit-lib_costs) | called_by | 26 bats unit tests for lib/costs.sh — path computation, routing, JSONL parsing, edge cases (T-807) |
| [lib_costs tests](/docs/generated/tests-unit-lib_costs) | tests_by | 26 bats unit tests for lib/costs.sh — path computation, routing, JSONL parsing, edge cases (T-807) |
| [claude_code](/docs/generated/web-terminal-adapters-claude_code) | called_by | Terminal adapter that spawns Claude Code agent sessions via PTY using claude -p (prompt) or claude -c (interactive) commands |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-costs.yaml`*
*Last verified: 2026-04-03*
