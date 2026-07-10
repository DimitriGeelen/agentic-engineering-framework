#!/usr/bin/env bats
# T-2521: fw designer sync — sha256 verify/reject/install contract.
#
# The whole point of `fw designer sync` is that AEF never vendors a build whose
# checksum doesn't match the pin (policy/designer-pin.yaml). These tests pin that
# contract with a throwaway PROJECT_ROOT + a fixture pin, so the accept path is
# guarded even before the real 0.1.0 build is delivered by 832.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO/agents/designer/designer.sh"
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/policy" "$ROOT/bin"
    # minimal fw shim so `fw watchtower url` inside the script doesn't explode
    printf '#!/usr/bin/env bash\necho "http://localhost:3000"\n' > "$ROOT/bin/fw"
    chmod +x "$ROOT/bin/fw"
    # fixture artifact + a pin whose sha256 matches it
    printf 'DESIGNER-BUILD-FIXTURE' > "$ROOT/artifact.html"
    FIX_SHA="$(sha256sum "$ROOT/artifact.html" | cut -d' ' -f1)"
    cat > "$ROOT/policy/designer-pin.yaml" <<EOF
version: "9.9.9"
sha256: "$FIX_SHA"
bytes: 22
vendored_path: "vendor/designer/fixture.html"
EOF
}

teardown() { rm -rf "$ROOT"; }

@test "sync installs a matching artifact read-only" {
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from "$ROOT/artifact.html"
    [ "$status" -eq 0 ]
    [ -f "$ROOT/vendor/designer/fixture.html" ]
    # installed copy is byte-identical
    run diff "$ROOT/artifact.html" "$ROOT/vendor/designer/fixture.html"
    [ "$status" -eq 0 ]
    # and read-only (no write bit)
    perms="$(stat -c '%a' "$ROOT/vendor/designer/fixture.html")"
    [ "$perms" = "444" ]
}

@test "sync REJECTS a mismatched artifact (exit 1, nothing installed)" {
    printf 'TAMPERED' > "$ROOT/bad.html"
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from "$ROOT/bad.html"
    [ "$status" -eq 1 ]
    [[ "$output" == *"MISMATCH"* ]]
    [ ! -f "$ROOT/vendor/designer/fixture.html" ]
}

@test "sync requires --from" {
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync
    [ "$status" -eq 2 ]
}

@test "status reports NOT SYNCED before install, PRESENT after" {
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOT SYNCED"* ]]
    env PROJECT_ROOT="$ROOT" bash "$SCRIPT" sync --from "$ROOT/artifact.html"
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"PRESENT"* ]]
}
