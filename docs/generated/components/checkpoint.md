# checkpoint

> Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints.

**Type:** hook | **Subsystem:** budget-management | **Location:** `agents/context/checkpoint.sh`

**Tags:** `budget`, `checkpoint`, `context`, `hook`, `PostToolUse`, `auto-handover`

## What It Does

Context Checkpoint Agent — Token-aware context budget monitor
Reads actual token usage from Claude Code JSONL transcript to warn
before automatic compaction causes context loss.
Primary: Token-based warnings from JSONL transcript (checked every 5 calls)
Fallback: Tool call counter (when transcript unavailable)
Note: Token reading lags by ~1 API call (~10-30K behind actual).
Thresholds are set conservatively to account for this.
Usage:
checkpoint.sh post-tool   — Called by Claude Code PostToolUse hook
checkpoint.sh reset       — Reset tool call counter (on commit)

### Framework Reference

When fixing a bug discovered through real-world usage (user testing, production incident, cross-platform failure):
1. **Classify the bug** — Is this a new failure class, or a repeat of a known pattern?
2. **Check learnings.yaml** — Does a learning already exist for this class?
3. If new class: `fw context add-learning "description" --task T-XXX --source P-001`
4. If systemic (same class hit 2+ times): register in `concerns.yaml`, consider tooling fix (Level C/D)

*(truncated — see CLAUDE.md for full section)*

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `F-003` | reads |
| `F-003` | writes |
| `agents/handover/handover.sh` | calls |
| `lib/paths.sh` | calls |

## Used By (6)

| Component | Relationship |
|-----------|-------------|
| `C-009` | triggers |
| `agents/handover/handover.sh` | called_by |
| `C-004` | called_by |
| `agents/audit/self-audit.sh` | read_by |
| `bin/claude-fw` | read_by |
| `C-009` | triggers_by |

## Documentation

- [Deep Dive: Context Budget Management](docs/articles/deep-dives/03-context-budget.md) (deep-dive)

## Related

### Tasks
- T-596: Fix context budget thresholds — Anthropic reduced window to 200K without notice
- T-691: Agent approval notification — PostToolUse hook detects resolved Watchtower approvals and tells agent to retry
- T-694: Approval file lifecycle — cleanup resolved files older than 7 days, reset notified tracker on session init
- T-724: Sync vendor copies — T-722 settings changes to .agentic-framework
- T-791: Fix checkpoint.sh cross-project transcript leak — scope find_transcript to current project

---
*Auto-generated from Component Fabric. Card: `checkpoint.yaml`*
*Last verified: 2026-02-20*
