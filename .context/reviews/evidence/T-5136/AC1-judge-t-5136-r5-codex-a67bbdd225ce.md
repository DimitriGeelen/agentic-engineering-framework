# Reviewer evidence — T-5136 AC#1

- dispatch: `judge-t-5136-r5-codex-a67bbdd225ce`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `d40b15e3f677ea0f7245fada4a544d2570aa4e7d`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `4d226d036a3e5574d88f65bdbd639c3a62c7969187675b2cdb0c573275094188`
- result.md sha256: `5f8115a77a5b6a5950665096520c2fe2b7167796c74721e099f9e0264333eb16`

## The worker's verdict block

```
1. [AC] The task list opens quickly and the pager is usable
VERDICT: not-evaluated
WHY: Both specified URLs failed to connect from this sandbox: curl exit 7, after 0 ms. No browser tool was available. I therefore could not verify loading times, Next/Previous interactions, or preservation of filter and sort.

I inspected all 18 supplied screenshots and enlarged the table headers and pager regions. Visual checklist findings:

| Control | 1024 | 1440 | 1920 |
|---|---|---|---|
| List table | Owner column partially clipped; later columns outside visible area | Visible, no overlap observed | Visible, no overlap observed |
| Page 1 pager | Count and Next visible, unclipped | Same | Same |
| Page 2 pager | Previous, count and Next visible, unclipped | Same | Same |
| Search box | Visible, unclipped | Same | Same |
| Tag cloud | Visible, no overlap | Same | Same |
| Try-a-search | Visible, no overlap | Same | Same |
| Fabric subsystem overview | Visible, no overlap observed | Same | Same |

Page 1 screenshots show “Showing 1–200 of 5125”; page 2 shows “Showing 201–400 of 5125”. Static images cannot establish interactive reachability or timing. The other required screenshots were inspected; graph labels overlap, and the board screenshot contains truncated card controls, outside this criterion’s specified list/search workflow.

GUIDANCE: Route to a reviewer with browser access to 192.168.10.107:3000. Perform all four steps, measure visibility times, and verify filter/sort preservation through paging. At 1024 px, also check horizontal access to the table’s remaining columns. The task’s written timing claims were not independently verified.

Evidence copies:

text
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/01-tasks-view-list.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/02-search.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/03-cockpit-activity.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/04-fabric.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/05-fabric-graph.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/06-tasks.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list-page2@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list-page2@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list-page2@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/search@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/search@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/search@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/fabric@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/fabric@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/fabric@1920.png


Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] The task list opens quickly and the pager is usable
VERDICT: not-evaluated
WHY: Both specified URLs failed to connect from this sandbox: curl exit 7, after 0 ms. No browser tool was available. I therefore could not verify loading times, Next/Previous interactions, or preservation of filter and sort.

I inspected all 18 supplied screenshots and enlarged the table headers and pager regions. Visual checklist findings:

| Control | 1024 | 1440 | 1920 |
|---|---|---|---|
| List table | Owner column partially clipped; later columns outside visible area | Visible, no overlap observed | Visible, no overlap observed |
| Page 1 pager | Count and Next visible, unclipped | Same | Same |
| Page 2 pager | Previous, count and Next visible, unclipped | Same | Same |
| Search box | Visible, unclipped | Same | Same |
| Tag cloud | Visible, no overlap | Same | Same |
| Try-a-search | Visible, no overlap | Same | Same |
| Fabric subsystem overview | Visible, no overlap observed | Same | Same |

Page 1 screenshots show “Showing 1–200 of 5125”; page 2 shows “Showing 201–400 of 5125”. Static images cannot establish interactive reachability or timing. The other required screenshots were inspected; graph labels overlap, and the board screenshot contains truncated card controls, outside this criterion’s specified list/search workflow.

GUIDANCE: Route to a reviewer with browser access to 192.168.10.107:3000. Perform all four steps, measure visibility times, and verify filter/sort preservation through paging. At 1024 px, also check horizontal access to the table’s remaining columns. The task’s written timing claims were not independently verified.

Evidence copies:

```text
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/01-tasks-view-list.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/02-search.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/03-cockpit-activity.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/04-fabric.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/05-fabric-graph.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/06-tasks.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list-page2@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list-page2@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/list-page2@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/search@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/search@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/search@1920.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/fabric@1024.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/fabric@1440.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-a67bbdd225ce/tmp/review-evidence/fabric@1920.png
```

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
