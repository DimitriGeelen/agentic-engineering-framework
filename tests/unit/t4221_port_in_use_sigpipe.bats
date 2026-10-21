#!/usr/bin/env bats
# T-4221 — "is this port held?" must not read SIGPIPE as "free".
#
# bin/watchtower.sh runs under `set -euo pipefail`. port_in_use was
# `ss -tlnp | grep -q ":$port "`: on a busy host ss prints ~250 KB, grep -q
# exits at the first match, ss takes SIGPIPE, the pipeline returns 141, and the
# allocator handed out a port another Watchtower already held (t3662 reds).
# lib/watchtower.sh:_watchtower_port_listening had the same idiom.
#
# Each function is extracted from its file and run against a stub `ss` that
# prints the held port's line FIRST and then a large tail, under pipefail.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEST_TEMP_DIR/bin"
    cat > "$TEST_TEMP_DIR/bin/ss" <<'SS'
#!/usr/bin/env bash
echo "State  Recv-Q Send-Q Local Address:Port Peer Address:Port Process"
echo "LISTEN 0      128          0.0.0.0:45678      0.0.0.0:*"
for i in $(seq 1 6000); do
    echo "LISTEN 0      128          0.0.0.0:$((20000 + i))      0.0.0.0:*    users:((\"filler\",pid=$i,fd=3))"
done
SS
    chmod +x "$TEST_TEMP_DIR/bin/ss"
}

teardown() {
    rm -rf "${TEST_TEMP_DIR:?}"
}

# _check FILE FUNC PORT — define FUNC from FILE, call it under pipefail with the
# stub ss first on PATH. Prints held / free.
_check() {
    local def
    def=$(sed -n "/^$2() {/,/^}/p" "$1")
    [ -n "$def" ] || { echo "no $2 in $1"; return 2; }
    PATH="$TEST_TEMP_DIR/bin:$PATH" bash -c "set -euo pipefail; $def
if $2 $3; then echo held; else echo free; fi"
}

@test "T-4221: bin/watchtower.sh port_in_use sees a port listed first in a large ss output" {
    run _check "$FRAMEWORK_ROOT/bin/watchtower.sh" port_in_use 45678
    [ "$status" -eq 0 ]
    [ "$output" = "held" ]
}

@test "T-4221: lib/watchtower.sh _watchtower_port_listening sees a port listed first in a large ss output" {
    run _check "$FRAMEWORK_ROOT/lib/watchtower.sh" _watchtower_port_listening 45678
    [ "$status" -eq 0 ]
    [ "$output" = "held" ]
}

@test "T-4221: control — a port not in the ss output is still free" {
    run _check "$FRAMEWORK_ROOT/bin/watchtower.sh" port_in_use 45679
    [ "$output" = "free" ]
    run _check "$FRAMEWORK_ROOT/lib/watchtower.sh" _watchtower_port_listening 45679
    [ "$output" = "free" ]
}

@test "T-4221: control — a port that is only a prefix of a listed one is free" {
    run _check "$FRAMEWORK_ROOT/bin/watchtower.sh" port_in_use 4567
    [ "$output" = "free" ]
}
