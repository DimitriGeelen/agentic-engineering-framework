# T-4489 — security follow-up to v1.8.13: T-4485 via the hotfix lane

The lane is the one T-4420 used (docs/reports/T-4420-hotfix-v1813.md). Work was done in scratch clones under
`.context/scratch/t4489/{hf,base}`. The branch commits were built in the main repo with plumbing: a private
`GIT_INDEX_FILE`, `commit-tree` and `update-ref`. **Nothing was pushed or tagged, VERSION was not changed and master was
not touched.**

## Version: parent's decision needed

**The release tooling accepts only X.Y.Z. A 4-part `v1.8.13.1` is not supported:**

- `lib/release.sh:release_bump_version`:
  - It splits the version into major, minor and patch only.
  - `fw release tag-and-release` derives the next version from the latest tag with `--bump patch|minor|major`, so from
    v1.8.13 it yields **v1.8.14**.
  - It has no way to name a 4th component. On a `v1.8.13.1` tag, patch would be `13.1` and the arithmetic fails.
- `lib/release.sh:399`: `fw release decide` requires `^v[0-9]+\.[0-9]+\.[0-9]+$`. That makes an unattended release of
  a 4-part version impossible (T-4364).
- `lib/version.sh:63`: `fw version bump` requires X.Y.Z.
- **`lib/version.sh:_version_lt`** (and its duplicate, `release_version_lt`) compares only 3 fields.
  - With `1.8.13.1`, the third field is `13.1` and `[ -lt ]` errors, which reads as "not less".
  - Consumers already on v1.8.13 carry this code vendored. They would not see 1.8.13.1 as newer than 1.8.13, and later
    would not see 1.8.14 as newer than 1.8.13.1.
  - Supporting a 4-part version would mean changing tooling that is already installed in the field. That is not a hotfix.

The candidates:

1. **v1.8.14 for this hotfix** (what `tag-and-release` produces by default). The broad bleeding-edge release moves to
   **v1.8.15**. The existing `v1.8.14-be.1..3` tags stay as historical pre-releases of what ships as v1.8.15, and
   later pre-releases are tagged `v1.8.15-be.N`. `docs/reports/field-test-v1.8.14-results.md` would need a note
   that its "v1.8.14" means the bleeding-edge line.
2. v1.9.0 for this hotfix. A minor bump for a one-file security fix misstates its size.
3. Teach the tooling 4-part versions. This is the field-compatibility problem above, so it is rejected.

**Recommendation: option 1.** It is the only number the existing tooling and consumers handle correctly. The
confusion it causes is limited to the `-be` tag names, and pre-release tags are excluded from every latest-release
lookup (`RELEASE_PRERELEASE_TAG_EXCLUDE`). Because the number is open, the branch has a neutral name. Once a number
is chosen, rename it: `git branch -m hotfix/pending-T-4489 hotfix/v1.8.14`.

## Contents

The branch is `hotfix/pending-T-4489` in the main repo, at **4ce3b23ec**:

| Commit | What |
|---|---|
| 66baa6060 | Code, tests and vendored copies from bleeding-edge **22bf75833** (T-4485), with no task file. Applied with `git apply --3way --index`, cleanly. 430abcc8f is task-file only (AC tick) and is not carried. |
| 4ce3b23ec | Tests only. `t4485_git_output_quoting.bats` test 11 calls `shell_write_scan.scan(c, P)` instead of `scan(c, P, P)`. The third argument, `project_root`, was added by T-4336 (human-AC tick guard, bleeding-edge only, not part of this hotfix). The 2-line change is shown below. |

The diff from 6efec63df to 4ce3b23ec touches 5 files (+246 −6):

- `agents/context/lib/safe-commands.sh` (16 lines)
- `lib/shell_write_scan.py` (54 lines)
- their vendored copies, which are byte-identical to their sources
- the new test file

Relative to bleeding-edge HEAD:

- `safe-commands.sh` and `shell_write_scan.py` still differ by T-4115 (`fw task stale` read-only), T-4479 (write-scan
  herestrings) and T-4336. None of those are in this hotfix.
- `check-project-boundary.sh` is identical, because the hotfix does not touch it.

## Field shapes probed on this tree

The field test (msg f5a021db) ran on bleeding-edge 056573e34, not on this branch. Its shapes were therefore
re-probed here with `is_bash_safe_command`, with PROJECT_ROOT set to the clone:

| Command | v1.8.13 | hotfix |
|---|---|---|
| `git diff "--output=/tmp/o"` / `'--output=…'` / `\--output=…` | SAFE | gated |
| `git diff $O` / `${O:-x}` | SAFE | gated |
| `git diff $'--output=F'` / `{--output=F,}` | SAFE | gated |
| `for o in --output=/tmp/o; do git diff $o; done` | SAFE | gated |
| `git diff --output="/tmp/o"`, `--outp=`, `git -C /tmp diff --output=` | gated | gated |
| `git diff --stat`, `git log --oneline -5`, `git show HEAD --stat`, `git diff --name-only HEAD~3` | SAFE | SAFE |

8 bypass shapes are SAFE on v1.8.13 and all 8 are gated on the hotfix. None of the read-only commands became a false
positive.

## Targeted comparison (each file alone, clean env)

**Method.** Each file ran on its own with `env -u PROJECT_ROOT -u CLAUDECODE -u CLAUDE_PROJECT_DIR -u _FW_PAYLOAD_CWD`
and `FRAMEWORK_ROOT=<clone>`, with the cwd at the clone. Runs were sequential, hotfix first, then v1.8.13.

`FRAMEWORK_ROOT` is set explicitly, not unset. On v1.8.13, `human_ac_tick_guard` and `t2954` default to the literal
main-checkout path (fixed later by T-4483). If it were unset, they would test the main checkout instead of the clone.
On base, the new t4485 file was copied into the clone, so it tests v1.8.13 code. Logs are in
`.context/scratch/t4489/logs/`.

The set is 27 files:

- **safe-commands:** context_safe_commands, safe_commands_chain, safe_commands_env_prefix,
  t3096_safe_commands_wrappers, t4264, test_safe_commands_git_commit.
- **`shell_write_scan` consumers (it has no suite of its own):** human_ac_tick_guard, t2954, t3695, t3746.
- **boundary:** check_project_boundary, t2920, t3076, t3768, t4114, t4126, t4149, t4284, t4343, t4344, t4395,
  test_boundary_hook_arguments.
- **named:** t4367, t4396, t4408, t4409, t4485.

| File | hotfix | v1.8.13 |
|---|---|---|
| 26 files: every file in the set except t4485 | all green (575/575) | all green, same counts |
| t4485_git_output_quoting, as first carried (66baa6060) | **red 10/11**, 3/3 runs, test 11 only | red 2/11, 3/3 runs (tests 1-7, 9, 11) |
| t4485_git_output_quoting, branch version (4ce3b23ec) | **green 11/11**, 3/3 runs | red 2/11, 3/3 runs, same 9 tests |

**Attribution of the one hotfix-only red.** Test 11 failed with `TypeError: scan() takes from 1 to 2 positional
arguments but 3 were given`. This is a test-API mismatch: the test was written against bleeding-edge, where T-4336
added `project_root`. It is not a defect in the hotfix code. The tests-only commit 4ce3b23ec removes it. After that
change, every scanner assertion in test 11 holds on the hotfix: 7 expansion shapes hit, `git diff HEAD` stays clean,
and `git_output_risk` behaves as expected. On v1.8.13 the regression file fails 9 of 11, so the fix is what it pins.

This was not the 95-minute full suite. Under the brief, the comparison is limited to the files that exercise the 2
changed modules.

**Hotfix-attributed failures: 0**

## Released 2026-10-20 as v1.8.14

master 6efec63df -> 2328ae76b, tag v1.8.14, GitHub release; merged back into bleeding-edge (8e9465cfb); operator approval "go with v1.8.14 for the hotfix and ship it".

## Post-release field results

| Project | Result | Evidence |
|---|---|---|
| 010-termlink | **WORKS** | msg 7b7b72e2: on v1.8.14 (their 766b1324d); their preserved safe-commands.sh merged clean with T-4485; "--output=x", --out\put=x, $o and --outp=x gated, plain git log SAFE |
| ring20-dashboard | **WORKS** | msg 4a13dc90: v1.8.13 -> v1.8.14 from a full clone of the tag, about 11 min, exit 0, no rollback; 37 local patches all applied strict, zero fuzz; doctor 0 FAIL before and after; fast lane 6 -> 7 failed, the extra one (test_t1826) passed when re-run alone (flake), no new failures; the installed safe-commands gates all 11 lines of their T-4367/T-4485 probe (7 SAFE on v1.8.13) |
| dimitri-mint-dev | **WORKS** (via v1.8.15-be.1) | msg ae5a4e7f: T-4485 gated (plain, abbreviated, quoted, through a variable), plain git log read-only; doctor 0 failures; findings filed as T-4498/T-4499/T-4500 |
