#!/usr/bin/env bats
# T-2756: bare `fw upgrade` from a consumer auto-clones the upstream and hands off
# to the CLONE's bin/fw (T-1634). The downgrade guards (T-1839 pin, T-1912
# runtime) lived only in the child, so an upstream whose fw predates them — a
# master lagging the consumer's bleeding-edge commit, a stale fork, an old tag —
# silently downgraded the consumer. The parent now decides ahead/diverged against
# the clone's history before any of the clone's code runs.
#
# Fixture: upstream default branch `master` at commit A, `bleeding-edge` at B on
# top of it. The upstream bin/fw is GUARDLESS: it rewrites the pin to 1.0.0 and
# leaves a marker. The consumer pins B (ahead of master) or A (control: same).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
    local g=(git -c user.name=t2756 -c user.email=t2756@example.invalid)
    UP="$TEST_TEMP_DIR/upstream-src"
    MARKER="$TEST_TEMP_DIR/child-ran"
    mkdir -p "$UP/bin"
    cat > "$UP/bin/fw" <<STUB
#!/usr/bin/env bash
# A pre-T-1839 fw: no downgrade guard, rewrites the pin unconditionally.
touch "$MARKER"
sed -i 's/^version:.*/version: 1.0.0/' "\$PROJECT_ROOT/.framework.yaml"
exit 0
STUB
    chmod +x "$UP/bin/fw"
    echo 1.0.0 > "$UP/VERSION"
    git -C "$UP" init -q -b master
    "${g[@]}" -C "$UP" add -A
    "${g[@]}" -C "$UP" commit -q -m A
    SHA_A="$(git -C "$UP" rev-parse HEAD)"
    git -C "$UP" checkout -q -b bleeding-edge
    echo 2.0.0 > "$UP/VERSION"
    "${g[@]}" -C "$UP" commit -q -am B
    SHA_B="$(git -C "$UP" rev-parse HEAD)"
    git -C "$UP" checkout -q master
    PROJ="$TEST_TEMP_DIR/consumer"
    mkdir -p "$PROJ/.agentic-framework"
    (cd "$PROJ/.agentic-framework" && git init -q && touch FRAMEWORK.md && git add FRAMEWORK.md \
        && "${g[@]}" commit -q -m init)
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_pin() {   # _pin <version> <sha>
    printf 'project_name: c\nversion: %s\nversion_sha: %s\nupstream_repo: %s\n' "$1" "$2" "$UP" \
        > "$PROJ/.framework.yaml"
}

_bare_upgrade() {
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$PROJ/.agentic-framework"
    run do_upgrade "$@"
    FRAMEWORK_ROOT="$saved"
}

@test "T-2756: consumer ahead of the upstream clone is refused before the clone's fw runs" {
    _pin 2.0.0 "$SHA_B"
    _bare_upgrade "$PROJ"
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSED"*"ahead"* ]]
    [[ "$output" == *"--force-downgrade"* ]]
    [ ! -e "$MARKER" ]
    grep -qx 'version: 2.0.0' "$PROJ/.framework.yaml"
}

@test "T-2756: --force-downgrade still hands off (explicit operator bypass)" {
    _pin 2.0.0 "$SHA_B"
    _bare_upgrade "$PROJ" --force-downgrade
    [ "$status" -eq 0 ]
    [ -e "$MARKER" ]
}

@test "T-2756: control — a consumer the clone contains is handed off as before" {
    _pin 1.0.0 "$SHA_A"
    _bare_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    [[ "$output" != *"REFUSED"* ]]
    [ -e "$MARKER" ]
}
