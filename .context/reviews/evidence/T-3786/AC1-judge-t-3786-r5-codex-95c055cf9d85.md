# Reviewer evidence — T-3786 AC#1

- dispatch: `judge-t-3786-r5-codex-95c055cf9d85`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `9083570c3b2b12e906fe69b356c5cddee117f374`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `d4762b588849ac7af3c2c95488adb3876f475e794cc035ffdb3a9105d445d1ae`
- result.md sha256: `881aadfe1d13f2c1127db927a59055b1674f6c8267cb8726474d0420e8042c59`

## The worker's verdict block

```
1. [AC] Search and ask still work, and never rebuild the index from the page
VERDICT: not-evaluated
WHY: Inspected all 23 supplied screenshots. Search results show 20 matches for “vector index,” including T-3786, at all three widths. Search controls and Ask input are visible without overlap; model selectors appear blank/narrow. No screenshot shows the requested answer. /search/ask shows only “Query too short.” Required captures for /ask, /ask/stream, and /search/load-conversation are missing. Static inspection confirms unavailable-index reporting without builder calls in the inspected branches, but unavailable-index browser behavior was not observed.
GUIDANCE: Route to a browser-capable reviewer to complete both specified interactions, capture the missing pages, verify model selection, and exercise an unavailable index in an isolated environment to confirm the remedy appears and no rebuild starts.

--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/01-search.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/02-root.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/05-health.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/06-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/07-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/08-gaps.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/09-api-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/10-api-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/11-search-ask.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/12-search-conversations.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/14-search-feedback-analytics.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/15-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/16-api-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/17-graduation.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search@1920.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search-results@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search-results@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search-results@1920.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/ask@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/ask@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/ask@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Search and ask still work, and never rebuild the index from the page
VERDICT: not-evaluated
WHY: Inspected all 23 supplied screenshots. Search results show 20 matches for “vector index,” including T-3786, at all three widths. Search controls and Ask input are visible without overlap; model selectors appear blank/narrow. No screenshot shows the requested answer. `/search/ask` shows only “Query too short.” Required captures for `/ask`, `/ask/stream`, and `/search/load-conversation` are missing. Static inspection confirms unavailable-index reporting without builder calls in the inspected branches, but unavailable-index browser behavior was not observed.
GUIDANCE: Route to a browser-capable reviewer to complete both specified interactions, capture the missing pages, verify model selection, and exercise an unavailable index in an isolated environment to confirm the remedy appears and no rebuild starts.

--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/01-search.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/02-root.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/05-health.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/06-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/07-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/08-gaps.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/09-api-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/10-api-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/11-search-ask.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/12-search-conversations.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/14-search-feedback-analytics.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/15-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/16-api-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/17-graduation.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search@1920.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search-results@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search-results@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/search-results@1920.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/ask@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/ask@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-95c055cf9d85/tmp/report/ask@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
