# T-3747 — pre-push red triage, round 4 (2026-10-04)

Scope: the 3 FAILs of `bin/fw audit --section structure` after the full unit run of
2026-10-04 20:06Z, for the unpushed range `0fd674383..HEAD` (T-3831–T-3837 upgrade/vendor/doctor,
T-3843/T-3841 arc close). Method: run each red alone, then check `.context/audits/unit-suite/<day>.yaml`
history and `full-audit-timing.yaml`. A red that passes alone and whose subject is timing or
concurrency is judged load-only; a red that fails alone is traced to its commit.

## Verdicts

| # | Item | Verdict | Cause | Fix / owner |
|---|------|---------|-------|-------------|
| 1+2 | Dead-negation lint + `tests/lint` invariant (`upgrade_fresh_machine_simulation.bats:573-574`) | regression fixed | T-3831 added two `! cmp -s` mid-test assertions (bash ignores `!` for errexit, so they could never fail) | `76922f3a5`: `run cmp -s …; [ "$status" -ne 0 ]`, with the `$output` assertion moved ahead of the `run`. `tests/lint/bats-dead-negation.bats` 13/13 |
| 3a | `t2093` t2 "F6 subshell-scoped force=true … (structural)" | regression fixed | T-3833 (`e34a32a75`) captured the regen output: `_regen_out=$( ( force=true; generate_claude_code_config … ) )`. Still subshell-scoped (so the code is right), but the test's `^\s*\(` grep no longer matched that site | `239e7a855`: the grep also accepts the `VAR=$( ( force=true; …` form. 6/6 |
| 3b | `upgrade_fresh_machine_simulation.bats` TIMED OUT (900 s) | regression fixed (budget, not a hang) | Not a hang: 20/20 green alone in 486 s. Earlier full runs took 567 / 776 / 431 s (10-01 / 10-02 / 10-03). Today's T-3831–T-3836 tests add about 95 s alone, which put the file over the per-file cap under 12-job load | `ba76d2c0c`: the four `fw init`-built consumer tests (T-2793 ×3, T-3671) moved to `upgrade_fresh_machine_simulation_vendored.bats`; shared helpers in `tests/fresh_machine_helper.bash`. Run concurrently: 203 s (16 tests) + 326 s (4 tests), all green |
| 3c | `test_arcs_pages_tokens.py::test_no_go_verdict_uses_danger_token` | regression fixed | T-3843 (`d33fdbadd`) added the "no close recommendation yet" card (`.anchor-rec-missing { border: 2px solid var(--wt-danger); }`). That is a legitimate third token use, and the test pinned an exact count of 2 | `4e5f3e6fe`: assert the new rule and count 3. (`test_only_neutral_fallback_hexes_remain` is a separate red already in the baseline; not touched) |
| 3d | `hook_telemetry_race` "concurrent increments are not lost" | load-only, test hardened | Passes alone (7/7); also red on the 10-03 full run. Under load a waiter starves past `flock -w ${FW_TELEMETRY_LOCK_WAIT:-2}` and takes the designed lossy degrade-to-allow path (L-331), which shows up as lost increments. The lock itself is correct | `ad5afcfb0`: this test sets `FW_TELEMETRY_LOCK_WAIT=120`, so it asserts serialisation rather than the 2 s bound. The control leg is unchanged and still fails the lock-free variant |
| 3e | `t3511_parked_merge_guard` "FW_ALLOW_PARKED_MERGE=1 permits the merge and says so" | load-only | Passes alone (13/13, 5.8 s); red on the 10-03 and 10-04 full runs. Runs a real `git merge` through the hook chain. No change in range touches the guard | T-3845 (filed) |
| 3f | `t3662` "configured PORT held by a foreign service still refuses" | load-only (flaky even at idle) | Passes alone on 2 of 3 runs; another run failed test 1 instead. Same port and startup-timing flake class, in the same file | T-3797 (existing: t3662 flakes under suite load) |
| 3g | `t1719_index_one_post_write` "retrievable … under the 5s budget" | load-only | 5 s wall-clock latency assertion. Passes alone (8/8); red on the 09-30 and 10-04 full runs | T-3846 (filed) |
| 3h | `t3062_prepush_runtime` "pre-push structure audit completes inside its budget" | **pre-existing, not load and not this range** | Fails alone: 324 s against a 150 s budget. `full-audit-timing.yaml` shows structure at 226–292 s since at least 2026-09-25 (about 100 s before that). Earlier full runs record this file at 0–1 s: it skipped on "another audit holds the lock", so the overrun stayed hidden. 10-04 is the first run in which it actually measured | T-3844 (filed). Needs a cost hunt, not a budget bump |
| 3i | `t3302_unit_suite_schedule` "starved pytest leg actually MEASURES its tests" | load-only | 15 s runner window with an 8 s pytest reserve; under load pytest startup can eat the reserve. Passes alone (20/20, 25 s) | T-3847 (filed) |

## Load-only reds for the operator

- `t3511_parked_merge_guard.bats`: FW_ALLOW_PARKED_MERGE=1 permits the merge and says so (T-3845)
- `t3662_watchtower_port_allocation.bats`: a configured PORT held by a foreign service still refuses (T-3797)
- `t1719_index_one_post_write.bats`: retrievable under the 5s budget (T-3846)
- `t3302_unit_suite_schedule.bats`: the starved pytest leg actually MEASURES its tests (T-3847)
- `hook_telemetry_race.bats`: concurrent increments are not lost. Load-only cause, but hardened in `ad5afcfb0`, so it should go green.

Not load-only, and not fixable inside this range: `t3062_prepush_runtime.bats` (T-3844). It fails
alone. It is pre-existing and was masked by the lock-skip, so it will stay red until the structure
section's cost is found.

## Notes

- §Consumer-Facing Command Hygiene in CLAUDE.md names `upgrade_fresh_machine_simulation.bats` only.
  The sibling `upgrade_fresh_machine_simulation_vendored.bats` carries the same obligation (both
  file headers say so). CLAUDE.md was not edited here.
- No vendored path changed (`bin/fw vendor self --check` is clean) and no `web/` file changed, so no
  vendor-sync commit and no Watchtower restart were needed.
- Not run: the full suite (left to the parent). `baseline.yaml` was not touched.
