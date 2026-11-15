# Reviewer evidence — T-3786 AC#1

- dispatch: `judge-t-3786-r5-codex-ccb262d7623b`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `3e064047d67404b9db6fd39f0d1c546bbfa94866`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `da9178648213e62f5ade8ad3a094d2de6de8ffc38c71f8c29c5679b087560329`
- result.md sha256: `12412a57668ef62c7c12bc1bd5258cbb79bc6cd698c8cc0a9a9df1f2be472e20`

## The worker's verdict block

```
1. [AC] Search and ask still work, and never rebuild the index from the page
VERDICT: not-evaluated
WHY: Inspected all 23 supplied screenshots. Search results show 20 matches for “vector index” at 1024, 1440 and 1920 px. Search controls, topic clouds, result lists, Ask panels and question inputs appear without overlap. Ask model selectors appear blank and narrow; interactive usability could not be verified. No supplied screenshot shows the requested question answered; /search/ask shows only “Query too short.” The referenced walkthrough screenshots and walk.json are absent. The live URL failed to connect (curl exit 7), preventing independent interaction. Static inspection confirms _get_db() raises instead of rebuilding and the ask stream emits “rebuild with: fw index reindex” before returning when unavailable, but runtime behavior remains unverified.
GUIDANCE: Route to a reviewer with browser access to the live service. Execute both specified interactions, observe the answer, and verify the unavailable-index message and absence of a rebuild using an isolated fixture. Inspect the loaded model selector at each configured width. Evidence copies are byte-identical; the export was not modified.

--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/01-search.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/02-root.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/03-health.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/04-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/05-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/06-gaps.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/07-api-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/08-api-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/09-search-ask.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/10-search-conversations.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/11-search-feedback-analytics.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/12-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/13-api-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/14-graduation.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search@1920.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search-results@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search-results@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search-results@1920.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/ask@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/ask@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/ask@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Search and ask still work, and never rebuild the index from the page
VERDICT: not-evaluated
WHY: Inspected all 23 supplied screenshots. Search results show 20 matches for “vector index” at 1024, 1440 and 1920 px. Search controls, topic clouds, result lists, Ask panels and question inputs appear without overlap. Ask model selectors appear blank and narrow; interactive usability could not be verified. No supplied screenshot shows the requested question answered; `/search/ask` shows only “Query too short.” The referenced walkthrough screenshots and walk.json are absent. The live URL failed to connect (curl exit 7), preventing independent interaction. Static inspection confirms `_get_db()` raises instead of rebuilding and the ask stream emits “rebuild with: fw index reindex” before returning when unavailable, but runtime behavior remains unverified.
GUIDANCE: Route to a reviewer with browser access to the live service. Execute both specified interactions, observe the answer, and verify the unavailable-index message and absence of a rebuild using an isolated fixture. Inspect the loaded model selector at each configured width. Evidence copies are byte-identical; the export was not modified.

--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/01-search.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/02-root.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/03-health.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/04-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/05-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/06-gaps.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/07-api-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/08-api-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/09-search-ask.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/10-search-conversations.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/11-search-feedback-analytics.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/12-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/13-api-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/rendered/14-graduation.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search@1920.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search-results@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search-results@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/search-results@1920.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/ask@1024.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/ask@1440.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-ccb262d7623b/tmp/report/T-3786/visual/ask@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
