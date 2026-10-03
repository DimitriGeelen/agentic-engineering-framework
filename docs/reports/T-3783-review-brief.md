# T-3783 — independent review brief

Task: `.tasks/active/T-3783-vector-database-semantic-recall-health-a.md`
Commits: c62bab1bc + 39769059c (the fixes that get the job and import path to consumers, from an earlier session), b007bc535 (health check), 06516872d (vendored copies).

## The failure being prevented

Semantic recall (the sqlite-vec index `.context/working/fw-vec-index.db`, embedded via Ollama) froze for about 2 months in 47 of 49 projects. Three things hid it:
- the hourly `fw index reindex` job was never seeded into consumers;
- the reindex exited 0 when it could not import `web/`;
- doctor said "Cron registry in sync", and index age was at most a WARN.

Two further silent paths were found while building this: the doctor freshness check and the audit canary both ran with `cwd=PROJECT_ROOT` and no FRAMEWORK_ROOT on the import path, so in every vendored consumer they reported **SKIP / INFO "not importable — skipped"**; and `fw recall`'s semantic path never imported at all (see the RCA).

## Design: one predicate

`lib/vector_index_health.py` uses the stdlib only, so it runs and FAILs exactly where `web/` cannot import. `evaluate()` runs these checks (any FAIL makes the whole verdict FAIL):

| check | FAIL when | code |
|---|---|---|
| index | file missing, unopenable (ro sqlite), or 0 rows in `documents` | `check_index` |
| manifest | manifest absent/corrupt, `finished_at` not a positive number, or no `canary_token` (`{}` is FAIL) | `check_manifest` |
| import | a child `python3` run with `cwd=PROJECT_ROOT`, `PYTHONPATH=FRAMEWORK_ROOT` (the same way `bin/fw` `index reindex` runs it) cannot `import web.embeddings` + `web.canary`, or times out | `run_child`, `_CHILD`, `check_import` |
| age | `now - finished_at > INDEX_MAX_AGE_HOURS` (default 24; the reindex runs hourly and rewrites the manifest on every run) | `check_age` |
| lag | more than `INDEX_MAX_LAG` (default 50) task ids on disk, or learning ids in learnings.yaml, absent from the indexed `documents` | `check_lag` |
| canary | in the child, `web.canary.verify_canaries(web.embeddings._semantic_search, manifest canary_token)`: real embed + sqlite-vec KNN against `VECTOR_DB_PATH` = the same DB. It is not run on a missing or empty index, because `_get_db()` would start a full rebuild; that case is FAIL "canary cannot run". `--no-canary` reports SKIP and never records. | `check_canary` |
| cron | `.context/cron-registry.yaml` missing, lacks `index-reindex-hourly`, or the job is not `status: active` | `check_cron` |
| usage (WARN) | share of `outcome: unavailable` rows in recall telemetry over 7d > `RECALL_FAIL_PCT_WARN` (default 10, min 10 rows) | `check_usage` |

There are three new config keys, each in both `lib/config.sh` FW_CONFIG_REGISTRY and `web/blueprints/config.py`.

## Wiring (`lib/vector-index-health.sh`)

- `vector_index_health [--no-canary]` resolves the config via `fw_config` and runs the predicate. Full runs pass `--record`, which writes `.context/working/vector-index-health.json`. `record()` returns TURNED_RED only when the status is FAIL **and** the previous recorded status was not FAIL; `_vih_notify_red` then calls `fw_notify` once. If the checker itself produces no output, the result is FAIL, never skip.
- **fw doctor** (`bin/fw`, search "T-3783: replaced the age-only WARN"): one line per check; a FAIL increments `issues`.
- **fw audit**, section `corpus-health` (`agents/audit/audit.sh`): FAIL→`fail`, WARN→`warn`. The section runs in the default set (empty `SECTIONS` means all), in `fw audit --cron` (full-daily), and in the 6-hourly `observations,gaps,corpus-health` job. It is deliberately NOT in pre-push `structure`.
- **Handover** (`agents/handover/handover.sh`, `VECIDX_LINE`): runs the full check and prints one line under Suggested First Action when red.
- **Hourly reindex** (`bin/fw index reindex`): after the reindex, including when it failed or could not import, runs the full check to stderr. Consumers that only have the seeded job therefore still record the verdict and push.
- **Operator push**: once per transition to red, from whichever full run sees it first.
- **Banner**: `degraded_banner()` is used by `agents/context/lib/memory-recall.py` (`fw recall`) and `lib/ask.py` (`fw ask`). It prints one stderr line, `semantic recall degraded: <reason> — results may be missing; fix: <cmd>`. The cause is this query's own embed failure if there was one; otherwise a fast-mode failure, or a red verdict recorded by the last full run (which covers a canary miss that fast mode cannot see).
- **fw recall's import fix**: `sys.path.insert(0, FRAMEWORK_ROOT)`, plus an `is_index_ready()` guard so a recall never starts a build. `focus.sh` (work-on) passes `--no-hybrid`, keeping its 10s budget.
- **Consumers**: the new files are vendored under `.agentic-framework/` (commit 06516872d) and reach consumers through `fw upgrade`. The job itself is seeded by `lib/cron-seed.sh` (c62bab1bc).
- **Docs**: CLAUDE.md §Context Integration has one paragraph naming the check and its remedy.

## Agent AC → evidence

1. **RCA**: `## RCA` in the task file. It now has six structural causes, including the recall import bug and the TermLink instance.
2. **Freshness**: `check_age` and `check_lag`, with FAIL in audit (`fail`) and in doctor (`issues`). Tests: "stale manifest is red", "age limit is configurable", "lag beyond the limit is red", "missing manifest is red", "empty manifest is red".
3. **Liveness + canary**: `check_index`, `check_import`, `check_canary`. Tests: "missing index is red…no search is attempted", "empty index is red", "import failure is red", "canary miss is red", and "fresh fixture is green, and the canary really ran a search" (asserts the search marker file was written by the stub's `_semantic_search` on the fixture DB). Live: the canary on the real index came back OK in doctor and audit.
4. **Surfacing**: handover `VECIDX_LINE`; the push tests ("operator push fires once per transition…" and "wrapper: fw_notify path really fires…", which use a stub dispatcher and count pushes); the banner tests; the wiring test; vendored copies.
5. **Tests**: `tests/unit/t3783_vector_index_health.bats`, 19 tests, all hermetic (temp project, temp sqlite, temp FRAMEWORK_ROOT whose `web/embeddings.py` stub queries the fixture DB and whose `web/canary.py` is the real one). The live 2.5 GB index is never touched.

## Known limits (stated, not hidden)

- The cron check reads the registry, not `/etc/cron.d`. The registry-to-deployed leg is the existing doctor/audit cron-drift check (T-1771).
- In the hermetic tests the canary goes through a stub `_semantic_search`, because real embeddings need Ollama. The real path is exercised live by doctor and audit on this host.
- A project with no recorded full run and only fast-mode callers (recall/ask) gets the banner but no push. Pushes come from full runs: doctor, audit, handover and the hourly reindex, which every consumer now has.
