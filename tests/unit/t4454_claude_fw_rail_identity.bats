#!/usr/bin/env bats
# T-4454 — claude-fw must register its TermLink session with the PROJECT key.
#
# TermLink registration reads TERMLINK_IDENTITY_FILE with the same precedence as
# signing. claude-fw spawned claude-master-$$ without it, so the session carried the
# HOST identity while every signing path used the project's RAIL_IDENTITY_FILE.
# A fake termlink on PATH records the identity env it sees at `spawn`.
# Never set the variable for a missing key: TermLink would mint a keypair there.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    P="$T/proj"
    mkdir -p "$P" "$T/bin"
    cat > "$T/bin/termlink" <<EOF
#!/bin/bash
if [ "\$1" = spawn ]; then
    printf '%s' "\${TERMLINK_IDENTITY_FILE-<unset>}" > "$T/spawn-identity"
fi
exit 0
EOF
    chmod +x "$T/bin/termlink"
    PATH="$T/bin:$PATH"
    export FRAMEWORK_ROOT="$REPO" PROJECT_ROOT="$P"
    unset TERMLINK_IDENTITY_FILE FW_RAIL_IDENTITY_FILE TERMLINK_RUNTIME_DIR
    TERMLINK_ENABLED=1 _CFW_RESUMED=0
    source <(awk '/^_cfw_framework_dir\(\) \{/,/^}/; /^_cfw_lib\(\) \{/,/^}/; /^_fw_project_tag\(\) \{/,/^}/; /^_cfw_rail_identity\(\) \{/,/^}/; /^termlink_start\(\) \{/,/^}/' \
        "$REPO/bin/claude-fw")
    sleep() { :; }
}

teardown() { rm -rf "$T"; }

@test "T-4454: an existing project key is exported before registration" {
    echo "RAIL_IDENTITY_FILE: .context/rail-identity.key" > "$P/.framework.yaml"
    mkdir -p "$P/.context" && : > "$P/.context/rail-identity.key"
    termlink_start
    [ "$(cat "$T/spawn-identity")" = "$P/.context/rail-identity.key" ]
}

@test "T-4454: the FW_RAIL_IDENTITY_FILE env tier wins over .framework.yaml" {
    echo "RAIL_IDENTITY_FILE: .context/rail-identity.key" > "$P/.framework.yaml"
    : > "$T/env.key"
    FW_RAIL_IDENTITY_FILE="$T/env.key" termlink_start
    [ "$(cat "$T/spawn-identity")" = "$T/env.key" ]
}

@test "T-4454: a configured but MISSING key is never exported, and no keypair is created" {
    echo "RAIL_IDENTITY_FILE: .context/rail-identity.key" > "$P/.framework.yaml"
    run termlink_start
    [ "$status" -eq 0 ]
    [ "$(cat "$T/spawn-identity")" = "<unset>" ]
    [ ! -e "$P/.context/rail-identity.key" ]
    [[ "$output" == *"WARNING: RAIL_IDENTITY_FILE="*"does not exist"* ]]
}

@test "T-4454: no RAIL_IDENTITY_FILE configured leaves the identity unset" {
    : > "$P/.framework.yaml"
    termlink_start
    [ "$(cat "$T/spawn-identity")" = "<unset>" ]
}
