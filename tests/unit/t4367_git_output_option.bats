#!/usr/bin/env bats
#
# T-4367: git diff|log|show|diff-tree|diff-index|whatchanged accept --output=FILE, which
# WRITES FILE. The read-only allowlist judged the verb only, so
# `git diff --output=/tmp/x HEAD` was SAFE with no active task.
#
# Fix: any word that is --output (or an unambiguous-prefix abbreviation, optionally
# =VALUE) on those verbs makes the command NOT SAFE; lib/shell_write_scan.py reports the
# target as a write. `-o` is not a git diff output flag and --output-indicator-* are
# display options, so neither is over-matched.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
# `if cmd; then false; fi`.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$ROOT/agents/context/lib/safe-commands.sh"
    export PROJECT_ROOT="$ROOT"
    export _FW_PAYLOAD_CWD="$ROOT"
}

# --- controls: still SAFE ----------------------------------------------------------

@test "T-4367: git diff HEAD is SAFE" {
    is_bash_safe_command "git diff HEAD"
}

@test "T-4367: git log --oneline is SAFE" {
    is_bash_safe_command "git log --oneline"
}

@test "T-4367: git diff --output-indicator-new=+ is SAFE (display option, not a file)" {
    is_bash_safe_command "git diff --output-indicator-new=+ HEAD"
}

@test "T-4367: git show -o is not over-matched" {
    is_bash_safe_command "git show -o HEAD"
}

# --- NOT SAFE ----------------------------------------------------------------------

@test "T-4367: --output=FILE is NOT SAFE on every affected verb" {
    local v
    for v in diff log show diff-tree diff-index whatchanged; do
        if is_bash_safe_command "git $v --output=/tmp/x HEAD"; then
            echo "SAFE: git $v --output=/tmp/x HEAD"; false
        fi
    done
}

@test "T-4367: separate-word --output FILE is NOT SAFE" {
    if is_bash_safe_command "git diff --output /tmp/x HEAD"; then false; fi
}

@test "T-4367: abbreviations --out / --outp / --outpu are NOT SAFE" {
    local a
    for a in --out=/tmp/x --outp=/tmp/x --outpu=/tmp/x --out; do
        if is_bash_safe_command "git log $a"; then echo "SAFE: $a"; false; fi
    done
}

@test "T-4367: --output behind git global options is NOT SAFE" {
    if is_bash_safe_command "git -C $ROOT --no-pager diff --output=/tmp/x"; then false; fi
}

@test "T-4367: --output after the path separator is a pathspec but stays NOT SAFE (fail closed)" {
    if is_bash_safe_command "git diff HEAD -- --output=x"; then false; fi
}

# --- write scanner ------------------------------------------------------------------

@test "T-4367: shell_write_scan reports git diff --output=<task file> as a write" {
    run python3 -I -c '
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
import shell_write_scan as s
for c in ("git diff --output=.tasks/active/T-1.md HEAD", "git log --output .tasks/active/T-1.md", "git -C . show --output=.tasks/active/T-1.md"):
    assert s.scan(c, sys.argv[1]), c
assert not s.scan("git diff HEAD", sys.argv[1])
' "$ROOT"
    [ "$status" -eq 0 ]
}
