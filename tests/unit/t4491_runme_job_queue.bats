#!/usr/bin/env bats
# T-4491: runme job queue, slice 1 of the T-4470 GO. Each of the six review findings in
# docs/reports/T-4470-runme-job-queue.md §6 has a test here proving it cannot happen in
# AEF's version (all six are red against a launcher that sources the job into its own
# shell), plus prerequisite 5 (the queue is never a Tier 0 authorisation) and 832's
# field lessons from addendum 1 (readiness probe, staged index named, 80-column pty,
# names not row numbers).

setup() {
    LIB="$BATS_TEST_DIRNAME/../../lib/runme.sh"
    TMPP="$(mktemp -d)"
    FW="$BATS_TEST_TMPDIR/fw-runme"
    printf '#!/bin/bash\nexport PROJECT_ROOT=%q\n[ "$1" = runme ] && shift\nsource %q\nrunme_main "$@"\n' "$TMPP" "$LIB" > "$FW"
    chmod +x "$FW"
    JOBS="$TMPP/.context/runme/jobs"
    ANS="$BATS_TEST_TMPDIR/answers"
    export FW_RUNME_TEST=1 FW_RUNME_TEST_ANSWERS="$ANS"
}

teardown() { chmod -R u+w "$TMPP" 2>/dev/null; rm -rf "$TMPP"; }

manifest() { printf '%s\n' "$2" > "$BATS_TEST_TMPDIR/$1.json"; "$FW" runme job new "$1" --manifest "$BATS_TEST_TMPDIR/$1.json"; }
answers() { printf '%s\n' "$@" > "$ANS"; }

@test "bin/fw routes runme job and runme queue to the queue" {
    run "$BATS_TEST_DIRNAME/../../bin/fw" runme job list --help
    [ "$status" -eq 0 ]
    run "$BATS_TEST_DIRNAME/../../bin/fw" runme bogus
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "job|queue"
}

# ---------------------------------------------------------------- finding 1
@test "F1: job code cannot reach confirm/ask/fail — a job redefining them still needs the operator's y" {
    manifest f1 '{"title":"redefine the launcher",
      "helpers":{"confirm":"return 0","ask":"REPLY=y","fail":"return 0"},
      "steps":[{"title":"export them","sh":"export -f confirm ask fail; touch '"$TMPP"'/f1-ran"}]}'
    "$FW" runme job dry-run f1
    answers n
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "STOPPED: not confirmed; nothing run"
    [ ! -e "$TMPP/f1-ran" ]
}

@test "F1: a shell job.sh is never loaded — not listed, not sourced, not run" {
    mkdir -p "$JOBS/001-legacy"
    printf 'touch %s/sourced\nJOB_TITLE=x\nsteps() { :; }\n' "$TMPP" > "$JOBS/001-legacy/job.sh"
    run "$FW" runme job list --all
    echo "$output" | grep -q "no pending jobs"
    answers y
    run "$FW" runme queue
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Nothing to run"
    [ ! -e "$TMPP/sourced" ]
}

# ---------------------------------------------------------------- finding 2
@test "F2: writing, listing and dry-running a job executes nothing in any field" {
    manifest f2 '{"title":"$(touch '"$TMPP"'/p1) `touch '"$TMPP"'/p2`",
      "why":"$(touch '"$TMPP"'/p3)\nexec 3<'"$TMPP"'/p4",
      "helpers":{"h":"touch '"$TMPP"'/p5"},
      "steps":[{"title":"redirect","sh":"touch '"$TMPP"'/p6 > '"$TMPP"'/p7","probe":["touch","'"$TMPP"'/p8"]}]}'
    "$FW" runme job list
    "$FW" runme job list --all
    "$FW" runme job dry-run f2
    for n in 1 2 3 4 5 6 7 8; do [ ! -e "$TMPP/p$n" ]; done
}

# ---------------------------------------------------------------- finding 3
@test "F3: a preflight/checks block is refused; dry-run runs no step and no probe" {
    printf '{"title":"t","preflight":"touch x","steps":[{"title":"s","sh":"true"}]}' > "$BATS_TEST_TMPDIR/p.json"
    run "$FW" runme job new pf --manifest "$BATS_TEST_TMPDIR/p.json"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "unknown key(s) \['preflight'\]"
    printf '{"title":"t","steps":[{"title":"s","sh":"true","check":"true"}]}' > "$BATS_TEST_TMPDIR/c.json"
    run "$FW" runme job new ck --manifest "$BATS_TEST_TMPDIR/c.json"
    [ "$status" -eq 2 ]
    manifest f3 '{"title":"t","steps":[{"title":"s","argv":["touch","'"$TMPP"'/step"],"probe":["touch","'"$TMPP"'/probe"]}]}'
    run "$FW" runme job dry-run f3
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Nothing was executed"
    [ ! -e "$TMPP/step" ]
    [ ! -e "$TMPP/probe" ]
}

# ---------------------------------------------------------------- finding 4
@test "F4: the operator confirms the resolved command — helper body and full argv shown before the prompt" {
    manifest f4 '{"title":"Short title","helpers":{"say_it":"echo HELPER-BODY-MARKER"},
      "steps":[{"title":"one","argv":["printf","%s\\n","arg with space"]},{"title":"two","sh":"say_it"}]}'
    "$FW" runme job dry-run f4
    answers n
    run "$FW" runme queue
    plan=$(printf '%s\n' "$output" | sed -n '1,/exactly as shown above/p')
    echo "$plan" | grep -q "HELPER-BODY-MARKER"
    echo "$plan" | grep -qF "printf '%s\\n' 'arg with space'"
    echo "$plan" | grep -q "say_it() {"
    echo "$output" | grep -q "Run step 1/2 of 001-f4 exactly as shown above"
}

@test "F4: a control character (screen escape) in any shown field is refused" {
    printf '{"title":"ok\\u001b[2Jhidden","steps":[{"title":"s","sh":"true"}]}' > "$BATS_TEST_TMPDIR/e.json"
    run "$FW" runme job new esc --manifest "$BATS_TEST_TMPDIR/e.json"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "control character"
}

# ---------------------------------------------------------------- finding 5
@test "F5: changing a helper after the dry run makes the job CHANGED and it does not run" {
    manifest f5 '{"title":"t","helpers":{"h":"true"},"steps":[{"title":"s","sh":"h; touch '"$TMPP"'/f5-ran"}]}'
    "$FW" runme job dry-run f5
    run "$FW" runme job list
    echo "$output" | grep -q "\[ready;"
    chmod u+w "$JOBS/001-f5/job.json"
    sed -i 's/"true"/"echo swapped"/' "$JOBS/001-f5/job.json"
    run "$FW" runme job list
    echo "$output" | grep -q "CHANGED since dry-run"
    answers y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "CHANGED since dry-run; nothing run"
    [ ! -e "$TMPP/f5-ran" ]
}

# ---------------------------------------------------------------- finding 6
@test "F6: scripted answers need FW_RUNME_TEST=1" {
    manifest f6 '{"title":"t","steps":[{"title":"s","argv":["touch","'"$TMPP"'/f6-ran"]}]}'
    "$FW" runme job dry-run f6
    answers y
    run env -u FW_RUNME_TEST "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "only with FW_RUNME_TEST=1"
    [ ! -e "$TMPP/f6-ran" ]
}

@test "F6: scripted answers are refused when steps would run in a real project" {
    : > "$TMPP/.framework.yaml"
    manifest f6r '{"title":"t","steps":[{"title":"s","argv":["touch","'"$TMPP"'/f6r-ran"]}]}'
    "$FW" runme job dry-run f6r
    answers y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "refused on a real project"
    [ ! -e "$TMPP/f6r-ran" ]
}

@test "F6: under CLAUDECODE=1 the queue refuses without the test runner" {
    manifest f6c '{"title":"t","steps":[{"title":"s","argv":["touch","'"$TMPP"'/f6c-ran"]}]}'
    "$FW" runme job dry-run f6c
    run env -u FW_RUNME_TEST -u FW_RUNME_TEST_ANSWERS CLAUDECODE=1 "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "the queue is the operator's command"
    [ ! -e "$TMPP/f6c-ran" ]
}

# ---------------------------------------------------------------- prerequisite 5
@test "P5: a queued Tier 0 step is held by check-tier0, the queue y is not an approval" {
    git -C "$TMPP" init -q
    manifest t0 '{"title":"force","steps":[{"title":"ok first","argv":["touch","'"$TMPP"'/t0-first"]},
      {"title":"push","sh":"touch '"$TMPP"'/t0-ran; git push --force origin master"}]}'
    "$FW" runme job dry-run t0
    answers y y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    [ -e "$TMPP/t0-first" ]
    [ ! -e "$TMPP/t0-ran" ]
    echo "$output" | grep -q "TIER 0"
    echo "$output" | grep -q "held by the Tier 0 gate; a queue 'y' is not an approval"
    [ ! -e "$JOBS/001-t0/done" ]
}

# ---------------------------------------------------------------- lifecycle and menu
@test "lifecycle: NOT REHEARSED is refused; a done job never runs again; a retired job leaves the queue" {
    manifest a '{"title":"Alpha","steps":[{"title":"s","sh":"echo run >> '"$TMPP"'/a-count"}]}'
    manifest b '{"title":"Beta","steps":[{"title":"s","sh":"true"}]}'
    run "$FW" runme job list
    echo "$output" | grep -q "001-a — Alpha  \[NOT REHEARSED; last: never run\]"
    answers 1
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "NOT REHEARSED; nothing run"
    "$FW" runme job dry-run a
    "$FW" runme job retire b --reason "superseded by 003"
    answers y
    run "$FW" runme queue
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DONE: 001-a"
    [ "$(wc -l < "$TMPP/a-count")" -eq 1 ]
    run "$FW" runme queue
    echo "$output" | grep -q "Nothing to run"
    [ "$(wc -l < "$TMPP/a-count")" -eq 1 ]
    run "$FW" runme job list --all
    echo "$output" | grep -q "001-a  \[done\]"
    echo "$output" | grep -q "002-b  \[RETIRED: superseded by 003\]"
}

@test "menu: last outcome records a stopped run with its reason" {
    manifest s '{"title":"Fails","steps":[{"title":"s","sh":"exit 3"}]}'
    "$FW" runme job dry-run s
    answers y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    run "$FW" runme job list
    echo "$output" | grep -q "last: STOPPED .*step 1/1 failed (rc=3)"
}

@test "a step runs in a child process with no inherited shell functions and no test switch" {
    manifest env '{"title":"env","steps":[{"title":"s","sh":"declare -F > '"$TMPP"'/funcs; env > '"$TMPP"'/envs"}]}'
    "$FW" runme job dry-run env
    answers y
    sneaky() { :; }; export -f sneaky
    run "$FW" runme queue
    [ "$status" -eq 0 ]
    ! grep -q sneaky "$TMPP/funcs" || false
    ! grep -q "^FW_RUNME_TEST" "$TMPP/envs" || false
}

# ---------------------------------------------------------------- 832 addendum 1
@test "addendum §3: readiness probes are asked for, run, and shown before the job is confirmed; a failing probe stops it" {
    manifest pr '{"title":"t","steps":[{"title":"s","argv":["touch","'"$TMPP"'/pr-ran"],"probe":["sh","-c","echo READY-PROBE-OUT; exit 4"]}]}'
    "$FW" runme job dry-run pr
    answers y y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "READY-PROBE-OUT"
    echo "$output" | grep -q "FAIL  probe for step 1 (rc=4)"
    echo "$output" | grep -q "readiness probe failed"
    [ ! -e "$TMPP/pr-ran" ]
}

@test "addendum §4: a job that leaves staged changes is named, then and at the next run" {
    git -C "$TMPP" init -q
    manifest st '{"title":"stages","steps":[{"title":"s","sh":"echo x > f; git add f"}]}'
    manifest nx '{"title":"next","steps":[{"title":"s","sh":"true"}]}'
    "$FW" runme job dry-run st
    "$FW" runme job dry-run nx
    answers 1 y
    run "$FW" runme queue
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "NOTE: 001-st left 1 staged path(s) in the git index: f"
    answers y
    run "$FW" runme queue
    echo "$output" | grep -q "staged path(s) (f), left by job 001-st"
}

@test "addendum §1-2: on a real 80-column pty the menu lines fit and the choice is shown by name" {
    long=$(printf 'very long title %.0s' $(seq 1 15))
    manifest one '{"title":"'"$long"'","steps":[{"title":"s","sh":"true"}]}'
    manifest two '{"title":"'"$long"'","steps":[{"title":"s","argv":["touch","'"$TMPP"'/two-ran"]}]}'
    "$FW" runme job dry-run one
    "$FW" runme job dry-run two
    run env -u FW_RUNME_TEST -u FW_RUNME_TEST_ANSWERS -u CLAUDECODE python3 - "$FW" <<'PY'
import os, pty, sys, time, struct, fcntl, termios, select
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], [sys.argv[1], "runme", "queue"])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
buf, sent = b"", []
deadline = time.time() + 20
while time.time() < deadline:
    r, _, _ = select.select([fd], [], [], 0.2)
    if r:
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        buf += chunk
    if b"Which job?" in buf and "pick" not in sent:
        time.sleep(0.3); os.write(fd, b"2\n"); sent.append("pick")
    if b"exactly as shown above" in buf and "go" not in sent:
        time.sleep(0.3); os.write(fd, b"y\n"); sent.append("go")
os.waitpid(pid, 0)
sys.stdout.write(buf.decode("utf-8", "replace"))
PY
    echo "$output" | grep -q "Chosen: 002-two"
    menu=$(printf '%s\n' "$output" | tr -d '\r' | grep -E '^  [0-9]+\. 00')
    [ -n "$menu" ]
    while IFS= read -r ln; do [ "${#ln}" -le 80 ]; done <<< "$menu"
    [ -e "$TMPP/two-ran" ]
}
