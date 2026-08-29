#!/usr/bin/env bats
# T-3213 (arc-012 IW-6) — CONFIRM the start event by running the wrapper.
#
# WHAT WAS MISSING, AND WHY IT MATTERED.
#
# T-3206 shipped a `start` event so the loop could say it is ARMED. T-3209 then
# taught `fw doctor` to attribute an absent ledger to "the supervisor predates the
# recorder" rather than blaming the operator. Both shipped on an explanation that
# fit every observation and that nobody had confirmed — while T-3209's own reason
# for existing is the distinction between a supported hypothesis and a measured
# fact. Neither suite ever invoked the wrapper: t3206 asserts the call site is
# defined and called, t3209 drives doctor's block against synthetic ledgers it
# writes itself. Both are correct and neither can see whether claude-fw, run,
# produces a line.
#
# That is the gap this file closes. Test 1 is the first execution of the shipped
# wrapper's recorder in the suite's history.
#
# WHY NOT "RESTART CLAUDE-FW". The wrapper in the hypothesis supervises the
# session doing the work; restarting it ends the observer. `_record_loop_event`
# resolves its log through `git rev-parse --show-toplevel`, so a scratch git repo
# gets its own ledger and the live one is untouched. Same shipped code path.
#
# AND WHY THE REAL LEDGER IS NEVER WRITTEN. Pointing this experiment at the
# project root would create the very file whose absence is the evidence, and make
# doctor report ARMED for a wrapper supervising nothing — manufacturing the exact
# false green arc-012 exists to kill. Every run below is confined to BATS_TEST_TMPDIR.
#
# `! cmd` at statement position is INERT in bats (T-3199, L-628) — the -e setting
# is ignored for any command preceded by `!`, so a failing negation passes. This
# file uses the sibling t3209 idiom `if cmd; then false; fi` throughout.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FW="$REPO_ROOT/bin/fw"
    WRAPPER="$REPO_ROOT/bin/claude-fw"
    TMP="$BATS_TEST_TMPDIR/t3213"
    mkdir -p "$TMP/bin" "$TMP/proj/.context/working"
}

# A scratch git repo — _record_loop_event resolves its log via git toplevel.
scratch_repo() {
    local d="$TMP/scratch"
    mkdir -p "$d/.context/working"
    git -C "$d" init -q . 2>/dev/null
    git -C "$d" config user.email t@t
    git -C "$d" config user.name t
    printf '%s\n' "$d"
}

# A `claude` that exits immediately, so the wrapper reaches its exit path fast.
stub_claude() {
    cat > "$TMP/bin/claude" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TMP/bin/claude"
}

# Run a wrapper (shipped, or a mutated copy) inside a scratch repo.
run_wrapper() {
    local wrapper="$1" dir="$2"
    ( cd "$dir" \
      && PATH="$TMP/bin:$PATH" FW_NO_STARTUP_BANNER=1 \
         timeout 60 bash "$wrapper" --no-restart >"$TMP/wrapper.out" 2>&1 )
}

ledger_of() { printf '%s\n' "$1/.context/working/continuous-run.jsonl"; }

# ── The confirming experiment ────────────────────────────────────────────────

@test "T-3213: running the SHIPPED wrapper writes a start event with reason=armed" {
    stub_claude
    local d; d="$(scratch_repo)"
    run_wrapper "$WRAPPER" "$d"
    local L; L="$(ledger_of "$d")"
    [ -f "$L" ]
    grep -q '"event": "start"' "$L"
    grep -q '"reason": "armed"' "$L"
}

@test "T-3213: the same run also writes a terminal exit event" {
    # "armed then exited" and "never armed" must be distinguishable on disk.
    # A start event alone would reintroduce the ambiguity from the other side.
    stub_claude
    local d; d="$(scratch_repo)"
    run_wrapper "$WRAPPER" "$d"
    local L; L="$(ledger_of "$d")"
    grep -q '"event": "exit"' "$L"
    grep -q '"reason": "auto-restart-disabled"' "$L"
}

@test "T-3213: start precedes exit in the ledger" {
    # Order is the whole point of an append-only log. If exit could land first,
    # a reader taking the LAST line — which is exactly what doctor does — would
    # report ARMED for a wrapper that had already quit.
    stub_claude
    local d; d="$(scratch_repo)"
    run_wrapper "$WRAPPER" "$d"
    local L; L="$(ledger_of "$d")"
    [ "$(head -1 "$L" | grep -c '"event": "start"')" -eq 1 ]
    [ "$(tail -1 "$L" | grep -c '"event": "exit"')" -eq 1 ]
}

@test "T-3213: the start event carries wrapper pid and restart configuration" {
    # So a future absent-ledger claim is checkable against the process table
    # rather than re-argued. This is the field doctor prints as "wrapper pid N".
    stub_claude
    local d; d="$(scratch_repo)"
    run_wrapper "$WRAPPER" "$d"
    local L; L="$(ledger_of "$d")"
    grep -q '"wrapper_pid": [1-9][0-9]*' "$L"
    grep -q 'restart=disabled' "$L"
}

# ── The mutation control ─────────────────────────────────────────────────────

@test "T-3213: MUTATION — strip the start call site and no start event is written" {
    # Build a real copy of the shipped wrapper with the start call removed.
    # If the suite stays green against that, tests 1-4 assert something other
    # than the call site they claim to cover.
    stub_claude
    local MUT="$TMP/claude-fw.mutated"
    # The call spans two lines (command + continued argument).
    sed '/^_record_loop_event start armed \\$/,+1d' "$WRAPPER" > "$MUT"

    # A mutation that changes no bytes reddens nothing for an uninteresting
    # reason, which would make this control vacuous in the way it exists to
    # detect. Assert it actually removed something.
    if diff -q "$WRAPPER" "$MUT" >/dev/null 2>&1; then
        echo "mutation changed no bytes — the sed pattern no longer matches" >&2
        false
    fi

    local d; d="$(scratch_repo)"
    run_wrapper "$MUT" "$d"
    local L; L="$(ledger_of "$d")"
    # The exit event still lands (T-3182's leg is untouched), so the ledger
    # exists — the START is what must be gone. Asserting "no file" would pass
    # for the wrong reason if the whole recorder broke.
    [ -f "$L" ]
    grep -q '"event": "exit"' "$L"
    if grep -q '"event": "start"' "$L"; then
        echo "start event present after removing its only call site" >&2
        false
    fi
}

# ── T-3209's second cause, discriminated rather than assumed absent ──────────

@test "T-3213: an unwritable ledger yields no record and does NOT change exit code" {
    # T-3209 names two causes for an absent ledger. The transient one is now
    # confirmed by test 1. This is the PERMANENT one: _record_loop_event is
    # non-fatal by design, so a recorder that cannot write must fail SILENTLY —
    # no record, and critically no change to the wrapper's exit code. A broken
    # recorder that broke the restart loop would be far worse than a quiet one.
    #
    # Denial mechanism: the ledger PATH is made a directory. `chmod 500` was the
    # obvious choice and is worthless here — this suite runs as root in CI and on
    # the origin host, where mode bits do not deny, so that version SKIPPED and
    # asserted nothing. A directory at the path makes open(..., "a") raise
    # IsADirectoryError for root and non-root alike, which is the property the
    # test actually needs.
    stub_claude
    local d; d="$(scratch_repo)"
    mkdir -p "$(ledger_of "$d")"

    local rc=0
    run_wrapper "$WRAPPER" "$d" || rc=$?

    # The wrapper still exits clean...
    [ "$rc" -eq 0 ]
    # ...and wrote no events, because the path it would append to is not a file.
    [ -d "$(ledger_of "$d")" ]
    if [ -n "$(find "$(ledger_of "$d")" -type f 2>/dev/null)" ]; then
        echo "recorder created files under an unwritable ledger path" >&2
        false
    fi
}

@test "T-3213: CONTROL — the unwritable case differs from the writable one" {
    # Proves the test above measures the denial rather than a wrapper that never
    # records anything under this harness at all. Same invocation, one difference.
    stub_claude
    local ok; ok="$(scratch_repo)"
    run_wrapper "$WRAPPER" "$ok"
    grep -q '"event": "start"' "$(ledger_of "$ok")"
}

# ── doctor flips branch on the ledger the experiment produced ───────────────

extract_block() {
    sed -n '/# Check: continuous-run loop ledger (T-3206/,/# Check: on-PATH claude-fw drift/p' "$FW" | head -n -1
}

fake_ps() {
    cat > "$TMP/bin/ps" <<PSEOF
#!/usr/bin/env bash
cat <<'TABLE'
$1
TABLE
exit 0
PSEOF
    chmod +x "$TMP/bin/ps"
}

run_block() {
    local blk; blk="$(extract_block)"
    cat > "$TMP/run.sh" <<RUNNER
CYAN=''; NC=''; YELLOW=''; GREEN=''; RED=''
warnings=0
PROJECT_ROOT="$TMP/proj"
_check() {
$blk
}
_check
echo "WARNCOUNT=\$warnings"
RUNNER
    PATH="$TMP/bin:$PATH" bash "$TMP/run.sh" 2>&1
}

@test "T-3213: CONTROL — the doctor block extracts and is substantial" {
    local blk; blk="$(extract_block)"
    [ -n "$blk" ]
    [ "$(printf '%s' "$blk" | wc -l)" -gt 20 ]
}

@test "T-3213: doctor reports ARMED against a ledger the real wrapper produced" {
    # The point of sourcing the fixture from an actual run rather than hand-writing
    # it: a hand-written ledger proves doctor parses what the TEST believes the
    # wrapper emits. This proves it parses what the wrapper ACTUALLY emits — the
    # producer/consumer join is where this class of bug lives (L-399).
    stub_claude
    local d; d="$(scratch_repo)"
    run_wrapper "$WRAPPER" "$d"
    # Keep only the start line: the state doctor sees while a wrapper is live.
    grep '"event": "start"' "$(ledger_of "$d")" > "$TMP/proj/.context/working/continuous-run.jsonl"
    fake_ps ""
    run run_block
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "last recorded ARMED"
}

@test "T-3213: doctor does NOT report ARMED when the ledger is absent" {
    # The other half of the flip. Without this, the assertion above could hold
    # for a block that says ARMED unconditionally.
    rm -f "$TMP/proj/.context/working/continuous-run.jsonl"
    fake_ps ""
    run run_block
    [ "$status" -eq 0 ]
    if echo "$output" | grep -q "last recorded ARMED"; then
        echo "doctor reported ARMED with no ledger present" >&2
        false
    fi
    echo "$output" | grep -q "never recorded"
}
