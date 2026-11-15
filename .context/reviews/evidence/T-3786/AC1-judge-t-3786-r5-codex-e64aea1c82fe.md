# Reviewer evidence — T-3786 AC#1

- dispatch: `judge-t-3786-r5-codex-e64aea1c82fe`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `84568c9d74419c8f99efc027dc45b614f93702bf`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `29859667b8b0d798ce3edb050633d56b483f3c9171a1ded21cc88023d239c1a9`
- result.md sha256: `92b0c3b910eb843371054798ae7c79cc5bb05da46c126d8a234bc45e7a546435`

## The worker's verdict block

```
1. [AC] Search and ask still work, and never rebuild the index from the page
VERDICT: not-evaluated
WHY: Inspected all 14 supplied screenshots. The search screenshot shows an empty query, without results. The search/ask screenshot shows “Query too short (min 2 characters)”, not an answer to the required question. I did not see /ask, /ask/stream, or /search/load-conversation. The task lacks ## Visual Verification. Neither the required interactions nor unavailable-index behavior were demonstrated.
GUIDANCE: Route to a reviewer with browser access to perform both specified queries and verify the unavailable-index message “rebuild with: fw index reindex” without starting a rebuild. Supply missing captures and visual verification evidence.

--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/01-search.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/02-root.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/05-health.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/06-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/07-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/08-gaps.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/09-api-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/10-api-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/11-search-ask.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/12-search-conversations.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/14-search-feedback-analytics.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/15-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/16-api-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/17-graduation.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Search and ask still work, and never rebuild the index from the page
VERDICT: not-evaluated
WHY: Inspected all 14 supplied screenshots. The search screenshot shows an empty query, without results. The search/ask screenshot shows “Query too short (min 2 characters)”, not an answer to the required question. I did not see `/ask`, `/ask/stream`, or `/search/load-conversation`. The task lacks `## Visual Verification`. Neither the required interactions nor unavailable-index behavior were demonstrated.
GUIDANCE: Route to a reviewer with browser access to perform both specified queries and verify the unavailable-index message “rebuild with: fw index reindex” without starting a rebuild. Supply missing captures and visual verification evidence.

--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/01-search.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/02-root.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/05-health.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/06-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/07-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/08-gaps.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/09-api-learnings.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/10-api-decisions.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/11-search-ask.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/12-search-conversations.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/14-search-feedback-analytics.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/15-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/16-api-patterns.png
--evidence /tmp/tl-dispatch/judge-t-3786-r5-codex-e64aea1c82fe/tmp/review-report/17-graduation.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
