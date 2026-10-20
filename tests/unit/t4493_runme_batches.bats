#!/usr/bin/env bats
# T-4493: runme job queue slice 3 of the T-4470 GO — ordered batches chosen by the
# operator (typed order or x), refused up front if any chosen job is not ready, stopped at
# the first failing job. A queue 'y' stays consent, never authorisation.

setup() {
    LIB="$BATS_TEST_DIRNAME/../../lib/runme.sh"
    TMPP="$(mktemp -d)"
    FW="$BATS_TEST_TMPDIR/fw-runme"
    printf '#!/bin/bash\nexport PROJECT_ROOT=%q\n[ "$1" = runme ] && shift\nsource %q\nrunme_main "$@"\n' "$TMPP" "$LIB" > "$FW"
    chmod +x "$FW"
    ANS="$BATS_TEST_TMPDIR/answers"
    export FW_RUNME_TEST=1 FW_RUNME_TEST_ANSWERS="$ANS"
}

teardown() { chmod -R u+w "$TMPP" 2>/dev/null; rm -rf "$TMPP"; }

manifest() { printf '%s\n' "$2" > "$BATS_TEST_TMPDIR/$1.json"; "$FW" runme job new "$1" --manifest "$BATS_TEST_TMPDIR/$1.json"; }
answers() { printf '%s\n' "$@" > "$ANS"; }
# a job whose single step appends its own letter to $TMPP/order
mk() { manifest "$1" '{"title":"job '"$1"'","steps":[{"title":"s","sh":"echo '"$1"' >> '"$TMPP"'/order"}]}'; "$FW" runme job dry-run "$1" >/dev/null; }
mk3() { mk a; mk b; mk c; }

@test "typed order 3,1,2 runs the jobs in exactly that order" {
    mk3
    answers "3,1,2" y y y
    run "$FW" runme queue
    [ "$status" -eq 0 ]
    [ "$(tr '\n' ' ' < "$TMPP/order")" = "c a b " ]
    echo "$output" | grep -q "DONE: batch of 3 job(s) completed in order"
}

@test "x runs every pending job in menu order" {
    mk3
    answers x y y y
    run "$FW" runme queue
    [ "$status" -eq 0 ]
    [ "$(tr '\n' ' ' < "$TMPP/order")" = "a b c " ]
}

@test "a single number still runs just that job" {
    mk3
    answers 2 y
    run "$FW" runme queue
    [ "$status" -eq 0 ]
    [ "$(cat "$TMPP/order")" = "b" ]
}

@test "duplicate, out-of-range and garbage choices run nothing" {
    mk3
    for bad in "1,1" "1,4" "0" "1,x" "a b" ""; do
        answers "$bad" y y y
        run "$FW" runme queue
        [ "$status" -eq 1 ]
        echo "$output" | grep -q "STOPPED: no valid choice"
        [ ! -e "$TMPP/order" ]
    done
}

@test "up-front refusal: one NOT REHEARSED job in the batch means nothing runs" {
    mk a; mk b
    manifest c '{"title":"never rehearsed","steps":[{"title":"s","sh":"echo c >> '"$TMPP"'/order"}]}'
    answers "1,2,3" y y y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "REFUSED: the batch holds job(s) that are not ready; nothing run"
    echo "$output" | grep -q "003-c: NOT REHEARSED"
    [ ! -e "$TMPP/order" ]
    [ -z "$(ls "$TMPP"/.context/runme/jobs/*/run-*.log 2>/dev/null)" ]
}

@test "up-front refusal: a job edited after its dry run (CHANGED) blocks the batch" {
    mk3
    printf '%s\n' '{"title":"edited","steps":[{"title":"s","sh":"echo EVIL >> '"$TMPP"'/order"}]}' > "$TMPP/.context/runme/jobs/002-b/job.json"
    answers "x" y y y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "002-b: CHANGED since dry-run"
    [ ! -e "$TMPP/order" ]
}

@test "a retired job is not offered, so x never includes it" {
    mk3
    "$FW" runme job retire b --reason "obsolete"
    answers x y y
    run "$FW" runme queue
    [ "$status" -eq 0 ]
    [ "$(tr '\n' ' ' < "$TMPP/order")" = "a c " ]
}

@test "a job retired after the menu was drawn is refused up front" {
    mk3
    export BATS_TEST_DIRNAME
    python3 - "$TMPP" <<'PY'
import sys, os
sys.path.insert(0, os.environ["BATS_TEST_DIRNAME"] + "/../../lib")
os.environ["PROJECT_ROOT"] = sys.argv[1]
import runme_queue as q
jobs = q.pending()
open(os.path.join(jobs[1], "retired"), "w").close()
class A:  # must never be asked: refusal comes first
    def ask(self, *a): raise SystemExit("asked")
    def confirm(self, *a): raise SystemExit("asked")
rc = q.run_batch(jobs, A())
assert rc == 1, rc
assert not os.path.exists(os.path.join(sys.argv[1], "order"))
PY
}

@test "stop at the first failing job: later chosen jobs are named and not run" {
    mk a
    manifest f '{"title":"fails","steps":[{"title":"s","sh":"echo f >> '"$TMPP"'/order; exit 3"}]}'
    "$FW" runme job dry-run f >/dev/null
    mk c
    answers "1,2,3" y y y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    [ "$(tr '\n' ' ' < "$TMPP/order")" = "a f " ]
    echo "$output" | grep -q "STOPPED: batch stopped at 002-f; not run: 003-c"
}

@test "stop when the operator declines a step: the rest of the batch does not run" {
    mk3
    answers "1,2,3" y n y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    [ "$(cat "$TMPP/order")" = "a" ]
    echo "$output" | grep -q "not run: 003-c"
}

@test "a batch 'y' is consent, not authorisation: a Tier 0 step holds the batch" {
    git -C "$TMPP" init -q
    mk a
    manifest t0 '{"title":"force","steps":[{"title":"push","sh":"touch '"$TMPP"'/t0-ran; git push --force origin master"}]}'
    "$FW" runme job dry-run t0 >/dev/null
    mk c
    answers "1,2,3" y y y
    run "$FW" runme queue
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "held by the Tier 0 gate; a queue 'y' is not an approval"
    [ ! -e "$TMPP/t0-ran" ]
    [ "$(cat "$TMPP/order")" = "a" ]
}
