# T-4490 Human AC#1 — REVIEW_GREEN_DEGRADED row on /config
Reviewer: claude-code seat (rung-5-panel:claude-code), dispatch judge-t-4490-r5-claude-code-f40e8ac7806c, revision fcd43f0be.

**Degraded single-vendor panel:** fewer vendors than the panel needs could be dispatched. This verdict is recorded and reported, but the criterion stays open until it gets a multi-vendor verdict.

## Source check
web/blueprints/config.py:86 — ("REVIEW_GREEN_DEGRADED", "1", "1 (default): ... closes a criterion as GREEN-DEGRADED when two or more seats of different vendors judged green and none dissented; never for tier-0, act-in-the-world or sovereignty criteria. Every such close is written on the criterion and WARNed by fw audit with a weekly count. Set 0 to opt out. T-4490.")
It comes directly after REVIEWER_JUDGE_WEEKLY_SPEND_CEILING (line 85) and uses the same tuple shape.

## Expected vs found
- Default 1: yes, the Current column shows 1, the Default column shows 1 and the source badge says DEFAULT.
- Description names the opt-out: yes ("Set 0 to opt out").
- Says every degraded close is WARNed and counted weekly by fw audit: yes ("WARNed by fw audit with a weekly count").
- Layout matches neighbours: yes. In the screenshots at 1024, 1440 and 1920, and the 1280 judge capture, the row is the last one in the Project table, directly under the spend-ceiling row. The env-var cell wraps in monospace, the value is bold, the default is muted monospace, the DEFAULT pill is used and the description wraps inside its column, all the same as the neighbouring rows. Nothing is clipped or overlapping, and the row has the same divider and padding. At 1024 the env-var name wraps into more lines, but every row on the page does that, so it is not specific to this row.

## Evidence
- 01-config-judge-t-4490-r5-claude-code-f40e8ac7806c.png (judge capture, 1280)
- config@1024-judge-t-4490-r5-claude-code-f40e8ac7806c.png, config@1440-judge-t-4490-r5-claude-code-f40e8ac7806c.png, config@1920-judge-t-4490-r5-claude-code-f40e8ac7806c.png
- crop-1920-spend-vs-degraded-judge-t-4490-r5-claude-code-f40e8ac7806c.png (the spend-ceiling row and the new row side by side)

Verdict: green
