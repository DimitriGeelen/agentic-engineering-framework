===VERDICT===
format: verdict/1
task: T-4475
reviewer: reviewer-judge-t-4475-r5-claude-code-99ad6ce6b7dc:claude-code
round: 1
vote: green
failed: []

## AC1 The new EMBED_WORKERS row on /config reads clearly next to its neighbours
Vote: green
Evidence: "Concurrent embed requests the vector reindex sends to the bulk embedding host (web/embeddings.py:_embed_batches; order preserved). Match it to the server's OLLAMA_NUM_PARALLEL; 1 is serial. Malformed or <1 means 1; T-4475"
Location: web/blueprints/config.py:96
Evidence: image: .context/reviews/evidence/T-4475/config@1920-judge-t-4475-r5-claude-code-99ad6ce6b7dc.png region 240,4245,1450,90
Location: .context/reviews/evidence/T-4475/config@1920-judge-t-4475-r5-claude-code-99ad6ce6b7dc.png region 240,4245,1450,90
Evidence: image: .context/reviews/evidence/T-4475/config@1440-judge-t-4475-r5-claude-code-99ad6ce6b7dc.png region 120,4910,1200,90
Location: .context/reviews/evidence/T-4475/config@1440-judge-t-4475-r5-claude-code-99ad6ce6b7dc.png region 120,4910,1200,90
Evidence: image: .context/reviews/evidence/T-4475/config@1024-judge-t-4475-r5-claude-code-99ad6ce6b7dc.png region 35,5855,955,135
Location: .context/reviews/evidence/T-4475/config@1024-judge-t-4475-r5-claude-code-99ad6ce6b7dc.png region 35,5855,955,135
Rule: criterion: "default `1`; the description says it sets concurrent embed requests during reindex, to match the server's OLLAMA_NUM_PARALLEL, and that 1 is serial; the row's layout matches its neighbours"
Conclusion: The EMBED_WORKERS row shows default 1 in the image, its description (config.py:96) states the OLLAMA_NUM_PARALLEL matching and serial-at-1 meaning, and the row uses the same columns, DEFAULT badge and text wrapping as its neighbours at 1024, 1440 and 1920 px.
Guidance: none required (green).

## Counter-search
Searched: the three widths for clipping, overlap or a row whose layout differs from neighbours; config.py for a default other than 1.
Found: no clipping or overlap at any width; config.py:96 has default "1". Capture notes record no console errors. bin/fw exists, so the steps' path is current.

## Change-my-mind
A screenshot of /config at any width where the EMBED_WORKERS row is clipped or misaligned with its neighbours, or a row description that omits the OLLAMA_NUM_PARALLEL / serial wording.
===END===
