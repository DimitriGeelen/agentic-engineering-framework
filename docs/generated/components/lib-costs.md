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

| Target | Relationship |
|--------|-------------|
| `lib/colors.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | calls |
| `web/blueprints/costs.py` | calls |
| `agents/handover/handover.sh` | calls |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-costs.yaml`*
*Last verified: 2026-04-03*
