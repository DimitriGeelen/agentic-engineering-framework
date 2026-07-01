# AGENT: check-task-ac-structure

**Type:** PreToolUse Hook  
**Trigger:** Write | Edit | MultiEdit on `.tasks/{active,completed}/T-*.md`  
**Origin:** T-2420 (implements T-2418 GO)

## Purpose

Prevents `### Human` headings from appearing outside the `## Acceptance Criteria` block in task files. This closes the T-2417 loss class where inserting `## ` headings between `### Agent` and `### Human` made the Human ACs invisible to the parser.

## Detection Logic

The hook:
1. Parses both old and new content for `### Human` headings
2. Counts malformed instances (those outside the AC block)
3. Blocks if NEW count > OLD count (introducing/worsening)
4. Passes if NEW count ≤ OLD count (fixing or preserving grandfathered state)

The AC block starts at `## Acceptance Criteria` and ends at the next `## ` heading.

## Exit Codes

- `0` — Allow (correct structure, fixing malformation, or grandfathered)
- `2` — Block (under agent control, introducing malformation, no override)

## Override

```bash
FW_ALLOW_AC_STRUCTURE_DRIFT=1
```

Bypasses the gate with Tier-2 log entry to `.context/working/.gate-bypass-log.yaml`.

## Grandfather Logic (No-Worse-Than)

The hook implements no-worse-than semantics:
- **Introducing** malformation (0 → 1): blocked
- **Worsening** malformation (1 → 2): blocked
- **Preserving** malformation (1 → 1): allowed
- **Fixing** malformation (2 → 1): allowed

This makes the rollout zero-risk — existing offenders (28 tasks / 1.2% as of 2026-07-01) cause no new friction. Legitimate edits to those files pass through unchanged.

## Why This Matters

`update-task.sh` extracts ACs using:
```bash
sed -n '/^## Acceptance Criteria/,/^## /p'
```

This pattern:
1. Starts capture at `## Acceptance Criteria`
2. Ends capture at the *next* `## ` heading

If you insert `## Build Summary` between `### Agent` and `### Human`, the sed command stops capturing before it reaches the Human ACs. The parser sees 0 Human ACs, the partial-complete gate doesn't fire, and the task completes with Human ACs unverified.

## Test Coverage

`tests/unit/check_task_ac_structure.bats` — 10 tests:
1. Correct structure passes
2. No Human heading passes
3. Non-task files pass through
4. Introducing malformation blocks under agent control
5. Override allows with log
6. Fixing malformation (decreasing count) passes
7. Preserving malformation (same count) passes
8. Worsening malformation (increasing count) blocks
9. Advisory mode when not under agent control
10. Edit tool detects malformation

## Wiring

Add to `.claude/settings.json` PreToolUse hooks (Write|Edit matcher):

```json
{
  "type": "command",
  "command": "/opt/999-Agentic-Engineering-Framework/bin/fw hook check-task-ac-structure"
}
```

After wiring, refresh the enforcement baseline:
```bash
bin/fw enforcement baseline
```

## Pattern

Mirrors `check-inception-decisions.py` (T-1984):
- Python implementation + shell wrapper
- Parse-old-then-new content comparison
- Agent-vs-human exit code gating
- Tier-2 bypass logging
- Standardized block message format
