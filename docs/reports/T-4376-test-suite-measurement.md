# T-4376 — Test-suite measurement (IW-1)

**Question (IW-1):** where does the unit suite's time and nondeterminism come from?
**Scope:** existing data only. The suite was not run for this report. Nothing under `tests/`, `lib/` or `agents/` was changed.
**Status:** exploration artefact for the inception; the go/no-go stays with the operator.

## 0. Sources, and what "a run" means

| Source | What it is | Used for |
|---|---|---|
| `.context/audits/unit-suite/LATEST.yaml`, `LAST-COMPLETE.yaml` | Latest full run, started 2026-10-19 10:29 UTC, jobs=12, wall 3370 s (identical content at time of reading) | §1 distribution, §3 |
| `.context/audits/unit-suite/2026-*.yaml` (42 dated reports) | One report per day (the last run of that day). 22 are schema v1 (no per-file data, 2026-09-08..09-29); **20 are schema v2** (2026-09-30..10-19) and carry `file_durations` and `files_timed_out` | §2, §3, §5 |
| `.context/audits/unit-suite/runs.log` | 83 START rows, 81 DONE rows (2026-09-08 → 2026-10-19), exit codes and wall time | §2 |
| `.context/audits/unit-suite/failures/*/{bats,pytest}/*.out` | Captured output of failing files for 10 individual runs (2026-10-15 → 10-18) | §3 (weak keyword counts only) |
| `.context/audits/unit-suite/baseline.yaml` | T-3621 red baseline, 44 entries | §3 |
| `.context/scratch/v1812/reports/{hf,base}/LATEST.yaml` | Same suite on two trees, both started 2026-10-18 22:50:55 UTC, jobs=6 each | §3, §5 |
| `git log --since=90.days -- tests/` | Test churn | §4 |
| Static scan of `tests/unit/*.bats` (860) and `tests/unit/*.py` (351) | Hermeticity heuristics | §4, §5 |

Important caveats that apply to every number below:

1. **Durations are wall-clock seconds per file under concurrent load** (jobs=12, or two suites sharing the host for hf/base), not isolated CPU time. "CPU-seconds" in this report means the sum of per-file wall seconds. Effective parallelism of the latest run = 36,182 / 3,370 = 10.7.
2. **Per-file timeout is 900 s** (`file_timeout_seconds`). A timed-out file is recorded as 900, so every duration figure for those files is a floor, and the total is truncated.
3. A "run" in the v2 analysis is the **last run of its day**. Runs earlier in the day (runs.log has 81 DONE rows vs 42 dated reports) are only visible through the `failures/` directories and runs.log, not through `file_durations`.
4. Test counts per file for §5 are **static**: `@test` lines for bats, `def test_` lines for pytest (12,088 total) — slightly different from the runner's counts (7,434 + 4,415 = 11,849). Treat shares as estimates (±3 points).

## 1. Duration distribution

**Method.** `legs.{bats,pytest}.file_durations` from `LATEST.yaml` (one number per file, seconds). Percentiles by linear interpolation over the sorted per-file values. Shares = sum of the N largest values / sum of all values.

### 1.1 Distribution (latest run, 2026-10-19)

| Population | Files | Sum (s) | p50 | p90 | p99 | max | ≤5 s | ≤30 s | ≥120 s | =900 s |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bats | 860 | 34,555 | 4.0 | 66.3 | 846.4 | 900 | 514 | 725 | 67 | 8 |
| pytest | 315 | 1,627 | 2.0 | 10.0 | 67.0 | 78 | 259 | 304 | 0 | 0 |
| **all** | **1,175** | **36,182** | **3.0** | **39.0** | **686.7** | 900 | 773 | 1,029 | 67 | 8 |

(The "all" ≤5 s / ≤30 s columns are bats + pytest sums.)

The suite is a long tail: the median file takes 3 s, 88 % of files take ≤30 s, and 5.7 % (67 files, all bats) take ≥120 s.

### 1.2 Concentration of time

| Top-N slowest files | Seconds | Share of total |
|---:|---:|---:|
| 10 | 8,893 | 24.6 % |
| 30 | 19,029 | 52.6 % |
| 50 | 24,239 | 67.0 % |
| 100 | 29,552 | 81.7 % |
| 200 | 32,536 | 89.9 % |

pytest is 315 files and 4.5 % of the time (1,627 of 36,182 s); its slowest file is 78 s. **The bats leg is the whole problem**: 95.5 % of the time, 8 files at the cap contribute 7,200 s alone (19.9 % of total).

### 1.3 Top 30 slowest files (latest run)

All bats. "TO" = hit the 900 s per-file timeout in this run.

| # | File | Seconds | # | File | Seconds |
|---:|---|---:|---:|---|---:|
| 1 | audit.bats | 900 TO | 16 | update_task.bats | 549 |
| 2 | greenfield_seed_audit_prototype.bats | 900 TO | 17 | test_doctor_scope_tags.bats | 511 |
| 3 | handover.bats | 900 TO | 18 | t2243_doctor_self_vendor_templates.bats | 508 |
| 4 | init_project_shape_detection.bats | 900 TO | 19 | t3443_audit_structure_framework_scope.bats | 501 |
| 5 | init_validation_ordering.bats | 900 TO | 20 | t2912_upgrade_hook_regen_convergence.bats | 471 |
| 6 | install_target_project.bats | 900 TO | 21 | resume.bats | 469 |
| 7 | t3974_wm_focus_consumer.bats | 900 TO | 22 | t3593_round5_grammar.bats | 454 |
| 8 | upgrade_fresh_machine_simulation_vendored.bats | 900 TO | 23 | fw_init_atomic.bats | 453 |
| 9 | validate_init_check_type_join.bats | 847 | 24 | hook_producer_site_parity.bats | 453 |
| 10 | doctor_designer_pin_drift.bats | 846 | 25 | test_large_file_scan.bats | 440 |
| 11 | t4248_install_inherited_env.bats | 823 | 26 | init_git_identity_blocker.bats | 407 |
| 12 | handover_digest.bats | 720 | 27 | t3593_tier0_action_approvals.bats | 392 |
| 13 | t4248_install_init_failure.bats | 675 | 28 | t4298_inherited_root_warning.bats | 373 |
| 14 | upgrade_fresh_machine_simulation.bats | 653 | 29 | t2290_doctor_mcp_content_check.bats | 349 |
| 15 | t4251_init_own_git_repo.bats | 587 | 30 | t3119_designer_currency.bats | 348 |

*Re-derive:* `yaml.safe_load(LATEST.yaml)['legs'][leg]['file_durations']`, sort descending, take 30.

### 1.4 What the slow files have in common (static observation, not a measurement)

The slow tail is dominated by file names that mention `init`, `install`, `upgrade`, `doctor`, `audit`, `handover` — i.e. tests that build a project from scratch (`fw init`), run a full `fw doctor` / `fw audit` / `fw upgrade`, or run the real handover. 21 of the 30 file names match `init|install|upgrade|doctor|audit|handover|vendor`; the rest (grammar, approval and parity tests) were not inspected line by line. These are end-to-end integration tests, not unit tests, living in `tests/unit/`.

## 2. Timeout frequency

**Method.** For each of the 20 v2 dated reports, take `legs.*.files_timed_out`; count reports per file. runs.log: count DONE rows by `bats_rc` / `pytest_rc`.

### 2.1 Per run

| Metric | Value |
|---|---:|
| v2 reports (2026-09-30 → 10-19) with ≥1 timed-out file | 16 of 20 |
| Files timed out per report (min / median / max) | 0 / 3.5 / 8 |
| Distinct files that timed out at least once | 19 |
| runs.log DONE rows | 81 |
| …with `bats_rc=124` | 74 (91 %) |
| …with `bats_rc=0` | 0 |
| …with `pytest_rc=124` | 16 (the early whole-leg timeouts and one on 10-18) |
| Wall time, rows that record it (n=58): min / median / max | 15 s / 2,884 s / 4,817 s |
| Wall time, dated v2 reports (n=20): range | 2,110 – 3,651 s |

**The bats leg has not exited 0 in any logged run.** Exit 124 appears as soon as one file hits its cap, so "bats_rc" is a one-bit signal that says "something timed out" and hides which red tests are real.

### 2.2 Per file (20 v2 reports)

| File | Timed out in N of 20 | Median s | Max s | Note |
|---|---:|---:|---:|---|
| doctor_designer_pin_drift.bats | 10 | 900 | 901 | in practice permanently at the cap |
| t2243_doctor_self_vendor_templates.bats | 9 | 866 | 900 | |
| test_doctor_scope_tags.bats | 9 | 681 | 901 | |
| t2290_doctor_mcp_content_check.bats | 8 | 635 | 901 | |
| t3119_designer_currency.bats | 8 | 615 | 901 | |
| t3974_wm_focus_consumer.bats | 8 (of 13 runs it existed) | 900 | 900 | |
| audit.bats | 6 | **2** | 900 | **bimodal**: 2 s or 900 s |
| fw_doctor_vendored_drift.bats | 4 | **1** | 900 | bimodal |
| t2332_bvp_propose_queue.bats | 2 | 10 | 900 | bimodal |
| fabric_coverage_single_source.bats | 2 | 20 | 900 | bimodal |
| greenfield_seed_audit_prototype.bats | 2 | 608 | 900 | |
| upgrade_fresh_machine_simulation.bats | 2 | 567 | 900 | |
| upgrade_fresh_machine_simulation_vendored.bats | 2 (of 16) | 707 | 900 | |
| worker_kinds_parity.bats | 2 | 364 | 900 | |
| init_project_shape_detection.bats | 2 | 103 | 900 | |
| init_validation_ordering.bats | 2 | 41 | 900 | |
| update_task.bats / handover.bats / install_target_project.bats | 1 each | 521 / 563 / 180 | 900 | |

Two distinct populations:

* **Persistently slow** (median ≥ 600 s): the first six rows. They are one slow `fw doctor` / `fw audit` invocation (or several) per test; they sit at 70–100 % of the cap on a good day, so any extra load tips them over.
* **Bimodal** (median ≤ 20 s, occasionally 900 s): `audit.bats`, `fw_doctor_vendored_drift.bats`, `t2332_bvp_propose_queue.bats`, `fabric_coverage_single_source.bats`. Normally cheap, sometimes hung to the cap. A 2 s → 900 s swing is not load; it is a hang, deadlock or a wait on a shared resource (the failure outputs show lock/serialised-audit symptoms, see §3.4). This is the nondeterminism that costs the most because the timeout result is unrelated to the code under test.

### 2.3 Spread across the whole suite (nondeterminism measure)

Method: for each file with ≥10 samples across the 20 v2 reports (1,058 files), spread = max − min.

| Spread of a file's duration across runs | Files |
|---|---:|
| ≥ 60 s | 111 |
| ≥ 300 s | 44 |
| max/min ≥ 5 (min ≥ 1 s) | 263 |

Of the 111 files with ≥60 s spread, 38 contain an executed `doctor`/`audit`/`handover` call (§4 scan) and 17 are flagged by the stricter "live" rule in §4. The remainder show spread without an obvious static cause, which is consistent with load-driven variance in `fw init` / `fw upgrade`-style tests that start many processes.

### 2.4 Same tree, same time: hf vs base (natural flakiness sample)

Both suites started at the same second, jobs=6 each, so they also competed for the same host (total concurrency 12).

| Metric | hf | base |
|---|---:|---:|
| Wall (s) | 5,626 | 5,288 |
| Sum of file durations (s) | 32,601 | 30,175 |
| Files timed out | bats 8 | bats 6 |
| Failed tests | 62 + 4 | 67 + 4 |

Per-file durations for the 1,157 files present in both: median absolute difference 1 s; **14 files differ by ≥60 s; 4 by ≥300 s** (`install_target_project.bats` 900 vs 2; `t4248_install_init_failure.bats` 635 vs 0 (why base took 0 s is not determined from the report); `t4248_install_inherited_env.bats` 623 vs 167; `t4298_inherited_root_warning.bats` 366 vs 2). Per-file duration at jobs=6 (hf) vs jobs=12 (latest) has a median ratio of 0.95 over 276 files ≥10 s: **halving the job count did not speed the typical file up**, so the cost is inside the files, not job-level contention (caveat: hf/base ran concurrently with each other).

## 3. Reds: run-to-run differences, load-only candidates, baseline

**Method.** Union of `legs.*.failed` (test names) for each of the 20 v2 reports; count how many of the 20 reports each name appears in. hf/base: set difference of the two `failed` lists. Baseline: `baseline.yaml.entries`.

### 3.1 Red presence across the 20 v2 reports

| Reds present in k of 20 reports | Distinct tests |
|---:|---:|
| 20 (every report) | 22 |
| 17–19 | 4 |
| 6–9 | 6 |
| 2–4 | 87 |
| 1 (a single report) | 127 |
| **total distinct red tests** | **246** |

* 22 tests are red in every report (the persistent core); 4 more are red in 17–19 reports.
* **127 distinct tests were red in exactly one report and 77 in exactly two**: 204 of 246 (83 %) are intermittent. A red that appears once in 20 days on unchanged-or-nearly-unchanged code is either a real defect fixed the next day or load/state flakiness; the data cannot separate them without per-run code revision, but the *shape* (clusters of 8–20 tests from one file in a single report, e.g. `init_head_bootstrap.bats`, `fw_focus_alias.bats`, `t3579_verdict_close_path.bats`, `t3099_go_scope_structural.bats`, `sessions_claude_code_adapter.bats`) points to a file-level cause (setup failure, timeout cut-off, shared fixture) rather than 8 independent bugs.
* pytest reds are concentrated in 4 files in single reports (`test_bvp_arc_membership_union.py`, `test_t3428_declarative_scoring.py`, `test_bvp_signals_rollup.py`, `test_t3427_unscored_driver.py`) — consistent with one code change breaking a group at once, not flakiness.

### 3.2 Load-only candidates

A test is listed as a *load-only candidate* if it is red in some reports and green in others while living in a file that also appears in the §2 bimodal or high-spread list, or if it differs between hf and base. This is a candidate list, not a proof.

| Test (file: name) | Reports red / 20 | Why it is a candidate |
|---|---:|---|
| hook_telemetry_race.bats: "per-fire cost stays under the documented 5ms budget" | 4 | asserts a wall-clock budget; fails under load by construction |
| hook_telemetry.bats: "performance: 1000 fires under 5000ms" | 1 | same class (timing assertion) |
| t1719_index_one_post_write.bats / t1719_post_write_index.bats: "inside the latency budget / under the 5s budget" | 1 + 1 | same class |
| t3636_objectives_seed.bats: "existing-project T-007 passes the onboarding gate's write-time check" | 4 | named in the T-4376 evidence as red only under parallel load (not confirmed here; not in the baseline) |
| t2290_doctor_mcp_content_check.bats t1/t2/t3 | 1 each (+ hf-only red) | file sits at 349–900 s; only hf vs base differs in this file |
| audit.bats: "audit runs structure section", "…compliance section", "…PASS/WARN/FAIL markers" | 6 / 1 / 1 | file is bimodal 2 s ↔ 900 s |
| t4119_terminator_handover_git_extension.bats (3 tests) | 4 / 1 / 1 | a terminator/timeout test: depends on elapsed time |
| t3511_parked_merge_guard.bats (7 tests, all in 2 reports) | 2 | whole file red in 2 reports |
| upgrade_fresh_machine_simulation.bats: 5 tests (T-3831 ×2, T-3833, T-3835, T-3836) | base only | 5 reds present in base, absent in hf |
| check_render_surface_human_ac_sigpipe.bats: "pre-fix pattern DID die with SIGPIPE" | 2 / base only | race on pipe close timing |

**hf vs base:** 72 distinct red tests in the union; 65 red in both; **7 differ** (6 base-only, 1 hf-only) = **9.7 % of the union flips between two runs of the same suite at the same time**. Timed-out files: 6 in both, 2 hf-only (`greenfield_seed_audit_prototype.bats`, `install_target_project.bats`), 0 base-only. The 5 base-only `upgrade_fresh_machine_simulation.bats` reds are the signature of a file that ran at 413 s (base) vs 305 s (hf) and fails depending on how long its internal steps take.

### 3.3 Baselined reds (every entry in `baseline.yaml`, 44 total)

| Owner task | Entries | Expires | Files (entries) |
|---|---:|---|---|
| T-4221 | 9 | 2026-10-31 | context_safe_commands (1), fabric_coverage_single_source (2), test_bin_fw_no_heredoc_cmd_sub (1), test_cron_registry_generated_drift (1), t1719_index_one_post_write (1), check_render_surface_human_ac_sigpipe (1), t3662_watchtower_port_allocation (1), t4119_terminator_handover_git_extension (1) |
| T-4325 | 6 | 2026-11-01 | fw_focus_alias (4), t1719_ask_routing (2) |
| T-4325 | 2 | 2026-10-27 | audit (1), hook_telemetry_race (1) |
| T-3611 | 5 | 2026-10-31 | approvals_close_ready_arcs (5) |
| T-3604 | 4 | 2026-10-31 | t2244_audit_self_vendor_drift (2), t2298_audit_structure_no_perfile_fork (2) |
| T-3609 | 4 | 2026-10-31 | lib_review (2), audit_inception_recommendation (1), review_pipefail (1) |
| T-3556 | 3 | 2026-10-31 | handover_push_timeout (3) |
| T-3615 | 3 | 2026-10-31 | doctor_hook_counters (3) |
| T-2787 | 1 | 2026-10-31 | no_root_framework_markers |
| T-3605 | 1 | 2026-10-31 | test_operator_facing_stderr.py |
| T-3612 | 1 | 2026-10-31 | atomic_yaml_write_lint |
| T-3614 | 1 | 2026-10-31 | audit_split_root_asset_lint |
| T-3747 | 1 | **2026-10-18 (already expired)** | t2243_doctor_self_vendor_templates |
| T-3992 | 1 | 2026-10-22 | t2452_doctor_quick |
| T-4038 | 1 | 2026-10-25 | fw_mode_detection |
| T-4138 | 1 | 2026-10-27 | test_doctor_litellm_ollama |

Counts (exact, from `baseline.yaml`): 44 entries, all `added_by: human`; expiry 2026-10-31 for 32 entries, 2026-11-01 for 6, 2026-10-27 for 3, and 2026-10-25 / 10-22 / 10-18 for one each. **32 of 44 expire on one day** (12 days after the latest run) and one has already expired. Most baselined files are in the doctor/audit/live-repo family from §4. By name match (estimate), all 22 always-red tests are covered by a baseline entry: the baseline is in effect the list of the persistent reds.

### 3.4 Failure text (weak signal)

Over the 334 captured `.out` files under `failures/`, case-insensitive keyword counts (a file can match several): "timed out / Terminated / exit 124" in **37**, "No such file or directory" in 5, "flock / lock held / stale-lock" in 2. A broader `lock` keyword matched 91 files but also matches ordinary words ("block", "unlock"), so it is not reported as a finding. The remaining failures are assertion failures on doctor/audit output (WARN/FAIL lines in captured output of 65 files). The text confirms that timeouts are a first-order failure mode but does not by itself separate "slow because loaded" from "slow because hung".

## 4. Static scan of tests/unit for live-state anchors

**Method.** Regex scan of `tests/unit/*.bats` and `tests/unit/*.py`. Comment lines and `@test` titles are excluded.

* **A — runs doctor/audit/handover:** an executed line (starts with `run`, `out=$(`, `X=$(`, `bash`, `timeout`) invoking `bin/fw doctor|audit|handover`, `$AUDIT`, `$HANDOVER`, `agents/audit/audit.sh`, `agents/handover/handover.sh`.
* **B — reads the repo's own state:** a line referencing `$FRAMEWORK_ROOT|$REPO_ROOT|…/../..` followed by `/.framework.yaml`, `/.context`, `/.tasks/active|completed`, `/.fabric`.
* "no temp root" = the file contains no `PROJECT_ROOT=` assignment (`sets`) and no `mktemp`/`BATS_TEST_TMPDIR`/`TEST_TEMP_DIR=` (`tmp`). This is a file-level approximation: a file that sets `PROJECT_ROOT` once can still run one test against the real repo, so **the "no temp root" counts are lower bounds** and the unqualified A/B counts are upper bounds. It also produces false positives where a line merely names the command (see below).

### 4.1 Counts

| Class | bats files (tests) | Note |
|---|---:|---|
| Bats files / tests in scope | 860 (7,481) | |
| A — executes doctor/audit/handover | 85 (725) | |
| A and no `PROJECT_ROOT=` in file | 31 (264) | |
| A and no `PROJECT_ROOT=` and no temp | **5 (38)** | strictest lower bound |
| B — reads repo `.framework.yaml/.context/.tasks/.fabric` | 42 (405) | many `cp` a template, which is benign |
| B and no `PROJECT_ROOT=`/temp | **11 (93)** | |
| invokes `bin/fw` at all (looser pass) | 192 (1,921) | |
| invokes `bin/fw` but never sets `PROJECT_ROOT=` | 89 (737) | |
| invokes `bin/fw`, no `PROJECT_ROOT=`, no temp | 32 (251) | |
| Pure: no fw call, no doctor/audit, no repo read | 497 (3,979) | 58 % of the bats files |
| pytest files that reference `.context/.tasks/.framework.yaml` with a repo/`__file__` anchor | 36 (353) | |
| …and no tmp fixture (`tmp_path`, `mkdtemp`, `TemporaryDirectory`) | **10 (89)** | |

Looser combined "any live signal" (A-no-set | B | fw-no-set-no-tmp) on the *first* pass was 187 files (1,674 tests); the stricter pass above is the better estimate for "definitely not hermetic" (5 + 11 + part of 32 = on the order of 40–50 bats files) and the looser one for "worth reviewing" (~190). Both are estimates.

### 4.2 Examples (file:line, first matching line)

Class A, repo-rooted doctor/audit run:

1. `tests/unit/doctor_designer_pin_drift.bats:39` — `run bin/fw doctor` (file median 900 s, timed out 10 of 20 runs)
2. `tests/unit/doctor_duplicate_hook_detection.bats:44` — `run "$FRAMEWORK_ROOT/bin/fw" doctor`
3. `tests/unit/reviewer_verdict_replacement_escape.bats:55` — `out=$(bin/fw doctor 2>&1); …`
4. `tests/unit/t2243_doctor_self_vendor_templates.bats:35` — `run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw doctor 2>&1"` (median 866 s)
5. `tests/unit/t2244_audit_self_vendor_drift.bats:38` — `out=$(cd "$FRAMEWORK_ROOT" && bin/fw audit --section structure 2>&1 || true)` (red in 18 of 20 reports)
6. `tests/unit/t2290_doctor_mcp_content_check.bats:49` — `run bin/fw doctor` (median 635 s)
7. `tests/unit/audit.bats:6` — `AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"` (then run against the repo; bimodal 2/900 s)
8. `tests/unit/audit_anchor_task_existence.bats:21`, `audit_d3_commit_velocity.bats:12` — `AUDIT`/`AUDIT_SH` pointing at the real audit script
9. `tests/unit/handover.bats:7` — `HANDOVER_DIR="$FRAMEWORK_ROOT/.context/handovers"` (writes against the live handover store; timed out 1 of 20)

Class A false positives seen in the same list (names the command, does not execute it against state): `drift_gate_not_shadowed_by_safelist.bats:125`, `fd_dup_not_chain_split.bats:59`, `safe_commands_chain.bats:69` (strings passed to a classifier), `audit.bats:48` and `handover.bats:37` (`--help`), `t2298_audit_structure_no_perfile_fork.bats:71` (`bash -n`).

Class B, reads the real project corpus:

10. `tests/unit/reviewer_human_ac_mechanical_signal.bats:15` — `TEST_TASKS="$FRAMEWORK_ROOT/.tasks/active"`
11. `tests/unit/test_reviewer_audience_mismatch.bats:20`, `test_reviewer_defer_as_hedge.bats:17`, `test_reviewer_prose_mismatch.bats:18`, `test_reviewer_review_link_homework.bats:18` — same `TEST_TASKS="$FRAMEWORK_ROOT/.tasks/active"`; these tests' outcomes depend on whichever tasks are active today
12. `tests/unit/t1719_happiness_signal.bats:41` — `HAPPINESS_FILE="$FRAMEWORK_ROOT/.context/working/happiness.jsonl"` (live working-memory file)
13. `tests/unit/docgen_component.bats:21` — `card=$(ls "$FRAMEWORK_ROOT/.fabric/components/"*.yaml | head -1)`
14. `tests/unit/escalation_scan_v05.bats:16` — loads `$FRAMEWORK_ROOT/.context/project/workflows/escalation-triage.yaml`
15. `tests/unit/t2488_strict_mcp_lean_worker.bats:18` — reads `.context/project/workflows/default.yaml`
16. `tests/unit/arc_create_no_constituent_tasks.bats:87` — loops over `$FRAMEWORK_ROOT/.context/arcs/*.yaml` (the live arcs, although the file also uses temp roots elsewhere)
17. `tests/unit/audit_graduation_counter.bats:48` — `live="$FRAMEWORK_ROOT/.context/project/learnings.yaml"`
18. `tests/unit/bvp_auto_promote.bats:25` — `cp "$FRAMEWORK_ROOT/.framework.yaml" "$FIX/.framework.yaml"` (copies the live project config into the fixture)

pytest:

19. `tests/unit/test_frontmatter_loader_equivalence.py:96` — `tasks = PROJECT_ROOT / ".tasks"`
20. `tests/unit/test_render_artefact_paths.py:118` — `PROJECT_ROOT.glob(".context/audits/**/*.yaml")` (reads the audit reports of the live run — including the one being written)
   Also (designer maps, live `.context/designer/projects`): `t2974_greenfield_operator_prose.py:122`, `t2979_existing_project_onboarding_map.py:39`, `test_corpus_lint_seam_marker.py:102`, `test_t3061_audit_wiring.py:58` (`FRAMEWORK_ROOT / ".tasks" / "active"`).

Name-level hits that directly match the failure modes in the task description: the `.framework.yaml` read (bvp_auto_promote.bats:25, item 18), the live-corpus assertions (`t3118_horizon_migration_scope.bats` "every completed task in the live corpus has a null or absent horizon", `t3235_archived_horizon_invariant.bats` "no task in the real corpus carries horizon: now under completed/", `audit_corpus_lint_findings.bats` "the audit sees the REAL store"), and the doctor/audit invocations in the top-timeout files (§2.2).

## 5. Candidate fast-tier

**Goal:** a tier that fits 10 minutes at jobs=6, i.e. at most 10 × 60 × 6 = **3,600 file-seconds** if packing were perfect.

**Method.**
1. Candidate set = all files with v2 timing data (1,175). Per-file cost = **median** of its durations across the 20 v2 reports (robust to the 900 s outliers).
2. Exclude: any file that timed out at least once in the 20 reports (19 files); bats files with an executed A line and no `PROJECT_ROOT=`; bats files with a B line and no `PROJECT_ROOT=`/temp; pytest files with a repo-anchored `.context/.tasks/.framework.yaml` reference and no tmp fixture. The remaining 1,116 files are the "hermetic-by-heuristic" set (CPU 20,256 s median-sum, 11,034 static tests).
3. Select under the budget. Tests per file are static counts (§0 caveat 4); share = selected tests / 12,088.

| Selection rule | Files | Σ file-seconds | Lower-bound wall @ jobs=6 | Static tests | Share of tests |
|---|---:|---:|---:|---:|---:|
| hermetic, median ≤ 30 s | 1,014 | 4,606 | 768 s (12.8 min) | 10,025 | 82.9 % |
| hermetic, median ≤ 60 s | 1,052 | 6,206 | 1,034 s | 10,411 | 86.1 % |
| hermetic, median ≤ 120 s | 1,076 | 8,219 | 1,370 s | 10,657 | 88.2 % |
| hermetic, median ≤ 300 s | 1,098 | 12,596 | 2,099 s | 10,820 | 89.5 % |
| **budget 3,600 s, shortest first** | **974** | 3,581 | 597 s | 9,507 | **78.6 %** |
| **budget 3,600 s, ranked by tests/second** | **952** | 3,600 | 600 s | 9,848 | **81.5 %** |

Reading this: an estimated **~950–975 files carrying ~79–82 % of the tests (estimate; ±3 points)** fit inside the 3,600 file-second budget. The remaining ~18–21 % of tests, ~215–225 files, carry most of the time: the same set that shows in §1.3 and §2.2.

Estimates and caveats:

* **The cost basis is conservative.** Durations were measured at jobs=12 with 10.7 effective parallelism; the ≤30 s cap alone gives 4,606 file-seconds, which at 10.7 effective parallelism is ~7 min wall. The "lower bound wall" column ignores packing inefficiency and the longest-file bound (longest file in the ≤30 s rule = 29.5 s, negligible).
* **The hermetic filter is a heuristic.** The static scan (§4) has false positives and false negatives. In particular the heuristic admits 10 hermetic-labelled files over 60 s median that are slow for reasons it does not see: `t4248_install_inherited_env.bats` 683 s, `t4251_init_own_git_repo.bats` 648 s, `t4248_install_init_failure.bats` 642 s, `handover_digest.bats` 518 s, `validate_init_check_type_join.bats` 504 s, `t2835_unknown_cmd_no_autoinit.bats` 452 s, `test_large_file_scan.bats` 414 s, `t3593_round5_grammar.bats` 379 s, `t4298_inherited_root_warning.bats` 375 s (pytest: `test_orchestrator_status_terminal_events.py` 368 s). A duration cap (≤30–60 s) removes them regardless of the hermeticity label — hence the cap rows above.
* **What the fast tier would still miss.** All 8 files that time out most often (the `doctor_*`, `audit`, `handover`, `init_*`, `install_*`, `upgrade_*` family) are excluded by construction. Whether the pre-push gate *needs* their assertions is IW-2's question; this report only shows the 8 capped files alone are 19.9 % of the measured time (a floor, since 900 is a cap) and are the primary source of nondeterminism.
* **The 22 always-red tests** (plus 4 red in 17–19 of 20 runs: `no_root_framework_markers.bats`, `context_safe_commands.bats`, `t2244_audit_self_vendor_drift.bats`, `test_cron_registry_generated_drift.bats`) have names suggesting filesystem-root, real-repo or real-audit dependence; their files were not opened to confirm. A fast tier must exclude or fix them before it can be a green gate.

## 6. Findings, stated plainly

1. **Time:** 1,175 files, ~36,200 file-seconds, 3,370 s wall at 10.7× parallelism. 24.6 % of the time is in 10 bats files, 52.6 % in 30, 81.7 % in 100. The median file takes 3 s.
2. **Timeouts:** 16 of 20 recent daily runs have ≥1 file at the 900 s cap (median 3.5, max 8); the bats leg's exit code was 124 in 74 of 81 logged runs and 0 in none. Six files are *permanently* near the cap (doctor/audit/vendor-drift integration tests); four more are *bimodal* (2 s vs 900 s), which is hang/serialisation behaviour, not slowness.
3. **Nondeterminism:** 83 % of the 246 distinct red tests were red in only 1–2 of 20 runs; 7 of 72 reds (9.7 %) flipped between hf and base at the same moment; 111 files vary by ≥60 s between runs. Timing-budget assertions (`hook_telemetry_race`, `hook_telemetry`, `t1719_*` latency) are red-under-load by construction.
4. **Hermeticity:** a minimum of ~5 + 11 bats files (131 tests) and ~10 pytest files (89 tests) are provably tied to live repo state; the looser scan flags ~190 files (1,674 tests) for review. Most of the time-cost tail is *integration-style* (project init, install, upgrade, full doctor/audit) rather than live-state reads.
5. **Baseline:** 44 entries, all operator-added, one expired (T-3747), 32 expiring on one date (2026-10-31).
6. **Fast tier:** an estimated 950–975 files / 79–82 % of tests fit a 3,600 file-second budget (≈ 10 min at jobs=6, ideal packing), with the heavy integration family left to a slower tier.

## 7. Limits of this measurement (what it cannot say)

* No per-run code revision is joined to the red lists, so a real regression that was fixed the next day looks the same as a flake. IW-4 and IW-3 need that join.
* One report per day for per-file data; the earlier same-day runs (up to 4 per day on 10-10, 10-12, 10-15, 10-17, 10-18) are only in `failures/` for failing files.
* Durations are contended wall-clock; isolated per-file cost needs a separate measurement run (not done here by instruction).
* The static scan is regex-based; it neither follows `source`d helpers nor `load`ed helper files, so a test that gets its root from a shared helper will be misclassified.
* Test counts in §5 are static; skipped and conditional tests are counted.

## Appendix: re-derivation

All numbers come from Python over the YAML files listed in §0 (no suite run):

* §1: `yaml.safe_load(LATEST.yaml)['legs'][leg]['file_durations']` → sort, percentiles, cumulative sum of the top N.
* §2: loop over `.context/audits/unit-suite/2026-*.yaml` with `schema == unit-suite-report-v2`; `files_timed_out` and `file_durations`; per-file `max-min`; runs.log by `grep -c` of `bats_rc=124` / `pytest_rc=124` among `DONE` rows.
* §3: set of `legs.*.failed` per report, count per name; `hf`/`base` symmetric difference; `baseline.yaml.entries` group by `owner`, `expires`, `added`.
* §4: two regex passes over `tests/unit/*.bats` and `*.py` as defined in §4; sample `file:line` from the first hit per file.
* §5: median per file over the v2 reports; exclusion rules as listed; greedy fill to 3,600 s.
* Churn (not tabulated above): `git log --since=90.days --name-only -- tests/` gives 1,213 commits touching 1,190 files in `tests/`; in `tests/unit/` 902 files were touched 1,672 times, 737 files were added and 6 deleted in the window; 784 of the touched files were touched once, the most-touched (14–16 touches each) are `t3580_*_test.py`, `test_sidecar_receiver_t3693.py`, `upgrade_fresh_machine_simulation.bats`, `t3579_verdict_close_path.bats`, `test_corpus_lint.py`. Growth: bats files 623 → 860 and pytest files 201 → 315 between 2026-09-08 and 2026-10-19; the suite roughly doubled its test count in six weeks.
