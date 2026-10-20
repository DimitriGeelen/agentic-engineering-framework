# T-4475 Human AC#1: EMBED_WORKERS row on /config (reviewer judge-t-4475-r5-claude-code-87afc379f16c, rung-5-panel:claude-code)

Revision under review: 362bba05ebfc4fd20f8e3aabab5dcdf51184a878

## Source
web/blueprints/config.py:75
("EMBED_WORKERS", "1", "Concurrent embed requests the vector reindex sends to the bulk embedding host (web/embeddings.py:_embed_batches; order preserved). Match it to the server's OLLAMA_NUM_PARALLEL; 1 is serial. Malformed or <1 means 1; T-4475")
It sits between INDEX_REINDEX_INTERVAL_HOURS and INDEX_MAX_LAG, alongside the other vector-index settings.

## Rendered (each screenshot cropped at full resolution around the row)
- 01-config (1280), config@1440, config@1920: the row FW_EMBED_WORKERS has Current 1, Default 1 and a DEFAULT badge. The description is fully legible.
  The env-var name wraps like its neighbours, the value and badge columns line up with them,
  and it uses the same row separator and padding.
- config@1024: the row's layout matches its neighbours. The description column is cut off at the right edge of the viewport
  ("_embed_batches;", "1 is"). The neighbouring rows are cut off the same way (INDEX_REINDEX_INTERVAL_HOURS shows "unless the", INDEX_MAX_LAG shows "before the").
  So this is a page-wide table overflow at 1024 that predates this task; this row did not introduce it.

## Against Expected
- default 1: yes
- says it sets concurrent embed requests during reindex: yes ("Concurrent embed requests the vector reindex sends ...")
- match the server's OLLAMA_NUM_PARALLEL: yes
- 1 is serial: yes
- layout matches neighbours: yes, at every width

Verdict: green. Side note, not blocking: /config overflows on the right at 1024px for every row.
