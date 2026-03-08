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
4. If systemic (same class hit 2+ times): register in `gaps.yaml`, consider tooling fix (Level C/D)

*(truncated — see CLAUDE.md for full section)*

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `F-003` | reads |
| `F-003` | writes |
| `agents/handover/handover.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `C-009` | triggers |
| `agents/handover/handover.sh` | called_by |
| `C-004` | called_by |

## Documentation

- [Deep Dive: Context Budget Management](docs/articles/deep-dives/03-context-budget.md) (deep-dive)

## Related

### Tasks
- T-175: Eliminate emergency/full handover distinction — single handover
- T-176: Adjust budget gate thresholds for no-compaction architecture
- T-177: Clean up compact hooks for manual-only use
- T-182: Reframe handover messaging from emergency panic to calm wrap-up
- T-194: ISO 27001-aligned assurance model — control register, OE testing, risk-driven cron redesign

---
*Auto-generated from Component Fabric. Card: `checkpoint.yaml`*
*Last verified: 2026-02-20*
