# T-3786 Human AC#1: evidence report (panel seat claude-code)

Criterion: Search and ask still work, and never rebuild the index from the page.

## What I checked myself (live, 2026-11-15, Watchtower at http://192.168.10.107:3000)

1. Step 1, search "vector index": `GET /search?q=vector+index` returned HTTP 200 in 10.5 s with
   "Found 30 results for vector index" and "15298 docs indexed"; T-3786 is among the results; the
   page contains no "unavailable" / "fw index reindex" text.
2. Step 2, ask "what is T-3786 about?": `GET /search/ask?q=...` (the stream the page's Ask AI mode
   reads, `web/static/js/chat.js`) returned HTTP 200 and streamed: status "Searching knowledge base...",
   status "Found 10 relevant sources — generating answer...", model `qwen3:14b`, then tokens, sources, `done`.
   Assembled answer: "T-3786 is related to the function `_get_db()` in ... web/embeddings.py ... This
   function now raises an `IndexUnavailable` exception instead of rebuilding ..." (correct). No
   "unavailable" / "reindex" event in the stream.
3. Never rebuilds: `.context/working/fw-vec-index.db` was 6,114,082,816 bytes with mtime
   2026-11-15 16:35:52.378642767 before both requests and identical after; no `.building` or scratch
   file appeared next to it; no reindex/build process was running.
4. Unavailable path (cannot be exercised on the live index without damaging it, so by code and test):
   - `web/blueprints/discovery.py:403-408`: when the index is not ready the ask stream yields status
     "Knowledge index is unavailable ... It is never rebuilt from this page; rebuild with: fw index reindex"
     and error "The embedding index is unavailable. Rebuild it with: fw index reindex", then returns.
     No build call; `grep build_index web/blueprints/` finds only that comment.
   - `web/embeddings.py:513-551` `_get_db`: raises `IndexUnavailable` (with the remedy) for an
     unopenable, empty or missing index; no fall-through to `build_index()`.
   - `web/static/js/chat.js:259` shows an `error` event's message in the page's error box.
   - `tests/unit/test_t3786_index_never_built_by_readers.py` (hermetic, tmp_path): 6 passed, including
     "no watchtower page module can start a build".

## Screenshots (all read)

Rendered pages: `/search` (01) shows search box, modes All/Keyword/Semantic/Ask AI, topic cloud, no
errors. `/search/ask` (11) is the stream called with no query: "Query too short" (expected for an empty
query). 02, 05-10, 12, 14-17 render normally, nothing about a rebuild; `/health` (05) reports
embeddings status "stale" with the app ok, i.e. it reports and builds nothing.

Visual checklist (search, search-results, ask at 1024/1440/1920):
- search: box, Search button, modes, topic cloud visible and unclipped at all three widths.
- search-results: 20 results for "vector index", "15293 docs indexed, 923991 chunks", T-3786 listed, at all three widths.
- ask: Ask AI panel, input, Send, Save Conversation visible at all three widths. The model picker is
  NOT filled in these static shots (provider and model blank at 1440; model blank at 1024 and 1920),
  so the checklist's "model picker ok" is not shown by them; `walk-2-ask.png` shows it filled
  (Ollama / dengcao/Qwen3-Reranker-0.6B) once loaded.
- At 1024 the theme toggle wraps to a second header line (site chrome, not this task).
- `walk-1-search.png`: results in the browser. `walk-2-ask.png`: an answer with "Sources (10)" in the browser.

## Notes

- In the browser the Ask AI picker defaulted to a reranker model, so the browser answer in
  `walk-2-ask.png` ends "I don't have enough information to answer this question". An answer does
  appear and nothing is rebuilt; the poor default is filed as T-5143 and is not index safety.
  The server default (`qwen3:14b`) answered correctly in my own run.
- Pages the capture did not include: `/ask`, `/ask/stream` (`web/blueprints/api.py`) and
  `/search/load-conversation`. The criterion's two steps use `/search` and its Ask AI stream
  `/search/ask` only, both of which I saw and exercised; I make no claim about the three unseen pages.

Verdict: not-evaluated.

Everything I saw and ran meets the criterion (sections above). But the capture was partial: `/ask`,
`/ask/stream` and `/search/load-conversation` were not captured, and the ledger lists `/ask` as a
required page for this criterion and refused a green ("required page '/ask' has no verified
screenshot (/ask: HTTP 404)"). I do not vote on pages I did not see.
