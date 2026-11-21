===VERDICT===
format: verdict/1
task: T-5351
reviewer: reviewer-judge-t-5351-r5-claude-code-d49de631d0b8:claude-code
round: 1
vote: green
failed: []

## AC1 The /config page shows the new SIDECAR_W1_PROMPT_ORIGIN row like its neighbours
Vote: green
Evidence: image: .context/reviews/evidence/T-5351/01-config-judge-t-5351-r5-claude-code-d49de631d0b8.png region 40,4376,1200,112
Location: .context/reviews/evidence/T-5351/01-config-judge-t-5351-r5-claude-code-d49de631d0b8.png region 40,4376,1200,112
Evidence: image: .context/reviews/evidence/T-5351/config@1024-judge-t-5351-r5-claude-code-d49de631d0b8.png region 36,5493,952,162
Location: .context/reviews/evidence/T-5351/config@1024-judge-t-5351-r5-claude-code-d49de631d0b8.png region 36,5493,952,162
Evidence: image: .context/reviews/evidence/T-5351/config@1440-judge-t-5351-r5-claude-code-d49de631d0b8.png region 120,4376,1200,112
Location: .context/reviews/evidence/T-5351/config@1440-judge-t-5351-r5-claude-code-d49de631d0b8.png region 120,4376,1200,112
Evidence: image: .context/reviews/evidence/T-5351/config@1920-judge-t-5351-r5-claude-code-d49de631d0b8.png region 235,3967,1450,90
Location: .context/reviews/evidence/T-5351/config@1920-judge-t-5351-r5-claude-code-d49de631d0b8.png region 235,3967,1450,90
Evidence: "    (\"SIDECAR_W1_PROMPT_ORIGIN\", \"0\", \"1 = in a project that runs TermLink's own W1 sidecar hooks (adapter/2 off by its w1-guard), the prompt hook sends exactly one adapter/2 prompt_submit (250 ms) so the main claim carries the receiver-checked origin; a failure claims origin unknown (T-5351, 010-termlink T-3694). 0 (default) = claim as before\"),"
Location: web/blueprints/config.py:58
Rule: criterion: "One row, default 0, the description readable and laid out like the rows around it; no broken table"
Conclusion: In all four captures the row FW_SIDECAR_W1_PROMPT_ORIGIN appears exactly once, with Current 0, Default 0, a DEFAULT source badge and its full description wrapped inside the Description column in the same five-column layout as the rows above and below it, and the table continues unbroken to its last row, so every clause holds.

## Counter-search
Searched: each capture's Env Var column for a second copy of the row's label (pixel match of the label against the whole column); web/blueprints/config.py for a second registry entry; the rows directly above and below the new row at 1024, 1280, 1440 and 1920 px for a shifted column, text running out of its cell or over a neighbour, or a truncated description; the table's end and the Custom Settings / How to override sections below it for a break in layout
Found: one label match per capture (y=4390, 5510, 4390, 3980) and one registry entry; columns line up with the neighbours at every width; the description is complete (ends "0 (default) = claim as before") in 3 to 6 lines depending on width; the label wraps over three lines in its narrow column and the DEFAULT badge wraps to "DEFAU/LT", but every neighbouring row does the same, so this is the table's existing style and not a defect of this row; the sections after the table render normally. The page prints the label with the FW_ prefix (FW_SIDECAR_W1_PROMPT_ORIGIN), as it does for every row. Cannot reproduce: the captures were judged as supplied; the page was not re-opened.

## Change-my-mind
A capture of /config in which the label FW_SIDECAR_W1_PROMPT_ORIGIN appears twice, or its Default cell shows something other than 0, or its description is cut off or overlaps a neighbouring row or column.
===END===
