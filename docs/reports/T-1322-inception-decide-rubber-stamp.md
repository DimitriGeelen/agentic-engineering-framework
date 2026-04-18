# T-1322: fw inception decide doesn't tick the RUBBER-STAMP Human AC

**Source:** termlink T-1130 pickup (P-039)
**Status:** GO — build sibling T-1324 (next session)
**Date:** 2026-04-18

## Bug

`fw inception decide T-XXX go|no-go` writes a Decision block, an Updates entry, and may set `status=work-completed`. But the corresponding `### Human` AC — typically:

```
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
```

remains unchecked. Per the Human-AC rule (T-372/T-373), unchecked Human ACs keep tasks in `.tasks/active/`. Inception tasks therefore land in "partial-complete" forever after their decision is recorded — directly contributing to G-008 ("64 tasks stuck in partial-complete").

## Root Cause

`lib/inception.sh:do_inception_decide` performs the following:
1. Validates inputs and gate state (sovereignty, recommendation present)
2. Appends `## Decision` block + Updates entry
3. Optionally calls update-task to set `status=work-completed`

It **never modifies** the `## Acceptance Criteria` `### Human` section. The unchecked box stays unchecked.

## Why GO

- Concrete bug — `decide` is the action the AC describes; leaving the box unchecked is incoherent
- Termlink: 10 tasks stuck (T-947–T-959) verified
- G-008: 64 tasks stuck in partial-complete; this is one of the contributors
- Fix is surgical, idempotent, and reversible
- Risk near zero — only ticks the box if it matches the AC text predicate

## Build Plan (T-1324, next session)

After writing the Decision block:

1. Locate `### Human` section in the task file
2. Find unchecked ACs whose text matches:
   - `[RUBBER-STAMP].*[Rr]ecord.*decision`, OR
   - `[REVIEW].*go/no-go decision`
3. Replace the leading `- [ ]` with `- [x]` for matched lines (line-level, idempotent)
4. Re-run the work-completed gate so the task auto-moves to `.tasks/completed/` if all other ACs are now satisfied
5. Bats regression:
   - Create an inception task with the framework's default template
   - Run `fw inception decide T-XXX go --rationale ...`
   - Assert: the `[REVIEW] Review exploration findings` AC is now `[x]`
   - Assert: the task file moved to `.tasks/completed/`

## Why Defer Build to Next Session

- Context budget already at 78% (warn level)
- Fix touches `lib/inception.sh` (load-bearing) and benefits from fresh attention
- Edge cases worth careful design:
  - What if the human added a custom Human AC that also mentions "decision"? (We must be specific to the templated text to avoid over-matching.)
  - What if the file has already been hand-edited and the box is checked? (Idempotency — must not error.)
  - What about `no-go` decisions? (Same path; same AC tick.)

## Decision Trail

- Source pickup: `.context/pickup/processed/P-039-bug-report.yaml`
- Inception: `.tasks/active/T-1322-pickup-fw-inception-decide-doesnt-tick-t.md`
- Build sibling: T-1324 (to be created next session)
- Recommendation: GO (build deferred)
