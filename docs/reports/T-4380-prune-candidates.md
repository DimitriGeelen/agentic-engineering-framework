# T-4380 — Prune and merge candidates, phase 1 (evidence only)

**Scope:** phase 1 of T-4380. This report collects evidence and proposes actions. Nothing under `tests/`, `lib/`,
`agents/` or `bin/` was changed. Phase 2 (the actual edits) waits for the parent's go.
**Inputs:** `docs/reports/T-4376-test-suite-refactor.md` and `docs/reports/T-4376-test-suite-measurement.md`.
**Rule followed:** nothing is pruned on taste. A candidate is backed either by a **mutation** (the code under test is
broken and the test stays green) or by **duplication** evidence (the same function, input and assertion, with the
kill sets compared under one mutation). Anything without that evidence is listed under "unproven".

## 0. Method and how to re-derive it

| Step | Tool (all under `.context/scratch/t4380/`) | What it does |
|---|---|---|
| Scratch tree | `mktree.sh` | `git archive HEAD` of the code and tests (no `.context`, no `.tasks` corpus, no `docs`) into `tree/`, given its own git repo. **The working tree is never mutated.** |
| Mutation runner | `mutate.sh NAME SRC OLD NEW TESTFILE…` | Replaces one exact string in `tree/SRC` (and refuses if the string is absent), runs the named test files inside `tree/` with `FRAMEWORK_ROOT`/`PROJECT_ROOT` unset, writes `runs/NAME.diff` and `runs/NAME.out`, then restores the tree. `NAME=control-*` runs the same files unmutated. |
| Replay | `runall.sh`, then `python3 -I summarize.py` | Every mutation in this report, in one script. The summary reads `runs/*.out`. |
| Static scans | `scan.py`, `scan_const.py`, `scan_copy.py`, `scan_dup.py`, `scan_samerun.py` | Never-fail statement shapes; asserts on test-local constants only; test lines copied verbatim from production code; identical test bodies; identical expensive invocations on an identical fixture. |
| Cost | `durations.json` | Median per-file wall seconds over the **21** schema-v2 suite reports (2026-09-30 → 2026-10-20). That is one more report than T-4376 used, because today's run landed. |

`.context/scratch/` is gitignored (`.gitignore:164`), so these scripts and run logs are local to this host and not
committed. Per the phase-1 scope, only this report and the task file are committed. If phase 2 needs them in-repo,
they move with phase 2.

**Expected saving** is the file median times the share of the file's expensive invocations (`fw doctor`, `fw audit`,
`fw init`, `handover.sh`, `resume.sh`) that a merge or delete removes. That assumes those invocations dominate the
file's cost. This is true for the doctor, audit and handover files below and is said per row. These are
contended-load seconds, as in T-4376 §0 caveat 1.

**A runner pitfall found on the way (it changes how phase 2 must test).** 50 bats files set
`FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"` (list: `hardcoded-root-files.txt`;
1,354 median file-seconds). Run from a scratch copy, a worktree or a consumer, they test **the main checkout**: they
inherit the session's `FRAMEWORK_ROOT`, or they fall back to the hard-coded path when it is unset. Evidence:
`m20-arc-syntax` adds a syntax error to `tree/lib/arc.sh`. The test "lib/arc.sh parses cleanly" goes red in the one
file that derives its root from `BATS_TEST_FILENAME` (`arc_dual_identity_verbs.bats`, 15/15 red). It stays green in
the four files with the fallback: `arc_abandon.bats` 12/12, `arc_create_no_constituent_tasks.bats` 5/5,
`arc_lifecycle_state_machine.bats` 11/11, `t3553_arc_demo_check.bats` 15/15 ok. Every one of those files has its own
"lib/arc.sh parses" test. `m20b` re-runs the same files with `FRAMEWORK_ROOT` set to the tree (§3). The nightly suite
is not affected: `agents/audit/unit-suite.sh:56` exports its own root. But no seeded-defect or historical-revision
run (IW-4) is valid on these 50 files until the fallback is removed. That fix is T-4378's (hermetic helper), not a
prune.

## (a) Tests that can never fail

### a.1 Static never-fail shapes: none found

`scan.py` looks for bodies whose every statement cannot return non-zero: only `run`, `echo` or assignments; only
`|| true`; inert negations; unconditional `skip`. It found **0 real hits** in 895 bats files. Its 3 hits are false
positives: `audit_flock.bats:57` and `:77` (`skip_if_no_flock` is a conditional helper) and
`validate_init_check_type_join.bats:223` (an assignment to a variable named `skipped`). 152 tests assert only through
file-local helpers (`assert_blocked`, `_assert_audit_ran`, …), and the helpers do assert. This matches T-4398's lint
(`tools/bats-dead-negation-lint.py tests/` reports clean). **The "cannot fail" population is not in the syntax. It is
in what the test runs.**

### a.2 CONFIRMED: the test runs its own copy of the production logic

These tests run an inline replica of the code they are named after: a Python heredoc or a shell block pasted into the
test. Breaking the real code leaves them green. Most also carry a source pin (`grep -q '<line>' audit.sh`), but a pin
only checks that a line of text exists. Every mutation below keeps the pinned text and breaks the behaviour.

| # | file:test(s) | Origin | Mutation (in `tree/`, `runs/<name>.diff`) | Result | Other test that goes red |
|---|---|---|---|---|---|
| A1 | `audit_ctl013_skip_nested_audit.bats`, all 6 behavioural tests (the regex is written out in the test) | T-1870 / L-391 | `m1-ctl013-noskip`: `agents/audit/audit.sh` CTL-013 skip branch `continue` → `:` (nested-audit lines no longer skipped: the origin bug) | 8/8 ok | none found (`grep -l cmd_skipped tests/`) |
| A2 | `audit_ctl_arc_tag_only_pattern.bats`, all 9 tests (`run_check` is a copy of the check block) | T-1881 | `m2-arctag-pattern`: `arc_tag_only_pattern=` → `'NEVER_MATCHES_T4380'` (check can never fire) | 9/9 ok | none found |
| A3 | `handover_filter_deferd_wip.bats`, the 3 behavioural tests (Python copy of the WIP loop) | T-1619 | `m3-handover-defer`: `agents/handover/handover.sh` DEFER `continue` → `pass` (DEFER'd inceptions back in WIP: the origin bug) | 7/7 ok (the pin `if wf == 'inception' and dec == 'DEFER':` survives) | none found |
| A4 | `audit_ctl_arc_membership_python_import.bats`, all 6 tests | T-3516 / OBS-546 | `m4-arcmember-window`: `WINDOW = 60` → `WINDOW = 0` in the audit block (nothing is ever flagged) | 6/6 ok | none found |
| A5 | `audit_split_root_asset_lint.bats`, the 9 behavioural tests (the header calls it an "inline replica") | T-2648 / OBS-097 | `m5-splitroot-count`: `splitroot_violations=$((…+1))` → `:` | 10 ok / 1 not ok, **identical to the control**. The red one is the live-count ratchet (§3). | none found |
| A6 | `audit_stale_slice_reference.bats`, all 13 tests | T-1975 / L-417 | `m6-staleslice-count`: the completed-task branch no longer counts | 13/13 ok | none found |
| A7 | `upgrade_relative_hook_path_detection.bats`, the 5 behavioural tests (replica of `check_stale_paths`) | T-1627 | `m7-upgrade-barerel`: `lib/upgrade.sh` bare-relative branch `stale += 1` → `pass` (the origin bug back) | 8/8 ok (the `startswith(` awk pin survives) | none found |
| A8 | `upgrade_duplicate_hook_detection.bats`, the 6 behavioural tests (Python copy of `fw_hooks`) | T-1479 | `m8-upgrade-dedup`: `lib/upgrade.sh:2605` `out.add((event, name))` → `pass` (no duplicate ever reported) | 11/11 ok | none found |
| A9 | `doctor_duplicate_hook_detection.bats` "behavioural: doctor's helper reports overlap…" (same copy again) | T-1480 | `m9-doctor-dedup`: `bin/fw:2330` `out.add((event, name))` → `pass` | 6/6 ok, including the full `fw doctor` smoke test | none found |
| A10 | `test_next_directive_schema.py`, the 3 `test_checkpoint_directive_extraction_*` tests and `test_claude_fw_signal_parse_*` (2) | T-2363 | `m10-checkpoint-directive`: `agents/context/checkpoint.sh` directive `print` → `pass`. `m11-claudefw-directive`: `bin/claude-fw:1457` reads `directive_x` | 9 passed, 9 passed | not checked outside this file |
| A11 | `render_surface_review_state_dup_human.bats`, all 5 tests. They copy a heredoc that **no longer exists** in `update-task.sh`; the logic moved to `lib/human_review_state.py` in T-3288. | T-1901 | `m12-review-state-firstonly`: `lib/human_review_state.py:29` keeps only the first `### Human` block (the origin bug) | 5/5 ok | none: `t3288_human_heading_suffix.bats`, the one real caller's test, also stays green (`m12b`, 7/7 ok) |
| A12 | `test_inception_decide_preserves_h3.py`, all 3 tests (`_rewrite_decision` is a "mirror") | T-1526 | `m13-inception-h2only`: `lib/inception.sh:711` `re.match(r'^#{2,} ', …)` → `line.startswith('## ')`. **This is the exact pre-fix code from the origin bug.** | 3 passed | not checked (13 inception_decide files; phase 2 must run them) |
| A13 | `test_doctor_consumer_version_ahead.bats:67`, `:77` and `test_upgrade_downgrade_guard.bats:77`, `:85` (they test GNU `sort -V`, nothing of ours), plus the pins `:30` / `:50` "uses sort -V" | T-1838 / T-1839, superseded by T-2713 | `m18-version-relation`: `lib/version-relation.sh` `_vr_set` always sets `match` (the real comparator, used by doctor and both upgrade guards) | both files 9/9 ok. `version_relation.bats` goes from 2 to 5 red (tests 1, 3, 6 newly red). | `version_relation.bats` (T-2713) |

Controls: every `control-*` run is green on the unmutated tree. The exceptions: `control-splitroot` (the ratchet, §3)
and `control-version` (tests 2 and 8 of `version_relation.bats` are red on the 1-commit scratch git; they depend on
history. This is an artefact of the scratch tree, not a finding).

**Why the "sort -V uses" pins pass.** T-2713 removed `sort -V` from the code. The string now survives only in
comments that say *not* to use it (`bin/fw:1460`, `:1690`, `:4215`, `lib/upgrade.sh:1618`). So the pin is satisfied
by the comment that records its own removal.

**Proposed action for a.2: strengthen, do not delete.** These files are the only tests of those checks (the last
column). Deleting them would leave the code untested; keeping them as they are measures nothing. The repo already has
the fix pattern: an extraction harness that runs the **shipped** block (`t3469_go_scope_tiers.bats`,
`t3099_go_scope_structural.bats`, `t3510_parked_branch_classification.bats` via T-3095). Their headers state this
exact defect: "a copy of the predicate in the test would pass forever after audit.sh changed". Phase 2 per row:
replace the replica with the extraction harness and **re-run the row's mutation; it must go red**. That red run is
the origin-bug evidence the arc's fault-detection-fidelity driver asks for. A13 is the exception: delete the four
`sort -V` tests and the two `sort -V` pins, because `version_relation.bats` already goes red on the mutation and the
code they describe was removed.

**Expected saving for a.2: about 0 s.** Each file has a median of 1–3 s, except A9 (below). The gain is fault
detection, not time.

### a.3 CONFIRMED weak: the expensive smoke test in A9

`doctor_duplicate_hook_detection.bats` "fw doctor runs without erroring (smoke, T-1480)" runs a full `fw doctor` on
the live repo. It asserts only that the output is non-empty and contains no Python traceback. Under `m9` (dedup
disabled) it stays green. It is the file's only expensive call: median **301 s**, against 1–3 s for its five
siblings. **Action:** after the A9 behavioural test is switched to the extraction harness, delete the smoke test.
Traceback detection in `fw doctor` is not this file's subject, and every doctor-running file in the suite would show
one. **Expected saving: ~301 s.**

## (b) Duplicate coverage

### b.1 Same expensive run, same fixture, different assertions: merge into one run (the time is here)

Each group runs the identical command on the identical fixture and then greps a different part of the output.
Duplication evidence: the statements up to and including the expensive call are byte-identical (`scan_samerun.py`;
each group was read by hand). **Merging keeps every assertion verbatim**, so each origin bug keeps its red run by
construction. The recommended shape keeps reporting per assertion: run once in `setup_file`, cache the output to a
file, and keep one `@test` per assertion reading the cache.

| Rank | File | Origin | Identical runs (line) | Proposed action | Saving (estimate) |
|---:|---|---|---|---|---:|
| 1 | `test_doctor_scope_tags.bats` (median 649 s) | T-1707 / G-065 | `run bash -c "$FW_BIN doctor 2>&1"` ×4 (63, 73, 82, 94); these are the file's only doctor runs | one doctor run, 4 assertions | 649 × 3/4 ≈ **487** |
| 2 | `greenfield_seed_audit_prototype.bats` (604 s; timed out 2 of 20 reports) | T-2703, T-2740 | `fw init "$proj"` + `seeded_run "$proj" audit` ×3 (all 3 tests) | one init and one audit, 3 assertions | 604 × 2/3 ≈ **403** |
| 3 | `t2243_doctor_self_vendor_templates.bats` (785 s) | T-2243 | t2, t3 and t4 each append one comment line to the same template, then `bin/fw doctor`. The fixtures differ only in the comment text; doctor sees "1 templates drift" each time. | one run for t2–t4 (t1 stays: different fixture) | 785 × 2/4 ≈ **393** |
| 4 | `handover.bats` (558 s) | T-923, T-944 | `"$HANDOVER" --no-commit` ×6 (53, 60, 67, 74, 80, 85) of 8 handover runs | one run, 6 assertions | 558 × 5/8 ≈ **349** |
| 5 | `resume.bats` (302 s) | T-922 | `quick` ×2 (40, 46), `status` ×4 (55–74), `sync` ×2 (82, 88) of 8 real runs | one run per subcommand | 302 × 5/8 ≈ **189** |
| 6 | `doctor_designer_pin_drift.bats` (873 s; at the cap 10 of 20) | T-2524 | t2 and t5: the same Python fixture edit (`sha256 = '0'*64`), then `bin/fw doctor` | fold t5's `git diff --quiet` assertion into t2 | 873 × 1/5 ≈ **175** |
| 7 | `worker_kinds_parity.bats` (317 s) | T-1735 | `fw doctor` at line 16 and line 102, same live repo | **delete** the test at line 101: its assertion (the parity line is printed) is implied by line 15's `OK.*Worker-kinds parity` (kill-set check `m21`, §3) | 317 × 1/2 ≈ **159** |
| 8 | `audit_corpus_lint_findings.bats` (319 s) | T-2985 | `_make_map fixture-dirty dirty` + `"$AUDIT" --section structure` ×3 (91, 100, 108) of 9 audit runs | one run, 3 assertions | 319 × 2/9 ≈ **71** |

**Total for b.1: about 2,226 file-seconds.** Together with a.3 (~301 s) that is **about 2,527 file-seconds, ~7 % of
the ~36,000 per run.** All of it is in files that are excluded from the fast tier anyway (T-4376 §5), so this
shortens the slow tier and the nightly run, not the pre-push gate.

Two cautions for phase 2:
- Files 1, 4, 5 and 7 run against the live repo (`handover.bats` writes the live `.context/handovers/`). Merging does
  not fix that. It is T-4378's hermetic-helper job. Do the merge first: one run fewer is one live-state write fewer.
- Re-measure after each merge. The proportional estimate assumes the repeated call dominates the file. The control is
  `t2835_unknown_cmd_no_autoinit.bats`, where it does not: `scan_samerun.py` estimates 113 s, but the repeated call
  takes 0.2 s in isolation. That row is in "unproven".

### b.2 Same function, same input, same assertion, in two files (kill sets compared)

The same mutation is run against both files. Identical kill sets mean the coverage is duplicated.

| Group | Members | Mutation | Kill sets | Keeper (red run on the origin) | Action | Saving |
|---|---|---|---|---|---|---:|
| B1 | `safe_commands_env_prefix.bats` "single / multiple env-var prefixes", "env-prefix + path-prefixed", "env-prefix + fw doctor" ↔ `t3374_env_prefix_denylist.bats` CONTROL ×4 (identical inputs and asserts) | `m14-envprefix-strip`: the T-1908 stripper call → `:` (the origin bug) | 7 red in the first file, 5 red in the second, including all 4 pairs | `safe_commands_env_prefix.bats` (T-1908 is the origin) | keep both. t3374's controls make that file self-contained when it is pointed at a pre-fix source (`FW_SAFE_COMMANDS_SRC`). Merging removes that and saves nothing. | ~0 |
| B2 | `git_common.bats` `get_task_name` ×2 ↔ `lib_tasks.bats` `get_task_name` ×3 (same `lib/tasks.sh` function) | `m15-get-task-name`: prepend `echo BROKEN` | 2 red ↔ 3 red; every `get_task_name` test in both files | `lib_tasks.bats` (T-764, the module's own file; superset: quoted and unquoted names) | delete the 2 `get_task_name` tests from `git_common.bats`. Its header says it tests `agents/git/lib/common.sh`; that function lives in `lib/tasks.sh`. (The `task_exists` tests look duplicated the same way but were not mutated: unproven.) | ~0 |
| B3 | `test_bvp_judge.py::test_unknown_is_never_falsely_favourable` ↔ `test_arc_driver_judge.py::test_unknown_is_never_falsely_favourable` ↔ `test_t3525_judge_verdict.py` | `m19-may-proceed-unknown`: `may_proceed` admits UNKNOWN | 2 red in each of the 3 files, both copies included | `test_t3525_judge_verdict.py::test_unknown_is_neither_green_nor_proceedable` (T-3525 defined `may_proceed`) | delete the two copies (T-3526, T-3527); their own UNKNOWN end-to-end tests also went red and stay | ~0 |
| B4 | `bash -n <file>` as a standalone test: 69 bats files, e.g. `$AUDIT` ×9, `$HANDOVER` ×5, `lib/arc.sh` ×5, `lib/upgrade.sh` ×4, `bin/fw` ×4 | `m20b` (§3) | same check repeated per file | one lint that runs `bash -n` over every shell file in the repo, if T-4379 wants it | merge into the lint, or leave | ~0 |
| B5 | A13 (`sort -V` ×4) | `m18` | 0 red in both files | `version_relation.bats` (T-2713) | delete (see a.2) | ~0 |

### b.3 Not duplicates: identical bodies, separate code (negative evidence)

`test_bvp_blueprint_cost.py` and `test_bvp_cli_arcs_rollup.py` share **6 byte-identical** test bodies on
`_arc_rolled_up_scores`. They are not duplicate coverage. `web/blueprints/bvp.py:516` and `lib/bvp.sh:667` are two
implementations, and the CLI file loads the Python body out of `lib/bvp.sh`. `m16-web-rollup` turns 2 red in the
blueprint file and 0 in the CLI file. `m17-cli-rollup` does the reverse. **Keep both.** The duplication is in the
production code, and these tests are what keeps the two copies in parity (T-1937).

Other identical-body groups from `scan_dup.py` (`dup.json`, 43 groups) were not proven either way. They are mostly
2-statement controls, compile checks of a template, and hook pass-through tests that reuse a body against a
different `$HOOK` set in `setup()`. Identical text there means different code, so they are not candidates.

## Ranking by file-seconds saved

| Rank | Candidate | Class | Evidence | Action | Saving (file-s) |
|---:|---|---|---|---|---:|
| 1 | `test_doctor_scope_tags.bats`, 4 doctor runs | duplicate run | identical invocation | merge | ~487 |
| 2 | `greenfield_seed_audit_prototype.bats`, 3 × init+audit | duplicate run | identical invocation | merge | ~403 |
| 3 | `t2243_doctor_self_vendor_templates.bats` t2–t4 | duplicate run | fixture equal up to a comment | merge | ~393 |
| 4 | `handover.bats`, 6 × `--no-commit` | duplicate run | identical invocation | merge | ~349 |
| 5 | `doctor_duplicate_hook_detection.bats` smoke | weak / never-fail under m9 | mutation `m9` | strengthen A9, then delete the smoke | ~301 |
| 6 | `resume.bats` | duplicate run | identical invocation | merge per subcommand | ~189 |
| 7 | `doctor_designer_pin_drift.bats` t5 → t2 | duplicate run | identical fixture and invocation | merge | ~175 |
| 8 | `worker_kinds_parity.bats` line 101 | subsumed duplicate | kill set `m21` (§3) | delete | ~159 |
| 9 | `audit_corpus_lint_findings.bats` 91/100/108 | duplicate run | identical invocation | merge | ~71 |
| 10 | A1–A12 inline replicas | never-fail (copy of code) | mutations m1–m13 | strengthen (extraction harness), then re-run the mutation | ~0 |
| 11 | A13 / B5 `sort -V` tests and pins | never-fail (obsolete premise) | mutation m18 | delete | ~0 |
| 12 | B2 `git_common.bats` task_exists/get_task_name | duplicate | kill set m15 | delete from git_common | ~0 |
| 13 | B3 judge UNKNOWN copies | duplicate | kill set m19 | delete the two copies | ~0 |
| 14 | B1 env-prefix controls | duplicate | kill set m14 | keep (self-contained control leg) | 0 |
| 15 | B4 `bash -n` repeats | duplicate | m20b | merge into a lint, if T-4379 takes it | ~0 |

## Unproven (no mutation or duplication evidence; do not act on these)

- `t2835_unknown_cmd_no_autoinit.bats`: the duplicate runs exist (37/43/49) but are cheap (0.2 s isolated). The 452 s
  median is not explained by them. Saving unproven; the slow part is elsewhere in the file.
- `t2290_doctor_mcp_content_check.bats` (523 s), `t3119_designer_currency.bats` (519 s),
  `t3158_designer_currency_check.bats` (188 s): every doctor run uses a different fixture, so they are not
  duplicates. They are slow because each test is a full `fw doctor`. Replacing them with focused checks is
  T-4377/T-4386 work, not a prune.
- `t3593_tier0_action_approvals.bats`: repeated `_hook "git push --force origin main"` calls (44/71/225, 121/458) are
  sub-second hook calls. No saving to claim.
- `test_doctor_scope_tags.bats` tests 2 and 3 skip whenever the host has no `[host]` finding. That is the
  "skip reads as ok" class (T-4382). Whether they ever ran in the nightly cannot be determined from the reports (no
  per-test skip data). Unproven, not a prune.
- The 43 identical-body groups in `dup.json` not discussed above.
- Whether any test **outside** the named file catches mutations A10 and A12. Only the named file was run. Phase 2 must
  run the whole suite under each mutation before any deletion. For A1–A9 and A11, a grep found no other test that
  names the mutated code, but a grep is not a run.

## 3. Side findings (reported to their owners, not acted on here)

1. **Hard-coded repo root in 50 bats files.** See §0. This blocks every seeded-defect or historical-revision run on
   those files, which is the instrument IW-4 needs. Owner: T-4378.
2. **`audit_split_root_asset_lint.bats` test 10 "shell-idiom ratchet (T-2649)" is red at HEAD.** It is red in the
   2026-10-20 `LATEST.yaml` (fast tier) and in the scratch control: `[ "$count" -eq 12 ]` against the live source
   tree. A live-count anchor (T-3326 class), and not in `baseline.yaml`.
3. **Runs m20b and m21** were made with `FRAMEWORK_ROOT` exported to the tree (`MUT_EXPORT_ROOT=1`), because the
   files involved have the hard-coded fallback. Results below.

### m20b: the same syntax error, with the root pointed at the tree

`arc_abandon.bats` 0/12 ok, `arc_create_no_constituent_tasks.bats` 0/5, `arc_lifecycle_state_machine.bats` 2/11,
`t3553_arc_demo_check.bats` 2/15. All four "lib/arc.sh parses" tests are red. Under `m20` (root unset) the same four
files were 43/43 green. **The fallback alone decides whether these files see the code they sit next to.** For B4 it
also shows that the five `bash -n lib/arc.sh` tests are one check repeated: every file that sees the tree goes red
on it.

### m21: is `worker_kinds_parity.bats` line 101 subsumed by line 15?

Mutation: `bin/fw` prints the healthy parity line as `WARN` instead of `OK`. Control (`control-wkp`, root set to the
tree): 7/7 ok. Mutated: test 1 (line 15, `OK.*Worker-kinds parity`) is red; test 7 (line 101, the line merely exists)
stays green. Its only assertion is that some line contains "Worker-kinds parity", and test 1's first `grep` asserts
the same, so any mutation that kills test 7 kills test 1. Test 7 detects nothing that test 1 does not. **Delete it
(rank 8).** That removes one of the file's two full `fw doctor` runs.

## Phase 2 checklist (for the parent's go)

1. Per a.2 row: switch to the extraction harness, re-run the row's mutation with `mutate.sh`, and require red. Record
   the red run in the task.
2. Per b.1 row: merge into `setup_file` with the output cached. Re-run the file and compare its duration with the
   median here.
3. Before any **deletion** (a.3, A13, B2, B3, m21): run the whole unit suite under that row's mutation in the scratch
   tree, with `FRAMEWORK_ROOT` exported to the tree, so the 50 hard-coded-root files see it too. Confirm that the
   keeper goes red and nothing else was the only test to catch it.
4. Before editing any bats file: run `python3 tools/bats-dead-negation-lint.py tests/` and require "clean".
