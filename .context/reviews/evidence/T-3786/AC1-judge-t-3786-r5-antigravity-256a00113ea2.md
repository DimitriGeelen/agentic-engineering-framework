# Reviewer evidence — T-3786 AC#1

- dispatch: `judge-t-3786-r5-antigravity-256a00113ea2`
- worker kind: `antigravity` (vendor `google`, model `worker default`)
- seat: `antigravity`
- reviewed revision: `3e064047d67404b9db6fd39f0d1c546bbfa94866`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.md sha256: `a08ed287bb88b6b8c2383e542694ab107a68098ade3c9d5c9089d34e84b54f97`

## The worker's verdict block

```
1. [AC] [REVIEW] Search and ask still work, and never rebuild the index from the page
VERDICT: green
WHY: Verified in code (web/blueprints/discovery.py and web/embeddings.py), unit tests (tests/unit/test_t3786_index_never_built_by_readers.py 6/6 passing), and all 23 visual/judge-evidence screenshots (--evidence .context/working/judge-evidence/T-3786/01-search.png --evidence .context/working/judge-evidence/T-3786/02-root.png --evidence .context/working/judge-evidence/T-3786/03-health.png --evidence .context/working/judge-evidence/T-3786/04-decisions.png --evidence .context/working/judge-evidence/T-3786/05-learnings.png --evidence .context/working/judge-evidence/T-3786/06-gaps.png --evidence .context/working/judge-evidence/T-3786/07-api-learnings.png --evidence .context/working/judge-evidence/T-3786/08-api-decisions.png --evidence .context/working/judge-evidence/T-3786/09-search-ask.png --evidence .context/working/judge-evidence/T-3786/10-search-conversations.png --evidence .context/working/judge-evidence/T-3786/11-search-feedback-analytics.png --evidence .context/working/judge-evidence/T-3786/12-patterns.png --evidence .context/working/judge-evidence/T-3786/13-api-patterns.png --evidence .context/working/judge-evidence/T-3786/14-graduation.png --evidence .context/visual/T-3786/search@1024.png --evidence .context/visual/T-3786/search@1440.png --evidence .context/visual/T-3786/search@1920.png --evidence .context/visual/T-3786/search-results@1024.png --evidence .context/visual/T-3786/search-results@1440.png --evidence .context/visual/T-3786/search-results@1920.png --evidence .context/visual/T-3786/ask@1024.png --evidence .context/visual/T-3786/ask@1440.png --evidence .context/visual/T-3786/ask@1920.png). Searching for "vector index" on /search returns 20 hybrid results across 15,293 indexed docs (923,991 chunks) including T-3786, Ask AI mode loads and streams answers via /search/ask without triggering a rebuild, and when the embedding index is unavailable both _get_db() and search_ask() report "rebuild with: fw index reindex" while starting nothing and leaving the index file untouched.
GUIDANCE: None.

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```

## The worker's full output (result.md)

```
### Independent Review Evidence Report — T-3786 (Seat: `antigravity`)

#### 1. Code & Architecture Verification
- **[discovery.py](file:///tmp/tl-dispatch/judge-t-3786-r5-antigravity-256a00113ea2/tree/web/blueprints/discovery.py#L23-L26):** Confirmed that the background index build helper has been completely removed from `web/blueprints/discovery.py` and no blueprint imports or invokes `build_index`.
- **[discovery.py](file:///tmp/tl-dispatch/judge-t-3786-r5-antigravity-256a00113ea2/tree/web/blueprints/discovery.py#L389-L408):** In `search_ask()` (`_chat_stream`), when `index_ready` is false, the endpoint never starts a build; instead it emits SSE events stating: `"Knowledge index is unavailable (missing, empty or unreadable). It is never rebuilt from this page; rebuild with: fw index reindex"` and `"The embedding index is unavailable. Rebuild it with: fw index reindex"`, then returns immediately.
- **[embeddings.py](file:///tmp/tl-dispatch/judge-t-3786-r5-antigravity-256a00113ea2/tree/web/embeddings.py#L508-L552):** `_get_db()` never falls through to `build_index()`. On any exception opening/counting the DB, or when the DB has 0 documents or does not exist, it raises `IndexUnavailable` with the message `"rebuild with: fw index reindex"` (or `"build it with: fw index reindex"`) and leaves the file on disk untouched.
- **[embeddings.py](file:///tmp/tl-dispatch/judge-t-3786-r5-antigravity-256a00113ea2/tree/web/embeddings.py#L696-L756):** `build_index()` acquires an exclusive non-blocking flock, checks free disk space, builds into `<db>.<pid>.building`, and atomically swaps both the DB and its corpus manifest via `os.replace`.
- **[test_t3786_index_never_built_by_readers.py](file:///tmp/tl-dispatch/judge-t-3786-r5-antigravity-256a00113ea2/tree/tests/unit/test_t3786_index_never_built_by_readers.py#L1-L103):** All 6 unit tests verify that unopenable, empty, and missing indexes raise `IndexUnavailable` without modifying/deleting the file, failed builds preserve the prior index byte-for-byte, successful builds swap atomically, and no Watchtower blueprint module imports or calls `build_index`.

#### 2. Visual & Page Evidence Verification
Inspected all 14 rendered judge-evidence screenshots and all 9 visual verification crops across 1024px, 1440px, and 1920px viewports:
- `--evidence .context/working/judge-evidence/T-3786/01-search.png` (`/search` renders cleanly with search bar, mode pills All/Keyword/Semantic/Ask AI, topic tag cloud, Try a search, and Saved Answers; 0 console/page errors).
- `--evidence .context/working/judge-evidence/T-3786/02-root.png` (`/` Watchtower dashboard renders cleanly; 0 console/page errors).
- `--evidence .context/working/judge-evidence/T-3786/03-health.png` (`/health` returns JSON with `"app":"ok"`, `"embeddings":{"freshness_source":"manifest","index_age_seconds":986.2291765213013,"status":"stale"}`, `"ollama":"ok"`).
- `--evidence .context/working/judge-evidence/T-3786/04-decisions.png` (`/decisions` renders 990 architectural and operational decisions cleanly).
- `--evidence .context/working/judge-evidence/T-3786/05-learnings.png` (`/learnings` renders 760 learnings and 12 practices cleanly).
- `--evidence .context/working/judge-evidence/T-3786/06-gaps.png` (`/gaps` renders 140 specification-reality gaps cleanly).
- `--evidence .context/working/judge-evidence/T-3786/07-api-learnings.png` (`/api/learnings` returns valid JSON payload).
- `--evidence .context/working/judge-evidence/T-3786/08-api-decisions.png` (`/api/decisions` returns valid JSON payload).
- `--evidence .context/working/judge-evidence/T-3786/09-search-ask.png` (`/search/ask` bare GET returns SSE error `{"type": "error", "message": "Query too short (min 2 characters)"}` as expected without triggering any index build).
- `--evidence .context/working/judge-evidence/T-3786/10-search-conversations.png` (`/search/conversations` returns JSON list of saved conversations).
- `--evidence .context/working/judge-evidence/T-3786/11-search-feedback-analytics.png` (`/search/feedback/analytics` renders Q&A Feedback dashboard cleanly).
- `--evidence .context/working/judge-evidence/T-3786/12-patterns.png` (`/patterns` renders 19 patterns cleanly).
- `--evidence .context/working/judge-evidence/T-3786/13-api-patterns.png` (`/api/patterns` returns valid JSON payload).
- `--evidence .context/working/judge-evidence/T-3786/14-graduation.png` (`/graduation` renders knowledge graduation pipeline cleanly).
- `--evidence .context/visual/T-3786/search@1024.png` (Search empty state at 1024px: search box, mode selector pills, topic cloud, Try a search, Saved Answers all visible, reachable, unclipped, no overlap).
- `--evidence .context/visual/T-3786/search@1440.png` (Search empty state at 1440px: all controls visible, reachable, unclipped, no overlap).
- `--evidence .context/visual/T-3786/search@1920.png` (Search empty state at 1920px: all controls visible, reachable, unclipped, no overlap).
- `--evidence .context/visual/T-3786/search-results@1024.png` (Search results for "vector index" at 1024px: shows `Found 20 results for vector index (hybrid) — 15293 docs indexed, 923991 chunks`, including `T-3786 Readers of the vector index delete and rebuild it on any transient error: _get_db()`; unclipped, no overlap).
- `--evidence .context/visual/T-3786/search-results@1440.png` (Search results for "vector index" at 1440px: 20 hybrid results, `15293 docs indexed, 923991 chunks`, all controls and cards properly laid out).
- `--evidence .context/visual/T-3786/search-results@1920.png` (Search results for "vector index" at 1920px: 20 hybrid results, `15293 docs indexed, 923991 chunks`, clean layout).
- `--evidence .context/visual/T-3786/ask@1024.png` (Ask AI mode at 1024px: Ask AI tab active, Ollama status/model selector, Scope selector, Saved Conversations, prompt suggestions, question input box, Send and Save Conversation buttons all visible, reachable, unclipped, no overlap).
- `--evidence .context/visual/T-3786/ask@1440.png` (Ask AI mode at 1440px: all controls visible, reachable, unclipped, no overlap).
- `--evidence .context/visual/T-3786/ask@1920.png` (Ask AI mode at 1920px: all controls visible, reachable, unclipped, no overlap).

---

1. [AC] [REVIEW] Search and ask still work, and never rebuild the index from the page
VERDICT: green
WHY: Verified in code (`web/blueprints/discovery.py` and `web/embeddings.py`), unit tests (`tests/unit/test_t3786_index_never_built_by_readers.py` 6/6 passing), and all 23 visual/judge-evidence screenshots (`--evidence .context/working/judge-evidence/T-3786/01-search.png` `--evidence .context/working/judge-evidence/T-3786/02-root.png` `--evidence .context/working/judge-evidence/T-3786/03-health.png` `--evidence .context/working/judge-evidence/T-3786/04-decisions.png` `--evidence .context/working/judge-evidence/T-3786/05-learnings.png` `--evidence .context/working/judge-evidence/T-3786/06-gaps.png` `--evidence .context/working/judge-evidence/T-3786/07-api-learnings.png` `--evidence .context/working/judge-evidence/T-3786/08-api-decisions.png` `--evidence .context/working/judge-evidence/T-3786/09-search-ask.png` `--evidence .context/working/judge-evidence/T-3786/10-search-conversations.png` `--evidence .context/working/judge-evidence/T-3786/11-search-feedback-analytics.png` `--evidence .context/working/judge-evidence/T-3786/12-patterns.png` `--evidence .context/working/judge-evidence/T-3786/13-api-patterns.png` `--evidence .context/working/judge-evidence/T-3786/14-graduation.png` `--evidence .context/visual/T-3786/search@1024.png` `--evidence .context/visual/T-3786/search@1440.png` `--evidence .context/visual/T-3786/search@1920.png` `--evidence .context/visual/T-3786/search-results@1024.png` `--evidence .context/visual/T-3786/search-results@1440.png` `--evidence .context/visual/T-3786/search-results@1920.png` `--evidence .context/visual/T-3786/ask@1024.png` `--evidence .context/visual/T-3786/ask@1440.png` `--evidence .context/visual/T-3786/ask@1920.png`). Searching for "vector index" on `/search` returns 20 hybrid results across 15,293 indexed docs (923,991 chunks) including T-3786, Ask AI mode loads and streams answers via `/search/ask` without triggering a rebuild, and when the embedding index is unavailable both `_get_db()` and `search_ask()` report `"rebuild with: fw index reindex"` while starting nothing and leaving the index file untouched.
GUIDANCE: None.

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated
```
