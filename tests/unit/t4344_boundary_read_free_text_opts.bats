#!/usr/bin/env bats
# T-4344 — the boundary read scanner skipped the word after a flag that takes NO value
# (`git diff --no-index -m /etc/shadow`, `git log --summary /etc/shadow`) because the
# value-taking free-text options (T-4284) were one global set applied to every git/fw
# command. The skipped word is a path operand, so the outside read was hidden.
#
# Fix: free-text options are keyed per command (and per git subcommand). The reported
# counts below are the regression; the T-4284 false positives must stay unflagged.
#
# Nothing here is executed: the outside path is built at run time and the scanner is
# only fed the command text.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    R="/$(printf 'ro%s' ot)"
    OUT="$R/.t4344-probe"                  # outside the project, never created
    SH="/etc/shadow"
    CWD="$FRAMEWORK_ROOT"
    unset PROJECT_ROOT
}

# Count the outside reads the scanner reports for <command>. Outside = /etc/* or /dev/null.
reads() {
    python3 -I -c '
import sys
sys.path.insert(0, sys.argv[1])
import shell_write_scan as s
outside = lambda p: p.startswith("/etc/") or p == "/dev/null"
print(len(s.scan_boundary_reads(sys.argv[2], sys.argv[3], outside)))
' "$FRAMEWORK_ROOT/lib" "$1" "$FRAMEWORK_ROOT"
}

hook() {
    local json
    json=$(python3 -c 'import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))' "$1" "$CWD")
    output=$(printf '%s' "$json" | bash "$HOOK" 2>&1)
    return $?
}

assert_blocked() {
    local rc=0
    hook "$1" || rc=$?
    [ "$rc" -eq 2 ] || { echo "expected BLOCKED (rc 2), got rc=$rc for: $1" >&2; echo "$output" >&2; return 1; }
}

# ── the four reported counts (scanner level) ─────────────────────────────────

@test "reported: git diff --no-index /etc/shadow /dev/null reads 2" {
    [ "$(reads "git diff --no-index $SH /dev/null")" -eq 2 ]
}

@test "reported: git diff --no-index -m /etc/shadow /dev/null reads 2 (was 1)" {
    [ "$(reads "git diff --no-index -m $SH /dev/null")" -eq 2 ]
}

@test "reported: git log --summary /etc/shadow reads 1 (was 0)" {
    [ "$(reads "git log --summary $SH")" -eq 1 ]
}

@test "reported: cat /etc/shadow reads 1" {
    [ "$(reads "cat $SH")" -eq 1 ]
}

# ── the same reads through the hook (the gate that must block them) ─────────

@test "hook blocks git log --summary of an outside file" {
    assert_blocked "git log --summary $OUT"
}

@test "hook blocks git diff --no-index -m of an outside file" {
    assert_blocked "git diff --no-index -m $OUT /dev/null"
}

# ── a flag that takes no value never skips the next word ────────────────────

@test "no-value flags: git log/diff/show do not skip a following path" {
    [ "$(reads "git log -m $SH")" -eq 1 ]
    [ "$(reads "git show --summary $SH")" -eq 1 ]
    [ "$(reads "git diff --summary $SH")" -eq 1 ]
}

@test "subcommand keying: git -C <dir> commit -m skips its message, git -C value is not a subcommand" {
    [ "$(reads "git -C $FRAMEWORK_ROOT commit -m \"fix $SH\" -- README.md")" -eq 0 ]
    [ "$(reads "git -C $SH log --summary")" -eq 1 ]
}

@test "free-text options still skip their value on the commands that take one" {
    [ "$(reads "git tag -m \"release $SH\" v0")" -eq 0 ]
    [ "$(reads "fw task create --rationale \"see $SH > x\"")" -eq 0 ]
    [ "$(reads "gh pr create --body \"$SH is in the body\"")" -eq 0 ]
}

# ── T-4284 false positives stay unflagged ───────────────────────────────────

@test "T-4284: commit message mentioning a path in prose is not a read" {
    [ "$(reads "git commit -m \"fix $SH handling\" -- README.md")" -eq 0 ]
}

@test "T-4284: fw rationale containing '>' and a path in prose is not a read" {
    [ "$(reads "bin/fw task update T-1 --rationale \"compare $SH > out\"")" -eq 0 ]
}
