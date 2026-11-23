===VERDICT===
format: verdict/1
task: T-4490
reviewer: reviewer-judge-t-4490-r5-claude-code-06165a4daa53:claude-code
round: 1
vote: green
failed: []

## AC1 The new REVIEW_GREEN_DEGRADED row on /config reads clearly next to the spend-ceiling row
Vote: green
Evidence: "FW_REVIEW_GREEN_DEGRADED 1 1 DEFAULT"
Location: command: tesseract .context/visual/T-4490/config@1024.png (OCR line, row at 1024 px width; the same key appears in the 1440 and 1920 captures)
Evidence: "1 (default): a rung-5 review panel whose only missing seats were provably unavailable closes a criterion as GREEN-DEGRADED when two or more seats of different vendors judged green and none dissented; never for tier-0, act-in-the-world or sovereignty criteria. Every such close is written on the criterion and WARNed by fw audit with a weekly count. Set 0 to opt out. T-4490."
Location: web/blueprints/config.py:126
Rule: criterion: "default `1`, description names the opt-out and that every degraded close is WARNed and counted weekly by fw audit; the row's layout matches its neighbours"
Conclusion: The row's default is 1, its description names the opt-out ("Set 0 to opt out") and says every such close is WARNed and counted weekly by fw audit, and the row sits in the same key / default / source / description columns as its neighbour "FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING 10000 19808 DEFAULT", so the criterion holds.
Evidence: "FW_BOUNDARY_EXTRA_READ_PATHS"
Location: command: tesseract .context/working/judge-evidence/T-4490/01-config.png (OCR line; the row sits between the WEEKLY_SPEND_CEILING and BOUNDARY_EXTRA_READ_PATHS rows in the /config table)

## Counter-search
Searched: all three width captures (1024, 1440, 1920) and the 01-config.png judge capture for the REVIEW_GREEN_DEGRADED row, its default cell, and any clipping or overlap around it; also re-read the registry text at web/blueprints/config.py:126.
Found: the key appears in all four captures, in the same table position between the spend-ceiling row and BOUNDARY_EXTRA_READ_PATHS; the 1024 capture shows its description wrapping inside the description column like the neighbours; no overlap or clipping was visible in the OCR text. The screenshots are downscaled (1024 px capture is 19604 px tall), so fine pixel alignment was judged from OCR text positions and the column order, not from pixel measurement.

## Change-my-mind
A capture in which the REVIEW_GREEN_DEGRADED row shows a default other than 1, a description missing the opt-out or the weekly fw audit WARN/count sentence, or a row whose description is clipped or overlaps the spend-ceiling row at any of the three widths.
===END===

Notes: Screenshots cited (copies in this directory): 01-config-judge-t-4490-r5-claude-code-06165a4daa53.png, config@1024-judge-t-4490-r5-claude-code-06165a4daa53.png, config@1440-judge-t-4490-r5-claude-code-06165a4daa53.png, config@1920-judge-t-4490-r5-claude-code-06165a4daa53.png. The Visual Verification checklist for T-4490 was not supplied in the brief, so the widths were judged as the row's presence, reachability and clipping in each capture. The browser recorded no console or page errors (per the brief).
