# T-3786 Human AC#1 — seat claude-code (rung-5-panel) — revision 84568c9d7

Criterion: "[REVIEW] Search and ask still work, and never rebuild the index from the page"

## Outcome: not-evaluated

### Why I cannot give a verdict
- The criterion is a render criterion: step 1 is a search for "vector index" on `/search`,
  step 2 is switching the same page to ask mode and asking "what is T-3786 about?".
- The capture was partial. I did NOT see `/ask`, `/ask/stream`, `/search/load-conversation`.
- The screenshots I did get do not show either step being carried out:
  - `01-search.png` is the EMPTY search landing page (no query, no results).
  - `11-search-ask.png` is the raw SSE body `Query too short (min 2 characters)`: the ask
    endpoint opened with no question. No answer is shown.
- The task file has no `## Visual Verification` section, so there is no task-side visual
  evidence for the results state or the ask-answer state.
- So I never saw results rendered in the page, nor an answer rendered in ask mode.

### What I did check (supporting, not a substitute for the rendered page)
1. Live HTTP, `GET http://192.168.10.107:3000/search?q=vector+index` -> 200, 135 kB; page text:
   "Found 20 results for vector index (hybrid) — 15253 docs indexed, 923401 chunks",
   first hits T-3861, T-4350. No "fw index reindex" unavailable-message in the page.
2. Live HTTP, `GET /search/ask?q=what+is+T-3786+about%3F` -> SSE stream:
   status "Searching knowledge base...", status "Found 10 relevant sources — generating answer...",
   model qwen3:14b (ollama), then tokens: "T-3786 is related to the function `_get_db()` in ...
   web/embeddings.py ... now raises an `IndexUnavailable` exception instead of rebuilding ...".
   The stream was cut by my 3000-byte read; I did not read the whole answer.
3. Code at the reviewed tree:
   - `web/embeddings.py` `_get_db` (lines 513-551): every failure path raises `IndexUnavailable`
     with "rebuild with: fw index reindex" / "build it with: fw index reindex"; no call to
     `build_index()` remains in it.
   - `web/blueprints/discovery.py` ask stream (lines 401-408): when the index is not ready it
     yields status "Knowledge index is unavailable ... It is never rebuilt from this page; rebuild
     with: fw index reindex" and an error event, then returns. No build is started.
   - grep of `web/blueprints/*.py`, `web/ask.py`: no caller of `embeddings.build_index`
     (the `build_index` in `web/search.py` is the separate tantivy keyword index).

### Not checked
- The rendered results list and the rendered ask-mode answer in a browser.
- The index-unavailable state on the page (it would need the live index made unavailable; I did
  not do that).
- `/ask`, `/ask/stream`, `/search/load-conversation` (not captured).

### Screenshots (copies in this directory, suffix `-<dispatch id>.png`)
01-search, 02-root, 05-health, 06-decisions, 07-learnings, 08-gaps, 09-api-learnings,
10-api-decisions, 11-search-ask, 12-search-conversations, 14-search-feedback-analytics,
15-patterns, 16-api-patterns, 17-graduation. Only 01 and 11 bear on this criterion. I opened
only those two; the other twelve are cited because the ledger requires it, not as something I
judged.
