# Reviewer evidence — T-4490 AC#1

- dispatch: `judge-t-4490-r5-codex-acb751ad2b80`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `a9dba0e9bd5e0b91e2c5a253befe7da18e8e9617`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `574e9da0193665ec553405cf0079dac6530c22dd0347a4103194c065932826b8`
- result.md sha256: `f9def8abb58b6875b6b80e423f2ff2db197e8ada5cbd97d19d552d428d63f43f`

## The worker's verdict block

```
## AC1 REVIEW_GREEN_DEGRADED clarity and placement
Vote: amber
Evidence: image: .context/working/judge-evidence/T-4490/01-config.png region 40,10880,1200,710
Location: .context/working/judge-evidence/T-4490/01-config.png region 40,10880,1200,710
Evidence: image: .context/visual/T-4490/config@1024.png region 37,17626,950,1238
Location: .context/visual/T-4490/config@1024.png region 37,17626,950,1238
Evidence: image: .context/visual/T-4490/config@1440.png region 120,10880,1200,710
Location: .context/visual/T-4490/config@1440.png region 120,10880,1200,710
Evidence: image: .context/visual/T-4490/config@1920.png region 235,8551,1450,427
Location: .context/visual/T-4490/config@1920.png region 235,8551,1450,427
Rule: The row “reads clearly next to the spend-ceiling row”; default is 1, description names opt-out, audit warnings and weekly counting, and layout matches neighbours.
Conclusion: All four screenshots show correct wording, default 1 and consistent unclipped layout, but three intervening settings separate the new row from the spend-ceiling row.
Guidance: Place REVIEW_GREEN_DEGRADED immediately after REVIEWER_JUDGE_WEEKLY_SPEND_CEILING and refresh the screenshots.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-4490
reviewer: rung-5-panel:codex
round: 1
vote: amber
failed: [1]

## AC1 REVIEW_GREEN_DEGRADED clarity and placement
Vote: amber
Evidence: image: .context/working/judge-evidence/T-4490/01-config.png region 40,10880,1200,710
Location: .context/working/judge-evidence/T-4490/01-config.png region 40,10880,1200,710
Evidence: image: .context/visual/T-4490/config@1024.png region 37,17626,950,1238
Location: .context/visual/T-4490/config@1024.png region 37,17626,950,1238
Evidence: image: .context/visual/T-4490/config@1440.png region 120,10880,1200,710
Location: .context/visual/T-4490/config@1440.png region 120,10880,1200,710
Evidence: image: .context/visual/T-4490/config@1920.png region 235,8551,1450,427
Location: .context/visual/T-4490/config@1920.png region 235,8551,1450,427
Rule: The row “reads clearly next to the spend-ceiling row”; default is 1, description names opt-out, audit warnings and weekly counting, and layout matches neighbours.
Conclusion: All four screenshots show correct wording, default 1 and consistent unclipped layout, but three intervening settings separate the new row from the spend-ceiling row.
Guidance: Place REVIEW_GREEN_DEGRADED immediately after REVIEWER_JUDGE_WEEKLY_SPEND_CEILING and refresh the screenshots.

## Counter-search
Searched: All four supplied screenshots, including native-resolution crops of the target row and neighbouring settings; the Visual Verification checklist’s single control at 1024, 1440 and 1920.
Found: The target row is visible, unobscured and unclipped at every width, with readable wrapping and matching column alignment; BOUNDARY_EXTRA_READ_PATHS, DESIGNER_FIELD_CATALOG and DESIGNER_FIELD_CATALOG_MAX_BYTES intervene before it in every capture.

## Change-my-mind
Updated screenshots showing REVIEW_GREEN_DEGRADED immediately adjacent to the spend-ceiling row, retaining the verified wording, default and unclipped layout at all three checklist widths.
===END===
```
