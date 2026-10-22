#!/usr/bin/env bats
#
# T-4650: the read-only allowlist refused `sed -n 1,5p docs/T-037-*.md` while the
# same command with a literal file passed (field report dimitri-mint-dev be.3, hit
# as a G-020 block on `sed -n 76,135p .tasks/completed/T-166-*.md`).
#
# Root cause: lib/shell_write_scan.py option_words returned None on any unquoted
# glob, and the sed checks in agents/context/lib/safe-commands.sh treat None as
# unsafe. Fix: option_words(globs=True) admits a glob word whose first character is
# a literal other than `-` as kind G (never an option); _fw_sed_runs_command refuses
# a G in the script position and admits G FILE operands only beside a print-only
# script (ADDR[,ADDR]p) with no operand that is a bare sed command letter.
# Classification only: nothing here is executed.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
# `if cmd; then false; fi`.

load helpers/known_cwd

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    known_cwd_setup
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

teardown() { known_cwd_teardown; }

_refused() {
    local c
    for c in "$@"; do
        if is_bash_safe_command "$c"; then echo "SAFE (expected gated): $c"; return 1; fi
    done
}

_safe() {
    local c
    for c in "$@"; do
        is_bash_safe_command "$c" || { echo "gated (expected SAFE): $c"; return 1; }
    done
}

@test "T-4650: the reported commands with a glob FILE operand are SAFE" {
    _safe 'sed -n 1,5p docs/T-037-*.md' 'sed -n 76,135p .tasks/completed/T-166-*.md'
}

@test "T-4650: print-only forms with ?, [..] and several glob operands are SAFE" {
    _safe 'sed -n 5p docs/T-?.md' 'sed -n /x/p docs/[ab].md' "sed -n '\$p' a/*.md b/*.md" \
        'sed -n -e 1p docs/*.md' 'sed -n 1,5p a.md docs/*.md'
}

@test "T-4650: the literal-file form is still SAFE" {
    _safe 'sed -n 1,5p docs/T-037-x.md' "sed -n 's/a/b/p' docs/x.md"
}

@test "T-4650: a detached w command after glob operands is NOT SAFE" {
    _refused 'sed -n 1p docs/*.md w out' 'sed -n 1p d/*.md W out'
}

@test "T-4650: in-place forms with a glob operand are NOT SAFE" {
    _refused 'sed -i s/a/b/ docs/*.md' 'sed -n -i 1p docs/*.md' 'sed --in-place 1p docs/*.md' \
        "sed -'i' 1p docs/*.md"
}

@test "T-4650: a write, an expansion or e flag in the script is NOT SAFE" {
    _refused "sed -n 'w x' f" "sed -n 'w x' docs/*.md" 'sed -n "$(echo 1p)" f' \
        "sed -e 's/a/b/e' f" "sed -e 's/a/b/e' docs/*.md" "sed -n 's/a/b/w x' docs/*.md"
}

@test "T-4650: a glob in the script position is NOT SAFE" {
    _refused 'sed -n 1*p f' 'sed -n d/*p f' 'sed -n -e 1*p f' 'sed -n --expression 1*p f'
}

@test "T-4650: a non-print script beside a glob operand is NOT SAFE" {
    _refused 'sed 1d docs/*.md' "sed 's/a/b/' docs/*.md" "sed -n '1p;2q' docs/*.md"
}

@test "T-4650: a glob that may expand to an option is NOT SAFE" {
    _refused 'sed -n 1p *.md' 'sed -n 1p ?x' 'sed -n 1p [-]i' 'sed -n 1p -*'
}
