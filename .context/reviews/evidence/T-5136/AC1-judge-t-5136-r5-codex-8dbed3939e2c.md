# Reviewer evidence — T-5136 AC#1

- dispatch: `judge-t-5136-r5-codex-8dbed3939e2c`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `aa5c2bb76f5c5c108c760fdbb0b163a1c8fe8a95`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `9bf74ca7240141e163f80dc0de4cde55736396d5d31d65ff7b822b300dc9541e`
- result.md sha256: `18474d876328b6a4ca526ae8c184de56a069b41c430d87472f8465b2cda2c82c`

## The worker's verdict block

```
1. [AC] The task list opens quickly and the pager is usable
VERDICT: not-evaluated
WHY: Both specified URLs failed to connect from this sandbox (curl exit 7; no HTTP response). I could not measure loading speed, exercise Next/Previous, or verify filter/sort retention. Existing timing claims were not independently verified.

I inspected all 18 supplied screenshots, plus enlarged top/bottom crops of all six list screenshots:

| Checklist control | 1024 | 1440 | 1920 |
|---|---|---|---|
| List table | Owner controls clipped at right; later columns not visible | No visible clipping or overlap | No visible clipping or overlap |
| Page 1 pager | Count and Next visible, unobstructed | Same | Same |
| Page 2 pager | Previous, count and Next visible, unobstructed | Same | Same |
| Search box | Visible, unclipped | Same | Same |
| Tag cloud | Visible, no overlap | Same | Same |
| Try-a-search | Visible, unclipped | Same | Same |
| Fabric subsystem overview | Cards visible, no overlap | Same | Same |

Page 1 screenshots show “Showing 1–200 of 5125”; page 2 shows “Showing 201–400 of 5125”. Screenshots establish appearance, not interactive reachability. The six additional rendered-page screenshots were also inspected; the task-list and board captures show only their tops.

GUIDANCE: Route this criterion to a reviewer with access to 192.168.10.107:3000 to time both pages and exercise paging after selecting a filter and sort. Also verify horizontal access to the clipped table columns at 1024px; the checklist’s unconditional “ok” is not established by those screenshots.

Evidence copies, paths relative to the export working directory:

--evidence ../tmp/review-T-5136-codex/rendered/01-tasks-view-list.png
--evidence ../tmp/review-T-5136-codex/rendered/02-search.png
--evidence ../tmp/review-T-5136-codex/rendered/03-cockpit-activity.png
--evidence ../tmp/review-T-5136-codex/rendered/04-fabric.png
--evidence ../tmp/review-T-5136-codex/rendered/05-fabric-graph.png
--evidence ../tmp/review-T-5136-codex/rendered/06-tasks.png
--evidence ../tmp/review-T-5136-codex/visual/list@1024.png
--evidence ../tmp/review-T-5136-codex/visual/list@1440.png
--evidence ../tmp/review-T-5136-codex/visual/list@1920.png
--evidence ../tmp/review-T-5136-codex/visual/list-page2@1024.png
--evidence ../tmp/review-T-5136-codex/visual/list-page2@1440.png
--evidence ../tmp/review-T-5136-codex/visual/list-page2@1920.png
--evidence ../tmp/review-T-5136-codex/visual/search@1024.png
--evidence ../tmp/review-T-5136-codex/visual/search@1440.png
--evidence ../tmp/review-T-5136-codex/visual/search@1920.png
--evidence ../tmp/review-T-5136-codex/visual/fabric@1024.png
--evidence ../tmp/review-T-5136-codex/visual/fabric@1440.png
--evidence ../tmp/review-T-5136-codex/visual/fabric@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] The task list opens quickly and the pager is usable
VERDICT: not-evaluated
WHY: Both specified URLs failed to connect from this sandbox (`curl` exit 7; no HTTP response). I could not measure loading speed, exercise Next/Previous, or verify filter/sort retention. Existing timing claims were not independently verified.

I inspected all 18 supplied screenshots, plus enlarged top/bottom crops of all six list screenshots:

| Checklist control | 1024 | 1440 | 1920 |
|---|---|---|---|
| List table | Owner controls clipped at right; later columns not visible | No visible clipping or overlap | No visible clipping or overlap |
| Page 1 pager | Count and Next visible, unobstructed | Same | Same |
| Page 2 pager | Previous, count and Next visible, unobstructed | Same | Same |
| Search box | Visible, unclipped | Same | Same |
| Tag cloud | Visible, no overlap | Same | Same |
| Try-a-search | Visible, unclipped | Same | Same |
| Fabric subsystem overview | Cards visible, no overlap | Same | Same |

Page 1 screenshots show “Showing 1–200 of 5125”; page 2 shows “Showing 201–400 of 5125”. Screenshots establish appearance, not interactive reachability. The six additional rendered-page screenshots were also inspected; the task-list and board captures show only their tops.

GUIDANCE: Route this criterion to a reviewer with access to `192.168.10.107:3000` to time both pages and exercise paging after selecting a filter and sort. Also verify horizontal access to the clipped table columns at 1024px; the checklist’s unconditional “ok” is not established by those screenshots.

Evidence copies, paths relative to the export working directory:

--evidence ../tmp/review-T-5136-codex/rendered/01-tasks-view-list.png
--evidence ../tmp/review-T-5136-codex/rendered/02-search.png
--evidence ../tmp/review-T-5136-codex/rendered/03-cockpit-activity.png
--evidence ../tmp/review-T-5136-codex/rendered/04-fabric.png
--evidence ../tmp/review-T-5136-codex/rendered/05-fabric-graph.png
--evidence ../tmp/review-T-5136-codex/rendered/06-tasks.png
--evidence ../tmp/review-T-5136-codex/visual/list@1024.png
--evidence ../tmp/review-T-5136-codex/visual/list@1440.png
--evidence ../tmp/review-T-5136-codex/visual/list@1920.png
--evidence ../tmp/review-T-5136-codex/visual/list-page2@1024.png
--evidence ../tmp/review-T-5136-codex/visual/list-page2@1440.png
--evidence ../tmp/review-T-5136-codex/visual/list-page2@1920.png
--evidence ../tmp/review-T-5136-codex/visual/search@1024.png
--evidence ../tmp/review-T-5136-codex/visual/search@1440.png
--evidence ../tmp/review-T-5136-codex/visual/search@1920.png
--evidence ../tmp/review-T-5136-codex/visual/fabric@1024.png
--evidence ../tmp/review-T-5136-codex/visual/fabric@1440.png
--evidence ../tmp/review-T-5136-codex/visual/fabric@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
