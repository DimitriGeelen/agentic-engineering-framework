# Reviewer evidence — T-5136 AC#1

- dispatch: `judge-t-5136-r5-codex-8d7d3da61aa7`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `34bc15411c2c6cf4895387b6975fbe4dd0461eab`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `fe78ce07a05b9dcd4523425fcd92b4615ffd4e28ac732b3332ad0f5ebcc76def`
- result.md sha256: `309cc8d6853c41bc3ede2c46b5e38fbf9279ea56d127526bfaf42194d08fecff`

## The worker's verdict block

```
1. [AC] The task list opens quickly and the pager is usable
VERDICT: not-evaluated
WHY: Inspected all six supplied screenshots. The task list and search tag cloud are visible, but the list screenshot ends before the pager. Static screenshots cannot establish loading times or filter/sort persistence during paging. The brief explicitly reports no ## Visual Verification section and requires not-evaluated for this render criterion; the required state-by-width evidence and bottom-of-table crops are unavailable.
GUIDANCE: Supply the Visual Verification checklist and screenshots for every configured width, including the pager. A browser-capable reviewer must measure list/search loading times, verify “Showing 1–200 of …”, exercise Next and Previous, and confirm filter/sort persistence.

--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/01-tasks-view-list.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/02-search.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/03-cockpit-activity.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/04-fabric.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/05-fabric-graph.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/06-tasks.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] The task list opens quickly and the pager is usable
VERDICT: not-evaluated
WHY: Inspected all six supplied screenshots. The task list and search tag cloud are visible, but the list screenshot ends before the pager. Static screenshots cannot establish loading times or filter/sort persistence during paging. The brief explicitly reports no `## Visual Verification` section and requires not-evaluated for this render criterion; the required state-by-width evidence and bottom-of-table crops are unavailable.
GUIDANCE: Supply the Visual Verification checklist and screenshots for every configured width, including the pager. A browser-capable reviewer must measure list/search loading times, verify “Showing 1–200 of …”, exercise Next and Previous, and confirm filter/sort persistence.

--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/01-tasks-view-list.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/02-search.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/03-cockpit-activity.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/04-fabric.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/05-fabric-graph.png
--evidence /tmp/tl-dispatch/judge-t-5136-r5-codex-8d7d3da61aa7/tmp/review-evidence/T-5136/06-tasks.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
