# OBS-292 — Where the framework writes memory, and what `index_one()` can actually hook

Analysis-only report for T-1719 A1 wiring. Read-only sweep of `bin/fw`, `agents/context/`,
`agents/task-create/`, `lib/`, `web/`. No source file was modified.

## Verdict

**Six real write sites** exist across the learning/decision/pattern/episodic/task surfaces —
not two. `lib/learnings.sh` does not exist and never did; the real handlers live in
`agents/context/lib/{learning,pattern,decision,episodic}.sh`.

**`index_one()` currently has ZERO callers** — `grep -rn index_one` over the whole repo
returns only its definition (`web/embeddings.py:668`) and its test
(`tests/unit/t1719_index_one_post_write.bats`). Nothing wires it.

**But indexing is NOT unwired.** `fw index reindex` → `reindex_incremental()` is live and
cron-scheduled hourly (`.context/cron-registry.yaml:51`, id `index-reindex-hourly`, `20 * * * *`,
origin T-3014). Every site below is *already* eventually indexed — within ≤1h. The wiring
question is therefore latency-reduction, not coverage. That materially changes the value case
for three of the six sites (see §Wiring Recommendation).

## Write Sites

### 1. `fw context add-learning`

- **Routing:** `bin/fw` → `agents/context/context.sh:72-76` → `source lib/learning.sh` → `do_add_learning`
- **Handler:** `agents/context/lib/learning.sh:15`
- **Target file:** `.context/project/learnings.yaml` (bound at `learning.sh:53`)
- **Write line:** `agents/context/lib/learning.sh:139` — `mv "$temp_file" "$learnings_file"`
  (awk rewrites the whole file to a tempfile, then atomically replaces it)
- **Shape:** **AGGREGATE-APPEND.** 395 KB / 4573 lines. At `MAX_CHUNK_CHARS = 1024`
  (`web/embeddings.py:107-108`) that is **~386 chunks**. `index_one()` accepts the path fine, but
  it re-embeds the entire file on every single learning added.
- **Secondary effect:** `learning.sh:143-148` fires `lib/publish-learning-to-bus.sh` (bus publish
  only — writes no corpus file).

### 2. `fw context add-pattern`

- **Routing:** `agents/context/context.sh:77-81` → `source lib/pattern.sh` → `do_add_pattern`
- **Handler:** `agents/context/lib/pattern.sh:5`
- **Target file:** `.context/project/patterns.yaml` (bound at `pattern.sh:69`)
- **Write line:** `agents/context/lib/pattern.sh:157` — `mv "$temp_file" "$patterns_file"`
- **Shape:** **AGGREGATE-APPEND.** 8.4 KB / 185 lines → ~8 chunks. Smallest of the three
  aggregates; a full re-embed here is genuinely cheap.

### 3. `fw context add-decision`

- **Routing:** `agents/context/context.sh:82-86` → `source lib/decision.sh` → `do_add_decision`
- **Handler:** `agents/context/lib/decision.sh:17`
- **Target file:** `.context/project/decisions.yaml` (bound at `decision.sh:70`)
- **Write line:** `agents/context/lib/decision.sh:147` — `echo "$entry" >> "$decisions_file"`
  (true append, not a rewrite)
- **Shape:** **AGGREGATE-APPEND.** 115 KB / 3140 lines → **~112 chunks** re-embedded per decision.
- **Note:** this handler is also invoked *programmatically* by
  `agents/task-create/update-task.sh:2251` (auto-capture of `## Decisions` at task close), so a
  single task close can call it N times — N full 112-chunk re-embeds if hooked naively.

### 4. `fw context generate-episodic` (fires on `--status work-completed`)

- **Routing:** `agents/context/context.sh:87-91` → `source lib/episodic.sh` → `do_generate_episodic`.
  Invoked from `update-task.sh:2295` (normal close) and `update-task.sh:1542`
  (partial-complete → human finalisation re-run).
- **Handler:** `agents/context/lib/episodic.sh` — `episodic_file` bound at line 245
- **Target file:** `.context/episodic/T-XXXX.yaml` — **one file per task**
- **Write lines:** `episodic.sh:256` (`cat >` — creates), `:287`, `:390-396`, `:399` (`cat >>` —
  final static block ends at `:421`). YAML validated at `:438`. File is settled after line 421.
- **Shape:** **SINGLE FILE.** ~2-6 KB → a handful of chunks. This is the textbook `index_one()`
  target: one path, one document, small, freshly written, never re-read.

### 5. Task file move `active/` → `completed/` (`--status work-completed`)

- **Handler:** `agents/task-create/update-task.sh`, two branches:
  - `:2052-2056` — normal completion path (`git mv` with `mv` fallback)
  - `:1503-1507` — partial-complete re-close path (human ticked their ACs later)
- **Target file:** `.tasks/completed/T-XXXX-<slug>.md` (`DEST` bound at `:2047` / `:1496`)
- **Last content write:** `update-task.sh:2087` — `_sed_i "s/^horizon:.*/horizon: null/"`.
  Earlier frontmatter writes at `:1968` (`last_update`), `:1981` (Updates append), `:2005`
  (`date_finished`), `:2012` (`owner`). Nothing writes `$TASK_FILE` after `:2087`.
- **Shape:** **SINGLE FILE** (~5-15 KB → ~5-15 chunks). But note it is a **rename**: the old
  `.tasks/active/T-XXXX-*.md` path still has live rows in the `documents`/`vec_documents`/
  `file_state` tables. `index_one()` adds the new path; it does **not** remove the stale one.
  Only `_delete_path_rows()` (`web/embeddings.py:657`) or a `reindex_incremental()` pass does that.
  **This site needs a delete-then-index pair, not a bare `index_one()`.**

### 6. `lib/subscribe-learnings-from-bus.sh` — cross-project learning ingest

- **Handler:** `lib/subscribe-learnings-from-bus.sh` (embedded python heredoc)
- **Target file:** `.context/project/received-learnings.yaml` (bound at `:36`)
- **Write line:** `lib/subscribe-learnings-from-bus.sh:202-203` — `with open(received_path,"w"): f.write(current)`
- **Shape:** **AGGREGATE-APPEND.** Currently absent from `.context/project/` on this host (never
  populated), so cost is nil today — but it is inside `AUTHORED_DIRS`, so it *is* corpus material
  the moment it exists. This is the site nobody in the T-1719 filing accounted for.

### Not a write site (checked and excluded)

- `web/blueprints/session.py:110,141` and `web/blueprints/cockpit.py:301,335` — Watchtower routes
  that shell out to `fw context add-decision` / `add-learning`. They converge on sites 1 and 3;
  hooking the handlers covers them for free. **Do not wire these separately.**
- `bin/fw:5998` — the `--source P-001` convenience wrapper, `exec`s into `context.sh add-learning`.
  Same convergence.
- `update-task.sh:1442` — `.context/working/happiness.jsonl` (T-1719 A2 retrieval-happiness
  signal). `.context/working/` is **not** in `AUTHORED_DIRS`; not corpus material.

## Existing Indexing

Something already does this. Loudly:

- **`web/embeddings.py:783` `reindex_incremental()`** — diffs `collect_files()` against the
  `file_state` table by content hash and re-embeds only the changed set. Atomic (builds on a DB
  copy, `os.replace`s it in).
- **`bin/fw:4967-4996` `fw index reindex`** — the CLI entry point that calls it.
- **`.context/cron-registry.yaml:51-64` `index-reindex-hourly`** — `20 * * * *`, flock-guarded,
  status `active`, origin T-3014. **Every site above is already picked up within the hour.**
- **`web/blueprints/discovery.py:31-33`** — calls `build_index()` (full rebuild) from a Watchtower
  route. Not a post-write hook; a manual/bootstrap path.
- **`lib/index-health.sh:37` / `agents/audit/audit.sh:2559` / `web/app.py:322`** — readers only
  (`index_freshness`, `corpus_health`). No writes.
- **`web/embeddings.py:668` `index_one()`** — defined, tested, **called by nothing**.

Corpus membership is confirmed for every target above: `web/search_utils.py:95-113` `AUTHORED_DIRS`
includes `(".tasks",)`, `(".context","episodic")`, `(".context","project")`; `INDEXED_SUFFIXES`
(`:92`) covers `.md`/`.yaml`.

## Wiring Recommendation

| # | Site | Path shape | `index_one()` fits? |
|---|------|-----------|---------------------|
| 4 | `.context/episodic/T-XXXX.yaml` | single, small | **Yes — best fit.** Hook after `episodic.sh:421`. |
| 5 | `.tasks/completed/T-XXXX-*.md` | single, renamed | **Partially** — needs stale-path delete first. |
| 2 | `.context/project/patterns.yaml` | aggregate, ~8 chunks | Yes, cost is tolerable. |
| 3 | `.context/project/decisions.yaml` | aggregate, ~112 chunks | **Poor fit.** |
| 1 | `.context/project/learnings.yaml` | aggregate, ~386 chunks | **Poor fit.** |
| 6 | `.context/project/received-learnings.yaml` | aggregate | Poor fit (same class as 1/3). |

**Sites 4 and 2 — wire `index_one()` directly.** One path, one small document, written once.
This is exactly what the function's docstring describes. Hook point for 4 is after the YAML
validation at `episodic.sh:438` (index only what parsed); for 2, after `pattern.sh:157`.

**Site 5 — `index_one()` alone is wrong.** The rename leaves orphan rows under the old
`.tasks/active/...` path that will keep surfacing in retrieval with pre-close content. Wire
`_delete_path_rows(db, old_rel_path)` **then** `index_one(new_path)`, at `update-task.sh:2087`
(after the last content write) and the equivalent point in the `:1503` branch. Both branches
must get it — see the T-1698 precedent in the comments at `:2313-2318`, where exactly this
duplicate-branch shape shipped half-wired.

**Sites 1, 3, 6 — `index_one()` is the wrong tool, and I'd argue against hooking them at all.**
The stated 1.6s budget is a measurement on a *single small document*; on `learnings.yaml` it is
~386 chunks / ~6 embed batches every time anyone records a learning, and site 3 is called in a
loop from `update-task.sh:2251` (N decisions → N × 112-chunk re-embeds in one task close). The
cost is per-write but the *content* added is one entry. Three options, in preference order:

1. **Do nothing — rely on the hourly `index-reindex-hourly` cron.** These are aggregates whose
   marginal entry is ~1/400th of the document; a ≤1h delay to retrievability is proportionate.
   This is the honest recommendation given the cron already exists.
2. **Split the aggregates into per-entry files** (`.context/project/learnings/L-NNN.yaml`), which
   makes `index_one()` correct by construction and fixes the re-embed cost permanently. Real work,
   touches `fw learnings`/`fw decisions`/audit readers, and belongs in its own task.
3. **Add an `index_append(path, text)`** that embeds only the new entry and upserts it as an
   additional chunk row for the same path — no full re-chunk. Does not exist today; would need
   `_delete_path_rows`-free partial upsert semantics that `index_one()` deliberately doesn't have.

The T-1719 AC's premise — "two call sites" — does not survive contact with the code. The count is
six, only two of them are clean `index_one()` targets, one needs a delete+index pair, and three are
aggregates where the right answer is probably the cron that is already running.
