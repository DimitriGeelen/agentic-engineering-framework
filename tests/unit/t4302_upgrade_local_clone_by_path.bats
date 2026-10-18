#!/usr/bin/env bats
# T-4302: the bare `fw upgrade` auto-clone of a LOCAL upstream must go by path.
# T-3886 switched that clone to full history with --filter=blob:none. Over
# file:// git ignores the filter and packs the whole framework history on every
# upgrade: ~40 s wall and ~58 s CPU on the 12k-commit repo, against ~9 s for the
# old --depth=1. The t2912 file runs six upgrades and went over its 900 s budget.
# A path clone keeps the full history (T-3886's origin guard still sees the pin)
# and skips the pack transfer. This test pins the clone argv, not a timing.
#
# Fixture: same shape as t3886 (framework runtime snapshot, consumer pins an older
# commit), but the git clone calls are logged by a shim so the argv is observable.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4302-XXXXXX)"
    export FRAMEWORK_ROOT
    local g=(git -c user.name=t4302 -c user.email=t4302@example.invalid)
    local wt snap="$TEST_TEMP_DIR/snap"
    wt="$(git -C "$FRAMEWORK_ROOT" stash create 2>/dev/null || true)"
    [ -n "$wt" ] || wt="HEAD"
    mkdir -p "$snap"
    git -C "$FRAMEWORK_ROOT" archive "$wt" bin lib agents policy web templates VERSION FRAMEWORK.md \
        | tar -x -C "$snap"
    git init -q "$TEST_TEMP_DIR/src"
    cp -a "$snap/." "$TEST_TEMP_DIR/src/"
    "${g[@]}" -C "$TEST_TEMP_DIR/src" add -A
    "${g[@]}" -C "$TEST_TEMP_DIR/src" commit -q -m "release 1"
    PIN="$(git -C "$TEST_TEMP_DIR/src" rev-parse HEAD)"
    echo 2 > "$TEST_TEMP_DIR/src/.t4302-marker"
    "${g[@]}" -C "$TEST_TEMP_DIR/src" add -A
    "${g[@]}" -C "$TEST_TEMP_DIR/src" commit -q -m "release 2"
    git clone -q --bare "$TEST_TEMP_DIR/src" "$TEST_TEMP_DIR/up.git"
    UPSTREAM="$TEST_TEMP_DIR/up.git"

    # git shim: logs the argv of every `clone`, then runs the real git.
    local real shim="$TEST_TEMP_DIR/shim"
    real="$(command -v git)"
    mkdir -p "$shim"
    cat > "$shim/git" <<SH
#!/bin/bash
case " \$* " in *" clone "*) printf '%s\n' "\$*" >> "$TEST_TEMP_DIR/clone.log" ;; esac
exec "$real" "\$@"
SH
    chmod +x "$shim/git"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Behind consumer: vendored shallow copy of UPSTREAM + .framework.yaml pinning PIN.
make_behind_consumer() {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj"
    git clone -q --depth=1 "file://$UPSTREAM" "$proj/.agentic-framework"
    cat > "$proj/.framework.yaml" <<YAML
project_name: proj
version: 1.8.0
version_sha: $PIN
provider: claude
upstream_repo: file://$UPSTREAM
YAML
    echo "$proj"
}

# Run the consumer's vendored fw upgrade with the logging git shim first on PATH.
run_upgrade_with_shim() {
    local proj="$1"
    (cd "$proj" && env -i \
        PATH="$TEST_TEMP_DIR/shim:/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        GIT_CEILING_DIRECTORIES="$(dirname "$TEST_TEMP_DIR")" \
        "$proj/.agentic-framework/bin/fw" upgrade "$proj") >/dev/null 2>&1 || true
}

@test "t4302: the auto-clone of a local upstream is observed by the git shim (fixture is not vacuous)" {
    local proj
    proj="$(make_behind_consumer)"
    run_upgrade_with_shim "$proj"
    [ -s "$TEST_TEMP_DIR/clone.log" ]
    grep -q "$UPSTREAM\|file://" "$TEST_TEMP_DIR/clone.log"
}

@test "t4302: the auto-clone goes by path: no file:// transport, no --filter pack on a local source" {
    local proj
    proj="$(make_behind_consumer)"
    run_upgrade_with_shim "$proj"
    [ -s "$TEST_TEMP_DIR/clone.log" ]
    # Pre-fix argv: `clone --filter=blob:none --quiet file:///…/up.git /tmp/…/fw`.
    # Counts, not `! grep`: bats does not fail a test on a negated line mid-body.
    [ "$(grep -c 'file://' "$TEST_TEMP_DIR/clone.log")" -eq 0 ]
    [ "$(grep -c -- '--filter' "$TEST_TEMP_DIR/clone.log")" -eq 0 ]
    [ "$(grep -c -- "$UPSTREAM" "$TEST_TEMP_DIR/clone.log")" -ge 1 ]
}
