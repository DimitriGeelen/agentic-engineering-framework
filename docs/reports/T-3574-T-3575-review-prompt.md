You are an INDEPENDENT REVIEWER (not the builder). EVALUATE, do not rubber-stamp. Verdicts: green / amber / red / escalate, each with mandatory guidance. Repo /opt/999-Agentic-Engineering-Framework: read-only EXCEPT your one report file. No commits, no fw task verbs.

Two performance fixes changed pages the operator uses daily. Judge whether each page still RENDERS and BEHAVES correctly, and whether the speed claims hold. Read:
- .tasks/active/T-3574-*.md and .tasks/active/T-3575-*.md (Context, criteria, recommendation)
- docs/reports/T-3574-T-3575-perf-notes.md (the builder's numbers)
- commits: `git log --oneline -12`, then the T-3574 and T-3575 diffs

Evidence (open with Read):
- /tmp/playwright-mcp/review/tasks-after.png: /tasks after the change
- /tmp/playwright-mcp/review/arc-continuous-after.png and arc-continuous-bvp-after.png: /arcs/continuous-run top, and its BVP section
Live: http://192.168.10.107:3002/tasks and http://192.168.10.107:3002/arcs/continuous-run (curl and time them yourself).

## T-3574 (arc page, 12-108s to about 1s)
The builder claims the BVP numbers are byte-identical before and after (tests/web/test_t3574_arc_page_perf.py). Check that test really compares the new code against the old algorithm, not the new code against itself. Does the arc page render unchanged?

## T-3575 (tasks page, 1.04MB to 305KB, cold 3.35s to 0.18s)
It caps board columns and trims markup. Check:
- **Nothing the operator relied on is gone.** Every filter, search, view, the ability to reach any task including completed ones, and bulk actions must still be reachable.
- **Stale data.** The cache is now change-driven with a 300s safety TTL. Can a changed task ever show stale on the page? Check the invalidation logic.
- **The open criterion.** "Warm DOMContentLoaded under 500ms" is unticked. Measured: 527-592ms (builder), and 494ms from a blank page (parent). Is that met, nearly met, or not met? Should the criterion stand, or is the page fast enough for its purpose? Give your call and why. Do not quietly move the target: if you recommend changing it, say so explicitly with the reason.

Write docs/reports/T-3574-T-3575-render-review.md with one section per task: VERDICT, WHAT I CHECKED, GUIDANCE. Print only the two verdict lines.
