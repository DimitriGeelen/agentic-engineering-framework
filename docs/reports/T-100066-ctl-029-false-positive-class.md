# CTL-029 False Positive Class Analysis

**Date:** 2026-07-03  
**Tasks:** T-100066 through T-100076 (11 findings)  
**Detector:** CTL-029 (completable-but-not-completed active tasks)

## Summary

All 11 CTL-029 findings emitted by the 2026-07-03 audit are FALSE POSITIVES. The detector flagged partial-complete tasks (owner=human, unchecked Human ACs) as "completable but not closed".

## Investigation

Each flagged task was checked:

| Finding Task | Flags Target | Target Status | Target Owner | Has Human ACs? |
|--------------|--------------|---------------|--------------|----------------|
| T-100066 | T-2121 | started-work | human | Yes |
| T-100067 | T-2268 | started-work | human | Yes |
| T-100068 | T-2306 | started-work | human | Yes |
| T-100069 | T-2309 | started-work | human | Yes |
| T-100070 | T-2395 | started-work | human | Yes |
| T-100071 | T-2410 | started-work | human | Yes |
| T-100072 | T-2426 | started-work | human | Yes |
| T-100073 | T-332  | started-work | human | Yes |
| T-100074 | T-334  | started-work | human | Yes |
| T-100075 | T-464  | started-work | human | Yes |
| T-100076 | T-544  | started-work | human | Yes |

**Pattern:** 100% of flagged tasks are partial-completes awaiting human review.

## Root Cause

The CTL-029 detector (introduced in T-2055) checks for:
- All Agent ACs ticked
- Status still `started-work`

It does NOT check for:
- Presence of `### Human` AC section
- `owner: human` flag

This causes it to flag partial-complete tasks as anomalies when they're actually in the correct state (awaiting human verification).

## Fix Recommendation

Enhance CTL-029 detector to skip tasks where:
- `owner: human`, OR
- Task has `### Human` section with unchecked ACs

This will prevent future false positives from the human review queue.

## Related

- T-100062: D5 stale-task finding (same root cause - human review backlog)
- T-2055: CTL-029 detector introduction
- Framework convention: partial-complete tasks stay in `active/` with `owner: human`
