===VERDICT===
format: verdict/1
task: T-5301
reviewer: reviewer-judge-t-5301-r5-claude-code-e6107a54724a:claude-code
round: 1
vote: green
failed: []

## AC1 Outside PR #116 is fit to merge into bleeding-edge (CONTRIBUTING step 6 read review)
Vote: green
Evidence: "Run: bin/watchtower.sh restart"
Location: bin/fw:3439
Evidence: "Run: bin/watchtower.sh stop && bin/watchtower.sh start"
Location: bin/fw:3444
Evidence: "Run: $(_emit_user_command"
Location: .context/working/judge-evidence/T-5301/pr116.diff:10
Evidence: "3444c3444"
Location: command: diff <(git show 14884992b:bin/fw) <bin/fw with PR diff applied via git apply --cached in a temp index>
Evidence: "diff --git a/tests/unit/issue68_doctor_watchtower_remedy.bats"
Location: .context/working/judge-evidence/T-5301/pr116.diff:39
Evidence: "not ok 2 #68: no doctor remedy points at bin/watchtower.sh"
Location: command: bats tests/unit/issue68_doctor_watchtower_remedy.bats (bin/fw = 14884992b:bin/fw, the base)
Evidence: "ok 2 #68: no doctor remedy points at bin/watchtower.sh"
Location: .context/working/judge-evidence/T-5301/pr116-testhost.log:89
Evidence: "run 20261122T184536Z-pr-116-cdbd: passed"
Location: .context/working/judge-evidence/T-5301/pr116-testhost.log:1
Evidence: "_emit_user_command() {"
Location: lib/fw-command.sh:65
Evidence: "post-image root == vendored: identical"
Location: command: git apply --cached (temp index) then cmp of :bin/fw against :.agentic-framework/bin/fw
Rule: criterion: "The change does exactly what #68 needs and nothing else, its test pins the defect, and it is safe to merge."
Conclusion: The diff changes exactly the two stale `bin/watchtower.sh` remedy lines in both identical copies plus one new test file, the test fails on the base and passes with the change, the helper it calls is a side-effect-free printf, and the framework's own testhost run passed, so the clause holds.

## Counter-search
Searched: other `bin/watchtower.sh` remedy prints inside the do_doctor body of bin/fw (awk-extracted body) and any further hunks in the PR diff beyond the two fw copies and the new test file.
Found: do_doctor's only `bin/watchtower.sh` prints were bin/fw:3439 and bin/fw:3444 (the two lines the PR replaces); the matches at bin/fw:3426-3428 are `$FRAMEWORK_ROOT/lib/watchtower.sh`, not remedies. The PR has no other hunks. Gaps found, none blocking: (a) the bats negative check greps only the literal `Run: bin/watchtower.sh`, so it pins less than the PR body claims ("for the whole do_doctor body"); (b) the PR's unchecked items (`fw audit`, `fw doctor` as a whole, full unit suite) were not run, and the testhost log I can read starts mid-output, so I could not confirm the full suite; its lint and changed phases are visible and passed; (c) the dead-pid restart result in the PR body is the contributor's report, not in the testhost log, and I did not re-run it.

## Change-my-mind
A second `bin/watchtower.sh` remedy inside do_doctor, a failure of the full unit suite or the lint phase in pr116-testhost.log, or a dead-pid `fw watchtower restart` that exits non-zero when run in a vendored project.
===END===
Reviewer notes (not part of the vote): suggested non-blocking follow-up for the contributor: tighten the negative test to match any `bin/watchtower.sh` inside the do_doctor body, and run the full unit suite before merge.
