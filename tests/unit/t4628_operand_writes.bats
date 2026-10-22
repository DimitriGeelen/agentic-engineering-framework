#!/usr/bin/env bats
#
# T-4628 (SECURITY, G-121): the read-only allowlist admitted uniq, xxd and gunzip by
# name on the claim that the filter arm's tools write only through a redirect. uniq
# and xxd write their SECOND operand; gunzip X.gz decompresses in place and deletes
# X.gz. Reported by ring20-dashboard round 2 (msg 9e201103).
#
# Fix: agents/context/lib/safe-commands.sh _fw_filter_operand_writes — operand count
# (option values skipped) for uniq/xxd, stdout/inspect flags for gunzip, on the
# dequoted words (_fw_option_words). Classification only: nothing here is executed.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
# `if cmd; then false; fi`.

load helpers/known_cwd

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    known_cwd_setup
    cd "$ROOT"
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

@test "T-4628: the probe's uniq, xxd and gunzip lines are NOT SAFE" {
    _refused "uniq IN OUT" "uniq -c IN OUT" "xxd IN OUT" "xxd -r -p IN OUT" \
        "gunzip X.gz" "gunzip -k X.gz" "gunzip -f X.gz"
}

@test "T-4628: uniq option values are skipped, options may follow operands" {
    _refused "uniq -f 1 IN OUT" "uniq -s2 IN OUT" "uniq --skip-fields 1 IN OUT" \
        "uniq --check-chars=3 IN OUT" "uniq IN OUT -c" "uniq -- IN OUT" "uniq -cw 4 IN OUT"
}

@test "T-4628: xxd option values are skipped, and options stop at the first operand" {
    _refused "xxd -s 16 IN OUT" "xxd -l 64 -c 8 IN OUT" "xxd -cols 8 IN OUT" \
        "xxd IN -r" "xxd -- IN OUT" "cat F | xxd -r -p - OUT"
}

@test "T-4628: gunzip -S does not hand its letter to the stdout check" {
    _refused "gunzip -Sc file.c" "gunzip -S c file.c" "gunzip --suffix c file.c" "gunzip -v X.gz"
}

@test "T-4628: quoted or expanded spellings are NOT SAFE" {
    _refused "uniq IN 'OUT'" 'uniq IN "$OUT"' "xxd IN \"OUT\"" 'gunzip "$F"' "uniq {IN,OUT}"
}

@test "T-4628: read-only forms and the G-121 controls stay SAFE" {
    _safe "uniq F" "uniq -c F" "uniq -f 1 F" "uniq --skip-chars 2 F" "sort F | uniq -c" \
        "xxd F" "xxd -l 64 F" "xxd -s 16 -c 8 F" "xxd -r -p F" "xxd -i F" \
        "gunzip -c X.gz" "gunzip -t X.gz" "gunzip -l X.gz" "gunzip -cd X.gz" \
        "gunzip --stdout X.gz" "cat X.gz | gunzip" "zcat X.gz" "sed -n 1p F"
}
