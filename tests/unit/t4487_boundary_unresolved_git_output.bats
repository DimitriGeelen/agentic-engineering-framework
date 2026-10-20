#!/usr/bin/env bats
#
# T-4487: scan_boundary (the project-boundary hook's write scanner) stayed CLEAN on a
# git diff-family --output target it cannot resolve from the text — `$o` set earlier in
# the same command, `${O:---output=/etc/x}`, `$(echo --output=/etc/x)`, a loop
# variable. _check_target only refused an unresolved target under `ctx.mentions`, which
# boundary mode never sets, so `git diff $o` wrote /etc/x past the boundary.
#
# Fix: boundary mode fails closed when such a word could begin with --output (its
# literal prefix is a prefix of `--output`) AND the command names a path outside the
# project. `git diff $BASE..HEAD` and friends that name no outside path stay clean
# (corpus cost measured in the task: <=68 of 222,119 real agent commands).

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export ROOT
}

# Prints HIT <reason> or CLEAN. guarded = anything outside $ROOT, /tmp and /dev.
scan() {
    python3 - "$1" <<'EOF'
import os, sys
root = os.environ["ROOT"]
sys.path.insert(0, os.path.join(root, "lib"))
import shell_write_scan as s
def guarded(p):
    return not (p == root or p.startswith(root + "/") or p.startswith(("/tmp", "/dev")))
hits = s.scan_boundary(sys.argv[1], root, guarded, lambda p: True)
print("HIT " + hits[0].reason if hits else "CLEAN")
EOF
}

# --- unresolved --output targets naming an outside path: refused -----------------

@test "T-4487: a variable set in the command carrying --output is refused" {
    run scan 'o=--output=/etc/x; git diff $o'
    [[ "$output" == HIT* ]]
}

@test "T-4487: a parameter default carrying --output is refused" {
    run scan 'git diff ${O:---output=/etc/x}'
    [[ "$output" == HIT* ]]
}

@test "T-4487: a command substitution yielding --output is refused" {
    run scan 'git diff $(echo --output=/etc/x)'
    [[ "$output" == HIT* ]]
}

@test "T-4487: a loop variable carrying --output is refused" {
    run scan 'for o in --output=/etc/x; do git log -p $o; done'
    [[ "$output" == HIT* ]]
}

@test "T-4487: a quoted variable and an abbreviated prefix are refused" {
    run scan 'o=/etc/x; git show "--ou=$o" HEAD'
    [[ "$output" == HIT* ]]
    run scan 'o=--output=../../etc/x; git diff "$o"'
    [[ "$output" == HIT* ]]
}

# --- controls: unresolved arguments that cannot write outside stay clean ----------

@test "T-4487 control: unresolved revisions naming no outside path stay clean" {
    run scan 'git diff $BASE..HEAD'
    [ "$output" = CLEAN ]
    run scan 'git log --oneline $(git merge-base HEAD master)..HEAD'
    [ "$output" = CLEAN ]
    run scan 'git show $sha -- lib/shell_write_scan.py'
    [ "$output" = CLEAN ]
}

@test "T-4487 control: an outside path only in a word that cannot be --output stays clean" {
    run scan 'git diff HEAD~$n -- lib/x.py > /tmp/t4487.diff; ls /etc/hosts'
    [ "$output" = CLEAN ]
}

@test "T-4487 control: literal --output inside the project or /tmp stays clean" {
    run scan 'o=--output=/tmp/x.diff; git diff $o'
    [ "$output" = CLEAN ]
    run scan 'git diff --output=/etc/x'
    [[ "$output" == HIT* ]]
}
