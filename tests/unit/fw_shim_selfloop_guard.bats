#!/usr/bin/env bats
# T-1278: Shim self-loop guard
#
# When bin/fw inside a framework repo gets overwritten with fw-shim content,
# the shim's find_fw() walks up from CWD, finds bin/fw (itself), and exec's.
# Without the guard, this recurses forever until a wrapping timeout kills it.
#
# With the guard: shim detects that realpath($fw_path) == realpath($BASH_SOURCE)
# and exits 2 with a restore hint.

setup() {
    TMPDIR=$(mktemp -d)
    # Fake framework repo layout: FRAMEWORK.md + bin/fw (which is the shim)
    mkdir -p "$TMPDIR/bin"
    cp "$BATS_TEST_DIRNAME/../../bin/fw-shim" "$TMPDIR/bin/fw"
    chmod +x "$TMPDIR/bin/fw"
    touch "$TMPDIR/FRAMEWORK.md"
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "shim self-loop is detected and exits non-zero within 1 second" {
    # Run the shim from the fake repo root. It should find itself and abort.
    run timeout 1 bash -c "cd '$TMPDIR' && bin/fw version"

    # Must exit non-zero (guard triggered) — NOT timeout 124 (infinite loop)
    [ "$status" -ne 0 ]
    [ "$status" -ne 124 ]

    # Error message should include our guard string
    [[ "$output" == *"Shim self-loop detected"* ]]
    [[ "$output" == *"git checkout HEAD -- bin/fw"* ]]
}

@test "shim works normally when bin/fw is the real CLI" {
    # Replace bin/fw with a minimal real-CLI stand-in (not the shim)
    cat > "$TMPDIR/bin/fw" <<'EOF'
#!/bin/bash
echo "real-cli: $*"
EOF
    chmod +x "$TMPDIR/bin/fw"

    # Invoke via the shim (installed at ~/.local/bin equivalent)
    local shim="$TMPDIR/shim-fw"
    cp "$BATS_TEST_DIRNAME/../../bin/fw-shim" "$shim"
    chmod +x "$shim"

    run timeout 2 bash -c "cd '$TMPDIR' && '$shim' version"
    [ "$status" -eq 0 ]
    [[ "$output" == *"real-cli: version"* ]]
}
