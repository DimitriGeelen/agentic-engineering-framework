# T-4475 Human AC#1 — EMBED_WORKERS row on /config (seat: claude-code)

Revision reviewed: cd09e255f6213362d8359a584c8b455396103d70
Rung: rung-5-panel:claude-code. **Degraded: single-vendor panel.** Fewer vendors could be dispatched than the panel needs, so this run cannot meet a multi-vendor requirement. This verdict is recorded, and the criterion stays open.

## What I checked
1. Source: `web/blueprints/config.py:75`
   `("EMBED_WORKERS", "1", "Concurrent embed requests the vector reindex sends to the bulk embedding host (web/embeddings.py:_embed_batches; order preserved). Match it to the server's OLLAMA_NUM_PARALLEL; 1 is serial. Malformed or <1 means 1; T-4475")`
   It sits between INDEX_REINDEX_INTERVAL_HOURS and INDEX_MAX_LAG, next to the other index settings.
2. Screenshots. I located the row with OCR, cropped it and looked at it:
   01-config.png (1280), config@1024/1440/1920.png.
3. Live page (http://192.168.10.107:3000/config, from `fw watchtower url`), measured with headless Chromium at a 1024x900 viewport.

## Findings
- Content: meets the Expected text. The row shows `FW_EMBED_WORKERS`, current `1`, default `1` and the DEFAULT source badge. The description says it sets concurrent embed requests during reindex, to match OLLAMA_NUM_PARALLEL, and that 1 is serial. The wording follows the same style as its neighbours (what it is, a code pointer, the fallback rule, the T-id).
- Layout at 1280, 1440 and 1920: matches its neighbours, with the same columns, badge and wrapping. No clipping or overlap.
- **Layout at 1024: regression caused by this row.** Measured on the live page:
  - The `.table-responsive` wrapper (overflow-x: auto) is 950px wide, and `.config-table` is **967.5px** wide.
  - With only the EMBED_WORKERS row hidden (display:none), the table measures **950px** and fits.
  - So this row alone widens the table by about 17.5px. The Description column of every row runs to the card's edge and is cut off there; the user has to scroll sideways to read it.
  - The screenshots confirm this. In config@1024.png, "_embed_batches;" and "1 is" run into the card edge. The rightmost text pixel in the table body is x=986 (the card edge is about 987). In the older T-4467 /config@1024 capture it is x=969, which leaves the usual right padding.
  - The likely cause is the long unbreakable token `(web/embeddings.py:_embed_batches;`, which sets the column's minimum width. Neighbour rows break their code pointers more easily.
- The Visual Verification table in the task marks 1024 as `ok`. The measurement says `clipped`.

## Verdict: amber
The row reads clearly and the text is right. At 1024 it pushes the table wider than its container and clips the Description column for the whole table.

## Needed
Make the pointer breakable: for example "web/embeddings.py _embed_batches", put a space after the colon, or give `.config-table td` `overflow-wrap:anywhere`. Then re-shoot `fw ux shots T-4475 config=<url>/config` and check that at 1024 the `.config-table` width is no more than the `.table-responsive` width.

## Evidence files (copies in this directory)
- 01-config-judge-t-4475-r5-claude-code-9e576f7ad315.png (the 01-config.png at the reviewed revision, sha256 7145cedc…; its row region is pixel-identical to the working judge-evidence copy, which differs only in the header status-bar text)
- config@1024-judge-t-4475-r5-claude-code-9e576f7ad315.png, config@1440-judge-t-4475-r5-claude-code-9e576f7ad315.png, config@1920-judge-t-4475-r5-claude-code-9e576f7ad315.png
- embed-row-1024-crop-judge-t-4475-r5-claude-code-9e576f7ad315.png (crop of the row at 1024 showing the text running to the card edge)
