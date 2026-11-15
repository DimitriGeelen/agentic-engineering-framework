# T-3786 Human AC#1 — evidence report (panel seat claude-code, rung 5)

Dispatch: judge-t-3786-r5-claude-code-8c29bf82cd84. Revision reviewed: 3e064047d67404b9db6fd39f0d1c546bbfa94866.
Criterion: "Search and ask still work, and never rebuild the index from the page".

Verdict: **green**.

## 1. The two steps, walked by me in a browser (Playwright/Chromium, 1440 px, live Watchtower on :3000, pid 2720054 started 2026-11-15 20:16, i.e. after the task's code commits of 08:14)

Step 1 — opened /search, typed "vector index", pressed Search:
- "Found 20 results for vector index (hybrid) — 15328 docs indexed, 927917 chunks" after 6.9 s; T-3786 itself is the fourth result.
- Screenshot: `mywalk-1-search-judge-t-3786-r5-claude-code-8c29bf82cd84.png`.

Step 2 — on the same page (no reload; URL still /search) clicked the "Ask AI" pill, typed "what is T-3786 about?", pressed Send, model picker left at its default:
- status "Searching knowledge base...", first answer text after 28.3 s, stream finished at about 40 s, "Sources (10)" under the answer.
- No error box, and nothing on the page says "fw index reindex" (the unavailable message did not appear, correctly: the index is available).
- Screenshot: `mywalk-2-ask-judge-t-3786-r5-claude-code-8c29bf82cd84.png`.
- Browser console errors / page errors during the whole walk: none.
- Requests the page made: GET /search, POST /search, GET /search/conversations, POST /search/ask. Nothing else.

## 2. "Never rebuild the index from the page"

Live index `.context/working/fw-vec-index.db`, measured immediately before step 1 and after step 2, and again after three further Ask AI page loads:
- size 6,147,796,992 bytes, mtime 1794775830.5699089, inode 754341008 — identical each time. Same inode rules out a replace as well as an in-place rebuild.
- Files beside it before and after: only `fw-vec-index.db`, `.manifest.json`, `.reindex.lock`. No `.building` or `.reindex.<pid>.tmp` scratch appeared.
- No reindex/build process was running (pgrep) when I started.

Code at the reviewed revision:
- `web/embeddings.py:513-551` `_get_db`: all three failure paths (cannot open, zero documents, no file) raise `IndexUnavailable` with "rebuild with: fw index reindex" / "build it with: fw index reindex". There is no call to `build_index` in it.
- `web/blueprints/discovery.py:403-408` (ask stream): when the index is not ready it emits a status event "Knowledge index is unavailable (missing, empty or unreadable). It is never rebuilt from this page; rebuild with: fw index reindex" and an error event "The embedding index is unavailable. Rebuild it with: fw index reindex", then returns. Nothing is started.
- `web/static/js/search-qa.js:210` shows an `error` event's message on the page, so that text reaches the reader.
- grep of `web/blueprints/*.py` for `build_index` / `reindex_incremental`: no hits.
- `python3 -m pytest tests/unit/test_t3786_index_never_built_by_readers.py`: 6 passed (unopenable, empty and missing index raise and leave the file untouched; failed build leaves the previous index byte-identical; successful build swaps atomically; no module under web/blueprints can start a build).

Not exercised live: the "index unavailable" branch on the real page. Doing so would mean breaking the 6 GB live index; I judged that branch from the code and the unit tests above. The criterion states it as a conditional ("If the index were unavailable, the page would say …"), which the code satisfies.

## 3. Things I saw that do not change the verdict

- **Answer quality.** The answer came from `dengcao/Qwen3-Reranker-0.6B:latest`, the model picker's default, which is a reranker, not a chat model. It rambled and ended "I don't have enough information to answer this task", although the retrieval found the T-3786 material (it mentions `_get_db()` raising instead of rebuilding). The criterion asks that an answer appears as before, and it does; the task's commits do not touch model selection (`git show 4593863c4 9e9174d2a --stat`: embeddings.py, discovery.py index branch, api.py, lib/ask.py exit code, tests). Already filed as T-5143 (status captured).
- **The task's ask@ shots were taken before the model list loaded.** In `ask@1024/1440/1920.png` the model picker is an empty stub (at 1440 the provider box is empty too), so those shots do not actually show the "model picker ok" the checklist claims. I re-captured the Ask AI panel at all three widths after the list loaded (`myask-loaded@{1024,1440,1920}-judge-t-3786-r5-claude-code-8c29bf82cd84.png`): provider "Ollama", model select 200 px wide showing the default, Test button, input and Send all inside the viewport, no horizontal scroll, no overlap. So the control is fine; the task's own shots were early.
- At 1024 px the theme toggle in the site navigation wraps to a second row. That is the shared nav, on every page, not something this task changed.

## 4. Screenshots read

Rendered pages (14), all read: 01-search (search box, modes, topic cloud, saved answers), 02-root (top of dashboard only, page is 55,267 px), 03-health (JSON: app ok, embeddings status "stale" with index_age_seconds 986, ollama ok), 04-decisions, 05-learnings, 06-gaps, 07-api-learnings (JSON), 08-api-decisions (JSON), 09-search-ask (bare GET: "Query too short (min 2 characters)", expected for a request with no query), 10-search-conversations (JSON, 2 conversations), 11-search-feedback-analytics, 12-patterns, 13-api-patterns (JSON), 14-graduation. All render; none shows an error or a rebuild message. The capture reported no console or page errors on any of them.

Visual evidence (9), all read against the task's checklist:
| state | control | 1024 | 1440 | 1920 |
|---|---|---|---|---|
| search | search box, modes, topic cloud | ok | ok | ok |
| search-results | result list for "vector index" (20 results, "15293 docs indexed, 923991 chunks") | ok | ok | ok |
| ask | Ask AI panel, input, Send | ok | ok | ok |
| ask | model picker | not shown loaded in the task's shot; ok in my re-capture | same | same |

`/health` reports embeddings "stale" at 986 s old. That is the freshness rail (T-3783), separate from this criterion; the index is present and served both steps.
