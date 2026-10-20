# T-4490 Human AC#1 — REVIEW_GREEN_DEGRADED row on /config (panel seat claude-code)

Revision reviewed: 15eae104dca363e25215f6355ca7a1d7880ab8de

## Source
`web/blueprints/config.py:86` (at the reviewed revision):
("REVIEW_GREEN_DEGRADED", "1", "1 (default): a rung-5 review panel whose only missing seats were provably unavailable closes a criterion as GREEN-DEGRADED when two or more seats of different vendors judged green and none dissented; never for tier-0, act-in-the-world or sovereignty criteria. Every such close is written on the criterion and WARNed by fw audit with a weekly count. Set 0 to opt out. T-4490.")
This is the row directly after REVIEWER_JUDGE_WEEKLY_SPEND_CEILING (line 85), and the last row of the Framework Settings table.

## Screenshots read (I cropped each around the row, rows y≈8050–8700 / 13850–14800 / 6100–6650)
- 01-config.png (1280x9305), config@1024.png, config@1440.png, config@1920.png (copied to this directory)

## Expected vs observed
- Default `1`: shown in bold as the value, `1` in the default column, and a DEFAULT badge, at every width. OK.
- Description names the opt-out: "Set 0 to opt out." OK.
- Says every degraded close is WARNed and counted weekly by fw audit: "Every such close is written on the criterion and WARNed by fw audit with a weekly count." OK.
- Layout matches neighbours: same five columns (key in monospace chip `FW_REVIEW_GREEN_DEGRADED`, bold value, monospace default, DEFAULT badge, description wrapping in the description column), same row divider and padding as FW_PROVISION_LOAD_MAX and FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING. The row is shorter than the spend-ceiling row because the key wraps over fewer lines. OK.

## Visual Verification checklist (config / REVIEW_GREEN_DEGRADED row)
- 1024: visible, reachable, no overlap. Text not clipped. The key column wraps hard (3-char lines) and the description column runs nearly to the viewport's right edge. Both happen in every neighbouring row too, so they come from the page, not from this row. ok
- 1440: visible, unclipped, no overlap. ok
- 1920: visible, unclipped, no overlap; description wraps to 5 lines. ok

## Non-blocking observations (pre-existing, page-wide)
- The narrow key column character-wraps long FW_* names at all widths. This was already the case for every row before this task.

Verdict: green.
