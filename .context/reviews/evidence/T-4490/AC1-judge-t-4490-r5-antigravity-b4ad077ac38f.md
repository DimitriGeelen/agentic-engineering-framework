# Reviewer evidence — T-4490 AC#1

- dispatch: `judge-t-4490-r5-antigravity-b4ad077ac38f`
- worker kind: `antigravity` (vendor `google`, model `worker default`)
- seat: `antigravity`
- reviewed revision: `7528a69d47aa187d279ab9f4a430811641485ce8`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `2cde4c990dfa527d465e2467517c55ce90cfc027e2a8ce63a3cd37cc8d5b50d5`
- result.md sha256: `5b1991d365f7c49cc6768ce092e9eb765e7d6c127f57e9da88abc1d1df451541`

## The worker's verdict block

```
## AC1 The new REVIEW_GREEN_DEGRADED row on /config reads clearly next to the spend-ceiling row
Vote: green
Evidence: image: .context/working/judge-evidence/T-4490/01-config.png region 40,10880,1200,346
Location: .context/working/judge-evidence/T-4490/01-config.png region 40,10880,1200,346
Evidence: image: .context/visual/T-4490/config@1024.png region 37,17626,950,634
Location: .context/visual/T-4490/config@1024.png region 37,17626,950,634
Evidence: image: .context/visual/T-4490/config@1440.png region 120,10880,1200,346
Location: .context/visual/T-4490/config@1440.png region 120,10880,1200,346
Evidence: image: .context/visual/T-4490/config@1920.png region 235,8460,1450,250
Location: .context/visual/T-4490/config@1920.png region 235,8460,1450,250
Evidence: "1 (default): a rung-5 review panel whose only missing seats were provably unavailable closes a criterion as GREEN-DEGRADED when two or more seats of different vendors judged green and none dissented; never for tier-0, act-in-the-world or sovereignty criteria. Every such close is written on the criterion and WARNed by fw audit with a weekly count. Set 0 to opt out. T-4490."
Location: web/blueprints/config.py:126
Evidence: "| config | REVIEW_GREEN_DEGRADED row | ok | ok | ok | new row after REVIEWER_JUDGE_WEEKLY_SPEND_CEILING; shots in .context/visual/T-4490/ |"
Location: .tasks/active/T-4490-green-degraded-closes-a-rung-5-review-pa.md:370
Rule: criterion: "The new REVIEW_GREEN_DEGRADED row on /config reads clearly next to the spend-ceiling row" / Expected: "default `1`, description names the opt-out and that every degraded close is WARNed and counted weekly by fw audit; the row's layout matches its neighbours" plus Visual Verification checklist at 1024, 1440, and 1920 px
Conclusion: In all four `/config` captures (1024, 1280, 1440, and 1920 px), `FW_REVIEW_GREEN_DEGRADED` renders immediately below `FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING` with Current `1`, Default `1`, Source `DEFAULT`, a complete legible description naming the `Set 0 to opt out.` opt-out and the weekly `fw audit` WARN count, and matching neighbour-row layout with zero clipping, overlap, or console/page errors.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-4490
reviewer: rung-5-panel:antigravity
round: 1
vote: green
failed: []

## AC1 The new REVIEW_GREEN_DEGRADED row on /config reads clearly next to the spend-ceiling row
Vote: green
Evidence: image: .context/working/judge-evidence/T-4490/01-config.png region 40,10880,1200,346
Location: .context/working/judge-evidence/T-4490/01-config.png region 40,10880,1200,346
Evidence: image: .context/visual/T-4490/config@1024.png region 37,17626,950,634
Location: .context/visual/T-4490/config@1024.png region 37,17626,950,634
Evidence: image: .context/visual/T-4490/config@1440.png region 120,10880,1200,346
Location: .context/visual/T-4490/config@1440.png region 120,10880,1200,346
Evidence: image: .context/visual/T-4490/config@1920.png region 235,8460,1450,250
Location: .context/visual/T-4490/config@1920.png region 235,8460,1450,250
Evidence: "1 (default): a rung-5 review panel whose only missing seats were provably unavailable closes a criterion as GREEN-DEGRADED when two or more seats of different vendors judged green and none dissented; never for tier-0, act-in-the-world or sovereignty criteria. Every such close is written on the criterion and WARNed by fw audit with a weekly count. Set 0 to opt out. T-4490."
Location: web/blueprints/config.py:126
Evidence: "| config | REVIEW_GREEN_DEGRADED row | ok | ok | ok | new row after REVIEWER_JUDGE_WEEKLY_SPEND_CEILING; shots in .context/visual/T-4490/ |"
Location: .tasks/active/T-4490-green-degraded-closes-a-rung-5-review-pa.md:370
Rule: criterion: "The new REVIEW_GREEN_DEGRADED row on /config reads clearly next to the spend-ceiling row" / Expected: "default `1`, description names the opt-out and that every degraded close is WARNed and counted weekly by fw audit; the row's layout matches its neighbours" plus Visual Verification checklist at 1024, 1440, and 1920 px
Conclusion: In all four `/config` captures (1024, 1280, 1440, and 1920 px), `FW_REVIEW_GREEN_DEGRADED` renders immediately below `FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING` with Current `1`, Default `1`, Source `DEFAULT`, a complete legible description naming the `Set 0 to opt out.` opt-out and the weekly `fw audit` WARN count, and matching neighbour-row layout with zero clipping, overlap, or console/page errors.

## Counter-search
Searched: all four full-page screenshots (`01-config.png` at 1280 px and `config@{1024,1440,1920}.png`) including cropped full-resolution views of the top header, surrounding rows (`FW_REVIEW_PAID_BACKENDS` through `FW_BOUNDARY_EXTRA_READ_PATHS`), and page footer; `web/blueprints/config.py:125-127`; `lib/config.sh:440`; `web/templates/config.html:50-66,115-145`; and `bin/fw` for stale command paths in Steps
Found: `bin/fw` exists and supports `watchtower restart` and `watchtower url`; `lib/config.sh:440` and `web/blueprints/config.py:126` agree on key name, default `1`, opt-out semantics, and weekly `fw audit` WARN; every cell of `FW_REVIEW_GREEN_DEGRADED` fits cleanly within the table bounds (`x=37..986` at 1024 px, `40..1239` at 1280 px, `120..1319` at 1440 px, `235..1684` at 1920 px) without mid-word breaks, clipping, or overlap; the only minor visual quirks seen elsewhere on `/config` (the global header dark-mode icon wrapping onto a second line at 1024 px and `FW_REVIEW_PAID_BACKENDS` wrapping its `allowed` default value) are pre-existing outside T-4490 and do not affect `FW_REVIEW_GREEN_DEGRADED`

## Change-my-mind
A `/config` capture at 1024, 1280, 1440, or 1920 px where `FW_REVIEW_GREEN_DEGRADED` is clipped, overlaps a neighbouring row or column, is not adjacent to `FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING`, displays a default other than `1`, or omits the `0` opt-out or weekly `fw audit` WARN from its rendered description.
===END===

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```
