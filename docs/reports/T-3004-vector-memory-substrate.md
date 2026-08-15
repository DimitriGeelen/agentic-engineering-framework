# T-3004 — Vector memory substrate: liveness, reliability, isolation, vendored client

**Status:** findings complete
**Filed:** 2026-08-15
**Workflow:** inception

## The question

The operator asked four things that are one question:

1. Is the vector database live, and is it actually being *used*?
2. What is its antifragility / reliability posture?
3. Is a structural refactor warranted — framework side and vendored-client side?
4. Should it be absolutely isolated? Specifically (operator, mid-session):
   *"can and should we migrate the vector db to an isolated per project vector db
   for vendored projects?"*

(1) is the evidence base. (2)–(4) are the decision.

## Findings

### F0 — It is not the database anyone thought it was

There is no Qdrant. Nothing listens on 6333/6334, no container runs one, and the
live source contains **zero** Qdrant client code — the four matches are two stale
comments in `agents/context/lib/focus.sh:140,148` and two regex *literals* in the
BVP estimator's file-scoring patterns (`estimator.py:525,830`). The comments
outlived the thing they described and are now actively misleading: they are why
"our vector database" reads as a service.

The actual store is **sqlite-vec** (`web/embeddings.py:1`, T-245) — an embedded
vector index inside a single SQLite file:

```
VECTOR_DB_PATH = $PROJECT_ROOT/.context/working/fw-vec-index.db
```

Ollama (`:11434`) is live and serves the embeddings (`nomic-embed-text-v2-moe`,
768-dim). So the *embedding provider* is a service; the *vector store* is a file.

### F1 — The index is live, answers queries, and is five months stale

| | |
|---|---|
| file | 74 MB, `is_index_ready()` → `True` |
| last written | **2026-03-10** (158 days ago) |
| highest task indexed | **T-409** (we are at T-3004) |
| docs / chunks | 1,380 / 21,292 |

Coverage against the corpus actually on disk:

| category | indexed | on disk | coverage |
|---|---:|---:|---:|
| Completed tasks | 373 | 2,643 | 14.1% |
| Episodic memory | 403 | 2,645 | 15.2% |
| Handovers | 295 | 1,697 | 17.4% |
| Research reports | 99 | 643 | 15.4% |
| Fabric cards | 136 | 1,045 | 13.0% |
| Active tasks | 35 | 348 | 10.1% |
| **total** | **1,341** | **9,021** | **~15%** |

**85% of the corpus is invisible to semantic recall**, and has been for months.

### F2 — Why it froze: the staleness check cannot fire (root cause)

`web/embeddings.py:193-213`:

```python
def _get_db():
    if _db is not None and (time.time() - _db_built_at) < STALE_SECONDS:   # :197
        return _db
    if DB_PATH.exists() and DB_PATH.stat().st_size > 4096:                 # :201
        _db = _init_db()
        if count > 0:
            _db_built_at = time.time()                                     # :206  ← resets
            return _db
    build_index()                                                          # :212  unreachable
```

`STALE_SECONDS = 3600` guards only the **in-process** handle. When it expires,
control falls to `:201`, which reopens the same file and sets `_db_built_at =
time.time()` — the *reuse* path stamps the clock as though it had rebuilt. The
age therefore resets to zero every time it is measured, and `build_index()` at
`:212` is reachable only when the file is missing or empty.

So once the file exists with ≥1 row, **it is never rebuilt again**. Not by age,
not by CLI invocation (every CLI run is a fresh process → `_db is None` → straight
to the reuse path), and not by schedule: no cron entry references the index.
`build_index()` has exactly three live callers, all requiring an explicit human
action (`web/search.py:98`, `web/blueprints/discovery.py:33`, and the
missing-file branch).

### F3 — The failure is silent in three independent places

This is the antifragility finding, and it is the one worth keeping. The system
degraded to 15% recall and **every instrument reported healthy**:

1. **`is_index_ready()` → `True`** — it asks "does the file have rows?", never
   "do those rows correspond to the corpus?"
2. **`index_stats()['built_at']` → 14 seconds ago** — measured live during this
   investigation while the file's mtime was 2026-03-10. The field is named for
   build time and carries open time (F2, `:206`). Any freshness check written
   against it is vacuous by construction.
3. **`fw doctor` says nothing** — no doctor or audit rail mentions the index at
   all. (Doctor also timed out at 180s in this session, rc=124 — separate defect,
   filed below.)

And the consumer of all this fails silently too. `focus.sh:144,152` — which runs
on **every `fw context focus`**, i.e. every task start:

```bash
timeout 10 python3 "$recall_script" --task "$task_id" --limit 5 2>/dev/null || true
timeout 15 python3 "$ask_script" --concise --no-think "Brief me on task ..." 2>/dev/null || true
```

`2>/dev/null || true` means a dead store, a missing Ollama, and a healthy store
that simply has nothing relevant are **the same observable event**: no briefing
appears. There is no state in which the operator or the agent is told recall
degraded. A briefing built from 15% of history is indistinguishable from a good
one, because the only evidence of quality is the text itself.

This is the exact shape of the false-green class this session has been working
through (T-2999 seed assertions, T-3000 template ordering): *a check that cannot
go red is not a check.* Here there are three of them stacked, plus a consumer that
discards the error stream.

### F4 — Isolation: already per-project, with a fail-open fallback

`web/config.py:18` —

```python
_PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", str(_FRAMEWORK_ROOT)))
```

Measured both branches:

```
PROJECT_ROOT=/tmp/fake-consumer  ->  /tmp/fake-consumer/.context/working/fw-vec-index.db
PROJECT_ROOT unset               ->  /opt/999-.../.context/working/fw-vec-index.db
```

`bin/fw:902` does `export PROJECT_ROOT` globally, so **every shim-mediated
invocation is correctly isolated**. The store is a gitignored file
(`.gitignore:97`) inside each project. There is no shared server, no shared
collection, no cross-project namespace.

Two real defects behind that otherwise-clean answer:

- **D-A (fail-open direction).** When `PROJECT_ROOT` is unset the default is
  `_FRAMEWORK_ROOT` — not "no index" but *the framework's own index*. A consumer
  path that misses the export reads and writes the framework's memory. The
  reachable surface is non-shim entry: `.mcp.json` launches the `fw` MCP server as
  bare `python3 agents/mcp/framework_mcp_server.py` with `env: {}`, inheriting
  whatever the Claude Code process has — and `bin/fw:166` documents a live
  `PROJECT_ROOT=$HOME` poisoning case (T-2390). Wrong-project recall would be
  silent, per F3.
- **D-B (consumers have nothing).** `/003-NTB-ATC-Plugin` has **no index file at
  all**. Nothing in `fw init` / `fw upgrade` builds one, and F2 means it will never
  be built automatically. Every consumer's semantic recall is a silent no-op today.

## Answering the operator's question

> *can and should we migrate the vector db to an isolated per project vector db
> for vendored projects?*

**Can:** there is nothing to migrate. Per-project isolation is already the
architecture — an embedded sqlite-vec file under each project's
`.context/working/`, resolved through `$PROJECT_ROOT`, gitignored, no server.
The premise of the question (a shared store to be split) does not hold.

**Should:** "absolute isolation" as a *stronger* posture is not the improvement
available here, and pursuing it would be motion without gain — it is what we
already have. Two things it does not currently mean, and should:

1. Isolation must **fail closed**. Today an unset `PROJECT_ROOT` silently borrows
   the framework's index (D-A). Isolation that degrades into *the wrong project's
   memory* rather than *no memory* is the one failure mode worth engineering
   against, and it is one line plus a guard.
2. Isolation is worth nothing when the isolated thing is empty (D-B) or frozen
   (F1/F2). A consumer today has perfect isolation and zero recall.

The honest reframe: **the isolation question is already answered; the liveness
question is not.** Effort belongs on freshness and observability, not topology.

The framework's own §TermLink note argues the inverse for machine-wide substrates
(shared binary, system sockets, cross-session discovery). It does not apply: the
vector index is derived per-project data with no cross-project protocol, so the
embedded-file model is right and should stay.

## Recommendation

**Recommendation:** GO — but on a scope deliberately narrower than the one asked
about, and not on migration.

**Rationale:** The migration this inception was asked to evaluate is already done
and needs no work (F4). What measurement found instead is a substrate that has
been silently serving 15% recall since March (F1) because its staleness check
resets its own clock (F2), while three independent instruments and one
error-discarding caller all report healthy (F3). That is a live antifragility
defect with a known root cause and a small fix, which outranks any topology
change. I am recommending GO on the freshness/observability work and NO-GO on
migration — recording both, because the second is the question that was asked.

**Evidence:**
- No Qdrant anywhere in live source; store is sqlite-vec at
  `$PROJECT_ROOT/.context/working/fw-vec-index.db` (`web/embeddings.py:52`,
  `web/config.py:45`)
- Index mtime 2026-03-10, highest indexed task T-409 vs current T-3004
- Coverage ~15% (1,341 of 9,021 corpus documents), measured per category
- `_db_built_at = time.time()` on the *reuse* path (`web/embeddings.py:206`) makes
  `STALE_SECONDS` unreachable and `built_at` vacuous — reproduced live
  (`built_at` = now, file mtime = March)
- `is_index_ready()` checks row count, not correspondence (`:175-190`)
- Zero doctor/audit coverage; zero cron rebuild entries
- `focus.sh:144,152` discards stderr and forces exit 0 on the only path that runs
  every task start
- `PROJECT_ROOT` unset → framework's own index (measured); `.mcp.json` `fw` server
  launches with `env: {}`
- `/003-NTB-ATC-Plugin` has no index file

**Proposed build slices** (each its own task, per §Task Sizing — filed only on GO):

| # | Slice | Why it is separate |
|---|---|---|
| 1 | Fix `_get_db()` so the reuse path preserves the true build time; persist `built_at` in the DB rather than in a module global | The root cause (F2). Everything else is detection. |
| 2 | `fw doctor` rail: index age + corpus-coverage ratio, WARN on drift | Makes F1 impossible to sit on unnoticed again |
| 3 | Scheduled/incremental reindex (cron, registry→generated→deployed chain per L-364) | Turns the fix into a standing property |
| 4 | Make degradation observable at `focus.sh` — distinguish "no store" / "store stale" / "no hits" instead of collapsing all three into silence | F3's consumer half; the `2>/dev/null \|\| true` shape |
| 5 | Fail-closed `PROJECT_ROOT`: refuse rather than default to `_FRAMEWORK_ROOT`; pass `PROJECT_ROOT` explicitly in `.mcp.json` | D-A — the only genuine isolation defect |
| 6 | Build an index on `fw init` / `fw upgrade` for consumers | D-B — consumers currently get a no-op |

Slices 1+2 are the minimum that converts a silent 85% loss into a visible one.

**NO-GO, recorded explicitly:** migrating to a per-project vector DB, and adopting
a server-backed store (Qdrant or otherwise). The first is already true; the second
would trade an isolated file for a shared service and re-introduce exactly the
cross-project bleed D-A currently risks.

## Dialogue Log

### 2026-08-15 — framing

- **Operator:** "please validate our vector database is live and being used, reflect
  in the anti fragility and reliability of our vector database for aef, consider
  refactoring and enhancing on a structural level for the framework and vendored
  client, also consider absolute isolation"
- **Agent:** treated as one inception rather than four tasks — liveness is the
  evidence for the other three, not an independent deliverable.

### 2026-08-15 — the premise did not survive measurement

- **Operator:** "ultra deep think can and should we migrate the vector db to a
  isolated per project vector db for vendored projects ??"
- **Agent:** answered against measurement rather than the premise. The store is
  already per-project (F4) — so the truthful answer is that the migration is a
  no-op, and saying otherwise would have produced a plausible plan for work with
  no effect. Recorded as an explicit NO-GO alongside the GO, so the question is
  answered rather than quietly dropped.
- **Course correction against my own first instinct:** the Qdrant comments in
  `focus.sh` and the operator's framing both pointed at a service. Probing ports
  first (finding nothing) and *then* reading the storage layer is what caught it;
  had I started from the comments I would have concluded "the vector DB is down"
  and been wrong in a way that reads correct.

## Open items surfaced, not pursued (each needs its own task)

- `fw doctor` timed out at 180s (rc=124) during this investigation. Unrelated to
  the index; noted because doctor is the rail slice 2 would add to.
- The two Qdrant comments at `focus.sh:140,148` should be corrected to sqlite-vec —
  they are why the substrate was misidentified.
