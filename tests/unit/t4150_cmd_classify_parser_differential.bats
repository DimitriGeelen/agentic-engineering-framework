#!/usr/bin/env bats
# T-4150 — the budget-gate classifier must read a command the way bash does.
#
# Verified 2026-10-13 (codex parser review, ring20-dashboard's hint, finding 2):
# lib/cmd_classify.py ADMITTED at critical budget three commands bash would use
# to run an arbitrary command, because its reading of the text differed from
# bash's:
#
#   1. process substitution   git status > >(touch X)
#   2. unquoted heredoc body  git status <<EOF / $(touch X) / EOF
#      (bash expands $(…) in an unquoted heredoc body; we blanked it as data)
#   3. comment hides opener   git status # <<EOF / touch X / EOF
#      (to bash `<<EOF` is comment text, so `touch X` is a command; we took
#      `<<EOF` as an opener and blanked `touch X` as heredoc data)
#
# Every case is fed to the classifier; none is executed. The outside-project
# target is assembled at run time so this file's text names no such path.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    MOD="$FRAMEWORK_ROOT/lib/cmd_classify.py"
    GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
    T="/""etc/t4150-probe"
}

cls() {
    output=$(python3 "$MOD" "$1" 2>&1)
    return $?
}

assert_allowed() {
    if cls "$1"; then return 0; fi
    echo "expected ALLOWED, got: $output" >&2
    return 1
}

# assert_blocked <command> <expected-substring-of-reason>
assert_blocked() {
    if cls "$1"; then
        echo "expected BLOCKED, got allowed: $1" >&2
        return 1
    fi
    if ! echo "$output" | grep -qF -- "$2"; then
        echo "blocked for the wrong reason: $output (wanted: $2)" >&2
        return 1
    fi
}

# ── The three verified bypasses (each was ADMITTED on HEAD before the fix) ────

@test "t4150: process substitution >( ) is refused" {
    assert_blocked "git status > >(touch $T)" "process substitution"
}

@test "t4150: process substitution <( ) is refused" {
    assert_blocked "git diff <(touch $T) x" "process substitution"
}

@test "t4150: unquoted heredoc body carrying \$( ) is refused" {
    assert_blocked "$(printf 'git status <<EOF\n$(touch %s)\nEOF\n' "$T")" "heredoc body"
}

@test "t4150: unquoted heredoc body carrying a backtick is refused" {
    assert_blocked "$(printf 'git status <<EOF\n`touch %s`\nEOF\n' "$T")" "heredoc body"
}

@test "t4150: unquoted heredoc body hiding \$( ) behind '#' is refused" {
    # '#' is not a comment inside a heredoc body; bash still expands the $( ).
    assert_blocked "$(printf 'git status <<EOF\n# $(touch %s)\nEOF\n' "$T")" "heredoc body"
}

@test "t4150: unterminated unquoted heredoc carrying \$( ) is refused" {
    # bash takes everything to end of input as the body and expands it.
    assert_blocked "$(printf 'git status <<EOF\n# $(touch %s)\n' "$T")" "heredoc body"
}

@test "t4150: '#' comment hiding a heredoc opener — next line is a command" {
    assert_blocked "$(printf 'git status # <<EOF\ntouch %s\nEOF\n' "$T")" "'touch' is not"
}

@test "t4150: comment after ';' (no space) also hides the opener" {
    # `#` starts a comment at any word start, and ';' ends a word.
    assert_blocked "$(printf 'git status;#<<EOF\ntouch %s\nEOF\n' "$T")" "'touch' is not"
}

@test "t4150: a near-miss terminator does not end the body early" {
    # bash ends a body only on a line equal to the delimiter: 'EOF ' is body.
    assert_blocked "$(printf 'git status <<EOF\nEOF \n# $(touch %s)\nEOF\n' "$T")" "heredoc body"
}

# ── Fail closed where the reading is not certain ──────────────────────────────

@test "t4150: an unterminated quote is refused" {
    assert_blocked "git commit -m \"unbalanced" "unterminated quote"
}

@test "t4150: ANSI-C \$'…' quoting is refused" {
    assert_blocked "git status \$'\\'' ; touch $T ; '" "ANSI-C"
}

@test "t4150: a heredoc delimiter with an expansion character is refused" {
    assert_blocked "$(printf 'git status <<$X\nbody\n$X\n')" "heredoc delimiter"
}

@test "t4150: nested quotes in \${…} cannot fake a heredoc opener" {
    # bash: "${x:-"<<'EOF'"}" is one double-quoted word — no heredoc, so the
    # next line runs. A flat quote tracker sees <<'EOF' outside quotes.
    assert_blocked "$(printf 'git status "${x:-"<<'"'"'EOF'"'"'"}"\ntouch %s\nEOF\n' "$T")" "nested quoting"
}

# ── Controls: ordinary wrap-up commands stay admitted ─────────────────────────

@test "t4150: control — quoted heredoc may carry \$( ) as literal text" {
    assert_allowed "$(printf "git commit -F - <<'EOF'\nT-4150: refuse \$(…) and \`x\` in bodies\nEOF\n")"
}

@test "t4150: control — double-quoted delimiter is quoted too" {
    assert_allowed "$(printf 'git commit -F - <<"EOF"\nT-1: $(not run)\nEOF\n')"
}

@test "t4150: control — partially quoted delimiter E\"O\"F is quoted" {
    assert_allowed "$(printf 'git commit -F - <<E"O"F\nT-1: $(not run)\nEOF\n')"
}

@test "t4150: control — hyphenated quoted delimiter works" {
    assert_allowed "$(printf "git commit -F - <<'END-MSG'\nT-1: a; b && c\nEND-MSG\n")"
}

@test "t4150: control — unquoted heredoc without expansion is allowed" {
    assert_allowed "$(printf 'git commit -F - <<EOF\nT-1: plain text, $HOME is only a variable\nEOF\n')"
}

@test "t4150: control — a heredoc opener followed by a comment" {
    assert_allowed "$(printf "git commit -F - <<'EOF' # message below\nT-1: x\nEOF\n")"
}

@test "t4150: control — '#' inside quotes and mid-word is not a comment" {
    assert_allowed 'git commit -m "fix #42" -m a#b'
}

@test "t4150: control — here-string <<< is not a heredoc" {
    assert_allowed 'git status <<< x'
}

@test "t4150: control — redirections and pipes stay allowed" {
    assert_allowed 'git log --oneline -5 2>&1 | head -3'
    assert_allowed 'git status > /dev/null'
}

@test "t4150: control — cd prefix chain still allowed" {
    assert_allowed "cd $FRAMEWORK_ROOT && git status"
}

# ── End to end: the real hook refuses the verified cases at critical ──────────

# hook <command>: drive the REAL hook at critical with a fresh status cache
# (the hook rewrites its cache, so each call gets its own project dir).
hook() {
    local work json
    work=$(mktemp -d "$BATS_TEST_TMPDIR/proj.XXXXXX")
    mkdir -p "$work/.context/working"
    printf '{"level":"critical","tokens":290000,"timestamp":%s,"source":"test"}' \
        "$(date +%s)" > "$work/.context/working/.budget-status"
    json=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","cwd":sys.argv[2],"tool_input":{"command":sys.argv[1]}}))' "$1" "$FRAMEWORK_ROOT")
    printf '%s' "$json" | PROJECT_ROOT="$work" bash "$GATE" >/dev/null 2>&1
}

@test "t4150: budget-gate hook refuses process substitution at critical" {
    run hook "git status > >(touch $T)"
    [ "$status" -eq 2 ]
}

@test "t4150: budget-gate hook refuses an unquoted heredoc \$( ) at critical" {
    run hook "$(printf 'git status <<EOF\n$(touch %s)\nEOF\n' "$T")"
    [ "$status" -eq 2 ]
}

@test "t4150: budget-gate hook refuses the comment-hidden opener at critical" {
    run hook "$(printf 'git status # <<EOF\ntouch %s\nEOF\n' "$T")"
    [ "$status" -eq 2 ]
}

@test "t4150: budget-gate hook control — quoted-heredoc commit admitted" {
    run hook "$(printf "git commit -F - <<'EOF'\nT-1: msg\nEOF\n")"
    [ "$status" -eq 0 ]
}
