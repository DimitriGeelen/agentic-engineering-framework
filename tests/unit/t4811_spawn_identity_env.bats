#!/usr/bin/env bats
# T-4811 — claude-fw must hand the project TermLink identity to the spawned session.
#
# T-4454 exports TERMLINK_IDENTITY_FILE in claude-fw's own shell, but the tmux spawn
# backend starts the session on a tmux server that does not inherit the caller's
# environment, so the session's register process signed with the HOST key (832 field
# report on be.31). termlink spawn takes --env KEY=VALUE; claude-fw must pass the key
# path there. A fake termlink on PATH records its argv; no real termlink or tmux runs.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    P="$T/proj"
    mkdir -p "$P" "$T/bin"
    cat > "$T/bin/termlink" <<EOF
#!/bin/bash
if [ "\$1" = spawn ]; then
    printf '%s\n' "\$@" > "$T/spawn-argv"
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

@test "T-4811: an existing project key is passed to termlink spawn as --env" {
    echo "RAIL_IDENTITY_FILE: .context/rail-identity.key" > "$P/.framework.yaml"
    mkdir -p "$P/.context" && : > "$P/.context/rail-identity.key"
    termlink_start
    grep -qx -- "--env" "$T/spawn-argv"
    grep -qx -- "TERMLINK_IDENTITY_FILE=$P/.context/rail-identity.key" "$T/spawn-argv"
}

@test "T-4811: a key path with spaces stays one --env argument" {
    mkdir -p "$T/key dir" && : > "$T/key dir/id.key"
    : > "$P/.framework.yaml"
    FW_RAIL_IDENTITY_FILE="$T/key dir/id.key" termlink_start
    grep -qx -- "TERMLINK_IDENTITY_FILE=$T/key dir/id.key" "$T/spawn-argv"
}

@test "T-4811: no project key leaves the spawn call without --env" {
    : > "$P/.framework.yaml"
    termlink_start
    [ -s "$T/spawn-argv" ]
    ! grep -q -- "--env" "$T/spawn-argv" || false
    ! grep -q "TERMLINK_IDENTITY_FILE" "$T/spawn-argv" || false
}

@test "T-4811: a configured but missing key adds no --env" {
    echo "RAIL_IDENTITY_FILE: .context/rail-identity.key" > "$P/.framework.yaml"
    run termlink_start
    [ "$status" -eq 0 ]
    ! grep -q -- "--env" "$T/spawn-argv" || false
    [ ! -e "$P/.context/rail-identity.key" ]
}
