#!/usr/bin/env bats
# T-2879 — `2>&1` must not defeat the safe-list.
#
# _fw_chain_split treated `&` as a chain separator unconditionally, so
# `bin/fw note "x" 2>&1` split into `bin/fw note "x" 2>` and `1`. The bare `1`
# matches nothing in the allowlist, so the whole compound failed — the splitter
# manufactured an unsafe segment out of a file-descriptor duplication.
#
# WHY THIS IS WIDER THAN ONE VERB: the safe-list is consulted only when there is no
# active task or focus has drifted — the recovery states where it is the only thing
# preventing a deadlock. `fw doctor 2>&1`, `git status 2>&1` and `ls -la 2>&1` were
# all gated there. Found one minute after T-2878 shipped, by using T-2878's own fix
# for real: the bats suite stayed green because it tested the bare verb form.
#
# THE CONTROL THAT DEFINES THE FIX: `cmd >& file` writes to `file` and MUST stay
# gated. The fix is narrow for exactly that reason — it requires the `&` to sit
# between a redirect operator and an fd target (digit or `-`). Relaxing it to
# "preceded by > or <" would admit `>& file` and turn a deadlock fix into a hole.

load ../test_helper

LIB="$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"

_allowed() { bash -c "source '$LIB'; is_bash_safe_command \"\$1\"" _ "$1"; }
# T-3223: the splitter emits NUL-TERMINATED segments (a quoted argument may
# legitimately contain a newline, so a newline delimiter cannot mark a
# boundary). Translate to newlines HERE so the line-counting assertions below
# still measure segments. Without this they count 1 for every input — which
# looks like a passing test right up until it is the only thing you have.
_segs()    { bash -c "source '$LIB'; _fw_chain_split \"\$1\" | tr '\\0' '\\n'" _ "$1"; }

@test "T-2879: SMOKE — a bare safe command is allowed and a write is not" {
    # If these two disagree, every leg below is measuring a broken harness.
    _allowed 'bin/fw doctor'
    ! _allowed 'echo hi > file.txt'
}

@test "T-2879: 2>&1 no longer defeats the safe-list" {
    _allowed 'bin/fw note "x" 2>&1'
    _allowed 'bin/fw doctor 2>&1'
    _allowed 'git status 2>&1'
    _allowed 'ls -la 2>&1'
}

@test "T-2879: 2>&1 composes with a safe pipeline" {
    _allowed 'bin/fw note "x" 2>&1 | tail -3'
    _allowed 'bin/fw handover 2>&1 | tail -5'
}

@test "T-2879: other fd-dup forms are handled" {
    _allowed 'bin/fw doctor >&2'
    _allowed 'bin/fw doctor 2>&-'
}

@test "T-2879: CONTROL — >& file is a WRITE and stays gated" {
    # The whole reason the fix tests the NEXT character rather than only the previous
    # one. `>&` followed by a filename redirects both streams into that file.
    if _allowed 'ls >& out.txt'; then false; fi
    ! _allowed 'bin/fw doctor >& /tmp/captured'
}

@test "T-2879: CONTROL — && still splits, so an unsafe tail still gates" {
    # If the fix over-matched, the `&&` chain would collapse into one segment and the
    # `rm -rf` would ride in on `fw doctor`'s safety. This is the OBS-184 shape.
    if _allowed 'bin/fw doctor 2>&1 && rm -rf /tmp/x'; then false; fi
    if _allowed 'bin/fw doctor 2>&1 | python3 -c "import os; os.remove(1)"'; then false; fi
    ! _allowed 'bin/fw config set FOO bar 2>&1'
}

@test "T-2879: the splitter keeps 2>&1 whole but still separates a real chain" {
    local out
    out=$(_segs 'bin/fw note "x" 2>&1')
    [ "$(printf '%s' "$out" | grep -c .)" -eq 1 ]

    out=$(_segs 'a 2>&1 && b')
    [ "$(printf '%s' "$out" | grep -c .)" -eq 2 ]

    out=$(_segs 'ls >& out.txt')          # write form must still split
    [ "$(printf '%s' "$out" | grep -c .)" -eq 2 ]
}

@test "T-2879: ANTI-VACUITY — restoring the unconditional split re-opens the defect" {
    # DURABLE MUTATION of live source, not `git show HEAD~N:` — a ref-based teeth check
    # goes inert on the next commit and skips while reporting ok (T-2874).
    local mutant="$BATS_TEST_TMPDIR/lib-mutant.sh"
    sed 's|if \[ "\$ch" = .&. \] && \[\[ "\${seg: -1}" == \[\\<\\>\] \]\] && \[\[ "\$nxt" == \[0-9-\] \]\]; then|if false; then|' \
        "$LIB" > "$mutant"
    local delta; delta=$(diff "$LIB" "$mutant" || true)   # diff exits 1 on "differs" (L-387)
    [ -n "$delta" ]        # a no-op sed proves nothing
    bash -n "$mutant"      # a mutant that cannot parse is not evidence (OBS-193)

    # THE DEFECT: with the guard forced false, 2>&1 splits and gates the whole command.
    run bash -c "source '$mutant'; is_bash_safe_command 'bin/fw doctor 2>&1'"
    [ "$status" -ne 0 ]
    # And the fixed source allows it — pins the mutation as the cause, not the harness.
    run bash -c "source '$LIB'; is_bash_safe_command 'bin/fw doctor 2>&1'"
    [ "$status" -eq 0 ]
}
