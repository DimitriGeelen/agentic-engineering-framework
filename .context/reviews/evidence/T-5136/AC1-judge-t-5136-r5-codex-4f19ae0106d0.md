# Reviewer evidence — T-5136 AC#1

- dispatch: `judge-t-5136-r5-codex-4f19ae0106d0`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `527d33c296ed874df862d1c012d7b1a24856126f`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `6e4138ba638a45a0f2512e87001327ea351bf193f00d8132dadaa6a8f0f3ebea`
- result.md sha256: `c44b8e49f59f2b7f85017cd13abc2e99527145b015ef888b6ba2443a1f7f4e51`

## The worker's verdict block

```
1. [AC] The task list opens quickly and the pager is usable
VERDICT: not-evaluated
WHY: Both live URLs failed to connect from this sandbox (curl exit 7, HTTP 000). I could not measure rendering time, operate Next/Previous, or verify filter/sort retention. Reviewed all 18 supplied screenshots, including enlarged list headers and pager rows. At all three widths, page 1 shows “Showing 1–200 of 5125” and Next; page 2 shows “Showing 201–400 of 5125” with Previous and Next, without pager clipping or overlap. Search box, tag cloud, search suggestions, and fabric subsystem overview are visible without overlap at all three widths. The 1024px list screenshots cut off right-hand table columns; horizontal reachability cannot be established from screenshots. The recorded walkthrough timings are author claims, not independently verified results.
GUIDANCE: Route to a reviewer with browser access to 192.168.10.107:3000 to execute all four steps, measure load times, verify filter/sort retention through paging, and check horizontal table access at 1024px.

Evidence copies inspected:

--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/01-tasks-view-list.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/02-search.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/03-cockpit-activity.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/04-fabric.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/05-fabric-graph.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/06-tasks.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list-page2@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list-page2@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list-page2@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/search@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/search@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/search@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/fabric@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/fabric@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/fabric@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] The task list opens quickly and the pager is usable
VERDICT: not-evaluated
WHY: Both live URLs failed to connect from this sandbox (curl exit 7, HTTP 000). I could not measure rendering time, operate Next/Previous, or verify filter/sort retention. Reviewed all 18 supplied screenshots, including enlarged list headers and pager rows. At all three widths, page 1 shows “Showing 1–200 of 5125” and Next; page 2 shows “Showing 201–400 of 5125” with Previous and Next, without pager clipping or overlap. Search box, tag cloud, search suggestions, and fabric subsystem overview are visible without overlap at all three widths. The 1024px list screenshots cut off right-hand table columns; horizontal reachability cannot be established from screenshots. The recorded walkthrough timings are author claims, not independently verified results.
GUIDANCE: Route to a reviewer with browser access to 192.168.10.107:3000 to execute all four steps, measure load times, verify filter/sort retention through paging, and check horizontal table access at 1024px.

Evidence copies inspected:

--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/01-tasks-view-list.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/02-search.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/03-cockpit-activity.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/04-fabric.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/05-fabric-graph.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/06-tasks.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list-page2@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list-page2@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/list-page2@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/search@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/search@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/search@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/fabric@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/fabric@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-4f19ae0106d0/tmp/review-evidence/fabric@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
