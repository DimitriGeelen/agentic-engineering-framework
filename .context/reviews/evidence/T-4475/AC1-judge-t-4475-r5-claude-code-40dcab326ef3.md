# T-4475 Human AC#1 — EMBED_WORKERS row on /config
Reviewer: claude-code (panel seat), dispatch judge-t-4475-r5-claude-code-40dcab326ef3, revision aa6ab3db17a50984007cba05a718c8defd28b76a
**Degraded: single-vendor panel.** This verdict is recorded and reported, but the panel could not satisfy its multi-vendor requirement, so the criterion stays open.

## Source (git show aa6ab3db1:web/blueprints/config.py:75)
("EMBED_WORKERS", "1", "Concurrent embed requests the vector reindex sends to the bulk embedding host (web/embeddings.py:_embed_batches; order preserved). Match it to the server's OLLAMA_NUM_PARALLEL; 1 is serial. Malformed or <1 means 1; T-4475")
- default 1: yes
- concurrent embed requests during reindex: yes
- match OLLAMA_NUM_PARALLEL: yes
- 1 is serial: yes
It sits between INDEX_REINDEX_INTERVAL_HOURS and INDEX_MAX_LAG, next to the other vector-index settings, and follows the same "what it is; how to read it; T-ref" style as they do.

## Rendered pages (Read, then cropped around the row at each width)
- 01-config.png (judge render, 1280): the FW_EMBED_WORKERS row is present, with Current 1, Default 1 and a DEFAULT badge.
- config@1920.png: the row is a single line and is aligned with its neighbours. The env-var column wraps FW_EMBED/_WORKERS the same way as FW_INDEX_*. Its description is 3 lines and is fully visible.
- config@1440.png: matches its neighbours; the description is 4 lines and fully visible.
- config@1024.png: the columns are aligned like the neighbouring rows, and the env var wraps per character exactly as its neighbours do. The description column runs to the right page edge. A few trailing characters are cut off at x≈987 ("_embed_batches;", "1 is"). The neighbouring rows show the same cut (INDEX_REINDEX_INTERVAL_HOURS loses "writes" and "the"; RECALL_USAGE_DAYS loses "zero-"). So this is an existing table-wide overflow at 1024 and is not caused by this row. It matches its neighbours, as the criterion asks. The task's VV table marks 1024 'ok'. That is fair for this row against its neighbours, but the page-wide clipping at 1024 could be a separate follow-up.

## Verdict: green
The row reads clearly, has the expected default and description, and its layout matches its neighbours at every width.
