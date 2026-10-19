# Review — T-4376 test-suite optimisation (opencode, T-3580)

## 1. Top 5 recommendations (impact per effort)

**R1 — Root-cause the four bimodal hang files before any tier work.** `audit.bats` (median 2 s, TO 6/20), `fw_doctor_vendored_drift.bats` (1 s, 4/20), `t2332_bvp_propose_queue.bats` (10 s, 2/20), `fabric_coverage_single_source.bats` (20 s, 2/20) swing seconds↔900 s. A 2→900 s swing is a hang, not load (§2.2), and each hang costs a full cap and flips `bats_rc` to 124, which is why **0 of 81 logged runs exited 0** (§2.1). Fixing four files converts the nightly from "never green" to "green-able" for maybe a day of work — the single highest leverage item. Prime suspect: concurrent files spawning `audit.sh` which serialises on the audit lock — the hazard `unit-suite.sh:8-14` already documents for the runner itself, now between test files.

**R2 — Move the ~30-file integration family out of `tests/unit/` into an e2e tier (T-4377), selected by measured median duration, not by the hermeticity label.** Top 30 files = 52.6 % of all file-seconds; 21/30 are init/install/upgrade/doctor/audit/handover (§1.3–1.4). §5 concedes the hermeticity heuristic *admits* 10 files over 60 s median it can't explain (`t4248_install_inherited_env.bats` 683 s, `t4251_init_own_git_repo.bats` 648 s…) — the duration cap is what actually excludes them. So define tier membership as "median ≤30 s over trailing 20 v2 reports, never timed out" (≈1,014 files, 4,606 file-seconds, 82.9 % of tests; §5 row 1). Use the hermeticity lint as a *gate on membership*, not the selector.

**R3 — Lower the per-file cap for the gate.** The plan says "no file timing out in <10 min", but the runner's `FILE_TIMEOUT` default is 900 s (`unit-suite.sh:96`). One bimodal hang admitted into the fast tier eats 15 of the gate's 10 minutes by itself. Set the gate's `FW_UNIT_SUITE_FILE_TIMEOUT` to ~120 s (fast-tier longest healthy file is ~30 s median) and let the cap, not hope, enforce the budget.

**R4 — Strip wall-clock assertions out of the fast tier** (`hook_telemetry_race.bats:148` "5 ms budget" — red 4/20; `hook_telemetry.bats` "1000 fires under 5000 ms"; `t1719_*` latency tests; `t3636_objectives_seed.bats` write-time check, red 4/20; §3.2). These are red-under-load *by construction* at jobs=12. Keep the concurrency-correctness assertions (they're hermetic and cheap); move budgets to a serial perf tier or assert on operation counts. Note the suite already contains the right pattern: `hook_telemetry_race.bats` runs its benchmark outside bats' DEBUG trap (lines 140–147) — extend that discipline to isolation.

**R5 — Replace the always-red baseline with quarantine + fix.** 22 tests red in 20/20 reports, all covered by 44 baseline entries; 32/44 expire the same day (2026-10-31) and T-3747's has already expired (§3.3). An always-red test carries zero bits of information — it cannot catch the bug it was written for, violating goal (c) as surely as deletion would. Triaging 22 named tests is bounded, small work; the shared expiry date is a cliff that will land mid-refactor.

## 2. Where the measurement or plan is wrong/missing

- **The tier-split criterion is misaligned.** As argued in R2: the hermeticity scan doesn't follow `load`ed helpers (§7), so it both over- and under-classifies; duration data is the reliable signal. The plan should say this outright.
- **Evidence-driven pruning (T-4380) rests on reds that can't be interpreted.** §7: no per-run code revision is joined to the red lists, so a real bug caught-and-fixed-next-day is indistinguishable from a flake (204/246 reds appear in ≤2 of 20 reports). Pruning on this evidence will delete tests that *did* their job. Before T-4380, generalise the control-leg pattern already in `hook_telemetry_race.bats:83` ("the defect must reproduce; if not, this test has no teeth") — each preserved test should demonstrably fail against its origin bug (recorded red-run or seeded-bug replay), not merely be "rarely red".
- **No instrument for IW-4.** "Proof of no coverage loss" has no baseline: no mutation/bug-seed detection rate exists. Without one run measuring how often the current suite catches a seeded defect, the fast tier's trustworthiness is an article of faith.
- **Zero budget headroom.** §5's 3,600 file-seconds *is* the 10-minute budget at jobs=6 with perfect packing. Gate runs will contend with developer machines; hf/base showed 4 files swinging ≥300 s between identical concurrent suites (§2.4). Target ≤2,400 file-seconds (≈33 % headroom) at first, tighten later.
- **Pytest needs almost nothing** — 1,627 s total, slowest file 78 s (§1.2). Effort belongs in the 10 no-tmp live-anchored pytest files (89 tests, §4.1) for fidelity, not speed. The plan doesn't make this split.

## 3. Refactor risks and early detection

| Risk | Early detector |
|---|---|
| Pruned/merged test loses its origin bug (fidelity) | Control-leg / seeded-bug replay per pruned group; mutation spot-checks on the fast tier monthly |
| Tier drift: new slow e2e files re-land in `tests/unit/` (suite doubled in six weeks, §churn) | Lint rejecting fast-tier files whose trailing median exceeds the cap; trend line of "files above threshold" in the nightly report |
| Fast tier green while real regressions surface only nightly | Count "reds first caught by nightly, code unchanged" per week; a climb means the boundary is wrong |
| Hidden cross-file couplings break on move (e.g. `test_render_artefact_paths.py:118` reads `.context/audits/**` including the report being written) | Run the fast tier twice back-to-back on one tree; diff reds — order/state dependence shows immediately |
| Baseline expiry cliff (32 entries on 10-31) conflating with refactor reds | Re-inventory baseline before T-4377 lands; stagger expiries |
| Excluding the hang files buries a real deadlock | R1 must precede exclusion; keep a serial 1-job nightly leg for the excluded four |

## 4. Real bugs, not slowness

- **The bimodal quartet is a bug class** (see R1): most plausibly audit-lock serialisation/deadlock between concurrently-running test files — corroborated by "flock/lock held" in 2 captured failures and 37 with timeout/Terminated (§3.4), and by `audit.bats:21-26` needing an exit-75 contention *skip* at all.
- **`t4248_install_init_failure.bats` at 0 s in base** (§2.4) is the most alarming datum in the report: a file that normally takes minutes "finishing" instantly means it exited before testing — setup failure or collection error recorded as a verdict. That is exactly the silent-can't-fail class goal (c) fears. Investigate before trusting any of its passes.
- **`install_target_project.bats` 900 vs 2 s and `t4298_inherited_root_warning.bats` 366 vs 2 s**: same-tree swings this large point to a wait on an external resource (the install path uses `env -i` with a bare PATH, `install_target_project.bats:37-42` — anything from git credential lookup to name resolution can block). Triage protocol: run each swing file 10× in isolation; hangs alone = internal bug, hangs only in-suite = cross-file interference.
- **`upgrade_fresh_machine_simulation.bats`' five base-only reds** at 413 s (base) vs 305 s (hf) are internal wall-clock-dependent assertions — a test-design bug, not product.
- **`doctor_designer_pin_drift.bats` (median 900 s) and `t2243` (866 s)**: a single `fw doctor` invocation needing >15 minutes is a *product* performance defect worth its own ticket; excluding the test from the gate hides it.

Bottom line: do R1 and R2 first — they are cheap, and together they deliver (a) and (b). Everything that deletes or moves a test (T-4380) should be gated on the control-leg rule from R5/§2, or goal (c) is unmet.
