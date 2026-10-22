#!/usr/bin/env bats
#
# T-4627 (SECURITY, G-121): the read-only allowlist admitted git ls-remote, fetch and
# push by verb name. --upload-pack=CMD (ls-remote, fetch; -u on ls-remote) and
# --receive-pack=CMD / --exec=CMD (push) make git RUN CMD as the remote's pack program
# for a local-path or ssh remote. Reported by ring20-dashboard round 2 (msg 9e201103).
#
# Fix: agents/context/lib/safe-commands.sh _fw_git_transport_runs_program — judged on
# the dequoted words (_fw_option_words). Classification only: nothing here is executed.
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

@test "T-4627: the probe's ls-remote and fetch lines are NOT SAFE" {
    _refused "git ls-remote --upload-pack=touch ." "git fetch --upload-pack=touch origin"
}

@test "T-4627: separate value, abbreviations and global options are NOT SAFE" {
    _refused "git ls-remote --upload-pack touch ." "git ls-remote --upl=touch ." \
        "git ls-remote --u=touch ." "git fetch --upload=touch origin" \
        "git -C . ls-remote --upload-pack=touch ." "git --no-pager fetch --upload-pack=x origin"
}

@test "T-4627: -u in any short form is NOT SAFE on ls-remote and fetch" {
    _refused "git ls-remote -u touch ." "git ls-remote -utouch ." "git ls-remote -qu touch ." \
        "git fetch -u origin"
}

@test "T-4627: push --receive-pack and --exec are NOT SAFE" {
    _refused "git push --receive-pack=touch origin" "git push --receive-pack touch origin" \
        "git push --rece=touch origin" "git push --exec=touch origin" "git push --ex=touch origin"
}

@test "T-4627: quoted or expanded spellings are NOT SAFE" {
    _refused "git ls-remote '--upload-pack=touch' ." "git fetch --upload-p\"ack=x\" origin" \
        'git fetch "$O" origin' "git ls-remote -{u,q} touch ." "git push \$'--exec=x' origin"
}

@test "T-4627: ordinary ls-remote, fetch and push stay SAFE" {
    _safe "git ls-remote origin" "git ls-remote --heads --refs origin" "git ls-remote --tags ." \
        "git fetch origin" "git fetch --prune --tags origin" "git fetch -q origin master" \
        "git push origin bleeding-edge" "git push -u origin x" "git push --repo=origin" \
        "git status" "git log --oneline -3"
}
