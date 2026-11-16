# T-3786 Human AC#1 — evidence report (panel seat claude-code)

Revision reviewed: 415d10706db6218e349a5b34f45204ebd7edffb3. Watchtower pid 3685542, `bin/fw watchtower current` passes (newer than every file under web/).

Criterion: search and ask still work, and never rebuild the index from the page.

## What I did (my own walk, headless Chromium via Playwright, 1440 px, 2026-11-16)

Step 1. Opened http://192.168.10.107:3000/search, typed "vector index", Enter.
- "Found 20 results for vector index (hybrid) — 15356 docs indexed, 931734 chunks" after 8.4 s. T-3786 itself is among the results.
- Shot: reviewer-walk-1-search.

Step 2. Same page, clicked "Ask AI", asked "what is T-3786 about?".
- Default model (picker preselects `dengcao/Qwen3-Reranker-0.6B:latest`): text streams within 22 s, "Sources (10)" follows. The text ends "I don't have enough information to answer this question." Shot: reviewer-walk-2-ask-default-model.
- Repeated with `qwen3:14b` chosen in the picker: after 28 s a correct answer ("... modifying `_get_db()` in web/embeddings.py to raise an IndexUnavailable exception instead of rebuilding ..."), Sources (10). Shot: reviewer-walk-3-ask-qwen3.
- Neither run printed "fw index reindex" or "unavailable" in the ask panel. (The search-results page contains the string "fw index reindex" once, inside the excerpt of result T-4350; it is result text, not a status message.)

Never rebuilt:
- `.context/working/fw-vec-index.db` before, after step 1, after step 2 and at the end of the review: 6,177,988,608 bytes, mtime 1794811383.231402, inode 754341008. Identical each time.
- No `.building` or `.tmp` file beside it; no `fw index reindex` or build process running.
- Requests the page made: GET /search, POST /search, GET /api/v1/health, GET /search/conversations, POST /search/ask. No console or page errors.

Code and tests at this revision:
- `web/embeddings.py` `_get_db` (lines 513-551): three `IndexUnavailable` raises (unopenable, empty, missing), each naming `fw index reindex`; no build call.
- `web/blueprints/discovery.py` 403-408: when the index is not ready the ask stream emits "It is never rebuilt from this page; rebuild with: fw index reindex" and returns. `grep build_index|reindex_incremental|_trigger_async web/blueprints/` finds only that comment.
- `python3 -m pytest -q tests/unit/test_t3786_index_never_built_by_readers.py`: 6 passed.
- I did not make the live index unavailable to see the message on the page (that would mean touching the 6 GB live index); the unavailable branch is judged from code and the tests.

## Two things the operator should know

1. Default ask answer is a non-answer. Walking step 2 exactly as written, without touching the picker, the page says it lacks information. The cause is the picker's default (a reranker model, first in the Ollama list), which is filed as T-5143 (status captured). The picker code (`web/static/js/search-qa.js`) was not changed by any T-3786 commit; its last changes are T-4061 (2026-10-11, telemetry) and March. So this is "as before", not a regression from this task, and the retrieval + stream path the task touched works. I counted it as outside this criterion.

2. The task's `ask@{1024,1440,1920}.png` shots do not show a populated model picker (model select blank at all three widths, provider blank too at 1440), though the checklist row says "model picker ok". They were captured before the async model list loaded. I re-shot live after 5 s at all three widths: provider "Ollama", model select populated (18 options), input and Send visible, no horizontal overflow (scrollWidth == clientWidth). Shots: reviewer-ask-live@1024/1440/1920.

## Screenshots read

Judge pages (all 14): 01-search (search box, modes, topic cloud, saved answers, fine), 02-root (top of dashboard only, fine), 03-health (JSON; embeddings status "stale", index age 962 s, freshness only), 04-decisions, 05-learnings, 06-gaps, 07-api-learnings, 08-api-decisions (JSON), 09-search-ask (bare GET: "Query too short", expected for a bare request), 10-search-conversations (JSON, 2), 11-search-feedback-analytics, 12-patterns, 13-api-patterns, 14-graduation. None shows an index error or a rebuild notice.

Visual checklist:
| state | 1024 | 1440 | 1920 |
|---|---|---|---|
| search: box, modes, topic cloud | ok | ok | ok |
| search-results: 20 results for "vector index", "15293 docs indexed" | ok | ok | ok |
| ask: panel, input, Send | ok | ok | ok |
| ask: model picker | blank in the task's shot; ok live | blank in the task's shot; ok live | blank in the task's shot; ok live |

At 1024 the top nav's theme toggle wraps onto a second row. That is the site header, not something this task changed.

## Verdict: green
