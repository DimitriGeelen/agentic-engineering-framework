# T-4382 — Bimodal and instant-finish test files: hang, skip, or old code?

Arc test-suite-health (arc-026), inception T-4376 GO. The two external reviews disagreed:
opencode read the 2 s ↔ 900 s swings as hangs (audit-lock deadlock between files), and codex
said the quick runs could be skips or older code (`docs/reports/T-4376-reviews/`). This report
measures each file and states the cause.

**Short answer: none of the six is a hang.** The swings come from three causes:

1. **A lock lottery.** A live audit in the real repo either loses `.context/locks/audit.lock`
   and skips (fast run, nothing measured), or wins it and pays a whole audit section (slow, up
   to the cap). This explains audit.bats and fabric_coverage_single_source.bats.
2. **Old code.** fw_doctor_vendored_drift.bats ran a full live `fw doctor` until 2026-10-06;
   t2332_bvp_propose_queue.bats called the live Watchtower until T-4384.
3. **Skips on a detached HEAD**, plus a real per-install cost. The "0 s" and "2 s" runs on
   the v1.8.11 base tree were every test skipping. The slow runs come from a ~92 s secret scan
   that every fresh install pays (T-4400).

Codex was right about the fast runs. Opencode was right that audit-lock contention is involved,
but it causes skips, not deadlocks.

## Method

- **History:** per-file `file_durations` and `files_timed_out` from every v2 report in
  `.context/audits/unit-suite/*.yaml` (v1 reports have no per-file data), plus the two
  same-moment trees `.context/scratch/v1812/reports/{hf,base}/LATEST.yaml`. Reports carry no
  revision id (T-4381), so history is split by report date against `git log` of each test file
  and the code it calls.
- **Alone runs:** `.context/scratch/T-4382/run5.sh <file> N` runs
  `timeout 1000 bats --timing tests/unit/<file>` N times, one file at a time, with project env
  unset. It counts ok / not ok / `# skip` per run. Every 60 s of a run it snapshots the process
  tree under bats, the holders of `.context/locks/audit.lock` (lsof), and every `audit.sh` on
  the host. Raw TAP and snapshots are in `.context/scratch/T-4382/out/<file>/`; that directory
  is gitignored, so the numbers below are the record.
- **"Alone" is relative.** The host was shared with other workers (T-4383 and T-4385 ran
  audit.bats at the same time) and with hourly cron audits from about 8 consumer projects.
  "Alone" means no other file from this suite run by me. For the lock question that is exactly
  the condition that matters.
- **Run counts:** 5 runs for the fast files. The install files ran 2 times each, because one
  run is 9–12 minutes of real installs. Their cost is deterministic and visible in the process
  snapshots, so more repeats would only add load to a shared host. audit.bats ran once; see
  its section.

## History (seconds per file in each nightly report; T = timed out at the 900 s cap)

| report | audit | vdrift | fabcov | t2332 | t4248 | inst_tp |
|---|---:|---:|---:|---:|---:|---:|
| 09-30 | 900T | 58 | 20 | 900T | – | 180 |
| 10-01 | 2 | 900T | 700 | 572 | – | 125 |
| 10-02 | 900T | 900T | 16 | 410 | – | 166 |
| 10-03 | 900T | 694 | 8 | 3 | – | 150 |
| 10-04 | 900T | 900T | 37 | 828 | – | 167 |
| 10-05 | 1 | 900T | 19 | 900T | – | 180 |
| 10-06 | 2 | 275 | 15 | 6 | – | 141 |
| 10-07 | 2 | **1** | 900T | 5 | – | 155 |
| 10-08 | 2 | 1 | 19 | 5 | – | 132 |
| 10-09 | 2 | 1 | 19 | 9 | – | 248 |
| 10-10 | 900T | 1 | 834 | 6 | – | 145 |
| 10-11 | 2 | 1 | 18 | 6 | – | 146 |
| 10-12 | 2 | 1 | 25 | 11 | – | 194 |
| 10-13 | 4 | 1 | 71 | 21 | – | 332 |
| 10-14 | 2 | 1 | 19 | 10 | – | 236 |
| 10-15 | 2 | 1 | 15 | 7 | – | 168 |
| 10-16 | 1 | 1 | 17 | 7 | – | 192 |
| 10-17 | 1 | 1 | 900T | 12 | – | 355 |
| 10-18 | 2 | 1 | 898 | 9 | 609 | 803 |
| 10-19 | 900T | 1 | 25 | 14 | 675 | 900T |
| v1.8.12 hf tree (10-18 22:50) | 900T | | | | 635 | 900T |
| v1.8.11 base tree (same second) | 900T | | | | **0** | **2** |

Bold marks the change points discussed below.

## Alone runs

| file | runs | wall per run (s) | ok / not ok / skip per run | notes |
|---|---:|---|---|---|
| fw_doctor_vendored_drift.bats | 5 | 5, 5, 5, 5, 5 | 4 / 0 / 0 | |
| t2332_bvp_propose_queue.bats (after T-4384) | 1 | 10 | 7 / 0 / 0 | re-measure only, as the brief asked |
| fabric_coverage_single_source.bats, **before** fix | 5 | 50, 51, 50, 30, 30 | 14 / 0 / **2** | both live legs skipped in all 5 runs: "audit lock held by a concurrent run" |
| fabric_coverage_single_source.bats, **after** fix | 5 | 74, 80, 85, 73, 69 | 15 / 0 / **0** | live legs ran each time (~24 s each) |
| t4248_install_init_failure.bats | 2 | 728, 547 | 3 / 0 / 0 | per test: 286 s, 193 s, 194 s (run 1) |
| install_target_project.bats | 2 | 998, 846 | 5 / 0 / 0 | per test: 203, 335, 191, 252, 16 s (run 1); 172, 184, 187, 285, 8 s (run 2) |
| audit.bats (as of 06658de93, T-4385) | 1 | 20 | 19 / 0 / **8** | all 8 live-repo tests skipped "audit lock contention (exit 75)"; only synthetic-project and stub tests ran |

Who held the lock during the before-fix fabcov runs (lsof, 17:01 to 17:10): an `audit.sh
--section structure` that another worker's `timeout 600 bats tests/unit/audit.bats` had
started (`.context/working/T-4385/run.sh`), plus a second audit.sh tree. In that tree the fd
200 lock was also held by its children (`timeout`, `fw`, `shellcheck`, `cat`, `python3`),
because the lock fd is inherited by everything audit.sh spawns (see T-4401).

## Verdicts

### fabric_coverage_single_source.bats — lock contention (skip or full section), fixed here

- **Fast runs (15–71 s):** tests 8 and 10, the live legs, ran `audit.sh --sections structure`
  in the real repo and skipped on "Another audit is already running". They skipped in 10 of 10
  alone runs today. The fast nightly numbers are therefore runs in which the live coverage
  differential measured nothing.
- **Slow runs (700 / 834 / 898 s, 900T):** the live legs won the lock. Each one then paid the
  whole structure section, which took 547 s in the timing ledger on 2026-10-19
  (`.context/audits/full-audit-timing.yaml`). Two legs come to about 1,100 s against a 900 s
  cap. This is not a hang: the process tree shows audit work in progress the whole time.
- **Fix (one-file test defect):** both live legs now run `audit.sh --check fabric-coverage`.
  This is the lockless single-check path from T-4209: it calls the same `check_fabric_coverage`
  function that the structure section calls (audit.sh:2613 and the top-level call at
  audit.sh:2817), and it takes no lock. A new guard test pins two things:
  - The structure section still calls that function, so `--check` still speaks for the section.
  - The file holds exactly two live `--check fabric-coverage` calls and no live `--section`
    call.

  Result: 0 skips in 5/5 runs, 69–85 s.
- **Red before / green after:** applied to the HEAD version, the guard counts
  check=0 / section=2 (red); applied to the new file it counts check=2 / section=0 (green).
  Behaviourally: 2 skips per run before (10/10 live legs unmeasured), 0 after.
- **Fault-detection fidelity:** the origin bug (T-2735) was a private watch-pattern glob
  inside audit.sh. It is still caught three ways:
  - the static "no private glob" test and its guard control (tests 2–3);
  - the "routes coverage through the canonical expander" test (test 4);
  - the live equality leg, which now always runs. Before the fix it was skipped whenever
    anything else was auditing.

  The fixture severity legs (tests 12–14) still run a full `--sections structure`. That is
  safe: they run against their own `PROJECT_ROOT`, so they take a private lock.

### audit.bats — lock contention (skip or full section), in flight under T-4383

- **2 s runs:** every live test hit exit 75 and skipped through the T-3328 helper. These runs
  measured nothing.
- **900T runs:** the file won the lock and ran its live sectioned audits in sequence (seven
  on the pre-T-4383 revision, mostly `structure`, which took 547 s today), so it reaches the
  cap on the first or second one.
  This is not a hang.
- Not edited here, because the file was in flight under two other tasks during this triage:
  - T-4383 moved the contract tests onto a synthetic project (69610b126, 16:06);
  - T-4385 merged a duplicate live structure run (06658de93, 17:53).

  Eight live-repo tests remain: compliance, traceability, the marker, header and timestamp
  tests, the live structure smoke, `--output` and YAML-valid. Moving them is part of T-4401.
- **Alone run (06658de93): 20 s, 19 ok, 8 skips.** All eight live tests got exit 75; the
  lock was held by cron audits and other workers' audit runs. This is the fast mode in its pure
  form: the file reports green and has measured only its synthetic and stub tests. I ran it
  once, not five times. A run that wins the lock holds the repo audit lock for 15 minutes or
  more and would make every other worker's audit on this host skip, which is the very harm
  being diagnosed. The slow mode is already established by the history (900T) and by the
  547 s structure section.

### fw_doctor_vendored_drift.bats — old code

- Before 4ee603957 (T-3950, 2026-10-06 22:03), the file ran a full `fw doctor` in the live
  repo. Under suite load that took 58–900 s.
- Every report since then shows 1 s. Today: 5/5 runs at 5 s, 0 skips.
- The swing in the history comes entirely from before that revision. Nothing to fix.

### t2332_bvp_propose_queue.bats — old code (live Watchtower, fixed by T-4384)

- The 410–900 s values are from the period when the file curled the live Watchtower with no
  timeout.
- After T-4384 made it hermetic: 10 s, 7/7, 0 skips.

### t4248_install_init_failure.bats — skip on a detached HEAD (0 s); slow because of a per-install cost

- **0 s on the base tree:** the v1.8.11 tree is a detached-HEAD checkout
  (`git rev-parse --abbrev-ref HEAD` returns `HEAD`). `setup_file` returns early and `setup`
  skips all three tests ("detached HEAD -- --local install needs a real branch name"). The
  base report has 28 skipped tests against 12 in hf, and this file accounts for 3 of the 16
  extra. The file did not fail to start, and no collection error occurred. It skipped, and its
  "pass" in that run measured nothing.
- **Slow (547–728 s alone, 609–675 s in the suite):** each test is a full `install.sh`: clone,
  `fw init`, `fw doctor`. The snapshots show where the time goes. `fw init`'s T-000 bootstrap
  commit runs the new project's own pre-commit hook, and its `secret-scan.sh scan-staged` scans
  all 2,678 freshly vendored framework files (38 MB). Measured on its own, that scan takes
  **92 s** (14 s of it in the per-path name loop). There is no hang. Filed as **T-4400**.
- The skip guard is legitimate (the `--local` install needs a branch name). The defect it
  hides is that a detached-HEAD run reports ok. That belongs to runner skip accounting
  (T-4381), which should reject unexplained skips.

### install_target_project.bats — skip on a detached HEAD (2 s); slow for the same per-install cost (900 s)

- **2 s on the base tree:** the same detached-HEAD guard skips all 5 tests.
- **125–355 s through 10-17, then 803 s and 900T:** five full installs, each paying the
  bootstrap secret scan (T-4400) and a `fw doctor` in the target. The jump on 10-18 coincides
  with two things:
  - t4248 and the other install-family files landing (more concurrent installs per night);
  - the larger vendored tree.

  It is not a hang. Alone: 998 s and 846 s, 5/5 ok, 0 skips.
  Four tests are 170–335 s each, one full install apiece, so the file sits at the 900 s cap
  even with nothing else from the suite running. Under suite load it times out, and that is
  the expected outcome, not a flake. The cure is T-4400 (cheaper init) and a duration-selected
  tier with its own cap (T-4377), not a test edit.

## Filed

- **T-4400:** `fw init`'s bootstrap commit secret-scans the whole vendored framework, about
  92 s per fresh install. This is the cost behind t4248, install_target_project and the
  install family.
- **T-4401:** tests/unit files that run a live sectioned audit in the real repo play the lock
  lottery: they skip or pay the whole section. A line-level grep finds up to 32 candidate files
  (not each confirmed live):
  audit.bats, audit_corpus_lint_findings.bats, audit_ctl012_compliance_section.bats,
  audit_ctl026_compliance_section.bats, audit_ctl028_completed_status_consistency.bats,
  audit_ctl030_completed_horizon_drift.bats, audit_flock.bats, audit_gate_bypass_log.bats,
  audit_null_timestamp.bats, audit_seed_corpus_refs.bats, audit_stale_arc_warning.bats,
  audit_trend_window.bats, audit_unclosed_satisfied_warn.bats, cron_flock_parity.bats,
  fabric_coverage_single_source.bats (done here), fabric_watch_pattern_fitness.bats,
  t2244_audit_self_vendor_drift.bats, t2930_audit_contention_exit_code.bats,
  t2969_draft_arc_complete_warning.bats, t3062_prepush_runtime.bats,
  t3070_audit_schedule_install_delegates_to_registry.bats,
  t3161_empty_registry_does_not_wipe_live_cron.bats, t3298_audit_lock_integrity.bats,
  t3444_ctl029_partial_complete.bats, t3507_arc_completion_union.bats,
  t3626_audit_schedule_install_project_root.bats, test_audit_completable_not_completed.bats,
  test_audit_cron_drift.bats, test_audit_cron_registry_generated_drift.bats,
  test_audit_retire_when.bats, test_audit_revert_chain.bats, test_audit_watchdog_fd.bats.

  The task also records that the lock fd is inherited by every child of audit.sh.

## For the other arc tasks

- **T-4381 (runner accounting):** the report should carry each file's skip count next to its
  duration. Today "2 s" and "skipped everything" look the same, and that is how the two
  reviews came to disagree.
- **T-4377 (tier split):** none of the bimodal files is a hang that excluding it would bury.
  audit.bats and the install family are slow by construction, not by deadlock.
