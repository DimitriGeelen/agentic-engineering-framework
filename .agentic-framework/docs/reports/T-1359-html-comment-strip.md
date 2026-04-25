# T-1359: Strip HTML comments from placeholder detector — research artifact

## Context

Pickup from termlink (source T-1167) reports Watchtower approvals page shows `ERROR: Placeholder content detected in task file` for tasks whose only unfilled content is the default Decisions-section HTML comment. The fix proposed: strip `<!-- ... -->` blocks before placeholder pattern match.

## Detector source

Single shell source: `lib/task-audit.sh:audit_task_placeholders` (line 21).

Regex pattern set (line 73):
```
\[Criterion [0-9]+\]|\[TODO\]|\[PLACEHOLDER\]|\[Your recommendation here\]|\[REQUIRED before
```

Existing exemptions:
- Fenced code blocks (` ```...``` `) — toggle at line 41
- Inline backtick spans (`` `...` ``) — stripped at line 68 (T-1327)
- `## Updates` section — exempt (line 48)
- `## Dialogue Log` section — exempt (line 52)

## Test results on own templates

| Template | Detector verdict |
|---|---|
| `.tasks/templates/inception.md` | PASSED (no false positive on Decisions comment) |
| `.tasks/templates/default.md` | PASSED |

Current framework templates do NOT trigger the detector. The termlink-side false positive requires inspection of termlink's T-243 task file (cross-machine, not performed).

## False-positive survey (active tasks)

Ran detector against all `.tasks/active/*.md`:
- `T-436-auto-compact-yolo-mode-automatic-compact.md` FAILS on lines 63, 76 — prose legitimately mentions `[TODO]` in discussion of handover quality, not as unfilled slot.

This is a **related but distinct** false-positive class:
- T-1359's target: `[TODO]`-like patterns inside `<!-- ... -->` (non-rendered content)
- T-436's pattern: `[TODO]`-like patterns in prose that *discusses* the pattern

This inception is scoped to comment-content only.

## Proposed fix

Extend `audit_task_placeholders` to skip content inside `<!-- ... -->` blocks, mirroring the existing fence-toggle pattern for multi-line comments:

```bash
# Toggle HTML comment block state (<!-- ... -->)
if [[ "$line" =~ \<!-- ]]; then
    in_comment=1
fi
[ $in_comment -eq 1 ] && {
    [[ "$line" =~ --\> ]] && in_comment=0
    continue
}
```

Single-line comments (`<!-- content -->`) handled by sed preprocess before the per-line regex check.

## Regression tests

Add 4 bats cases to `tests/unit/lib_task_audit.bats`:
1. `[TODO]` inside `<!-- ... -->` → PASSED
2. `[TODO]` outside any comment → FAILED (still triggers)
3. Mixed: one comment + one real placeholder → FAILED on the real one
4. Nested: comment containing inline backticks → PASSED

## Build plan

- **B1** (~1 session): Patch `lib/task-audit.sh`, add 4 bats tests, ~90 min.
- **B2** (optional): Update `tests/integration/audit_blocks_review_and_decide.bats` with new exemption case.

## Related work

- T-1113: Placeholder audit chokepoint introduced.
- T-1298: DEFER'd a different framing (generic Go/No-Go defaults) — not the same class.
- T-1327: Inline-backtick false-positive stripped. This extends the same exempt-content pattern to HTML comments.

## Decision trail

See task file `.tasks/active/T-1359-pickup-watchtower-placeholder-detector-m.md` for full Recommendation GO, Evidence, and B1/B2 build plan.
