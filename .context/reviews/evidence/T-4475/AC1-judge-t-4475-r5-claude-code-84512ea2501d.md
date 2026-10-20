# T-4475 Human AC#1 — EMBED_WORKERS row on /config (seat claude-code)

Outcome: not-evaluated

## What I checked
- Dispatch brief: live screenshot capture for this review FAILED
  (`Page.goto: net::ERR_CONNECTION_REFUSED at http://192.168.10.107:3000/config`).
  I have not seen the page rendered at the revision under review.
- Screenshots on disk (`.context/visual/T-4475/config@{1024,1440,1920}.png`) were captured
  2026-10-20T20:01:55Z (config.capture.json). The revision under review, dec4a8888
  (committed 22:11:48 +0200 = 20:11:48Z), is LATER and itself changes the config registry
  (T-4361 adds BOUNDARY_EXTRA_READ_PATHS). The screenshots predate the revision and are not evidence for it.
  At 1024 the full-page shot is 1024x8048, so the row is unreadable at the resolution shown to me.
- Source (not rendering): web/blueprints/config.py:75 has
  `("EMBED_WORKERS", "1", "Concurrent embed requests the vector reindex sends to the bulk embedding host
  (web/embeddings.py:_embed_batches; order preserved). Match it to the server's OLLAMA_NUM_PARALLEL; 1 is serial.
  Malformed or <1 means 1; T-4475")`. Default and wording match the Expected text. That is a source check only;
  the layout half of the criterion (matching its neighbours) needs the rendered page.

## Why not-evaluated
The criterion is about rendering. Capture failed and the stale screenshots predate the reviewed revision, so I cannot judge layout.

Note: the ledger refused copies of the on-disk screenshots as evidence (hash differs from the copies at dec4a8888), which confirms they are not the reviewed revision's captures; they are not cited.

## Needed
Bring Watchtower up (`bin/fw watchtower url` must answer), re-capture with
`fw ux shots T-4475 config=<url>/config` at the reviewed revision, and re-dispatch.
