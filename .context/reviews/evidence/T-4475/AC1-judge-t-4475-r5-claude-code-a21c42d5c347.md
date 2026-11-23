===VERDICT===
format: verdict/1
task: T-4475
reviewer: reviewer-judge-t-4475-r5-claude-code-a21c42d5c347:claude-code
round: 1
vote: green
failed: []

## AC1 The new EMBED_WORKERS row on /config reads clearly next to its neighbours
Vote: green
Evidence: image: config@1440-judge-t-4475-r5-claude-code-a21c42d5c347.png region 140,7880,1200,100
Location: config@1440-judge-t-4475-r5-claude-code-a21c42d5c347.png region 140,7880,1200,100
Evidence: "Malformed or <1 means 1; T-4475"
Location: web/blueprints/config.py:96
Evidence: image: config@1024-judge-t-4475-r5-claude-code-a21c42d5c347.png region 40,12820,960,135
Location: config@1024-judge-t-4475-r5-claude-code-a21c42d5c347.png region 40,12820,960,135
Evidence: image: config@1920-judge-t-4475-r5-claude-code-a21c42d5c347.png region 200,6200,1500,80
Location: config@1920-judge-t-4475-r5-claude-code-a21c42d5c347.png region 200,6200,1500,80
Rule: criterion: "default `1`; the description says it sets concurrent embed requests during reindex, to match the server's OLLAMA_NUM_PARALLEL, and that 1 is serial; the row's layout matches its neighbours"
Conclusion: The rendered row shows default 1, a description stating concurrent embed requests, OLLAMA_NUM_PARALLEL matching and 1 being serial, and its layout matches the FW_SEMANTIC_RECALL neighbour at 1024, 1440 and 1920 px.

## Counter-search
Searched: the 1024 px capture for a clipped or split name, and the 1280 px judge capture (01-config-judge-t-4475-r5-claude-code-a21c42d5c347.png) for the same row, to see whether the description or badge differed at other widths.
Found: no clipped or split names; the 1280 px capture at region 60,7880,1160,100 shows the same row text and layout. The name column renders as FW_EMBED_WORKERS, and the neighbour rows use the same FW_ prefix, so this is the page's display convention rather than a wrong name. The description column wraps in narrow layouts, as neighbours do.

## Change-my-mind
A capture in which the description omits OLLAMA_NUM_PARALLEL or the "1 is serial" wording, or in which the EMBED_WORKERS row's columns misalign with FW_SEMANTIC_RECALL.

Notes: Located the row with tesseract tsv in each capture, then cropped it to read the text. Vote covers Human AC#1 only; I did not check the task file's Visual Verification table. The criterion says EMBED_WORKERS; the page shows FW_EMBED_WORKERS, read here as the same row under the page's FW_ prefix. The operator should confirm that reading.
===END===
