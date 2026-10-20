# T-4380 phase 2 — evidence (proven items only)

Scope (parent's go, 2026-10-20): (1) rewrite the 13 tests A1–A13 of `T-4380-prune-candidates.md` §a.2 so they run the
real production code; (2) merge the three duplicate groups the report marks as mutation-proven. Everything else in the
report (unproven rows, the A10/A12 whole-suite caveat, the b.1 doctor/audit merge estimates, the A9 smoke deletion, B1,
B4) is untouched. Only `tests/` changed.

**Method.** Each rewritten test was synced into the scratch tree `.context/scratch/t4380/tree` (a `git archive` of HEAD,
gitignored, local to this host), run unmutated (control) and under the report's mutation (`runall.sh` line of the same
name, through `mutate.sh`; `prove.sh NAME…` syncs and replays). Roots are derived from the test file's location
(`test_helper.bash` or `parents[2]`), never a literal `/opt` path. The shipped code is reached by cutting the block out
of the production file between its own delimiters (the `t3469_go_scope_tiers.bats` pattern) with a guard that fails
loudly if the block moves, or by calling the module directly.

## (1) A1–A13: before / after

| # | File | Before (mutation) | After: control | After: mutation red | How the real code is reached |
|---|---|---|---|---|---|
| A1 | `audit_ctl013_skip_nested_audit.bats` | `m1` 8/8 ok | 9/9 ok | `m1` 4 red (1,2,3,5) | CTL-013 block cut from `audit.sh`, run on a fixture completed task with a failing `fw` stub on PATH |
| A2 | `audit_ctl_arc_tag_only_pattern.bats` | `m2` 9/9 ok | 9/9 ok | `m2` 3 red (2,3,7) | check block cut from `audit.sh` |
| A3 | `handover_filter_deferd_wip.bats` | `m3` 7/7 ok | 7/7 ok | `m3` 1 red (4) | WIP renderer cut from `handover.sh` (stops before the Deferred-Inceptions section) |
| A4 | `audit_ctl_arc_membership_python_import.bats` | `m4` 6/6 ok | 6/6 ok | `m4` 1 red (2) | scanner python cut from `audit.sh` |
| A5 | `audit_split_root_asset_lint.bats` | `m5` identical to control | 11/11 ok | `m5` 5 red (2,3,4,6,9) | check block cut from `audit.sh` |
| A6 | `audit_stale_slice_reference.bats` | `m6` 13/13 ok | 13/13 ok | `m6` 6 red (2,3,4,8,10,11) | check block cut from `audit.sh` |
| A7 | `upgrade_relative_hook_path_detection.bats` | `m7` 8/8 ok | 8/8 ok | `m7` 2 red (4,8) | `check_stale_paths` cut from `lib/upgrade.sh` |
| A8 | `upgrade_duplicate_hook_detection.bats` | `m8` 11/11 ok | 11/11 ok | `m8` 2 red (6,11) | `dup_analysis` python cut from `lib/upgrade.sh` |
| A9 | `doctor_duplicate_hook_detection.bats` (behavioural test only) | `m9` 6/6 ok | 6/6 ok | `m9` 1 red (behavioural) | `dup_pairs` python cut from `bin/fw` |
| A10 | `test_next_directive_schema.py` | `m10`,`m11` 9 passed | see finding below: 9 passed (repaired scratch snippet, `--runxfail`) | `m10f` 1 failed; `m11` 1 failed | snippets cut from `checkpoint.sh` and `bin/claude-fw` |
| A11 | `render_surface_review_state_dup_human.bats` | `m12` 5/5 ok | 5/5 ok | `m12` 1 red (2) | calls `lib/human_review_state.py` |
| A12 | `test_inception_decide_preserves_h3.py` | `m13` 3 passed | 3 passed | `m13` 1 failed | `PYDECIDE` heredoc cut from `lib/inception.sh`, run on a fixture task file |
| A13 | `test_doctor_consumer_version_ahead.bats`, `test_upgrade_downgrade_guard.bats` | `m18` 0 red in both | 27/27 ok (with `version_relation.bats`) | `m18` 4 red (T-1838 8,9; T-1839 8,9) | `lib/version-relation.sh` on a two-commit fixture repo; the `sort -V` pins now pin `fw_version_relation` |

Savings: about 0 s for all 13 (1–3 s files, as in the report). The gain is fault detection: 13 files that could not go
red under their own origin bug now do.

Notes on individual rows:

- **A9.** The 301 s smoke test (`fw doctor runs without erroring`) is *not* deleted: it is one of the file's tests, and
  this phase forbids deleting A-file tests. Left for the parent to decide (report §a.3, ~301 s).
- **A13.** Kept and rewritten (the report said delete; this phase says do not delete). The GNU `sort -V` tests became
  tests of the comparator the code actually uses.
- **A5.** The T-2649 shell-idiom ratchet (test 10), red at HEAD when the report was written, is green now (T-4484 moved
  its baseline to 22); not touched.

### FINDING — A10 found a live production bug (not fixed here; `tests/` only)

Running the shipped snippet instead of a copy shows that `agents/context/checkpoint.sh:336-345` (the `_directive_json`
python) has **lost its indentation** — `try:` is followed by an unindented `with open(...)`. It is a `SyntaxError`,
swallowed by `2>/dev/null … || _directive_json=""`, so **the restart signal never carries the directive**. `git log -S`
puts it at `b0758d0fc` (T-3989, 2026-10-08): about 12 days silent. The old copy-test kept passing the whole time.

Handling: the positive test `test_checkpoint_directive_extraction_helper_present_when_file` is
`@pytest.mark.xfail(strict=True)` with that reason, so it flips to a failure the moment `checkpoint.sh` is repaired and
the marker is removed with the fix. The proof of the other direction was done on a scratch copy with the snippet repaired
(`tree` commit "scratch: repaired checkpoint.sh…"), run with `PYTEST_ADDOPTS=--runxfail`: control 9 passed; `m10f`
(directive `print` → `pass`) 1 failed; `m11` (reader looks up `directive_x`) 1 failed (`…extracts_new_payload`). The two
"empty when absent / missing" tests pass on the broken code as well (an empty output is also what a syntax error
produces); they cannot be strengthened without the fix. **Needs its own task (build/bug, `checkpoint.sh`).**

## (2) Duplicate groups (mutation-proven, keeper red first)

| Group | Mutation | Keeper red? | Deleted | Saving |
|---|---|---|---|---|
| B2 `get_task_name` | `m15` (`echo BROKEN` prepended in `lib/tasks.sh`), rerun now: `lib_tasks.bats` tests 8,9,10 all red (and `git_common.bats` 9,10) | yes — `lib_tasks.bats` (T-764, the function's own file) | the 2 `get_task_name` tests in `git_common.bats` (comment left pointing at `lib_tasks.bats`; `task_exists` tests kept, unproven) | ~0 s |
| B3 judge UNKNOWN copies | `m19` (`may_proceed` admits UNKNOWN), rerun now: 2 red in each of the 3 files; keeper `test_t3525_judge_verdict.py::test_unknown_is_neither_green_nor_proceedable` red; each copy-file's own end-to-end UNKNOWN test also red | yes | `test_unknown_is_never_falsely_favourable` in `test_bvp_judge.py` (T-3526) and `test_arc_driver_judge.py` (T-3527); 82 tests across the 3 files pass | ~0 s |
| m21 `worker_kinds_parity.bats` line 101 | `m21` (`bin/fw` prints the healthy line as WARN), rerun now: test 1 (`OK.*Worker-kinds parity`) red, the line-101 test stays green | yes — test 1 | "doctor parity check exits without crashing in fresh shell" (a second full `fw doctor`) | est. ~159 file-s (one of two doctor runs; re-measure at the next suite report) |

The whole-suite-under-mutation check from the report's checklist (item 3) was not run for these three; the scope here
was the keeper-red-under-the-same-mutation evidence, as instructed. `tools/bats-dead-negation-lint.py tests/` →
"clean"; `tests/lint/bats-git-discovery-fence.bats` → 5/5 ok; `tools/bats-test-isolation-lint.py tests/` → new 0.

Per-file raw runs: `.context/scratch/t4380/runs/*.out` (local, gitignored); the replay lines are the ones in
`runall.sh`, plus the `control-nextdir-fixed` / `m10f-…` pair appended for A10.
