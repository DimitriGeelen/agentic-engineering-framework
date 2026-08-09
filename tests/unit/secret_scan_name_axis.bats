#!/usr/bin/env bats
# T-2897: the secret scanner's name axis.
#
# The content axis keys on vendor-prefixed credentials. `secrets.token_hex(32)`
# has no vendor prefix, so the one class of secret the framework PRODUCES is the
# class content scanning cannot see. These tests pin the second axis: tracked
# FILENAMES.
#
# Every "does not fire" test in here is only worth something because the tests
# above it prove the scanner fires at all. The failure mode this guards against
# is a check that silently answers "clean" to everything — which is exactly what
# printed [PASS] Secret scan: tracked tree clean across a two-month exposure.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    cd "$TEST_TEMP_DIR"
    git init -q .
    git config user.email t@t; git config user.name t
    source "$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"
}

teardown() {
    cd /
    rm -rf "$TEST_TEMP_DIR"
    unset PROJECT_ROOT
}

track() {   # create + stage, so git ls-files sees it
    mkdir -p "$(dirname "$1")"
    printf '%s\n' "${2:-x}" > "$1"
    git add -f "$1"
}

# --- the actual file, at its actual path ------------------------------------

@test "name-axis: fires on .fw-secret-key at its real path (T-2897)" {
    track .context/working/.fw-secret-key "deadbeef"
    run scan_names
    [ "$status" -eq 1 ]
    [[ "$output" == *"name:DEFINITIVE"* ]]
    [[ "$output" == *".context/working/.fw-secret-key"* ]]
}

@test "name-axis: an UNTRACKED key is not a leak" {
    # This is the normal, correct end state of T-2896's gitignore rules.
    # A scanner that flags it would train people to ignore it.
    mkdir -p .context/working
    echo deadbeef > .context/working/.fw-secret-key
    run scan_names
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "name-axis: fires on a key nested under a vendored copy" {
    track .agentic-framework/.context/working/.fw-secret-key
    run scan_names
    [ "$status" -eq 1 ]
    [[ "$output" == *".agentic-framework/.context/working/.fw-secret-key"* ]]
}

@test "name-axis: fires on private-key extensions" {
    track deploy.pem
    track store.jks
    run scan_names
    [ "$status" -eq 1 ]
    [[ "$output" == *"deploy.pem"* ]]
    [[ "$output" == *"store.jks"* ]]
}

@test "name-axis: qualifier+noun pair fires as ANNOUNCED, labelled as a guess" {
    track config/auth-token.json
    run scan_names
    [ "$status" -eq 1 ]
    [[ "$output" == *"name:ANNOUNCED"* ]]
}

# --- false-positive controls: the reason a check survives contact ----------

@test "name-axis: silent on the scanner's own source and its tests" {
    # 832's control. A check that cries wolf on the code implementing it gets
    # reverted, and then nothing is watching the axis at all.
    track agents/git/lib/secret-scan.sh
    track lib/secrets_store.py
    track tests/unit/secret_key_gitignore.bats
    run scan_names
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "name-axis: 'token' alone is not a signal (832 measured 17/17 false)" {
    track reports/token-budget-2026-08.yaml
    track web/static/design-tokens.json
    track .tasks/completed/T-2277-csrf-token-rca.md
    run scan_names
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "name-axis: prose about secrets is not a secret" {
    track docs/secret-key-rotation-guide.md
    track docs/private-key-handling.rst
    run scan_names
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "name-axis: 'credentials' as a compound suffix is prose, as a stem is a store" {
    # First cut had `credential` as both qualifier and noun, so one word
    # completed the pair and three fabric cards describing credential-handling
    # source were flagged. Both directions pinned here.
    track .fabric/components/lib-url-credentials.yaml
    run scan_names
    [ "$status" -eq 0 ]

    track config/credentials.json
    run scan_names
    [ "$status" -eq 1 ]
    [[ "$output" == *"credentials.json"* ]]
}

# --- the wiring: this is the anti-false-green assertion ---------------------

@test "name-axis: scan_tree FAILS on a tracked key with clean content (T-2897)" {
    # The point of the task. scan-tree is the surface that printed
    # "[PASS] Secret scan: tracked tree clean" for two months. Its content axis
    # sees nothing here — 'deadbeef' matches no vendor pattern — so if the name
    # axis were wired anywhere else, this would still come back PASS.
    mkdir -p .secret-scan-cfg
    printf 'aws-akia\tAKIA[0-9A-Z]{16}\n' > .secret-scan-patterns
    track .context/working/.fw-secret-key "deadbeef"

    run scan_tree
    [ "$status" -eq 1 ]
    [[ "$output" == *".fw-secret-key"* ]]
}

@test "name-axis: scan_tree still PASSES on a tree with neither axis tripped" {
    printf 'aws-akia\tAKIA[0-9A-Z]{16}\n' > .secret-scan-patterns
    track src/app.py "print('hello')"
    run scan_tree
    [ "$status" -eq 0 ]
}

# --- and the live tree, with no exemptions ---------------------------------

@test "name-axis: this repo is clean with an empty allowlist" {
    # A check needing exemptions on day one has the wrong threshold.
    cd "$FRAMEWORK_ROOT"
    PROJECT_ROOT="$FRAMEWORK_ROOT" run bash "$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh" scan-names
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- the gate, not just the audit -----------------------------------------

@test "name-axis: scan_staged REFUSES a commit that adds a key (T-2897)" {
    printf 'aws-akia\tAKIA[0-9A-Z]{16}\n' > .secret-scan-patterns
    track .context/working/.fw-secret-key "deadbeef"
    run scan_staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"name:DEFINITIVE"* ]]
}

@test "name-axis: scan_staged allows an ordinary staged file" {
    printf 'aws-akia\tAKIA[0-9A-Z]{16}\n' > .secret-scan-patterns
    track src/app.py "print(1)"
    run scan_staged
    [ "$status" -eq 0 ]
}

@test "name-axis: scan_staged does not re-flag an already-committed key on edit" {
    # Gating additions, not touches. A gate that fires on every subsequent edit
    # to an accepted path trains people to bypass it.
    printf 'aws-akia\tAKIA[0-9A-Z]{16}\n' > .secret-scan-patterns
    track .context/working/.fw-secret-key "old"
    git -c core.hooksPath=/dev/null commit -q -m "pre-existing" 2>/dev/null

    echo "rotated" > .context/working/.fw-secret-key
    git add -f .context/working/.fw-secret-key
    run scan_staged
    [ "$status" -eq 0 ]
}
