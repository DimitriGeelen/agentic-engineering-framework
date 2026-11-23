# Reviewer evidence — T-5301 AC#1 (REFUSED: no verdict)

- dispatch: `judge-t-5301-r5-opencode-c9b8437354ba`
- worker kind: `opencode`
- seat: `opencode`
- result.jsonl sha256: `094c3d6c75a81df462ae524087f07eaaa308f921027346c7ff1eb47bfb1cc4b7`
- result.md sha256: `986c2b476ae8e578fd3a777db03289b74f72a864eba9af2bb704f4c3013a267f`

## verdict/1 check: refused

not a valid verdict/1 vote for AC1:
- AC1: Evidence '"_emit_user_command() { _emit_user_command_in \\"${PROJECT_RO' is neither a "verbatim quote" nor `image: <file> region x,y,w,h` / `image: <file> selector <css>`
- AC1: Location '.context/working/judge-evidence/T-5301/pr116-testhost.log:1,' is not `<path>:<line>`, `<image> region x,y,w,h`, `<image> selector <css>` or `command: <cmd>`
- AC1: Location 'lib/fw-command.sh:65-66; bin/fw:3433' is not `<path>:<line>`, `<image> region x,y,w,h`, `<image> selector <css>` or `command: <cmd>`
- AC1: Location 'lib/fw-command.sh:29-34,13' is not `<path>:<line>`, `<image> region x,y,w,h`, `<image> selector <css>` or `command: <cmd>`

## The worker's full output (result.md)

```
PR description and diff read. Now I'll verify the export at the reviewed revision: the two remedy lines in `bin/fw`, the vendored copy's identity, and the `_emit_user_command` helper.
`bin/fw:3439,3444` still print the defective remedies, and the two copies are byte-identical. Now check the diff context matches, `_emit_user_command` exists, and read the test-host log.
Diff context matches the export exactly, and `_emit_user_command` is an existing helper (bin/fw:1745 fallback, lib/fw-command.sh) already used at doctor time (bin/fw:3433, 3451). Now the test-host log:
All 3 #68 tests passed in the changed phase of run `20261122T184536Z-pr-116-cdbd`. Final verification: blob hash of the export vs the diff's index line, secrets scan, `do_doctor` bounds, and the helper's behavior.
One last look at the `_emit_user_command` definition to confirm it only prints (never executes):
All verification is complete. Every step of the criterion checked out:

- **Diff scope**: exactly 3 file sections — identical hunks in `bin/fw` and `.agentic-framework/bin/fw` (both `index 4cf1d2028..d51c1f8f5`, and the export copies are byte-identical per `cmp`), each replacing exactly the two `Run: bin/watchtower.sh …` lines with `Run: $(_emit_user_command "watchtower restart")`, plus the new `tests/unit/issue68_doctor_watchtower_remedy.bats` (+36 lines). No other changes; secrets-pattern scan clean.
- **No new doctor-time commands**: `_emit_user_command` (lib/fw-command.sh:65) is printf-only and already used inside `do_doctor` at the reviewed revision (bin/fw:3433, 3451).
- **Test host**: run `20261122T184536Z-pr-116-cdbd` passed, changed phase `1..3` with all 3 #68 tests ok, lint rc=0.
- **Reviewed revision**: bin/fw:3439/3444 still print the defective remedies with context matching the hunk line-for-line; the `exec "$FRAMEWORK_ROOT/bin/watchtower.sh"` calls at 9369+ are the router outside `do_doctor`, untouched and correct.

```
===VERDICT===
format: verdict/1
task: T-5301
reviewer: opencode (rung-5-panel seat)
round: 1
vote: green
failed: []

## AC1 Outside PR #116 is fit to merge into bleeding-edge (CONTRIBUTING step 6 read review)
Vote: green
Evidence: "diff --git a/bin/fw b/bin/fw" ... "-                echo -e \"         Run: bin/watchtower.sh restart\"" / "+                echo -e \"         Run: $(_emit_user_command \"watchtower restart\")\"" and "-            echo -e \"         Run: bin/watchtower.sh stop && bin/watchtower.sh start\"" / "+            echo -e \"         Run: $(_emit_user_command \"watchtower restart\")\""
Location: .context/working/judge-evidence/T-5301/pr116.diff:20-38
Evidence: "diff --git a/tests/unit/issue68_doctor_watchtower_remedy.bats b/tests/unit/issue68_doctor_watchtower_remedy.bats" / "new file mode 100644"
Location: .context/working/judge-evidence/T-5301/pr116.diff:39-43
Evidence: "                echo -e \"         Run: bin/watchtower.sh restart\"" and "            echo -e \"         Run: bin/watchtower.sh stop && bin/watchtower.sh start\""
Location: bin/fw:3439-3444
Evidence: "cmp bin/fw .agentic-framework/bin/fw && echo IDENTICAL" -> "IDENTICAL"; both file headers in the diff read "index 4cf1d2028..d51c1f8f5 100755"
Location: command: cmp bin/fw .agentic-framework/bin/fw
Evidence: "fw testhost run --pr 116: run 20261122T184536Z-pr-116-cdbd: passed" and "1..3 / ok 1 #68: do_doctor exists (anchor for the checks below) / ok 2 #68: no doctor remedy points at bin/watchtower.sh / ok 3 #68: stale-triple and endpoint-down remedies go through _emit_user_command" and "== testhost guest: done rc=0 =="
Location: .context/working/judge-evidence/T-5301/pr116-testhost.log:1,87-92
Evidence: "_emit_user_command() { _emit_user_command_in \"${PROJECT_ROOT:-$PWD}\" \"${1:-}\" }" with body "printf 'cd %s && %s %s\n' ..." (printf-only, never executes) and "Run: $(_emit_user_command \"watchtower restart\")" already present in the log-fd branch
Location: lib/fw-command.sh:65-66; bin/fw:3433
Evidence: "[ -f \"$root/FRAMEWORK.md\" ] && [ -f \"$root/bin/fw\" ] ... else echo \".agentic-framework/bin/fw\"" and header rule "Never bin/watchtower.sh: Watchtower is `<fw path> watchtower ...`"
Location: lib/fw-command.sh:29-34,13
Rule: criterion: "the diff changes only the two Watchtower remedy lines in bin/fw and its identical vendored copy ... to Run: $(_emit_user_command \"watchtower restart\"), and adds tests/unit/issue68_doctor_watchtower_remedy.bats ... no other changes, no secrets and no new commands run at doctor time ... the two lines it replaces still print bin/watchtower.sh ... its test pins the defect, and it is safe to merge"
Conclusion: The diff (read in full, 80 lines, exactly 3 file sections) makes precisely those two-line replacements in both byte-identical copies plus the new bats file, the replaced defective lines are still present at bin/fw:3439/3444 at the reviewed revision with context matching the hunk line-for-line, the remedy now goes through the existing printf-only _emit_user_command helper already used elsewhere in do_doctor (so nothing new executes at doctor time), a secrets-pattern scan of the diff is clean, the isolated testhost run 20261122T184536Z-pr-116-cdbd passed including all 3 #68 tests with the lint phase rc=0, and the bats suite pins the defect (test 2 fails on any `Run: bin/watchtower.sh` in the do_doctor body, test 3 pins the new literal after both WARN anchors, test 1 anchors the extraction), so the PR does exactly what #68 needs and nothing else and is fit to merge.

## Counter-search
Searched: all 80 lines of pr116.diff for any file section, added line, mode change or secret pattern beyond the three described (none found); every "bin/watchtower.sh" occurrence in bin/fw (only 3439/3444 are user-printed Run: remedies; 9369-9383 are exec calls in the fw watchtower router outside do_doctor, using FRAMEWORK_ROOT, untouched); whether _emit_user_command could execute or had side effects (printf-only, lib/fw-command.sh:53-66, with a fallback at bin/fw:1745); whether the diff's base blob hash matches the export (it does not: diff index 4cf1d2028 vs git hash-object 0a1bfc221, expected since the PR bases on bleeding-edge bbcff3cfd while this export is revision 14884992b — but every removed and context line matches the export exactly at the same line numbers, which is the comparison criterion step 4 directs); whether the bats test could pass vacuously (test 1 anchors do_doctor at bin/fw:2075 with body to 3900 containing the changed lines, and test 3 requires the new literal to be present, so a broken extraction fails both)
Found: nothing against the green; the only asymmetry (PR base bbcff3cfd vs export revision) does not affect application at the reviewed revision

## Change-my-mind
A fourth file section or any added line in pr116.diff beyond the two remedy lines per fw copy and the bats file, a secret-shaped string in the diff, or an execution path where _emit_user_command is invoked at doctor time but defined nowhere (neither lib/fw-command.sh nor the bin/fw:1745 fallback).
===END===
```

Summary: 1 green, 0 amber, 0 red, 0 escalate, 0 not-evaluated.
```
