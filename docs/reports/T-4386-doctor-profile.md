# T-4386 — `fw doctor` profile: why one run took 3-4 minutes

**Symptom.** `tests/unit/doctor_designer_pin_drift.bats` (5 tests) and
`tests/unit/t2243_doctor_self_vendor_templates.bats` (4 tests) each run a full
`bin/fw doctor` against the framework repo once per test, and each file took
~900 s (median 900 s / 866 s, external review T-4376). Doctor runs the same
checks in the fixture as it does for the operator: the per-run cost (~200 s on a
loaded host, ~135 s on a quieter one) was the product defect. The tests only
multiplied it.

## Method

`bin/fw` sourced under `bash -x` with
`PS4='+${EPOCHREALTIME} ${BASH_SOURCE##*/}:${LINENO} '` (PS4 has to be set inside
the shell: bash running as root ignores an inherited PS4). Each trace line's
duration was taken as the gap to the next trace line, then ranked. The test
environment was reproduced (`FW_DOCTOR_SMOKE=0`, the TermLink tripwire first on
PATH). The host load average was 20-54 on 24 cores throughout, so absolute
numbers vary ±30% between runs. The ranking was stable.

## Where the time went (before, one run, 199 s under load ≈ 50)

| s | check | cause |
|---:|---|---|
| 25.3 | Session tokens (`lib/costs.sh` `costs_main current`) | parsed **every** transcript (455 files, 1.5 GB) to print the newest one |
| 18.4 | Vector-index health (`lib/vector_index_health.py`) | ~8 s child (import `web.embeddings` + canary) then ~6 s lag/drift hash scan, back to back |
| 17.8 | Stalled tasks (`lib/resolver.py stalled`) | per dispatched task: a pathlib glob of the 930-entry `.tasks/active/` (×2), a YAML re-parse, one `git log` each |
| ~18 | Task debt (`bin/fw` loop) | `grep\|head\|sed\|tr` + `date` forked for each of 930 active tasks (~4,600 processes) |
| 14.3 | port3000 hygiene (`tools/port3000_hygiene.py`) | `HIT_RE.search` over the whole text of 1.9k files (78 MB) that mention `:3000` |
| 13.8 | Hook exercise (`lib/doctor-hook-exercise.py`) | 27 hooks run one after another, each a full `bin/fw` start |
| 9.3 | Armed index entries (`lib/index_reconcile.py`) | full-history `git log -- path` per staged task file (depends on the shared index: ~0 s when nothing is staged) |
| 7.5 | Plugin task-awareness (`agents/audit/plugin-audit.sh`) | one `python3` per plugin skill/agent/command file |
| 5.9 | Design-conformance register (`lib/design_register.py`) | YAML-parsed all ~4.4k tasks to look up a handful of owner ids |
| 5.1 | Fabric under-populated cards (`agents/fabric/lib/underpopulated.py`) | pure-Python `yaml.safe_load` over ~1.5k cards |
| 5.9 | Branch hygiene | per-branch `git merge-base`/`rev-list` (not changed) |
| 4.5 | Delegation surface | classification of 931 tasks (not changed) |

## Fixes (no check removed; every output verified identical)

| check | fix | before → after (standalone) | parity evidence |
|---|---|---|---|
| Session tokens | `current` mode parses only the newest transcript, and JSON-decodes only lines containing `"usage"` (timestamps are not printed in that mode) | 25 s → 0.2 s (2.8 s when the newest transcript is a 388 MB live session) | same turns/tokens/model on the 388 MB file |
| Stalled tasks | active-dir listing cached on dir mtime; per-file snapshot cached on (mtime_ns, size); one `git log --since=<earliest window>` for the scan | 7.5 s → 2.3 s | `stalled --json` byte-identical |
| port3000 | `_has_hit`: find each `:3000`, test the host at the two possible offsets; `relative_to` only for files with hits | 11.6 s → 3.4 s | all 1,116 hits identical (path, line, category, reason, hash) |
| Hook exercise | probes run on an 8-thread pool, results gathered in job order (Claude Code itself runs matching hooks concurrently) | 13.8 s → 2.4 s | `27\|0` either way |
| Plugin audit | `classify_files FILE...`: one `python3` for all files | 9.7 s → 0.65 s | `--doctor-check` and full report identical |
| Vector-index health | child and lag scan run side by side; `relative_to` replaced by a prefix slice | 22 s → 9.4 s | verdict lines identical |
| Task debt | `lib/task_debt.py`: same predicate, one process | 12.6 s → 0.15 s | 63 = 63 on the live corpus; a test pins parity with the old loop |
| Design register | `register_violations` defaults to `LazyTaskIndex` (T-3749, same entries) | 4.8 s → 0.9 s | identical output; 74 existing tests pass |
| Under-populated cards | libyaml `CSafeLoader` when present (as `design_register.py` does) | ~5 s → 1.0 s | JSON identical |

**After:** one plain `bin/fw doctor` in the fixture env took **50 s** (load ≈ 20);
the two bats files took **251 s** (5 tests) and **192 s** (4 tests), against ~900 s
each before. Every test was green with 0 skips.

## Not fixed here (remaining cost, for a follow-up if wanted)

- Vector-index child (~8 s): importing `web.embeddings` and embedding the canary
  *is* the check. Doctor already exposes `FW_DOCTOR_INDEX_FAST=1` / `--quick` for
  skipping it; tests that do not test the index could set it.
- Branch hygiene (~4-5 s) is many small per-branch git calls. Batching them is a
  rewrite of `lib/branch-hygiene.sh`.
- Delegation surface (~4 s), spread over 931 classifications.
- `index_reconcile` (0-9 s, depending on what the shared index has staged): one
  full-history `git log` per staged path.
- Roughly 20 s of long tail: hundreds of short forks across ~200 checks.
- The tests themselves: each test in these two files pays a whole doctor run to
  assert on one line. A doctor section filter would make them cheap. That is a
  test-design change, out of this task's scope.

## Side finding — Task debt undercounts (separate bug, not changed here)

843 of 929 active tasks store `last_update` single-quoted
(`last_update: '2026-10-19T12:29:28Z'`). The old loop strips only double quotes,
and `date -d "'…'"` rejects the value, so those tasks are **never** counted as
stale. The check sees 86 tasks out of 929. `lib/task_debt.py` keeps that behaviour
on purpose so this task changes speed only: fixing it would change the WARN count
(63 today) and it is its own bug (one bug = one task). Flagged to the parent for
filing.
