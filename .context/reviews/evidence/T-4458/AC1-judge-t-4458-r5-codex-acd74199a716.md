# Reviewer evidence — T-4458 AC#1

- dispatch: `judge-t-4458-r5-codex-acd74199a716`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `2d39ac6d4a222e9ec96434f1db20885abad4efe2`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `1866ae63b1ec169f182eb3cd076c9b22ae905b30d87a84e4fbca8c2007d1ad80`
- result.md sha256: `fbfd2f21daf5bb84e2a6e90bade48121ce6cc910e7a3ab6c6c647ddac16811a4`

## The worker's verdict block

```
## AC1 Degraded-search notice reads clearly and the page stays usable
Vote: not-evaluated
Evidence: image: .context/working/judge-evidence/T-4458/01-search.png region 40,150,1200,540
Location: .context/working/judge-evidence/T-4458/01-search.png region 40,150,1200,540
Evidence: image: .context/working/judge-evidence/T-4458/02-root.png region 40,150,1200,710
Location: .context/working/judge-evidence/T-4458/02-root.png region 40,150,1200,710
Evidence: image: .context/working/judge-evidence/T-4458/03-decisions.png region 40,185,1200,773
Location: .context/working/judge-evidence/T-4458/03-decisions.png region 40,185,1200,773
Evidence: image: .context/working/judge-evidence/T-4458/04-learnings.png region 40,185,1200,746
Location: .context/working/judge-evidence/T-4458/04-learnings.png region 40,185,1200,746
Evidence: image: .context/working/judge-evidence/T-4458/05-gaps.png region 0,0,460,900
Location: .context/working/judge-evidence/T-4458/05-gaps.png region 0,0,460,900
Evidence: image: .context/working/judge-evidence/T-4458/06-api-learnings.png region 0,0,1280,900
Location: .context/working/judge-evidence/T-4458/06-api-learnings.png region 0,0,1280,900
Evidence: image: .context/working/judge-evidence/T-4458/07-api-decisions.png region 0,0,1280,900
Location: .context/working/judge-evidence/T-4458/07-api-decisions.png region 0,0,1280,900
Evidence: image: .context/working/judge-evidence/T-4458/08-search-ask.png region 0,0,1280,100
Location: .context/working/judge-evidence/T-4458/08-search-ask.png region 0,0,1280,100
Evidence: image: .context/working/judge-evidence/T-4458/09-search-conversations.png region 0,0,1280,100
Location: .context/working/judge-evidence/T-4458/09-search-conversations.png region 0,0,1280,100
Evidence: image: .context/working/judge-evidence/T-4458/10-search-feedback-analytics.png region 40,150,1200,365
Location: .context/working/judge-evidence/T-4458/10-search-feedback-analytics.png region 40,150,1200,365
Evidence: image: .context/working/judge-evidence/T-4458/11-patterns.png region 0,0,610,900
Location: .context/working/judge-evidence/T-4458/11-patterns.png region 0,0,610,900
Evidence: image: .context/working/judge-evidence/T-4458/12-api-patterns.png region 0,0,1280,900
Location: .context/working/judge-evidence/T-4458/12-api-patterns.png region 0,0,1280,900
Evidence: image: .context/working/judge-evidence/T-4458/13-graduation.png region 40,185,1200,885
Location: .context/working/judge-evidence/T-4458/13-graduation.png region 40,185,1200,885
Rule: AC1 requires understandable timeout messaging when shown, usable search results, and dashboard loading without waiting for the full search duration; the brief explicitly requires not-evaluated when the task lacks its Visual Verification section.
Conclusion: All thirteen images are viewable, but the search capture shows an empty query rather than the required search state, the dashboard capture cannot establish concurrent loading time, and the required Visual Verification section and state-by-width evidence are missing.
Guidance: Supply the missing ## Visual Verification section with captures for every checklist state at every configured width, including results for `release decision` in default hybrid mode and the timeout notice when applicable; provide timestamped evidence that the dashboard loads while semantic search remains running.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-4458
reviewer: codex
round: 1
vote: not-evaluated
failed: [1]

## AC1 Degraded-search notice reads clearly and the page stays usable
Vote: not-evaluated
Evidence: image: .context/working/judge-evidence/T-4458/01-search.png region 40,150,1200,540
Location: .context/working/judge-evidence/T-4458/01-search.png region 40,150,1200,540
Evidence: image: .context/working/judge-evidence/T-4458/02-root.png region 40,150,1200,710
Location: .context/working/judge-evidence/T-4458/02-root.png region 40,150,1200,710
Evidence: image: .context/working/judge-evidence/T-4458/03-decisions.png region 40,185,1200,773
Location: .context/working/judge-evidence/T-4458/03-decisions.png region 40,185,1200,773
Evidence: image: .context/working/judge-evidence/T-4458/04-learnings.png region 40,185,1200,746
Location: .context/working/judge-evidence/T-4458/04-learnings.png region 40,185,1200,746
Evidence: image: .context/working/judge-evidence/T-4458/05-gaps.png region 0,0,460,900
Location: .context/working/judge-evidence/T-4458/05-gaps.png region 0,0,460,900
Evidence: image: .context/working/judge-evidence/T-4458/06-api-learnings.png region 0,0,1280,900
Location: .context/working/judge-evidence/T-4458/06-api-learnings.png region 0,0,1280,900
Evidence: image: .context/working/judge-evidence/T-4458/07-api-decisions.png region 0,0,1280,900
Location: .context/working/judge-evidence/T-4458/07-api-decisions.png region 0,0,1280,900
Evidence: image: .context/working/judge-evidence/T-4458/08-search-ask.png region 0,0,1280,100
Location: .context/working/judge-evidence/T-4458/08-search-ask.png region 0,0,1280,100
Evidence: image: .context/working/judge-evidence/T-4458/09-search-conversations.png region 0,0,1280,100
Location: .context/working/judge-evidence/T-4458/09-search-conversations.png region 0,0,1280,100
Evidence: image: .context/working/judge-evidence/T-4458/10-search-feedback-analytics.png region 40,150,1200,365
Location: .context/working/judge-evidence/T-4458/10-search-feedback-analytics.png region 40,150,1200,365
Evidence: image: .context/working/judge-evidence/T-4458/11-patterns.png region 0,0,610,900
Location: .context/working/judge-evidence/T-4458/11-patterns.png region 0,0,610,900
Evidence: image: .context/working/judge-evidence/T-4458/12-api-patterns.png region 0,0,1280,900
Location: .context/working/judge-evidence/T-4458/12-api-patterns.png region 0,0,1280,900
Evidence: image: .context/working/judge-evidence/T-4458/13-graduation.png region 40,185,1200,885
Location: .context/working/judge-evidence/T-4458/13-graduation.png region 40,185,1200,885
Rule: AC1 requires understandable timeout messaging when shown, usable search results, and dashboard loading without waiting for the full search duration; the brief explicitly requires not-evaluated when the task lacks its Visual Verification section.
Conclusion: All thirteen images are viewable, but the search capture shows an empty query rather than the required search state, the dashboard capture cannot establish concurrent loading time, and the required Visual Verification section and state-by-width evidence are missing.
Guidance: Supply the missing ## Visual Verification section with captures for every checklist state at every configured width, including results for `release decision` in default hybrid mode and the timeout notice when applicable; provide timestamped evidence that the dashboard loads while semantic search remains running.

## Counter-search
Searched: Opened all thirteen supplied screenshots for the requested query, results, degraded-search notice, dashboard rendering, and evidence of concurrent loading.
Found: Search controls and dashboard content render without a visible 500 page; none of the images shows the requested query or timeout notice, and static dashboard content establishes no loading duration. The other pages and API responses do not resolve these gaps.

## Change-my-mind
A complete Visual Verification section and corresponding state-by-width captures showing the required hybrid search outcome, together with timing evidence showing the dashboard completes loading before the ongoing semantic search ends.
===END===
```
