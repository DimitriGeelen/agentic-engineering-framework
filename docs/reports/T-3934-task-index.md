# T-3934 — A derived task index for large projects (inception)

## Question
At about 3,900 task files, should AEF add an opt-in second state layer: a derived, rebuildable
index that pages and CLI listings query, while the Markdown/YAML files stay authoritative?

## Evidence (2026-10-06)
- **Every surface re-derives the task corpus itself.** Python sites that glob task files:
  web/ 21, lib/ 28, agents/ 13 — 62 independent derivations (spike:
  scratchpad `t3934_measure.py`, pattern `glob(... T-* | *.md)` filtered to task paths).
- **A full frontmatter parse costs 24.9 s** for 3,918 files at host load ~18 (same day, the
  operator's "loading is ridiculously slow again").
- **Per request, not per change.** Stack dumps of a stalled Watchtower (115 threads): 38 in
  `pathlib.glob`, 13 in `_dir_signature`, 10 queued on the link index's lock
  (`web/shared.py:782`, a ~15.8K-file walk), plus YAML re-parses — all repeating work whose
  inputs had not changed.
- **The fixes so far are instances, not the class.** T-3920 (task_index parse memo),
  T-3736 (link-index single flight), episodic/dir signatures — each a page-local cache with its
  own invalidation rule. G-108 (one fact, one predicate) applies to caches too.
- Today's acute stall had a different, separate cause (T-3933: tests sweeping the live server);
  removing it brought /approvals to ~4.3 s, not under the 3 s target. The structural cost remains.

## Shape proposed (operator agreed the direction, 2026-10-06)
1. Files remain the source of truth (git traceability, diffs, D4 portability, hand-editable).
2. A derived index — SQLite (stdlib `sqlite3`, no daemon, one file per project) — under
   `.context/`, **gitignored**, rebuildable from the files at any time.
3. **Tasks first** (the most-used service): id, name, status, horizon, owner, workflow_type,
   arc_id, tags, dates, AC counts (agent/human, ticked/open), file path + mtime + size.
4. Freshness by (path, mtime, size) on read, plus an incremental refresh hook after
   `fw task update` / create; a full rebuild verb (`fw index tasks --rebuild`).
5. File fallback: if the index is missing, stale beyond repair, or the module fails, callers fall
   back to today's scan — a small project never needs it.
6. Opt-in by scale: config switch plus a `fw doctor` hint past ~1,000 tasks.

## Open questions (for the dialogue)
- IW-1: Freshness when an agent edits a task file directly (Edit tool, no fw verb) — is a cheap
  (mtime,size) stat sweep per query enough, or does it need a watcher?
- IW-2: Which consumers move first — /approvals + /tasks only, or also the CLI (`fw task list`)?
- IW-3: One shared query module that the 62 sites converge on, or index only the hot paths?
- IW-4: Concurrency — multiple writers (sessions, cron, Watchtower threads) against one SQLite
  file: WAL mode + rebuild-on-corruption, enough?
- IW-5: Do episodics/handovers/fabric follow later under the same module, or stay out of scope?

## Dialogue log
- 2026-10-06, operator: "Could it be as we are growing into three and a half thousand tasks now
  that our database design needs upgrading and we need to add a second option? … the default we
  have now is good for many projects but … at a certain scale … a different database design …
  more than database engine probably."
- Agent: agreed, refined to "how we derive state, not the engine" — files authoritative, derived
  SQLite index, opt-in by scale; today's stall itself was T-3933, but the stack dumps showed the
  per-request re-derivation cost.
- Operator: "a very good design approach … indeed I would get[it] ignored as we can rebuild …
  I would start with TASK … as a service. That's the most." → gitignored; tasks first.
