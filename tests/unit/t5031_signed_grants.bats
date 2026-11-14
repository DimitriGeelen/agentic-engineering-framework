#!/usr/bin/env bats
# T-5031 (operator ruling 2026-11-14, "Signed commit"): once policy/grants-allowed-signers has
# been committed, a grant counts only from an SSH-signed commit by a listed key. The signers
# list is a chain: each change signed by a key from the previous version, the first one
# self-signed (the anchor, shown by doctor). Real keys (ssh-keygen), real signed commits, git's
# own verifier. Projects that never adopted signing keep the trailer rule with a doctor WARN.

load ../git_fence

setup() {
    command -v ssh-keygen >/dev/null || { echo "ssh-keygen missing"; false; }
    _FW_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    AG="$_FW_ROOT/lib/access_grants.py"
    T="$(mktemp -d)"
    R="$T/proj"; K="$T/keys"
    mkdir -p "$R/policy" "$K"
    ssh-keygen -q -t ed25519 -N "" -C op@test -f "$K/op"
    ssh-keygen -q -t ed25519 -N "" -C op2@test -f "$K/op2"
    ssh-keygen -q -t ed25519 -N "" -C agent@test -f "$K/agent"
    git -C "$R" init -q
    git -C "$R" config user.email t@t
    git -C "$R" config user.name t
    echo src > "$R/a.txt"; git -C "$R" add a.txt; git -C "$R" commit -qm init
    GRANT=$'grants:\n  - path: /srv/t5031\n    level: create\n    via: /srv/t5031\nnever_write: [/srv/t5031-admin]\n'
}

teardown() { rm -rf "$T"; }

signer_line() { echo "$1@test $(cut -d' ' -f1,2 "$K/$1.pub")"; }
# commit_as KEY MSG — signed with KEY; "none" = unsigned
commit_as() {
    if [ "$1" = none ]; then
        git -C "$R" commit -qm "$2" -m "Grants-Change: operator"
    else
        git -C "$R" -c gpg.format=ssh -c user.signingkey="$K/$1.pub" commit -S -qm "$2" -m "Grants-Change: operator"
    fi
}
put() { printf '%s' "$2" > "$R/$1"; git -C "$R" add "$1"; }
show() { run python3 "$AG" show "$R"; }
granted() { show; [[ "$output" == *"/srv/t5031  (via"* ]]; }

@test "legacy (no signers list ever): trailer-only grant counts, doctor WARNs" {
    put policy/access-grants.yaml "$GRANT"; commit_as none "grant"
    granted
    run python3 "$AG" doctor "$R"
    [[ "$output" == *"WARN access grants are protected by the"* ]]
}

@test "bootstrap: signers list + grant signed by the listed key count; doctor names the anchor" {
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'
    put policy/access-grants.yaml "$GRANT"; commit_as op "adopt signing"
    granted
    fpr=$(ssh-keygen -lf "$K/op.pub" | awk '{print $2}')
    run python3 "$AG" doctor "$R"
    [[ "$output" == *"anchored on key $fpr"* ]]
}

@test "after adoption: an unsigned grant change grants nothing, never_write still holds" {
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'; commit_as op "adopt"
    put policy/access-grants.yaml "$GRANT"; commit_as none "unsigned grant"
    show
    [[ "$output" == *"INVALID: unsigned or unverified"* ]]
    [[ "$output" != *"/srv/t5031  (via"* ]]
    [[ "$output" == *"never_write"*"/srv/t5031-admin"* ]]
}

@test "after adoption: a grant signed by a key NOT in the list grants nothing" {
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'; commit_as op "adopt"
    put policy/access-grants.yaml "$GRANT"; commit_as agent "agent-signed grant"
    show
    [[ "$output" == *"not in the allowed-signers list"* ]]
}

@test "an agent adding its own key to the list (self-signed) breaks the chain" {
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'; commit_as op "adopt"
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'"$(signer_line agent)"$'\n'; commit_as agent "add me"
    put policy/access-grants.yaml "$GRANT"; commit_as agent "my grant"
    show
    [[ "$output" == *"signers change"*"previous list"* ]]
    [[ "$output" != *"/srv/t5031  (via"* ]]
}

@test "the same change in ONE commit (own key added and grant signed by it) is refused too" {
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'; commit_as op "adopt"
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'"$(signer_line agent)"$'\n'
    put policy/access-grants.yaml "$GRANT"; commit_as agent "add me and grant"
    show
    [[ "$output" != *"/srv/t5031  (via"* ]]
}

@test "the operator adds a second key (signed by the first): grants signed by the second count" {
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'; commit_as op "adopt"
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'"$(signer_line op2)"$'\n'; commit_as op "add op2"
    put policy/access-grants.yaml "$GRANT"; commit_as op2 "grant by op2"
    granted
}

@test "removing the signers list voids the grants (no downgrade to the trailer rule)" {
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'
    put policy/access-grants.yaml "$GRANT"; commit_as op "adopt"
    git -C "$R" rm -q policy/grants-allowed-signers; commit_as none "drop list"
    show
    [[ "$output" == *"was removed"* ]]
}

@test "a grant last changed before signing was adopted must be re-committed signed" {
    put policy/access-grants.yaml "$GRANT"; commit_as none "legacy grant"
    put policy/grants-allowed-signers "$(signer_line op)"$'\n'; commit_as op "adopt later"
    show
    [[ "$output" == *"before signing was adopted"* ]]
}

@test "guards: the signers file is refused to typed writes and to an agent commit" {
    run python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import access_grants as a; print(a.is_grant_file_or_ancestor(sys.argv[2] + "/policy/grants-allowed-signers", sys.argv[2]))' "$_FW_ROOT/lib" "$R"
    [ "$output" = "True" ]
    put policy/grants-allowed-signers "$(signer_line agent)"$'\n'
    run env CLAUDECODE=1 bash -c "cd '$R' && bash '$_FW_ROOT/agents/git/lib/grant-file-guard.sh'"
    [ "$status" -eq 1 ]
}
