#!/usr/bin/env bats
# T-2446: bin/fw trusts CLAUDE_PROJECT_DIR ONLY when the cwd is not genuinely inside
# a *different* real project. Origin: F10 / T-2441 dogfood — a TermLink shell rooted
# in a consumer (/opt/505) inherited CLAUDE_PROJECT_DIR=/opt/999 from the long-lived
# CC-spawned daemon and mis-resolved /opt/999's Watchtower. Same daemon-poison class
# T-2391 fixed for inherited PROJECT_ROOT, extended to CLAUDE_PROJECT_DIR via the
# shared _project_root_is_stale discriminator (=$HOME / no-marker = poison/hook).
#
# Surface under test: bin/fw "Resolve PROJECT_ROOT" block (CLAUDE_PROJECT_DIR branch).
# Observed via `fw version` ("Project: <root>").
#
# Dual-case (the two halves of the contract):
#   (a) CC-hook / $HOME-poison: cwd-root is $HOME (or no marker) → CLAUDE_PROJECT_DIR wins
#   (b) genuine consumer-cwd:  cwd-root is a real non-$HOME project ≠ CLAUDE_PROJECT_DIR → cwd wins
#
# t1 in t2390_project_root_claude_dir.bats pins case (a) from the other direction
# (CLAUDE_PROJECT_DIR preferred); this file pins the F10 inversion in (b).

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    # CONSUMER: a genuine, fully-provisioned project (.framework.yaml + .tasks),
    # non-$HOME — the /opt/505 analogue.
    CONSUMER="$(mktemp -d -t fw-t2446-consumer-XXXXXX)"
    mkdir -p "$CONSUMER/.tasks"
    printf 'version: test\n' > "$CONSUMER/.framework.yaml"

    # FOREIGN: a different valid project that a daemon leaked via CLAUDE_PROJECT_DIR
    # — the /opt/999 analogue.
    FOREIGN="$(mktemp -d -t fw-t2446-foreign-XXXXXX)"
    mkdir -p "$FOREIGN/.tasks"
    printf 'version: test\n' > "$FOREIGN/.framework.yaml"

    # A neutral HOME with no marker, distinct from CONSUMER, so the consumer cwd is
    # never mistaken for the $HOME-poison signature.
    NEUTRAL_HOME="$(mktemp -d -t fw-t2446-home-XXXXXX)"

    # POISON_HOME: the canonical CC-hook poison — a $HOME that carries a stray
    # .tasks (the /root/.tasks analogue) the $PWD walk would otherwise latch.
    POISON_HOME="$(mktemp -d -t fw-t2446-poison-XXXXXX)"
    mkdir -p "$POISON_HOME/.tasks"
}

teardown() {
    rm -rf "$CONSUMER" "$FOREIGN" "$NEUTRAL_HOME" "$POISON_HOME"
}

@test "t1 (b): genuine consumer cwd wins over a daemon-leaked CLAUDE_PROJECT_DIR (F10 fix)" {
    cd "$CONSUMER"
    run env -u PROJECT_ROOT HOME="$NEUTRAL_HOME" CLAUDE_PROJECT_DIR="$FOREIGN" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$CONSUMER"
    ! echo "$output" | grep -q "Project:.*$FOREIGN"
}

@test "t2 (a): \$HOME-stray-marker poison → CLAUDE_PROJECT_DIR still wins (T-2390/T-2391 preserved)" {
    cd "$POISON_HOME"
    run env -u PROJECT_ROOT HOME="$POISON_HOME" CLAUDE_PROJECT_DIR="$FOREIGN" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$FOREIGN"
    ! echo "$output" | grep -q "Project:.*$POISON_HOME"
}

@test "t3 (a): no ancestry marker (cwd=\$HOME, empty) → CLAUDE_PROJECT_DIR wins" {
    cd "$NEUTRAL_HOME"
    run env -u PROJECT_ROOT HOME="$NEUTRAL_HOME" CLAUDE_PROJECT_DIR="$FOREIGN" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$FOREIGN"
}

@test "t4: explicit PROJECT_ROOT still wins unconditionally (env contract intact)" {
    # The T-2446 change lives entirely inside the CLAUDE_PROJECT_DIR branch, which is
    # only reached when PROJECT_ROOT is empty/stale. A real (non-$HOME, marker) env
    # PROJECT_ROOT must short-circuit before any of it.
    cd "$CONSUMER"
    run env PROJECT_ROOT="$FOREIGN" HOME="$NEUTRAL_HOME" CLAUDE_PROJECT_DIR="$CONSUMER" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$FOREIGN"
}
