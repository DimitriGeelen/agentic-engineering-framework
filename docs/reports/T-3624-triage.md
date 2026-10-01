# T-3624 — OBS-587 triage D: 17 untriaged baselined red bats files

Each file was run alone on `bleeding-edge` (`timeout 600 bats tests/unit/<f>.bats`).
Every fix was then re-run in my shell and again under a cron-like `env -i
PATH=/usr/local/bin:/usr/bin:/bin HOME=/root`, which is how the nightly runner
sees the world. Pass criteria: 0 `not ok` and 0 `# skip`.

## Verdicts

| File | Failing tests (alone, HEAD) | Breaking commit | Verdict | Action |
|---|---|---|---|---|
| t3127_audit_timing_headroom | 10 TERM trap records timed_out on a real kill | e67ab85c5 (T-3602, per-file parallel runner) exposed a test that ran `audit.sh` against the **live** audit lock | STALE TEST (not hermetic) | 3628cd76c: scratch PROJECT_ROOT |
| t3202_audit_kill_source | 16 externally-killed audit records kill_source external | same as above | STALE TEST (not hermetic) | 3628cd76c: scratch PROJECT_ROOT, kill at 4s |
| t3459_metrics_quality_cache | 8 TTL equals shared.py `_TASK_CACHE_TTL` | a04b21822 (T-3575 raised `_TASK_CACHE_TTL` 30→300 on purpose, as a safety net beside the stat signature) | STALE TEST | 65a363f68: assert 0 < quality TTL ≤ task-cache TTL |
| test_worker_kind_drift | 1 VALID_WORKER_KINDS in bin/fw | 85a876aa9 (T-1807 moved the set to lib/workflow_lint.py) | STALE TEST | 056702755: read lib/workflow_lint.py, exclude ollama-thin-loop (lib/spawn.py) and ollama-direct (spawns nothing). Test 4 had also passed vacuously over an empty set |
| test_orchestrator_status_synthetic_filter | 1-7 (all) | 67893ed78 (T-2391 re-resolves a markerless PROJECT_ROOT, so the fixture fell through to the live repo: 2782 dispatches) | STALE TEST | 9dded830a: fixture gets `.tasks/` |
| test_upgrade_runtime_downgrade_guard | 5, 6 refuse when consumer AHEAD | 3051b45bd (T-2713 decides direction by git ancestry; a bare pin with no tag is `undecidable` and proceeds) | STALE TEST | d98eb41d7: pin a `version_sha` whose parent is HEAD, written into a scratch object dir reached by `GIT_ALTERNATE_OBJECT_DIRECTORIES`, so the live object store is never written |
| task_id_race | 4 fails loudly when keylock.sh missing | 6431393ae (T-3111 paths.sh sources worktree-identity.sh, so the fake root died before keylock) | STALE TEST | f4fac452e: fake root copies worktree-identity.sh |
| test_audit_cron_drift | 1 in-sync → exit 0 | 92deaef0c (T-3105 empty candidate sets WARN, so exit 1) and 705269221 (T-3581 the verdict-ledger check FAILs where git cannot answer) | STALE TEST | 71f837f8e: fixture `git init`, assert no FAIL (≠2) plus the cron output |
| test_audit_retire_when | 8, 9, 11 | 26bbee259 (T-3428 unscorable-driver WARN names every driver id) | STALE TEST | be8f11535: assert on the section's own `free driver <id>` prefix |
| test_audit_watchdog_fd | 2 two sequential runs | 92deaef0c / 705269221 (audit exits 1/2 in the fixture; `out=$(…)` aborts under bats errexit) | STALE TEST | 5824ea907: `|| true`, the verdict is the output |
| test_doctor_litellm_ollama | 1, 4 | 39f57ff85 (T-2490 `/health` → `/health/liveliness`), de6cfb070 (T-2592 marker `ollama(-thin)?-loop`) | STALE TEST | fc2bcc792 |
| test_index_doctor_rail | 1 real index stale at default threshold | none: the test pinned the **live** index's age (T-3326 mutable-corpus class) and went red when the index was rebuilt (manifest age 19 min on 2026-10-01) | STALE TEST | 92ea27ec5: stale/fresh/zero legs use a 30-day-old fixture DB, asserting `source: db_mtime` |
| t3231_help_exemption_scope | nightly: 10, 11 (focus-drift legs). Green in an agent shell | 1cdd9b453 (the test itself): its drift harness inherited `CLAUDECODE`, and focus-drift blocks only under agent control (T-1739, c02a5a395). Reproduced under `env -i` | STALE TEST (env leak) | cfd5eda6a: set `CLAUDECODE=1` in the drift harness |
| t3161_empty_registry_does_not_wipe_live_cron | 4, 5 doctor WARN/SKIP lines | 176445c64 (T-2812): `hooks_dir=$(git … rev-parse)` under `set -euo pipefail` kills `fw doctor` (rc 128) when PROJECT_ROOT is not a git repo. Latent until the T-3610 git fence stopped fixtures resolving to the stray `/.git` | CODE REGRESSION | T-3630 |
| test_cron_registry_generated_drift | 1, 2, 3 | same as t3161 (doctor rc 128, verified in the fixture) | CODE REGRESSION | T-3630 (same bug) |
| test_bin_fw_no_heredoc_cmd_sub | 1 the T-1946 lint | 6cbc5dd55 (T-3429, bin/fw:2288) and b072d815f (T-3206, bin/fw:2803) reintroduced heredoc-in-`$(…)`. The lint's own controls (tests 2-3) pass | CODE REGRESSION | T-3632 |
| t3182_loop_exit_recorder | 6 each exit path records a DISTINCT reason | 8c42fe698 (T-3243) added a second `exit max-restarts` on the re-arm path. Bisect over bin/claude-fw: 6e1a0332b clean, 8c42fe698 first duplicate | CODE REGRESSION | T-3633 |

## Counts

- STALE TEST fixed: **13 files** (t3127, t3202, t3459, test_worker_kind_drift,
  test_orchestrator_status_synthetic_filter, test_upgrade_runtime_downgrade_guard,
  task_id_race, test_audit_cron_drift, test_audit_retire_when,
  test_audit_watchdog_fd, test_doctor_litellm_ollama, test_index_doctor_rail,
  t3231_help_exemption_scope).
- CODE REGRESSION: **4 files, 3 bugs**: T-3630 (doctor in a non-git project,
  covers t3161 and test_cron_registry_generated_drift), T-3632 (bin/fw heredoc
  lint), T-3633 (claude-fw duplicate `max-restarts` reason).
- UNCLEAR: 0. ENVIRONMENT: 0.

## Notes

- **Off-limits code.** test_audit_cron_drift and test_audit_watchdog_fd trip the
  reviewer-verdict ledger check (lib/verdict_ledger.py, being edited by another
  worker), which FAILs "git cannot answer" in a non-git project even with no
  ledger. I classified that as deliberate T-3581 fail-closed behaviour and made
  the fixtures git repos; I touched no ledger code. Whether an absent ledger in a
  non-git project should FAIL is for the T-3581 owner to decide.
- **Live-state side effect, fixed.** Before the fix, t3127 test 10 and t3202 test
  16 deleted and then rewrote `.context/audits/full-audit-timing.yaml` in the live
  checkout. When the assertion failed first, they never restored it.
- **Stale comment, not a test issue.** `web/blueprints/metrics.py:60` still says
  "same window as shared.py's _TASK_CACHE_TTL" (now 300 vs 30).
- **Not hermetic, WARN-only.** The structure-audit fixtures still print the
  host's DM-rail WARNs (`fw sidecar dm-stale` reads host state). This doesn't
  affect any verdict here.
- **Baseline.** AC 4 (`unit_suite_baseline.py regenerate`) was left to the
  parent, as instructed.
