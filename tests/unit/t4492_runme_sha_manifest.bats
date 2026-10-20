#!/usr/bin/env bats
# T-4492: runme job queue slice 2 of the T-4470 GO — the sha manifest over job.json and
# every file a step reaches, rechecked immediately before each step (prerequisite 3,
# review finding 5: "the sha binds job.sh only"), and the per-step y/N confirm with
# typeahead discarded. Each finding-5 leg is red against slice 1, which hashed job.json
# only and confirmed once for the whole job.

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

# ---------------------------------------------------------------- finding 5
@test "F5: a script a step calls, edited after the dry run, is not run" {
    printf 'echo ORIGINAL > %s/out\n' "$TMPP" > "$TMPP/s.sh"
    manifest sc '{"title":"t","steps":[{"title":"s","argv":["bash","s.sh"]}]}'
    run "$FW" runme job dry-run sc
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "sha-bound files (rechecked just before this step): .*s.sh"
    printf 'echo SWAPPED > %s/out\n' "$TMPP" > "$TMPP/s.sh"
    run "$FW" runme job list
    echo "$output" | grep -q "CHANGED since dry-run"
    answers y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "changed since dry-run: s.sh changed"
    [ ! -e "$TMPP/out" ]
}

@test "F5: a script named in an sh step or a helper is bound too" {
    mkdir -p "$TMPP/tools"
    printf 'true\n' > "$TMPP/tools/a.sh"
    printf 'true\n' > "$TMPP/tools/b.sh"
    manifest hs '{"title":"t","helpers":{"h":"bash tools/b.sh"},
      "steps":[{"title":"s","sh":"cd . && ./tools/a.sh; h; touch '"$TMPP"'/hs-ran"}]}'
    run "$FW" runme job dry-run hs
    echo "$output" | grep -q "tools/a.sh"
    echo "$output" | grep -q "tools/b.sh"
    echo 'touch /dev/null' >> "$TMPP/tools/b.sh"
    answers y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "tools/b.sh changed"
    [ ! -e "$TMPP/hs-ran" ]
}

@test "F5: a declared script is bound; missing at dry-run is refused" {
    manifest dm '{"title":"t","scripts":["lib/sourced.sh"],"steps":[{"title":"s","sh":"true"}]}'
    run "$FW" runme job dry-run dm
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "declared script(s) not found: lib/sourced.sh"
    mkdir -p "$TMPP/lib"; echo 'X=1' > "$TMPP/lib/sourced.sh"
    "$FW" runme job dry-run dm
    echo 'X=2' > "$TMPP/lib/sourced.sh"
    answers y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "lib/sourced.sh changed"
}

@test "F5: a file an earlier step edits stops the later step that calls it, just before it" {
    printf 'echo ONE\n' > "$TMPP/later.sh"
    manifest ea '{"title":"t","steps":[
      {"title":"rewrite","sh":"echo \"touch '"$TMPP"'/evil\" > '"$TMPP"'/later.sh"},
      {"title":"call","argv":["bash","later.sh"]}]}'
    "$FW" runme job dry-run ea
    answers y y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "ok    step 1/2"
    echo "$output" | grep -q "STOPPED: step 2/2: later.sh changed since dry-run"
    [ ! -e "$TMPP/evil" ]
    [ ! -e "$JOBS/001-ea/done" ]
}

@test "F5: a file that appears after the dry run under a name a step uses is refused" {
    manifest nw '{"title":"t","steps":[{"title":"s","sh":"test -f ./maybe.sh && bash ./maybe.sh; true"}]}'
    "$FW" runme job dry-run nw
    printf 'touch %s/nw-ran\n' "$TMPP" > "$TMPP/maybe.sh"
    answers y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "maybe.sh is newly named"
    [ ! -e "$TMPP/nw-ran" ]
}

@test "the resolved executable of an argv command is bound" {
    mkdir -p "$TMPP/bin"
    printf '#!/bin/sh\ntrue\n' > "$TMPP/bin/mytool"; chmod +x "$TMPP/bin/mytool"
    export PATH="$TMPP/bin:$PATH"
    manifest ex '{"title":"t","steps":[{"title":"s","argv":["mytool"]}]}'
    run "$FW" runme job dry-run ex
    echo "$output" | grep -q "bin/mytool"
    printf '#!/bin/sh\ntouch %s/ex-ran\n' "$TMPP" > "$TMPP/bin/mytool"
    answers y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    [ ! -e "$TMPP/ex-ran" ]
}

@test "the manifest itself is bound: editing it makes the job not ready" {
    printf 'true\n' > "$TMPP/s.sh"
    manifest mm '{"title":"t","steps":[{"title":"s","argv":["bash","s.sh"]}]}'
    "$FW" runme job dry-run mm
    chmod u+w "$JOBS/001-mm/dryrun.manifest.json"
    sed -i 's/"[0-9a-f]\{64\}"/"0000"/' "$JOBS/001-mm/dryrun.manifest.json"
    run "$FW" runme job list
    echo "$output" | grep -q "NOT REHEARSED (no file manifest)"
    answers y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
}

@test "an output redirect target is not treated as a called file" {
    echo old > "$TMPP/out.txt"
    manifest rd '{"title":"t","steps":[{"title":"one","sh":"echo new > out.txt"},{"title":"two","sh":"echo again >> out.txt"}]}'
    run "$FW" runme job dry-run rd
    ! echo "$output" | grep -q "sha-bound files.*out.txt" || false
    answers y y
    run "$FW" runme queue
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DONE: 001-rd"
}

# ---------------------------------------------------------------- per-step confirm
@test "per-step confirm: each step asked just before it runs; n stops, later steps not run" {
    manifest ps '{"title":"t","steps":[{"title":"first","argv":["touch","'"$TMPP"'/ps1"]},
      {"title":"second","argv":["touch","'"$TMPP"'/ps2"]},{"title":"third","argv":["touch","'"$TMPP"'/ps3"]}]}'
    "$FW" runme job dry-run ps
    answers y n
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Run step 1/3 of 001-ps exactly as shown above"
    echo "$output" | grep -q "Run step 2/3 of 001-ps exactly as shown above"
    ! echo "$output" | grep -q "Run step 3/3" || false
    echo "$output" | grep -q "STOPPED: step 2/3 not confirmed; later steps not run"
    [ -e "$TMPP/ps1" ]
    [ ! -e "$TMPP/ps2" ]
    [ ! -e "$TMPP/ps3" ]
    # step 1 ran before step 2 was asked
    before=$(printf '%s\n' "$output" | sed -n '/ok    step 1\/3/,$p')
    echo "$before" | grep -q "Run step 2/3"
}

@test "per-step confirm: the step's resolved command is shown again right before its prompt" {
    manifest sh2 '{"title":"t","helpers":{"h":"echo HELPER-MARK"},
      "steps":[{"title":"a","argv":["true"]},{"title":"b","sh":"h"}]}'
    "$FW" runme job dry-run sh2
    answers y n
    run "$FW" runme queue
    seg=$(printf '%s\n' "$output" | sed -n '/^Step 2\/2: b/,/Run step 2\/2/p')
    echo "$seg" | grep -q "| h() {"
    echo "$seg" | grep -q "HELPER-MARK"
}

@test "per-step confirm: typeahead typed before the prompt on a real pty is discarded" {
    manifest ta '{"title":"t","steps":[{"title":"s","argv":["touch","'"$TMPP"'/ta-ran"]}]}'
    "$FW" runme job dry-run ta
    run env -u FW_RUNME_TEST -u FW_RUNME_TEST_ANSWERS -u CLAUDECODE python3 - "$FW" <<'PY'
import os, pty, sys, time, select
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], [sys.argv[1], "runme", "queue"])
os.write(fd, b"y\ny\ny\n")          # typed ahead, before any prompt exists
buf, sent = b"", False
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
    if b"[y/N]" in buf and not sent:
        time.sleep(0.5); os.write(fd, b"n\n"); sent = True
os.waitpid(pid, 0)
sys.stdout.write(buf.decode("utf-8", "replace"))
PY
    echo "$output" | grep -q "Run step 1/1 of 001-ta"
    echo "$output" | grep -q "STOPPED: not confirmed; nothing run"
    [ ! -e "$TMPP/ta-ran" ]
}

@test "a per-step y is consent, not authorisation: check-tier0 still holds a Tier 0 step" {
    git -C "$TMPP" init -q
    manifest t0 '{"title":"force","steps":[{"title":"push","sh":"touch '"$TMPP"'/t0-ran; git push --force origin master"}]}'
    "$FW" runme job dry-run t0
    answers y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "operator confirmed step 1/1"
    echo "$output" | grep -q "held by the Tier 0 gate; a queue 'y' is not an approval"
    [ ! -e "$TMPP/t0-ran" ]
}
