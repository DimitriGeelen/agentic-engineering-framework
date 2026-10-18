# T-4246 — v1.8.11 full-suite comparison (413701ff9 vs v1.8.10 704c9988f)

**Method:** as for v1.8.10 (docs/reports/T-4092-hotfix-v1810.md): fresh clones of each commit under
`.context/scratch/v1811/{tip,base}`, `agents/audit/unit-suite.sh` in each, run in parallel, own report dir and lock.
Reports: `.context/scratch/v1811/reports/{tip,base}/LATEST.yaml`; comparison script `.context/scratch/v1811/compare.py`;
reruns of differences in `.context/scratch/v1811/reruns/`. The dispatched worker (w4246-suite) completed both runs and
the reruns, then hit its 2.5 h limit while bisecting; this report was written by the parent from its data.

| | tip 413701ff9 | control 704c9988f (v1.8.10) |
|---|---|---|
| wall | 6392 s | 5929 s |
| bats files / tests | 836 / 7246 | 770 / 6717 |
| bats failed (skipped) | 85 (26) | 77 (18) |
| pytest files / tests | 308 / 4299 | 286 / 4060 |
| pytest failed (skipped) | 6 (4) | 6 (4) |

Tip has 66 more bats files and 22 more pytest files: the new tests of this release.

**Per-file timeouts (900 s cap):** both sides: audit.bats, handover.bats, init_project_shape_detection.bats,
init_validation_ordering.bats, t2244_audit_self_vendor_drift.bats, t3974_wm_focus_consumer.bats,
test_fw_gaps_closure_check.bats. **Tip only:** t2912_upgrade_hook_regen_convergence.bats → T-4302.
Pytest timeouts (both): test_orchestrator_status_outcomes.py, test_orchestrator_status_terminal_events.py.

**Failing on both sides (not attributable to the release):** bats 63, pytest 6 (the same 6: test_bvp_usage_axis ×2,
test_cockpit_activity, test_govd_sandbox ×2, test_operator_facing_stderr).

**Failing on control only (14):** load-flaky or fixed by the release (audit.bats compliance, render-surface SIGPIPE
sentinel, t2290 t2, t3118/t3235 corpus horizon invariants, t3511 ×3, test_audit_watchdog_fd, and five
upgrade_fresh_machine_simulation cases).

## Failing on tip only (22) — attribution

| Test(s) | Count | Attribution | Status |
|---|---|---|---|
| upgrade_marked_region.bats | 6 | Release diff: T-4232 now refuses invented governance lines the fixtures used | FIXED, T-4294 (fixtures use the template text; refusal pinned) |
| t3048_bats_leg_guard.bats | 4 | Release diff: T-4248 rejects a fake FRAMEWORK_ROOT without lib/ and agents/ | FIXED, T-4295 |
| fw_version_output.bats | 1 | Same as above | FIXED, T-4295 |
| t2936_bootstrap_quoted_redirect.bats | 1 | Release diff: T-4265's nested `(skip\|status)` group broke the test's verb derivation | FIXED, T-4293 |
| t3636_objectives_seed.bats | 1 | Release diff, real bug: T-4251's HOME resolution aborts `fw init` under set -e when HOME is missing | FIXED, T-4296 (regression test added) |
| t3647_claude_fw_register_leak.bats | 3 | Under investigation | T-4300 |
| t4119_terminator_handover_git_extension.bats | 3 | Under investigation | T-4300 |
| t2919_budget_gate_command_classify.bats | 1 | Under investigation | T-4301 |
| t3254_driver_refusals.bats | 1 | Under investigation | T-4301 |
| t3602_unit_suite_partial_run.bats | 1 | Under investigation (suspect T-3794) | T-4301 |

Differences attributed to the release diff so far: **13, all fixed** (T-4293, T-4294, T-4295, T-4296). Open: 9 plus
one tip-only timeout, under T-4300..T-4302. One of the 13 (T-4296) was a real product bug, not a test artefact: it
would have made `fw init` fail silently on hosts with no HOME.

## Result

Pending T-4300..T-4302. The release gate ("no failure attributed to the release diff that is not fixed or baselined
with an owner") is not yet met.
