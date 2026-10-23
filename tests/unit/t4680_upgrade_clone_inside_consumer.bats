#!/usr/bin/env bats
# T-4680: `fw upgrade` run through a framework clone placed INSIDE the consumer
# tree upgrades from that clone and pins its HEAD (the tag commit).
#
# Field report (ring20, be.4): a clone at a tag inside the consumer was taken as
# bare-from-consumer and `upstream_repo`'s default branch was auto-cloned instead;
# the same clone outside the project worked. Cause: the consumer's agent session
# inherits FRAMEWORK_ROOT=<consumer>/.agentic-framework, and the T-4362 rule in
# bin/fw dropped that inherited value only for a checkout OUTSIDE the project.
#
# Fixture: a framework repo with a tag, moved on past the tag; the consumer's
# vendored copy is a clone of the moved-on HEAD, and fw-src/ inside the consumer is
# a clone at the tag. lib/upgrade.sh is a stub that reports FRAMEWORK_ROOT and calls
# the REAL pin writer (lib/version-relation.sh:fw_record_version_sha), so a
# bare-from-consumer run shows up as FRAMEWORK_ROOT = the vendored copy.

setup() {
    _FW_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    [ -f "$_FW_ROOT/bin/fw" ] || skip "fw not found"

    TEST_ROOT="$(mktemp -d)"
    UP="$TEST_ROOT/upstream"
    CONSUMER="$TEST_ROOT/consumer"
    SRC="$CONSUMER/fw-src"
    VENDORED="$CONSUMER/.agentic-framework"

    mkdir -p "$UP/bin" "$UP/lib" "$UP/agents" "$UP/.tasks"
    echo "keep" > "$UP/.tasks/.keep"
    echo "keep" > "$UP/agents/.keep"
    echo "# fixture framework" > "$UP/FRAMEWORK.md"
    cp "$_FW_ROOT/bin/fw" "$UP/bin/fw"
    chmod +x "$UP/bin/fw"
    cp "$_FW_ROOT"/lib/*.sh "$_FW_ROOT"/lib/*.py "$UP/lib/" 2>/dev/null || true
    : > "$UP/lib/init.sh"
    cat > "$UP/lib/upgrade.sh" <<'STUB'
do_upgrade() {
    echo "UPGRADE-FRAMEWORK_ROOT=$FRAMEWORK_ROOT"
    source "$FRAMEWORK_ROOT/lib/version-relation.sh"
    fw_record_version_sha "$1/.framework.yaml" "$FRAMEWORK_ROOT"
}
STUB
    echo "1.0.0" > "$UP/VERSION"
    git -C "$UP" init -q
    git -C "$UP" config user.email t@t
    git -C "$UP" config user.name t
    git -C "$UP" add -A
    git -C "$UP" commit -qm "release"
    git -C "$UP" tag v1.0.0
    TAG_SHA=$(git -C "$UP" rev-parse v1.0.0)
    echo "2.0.0-dev" > "$UP/VERSION"
    git -C "$UP" commit -qam "post-release work"
    HEAD_SHA=$(git -C "$UP" rev-parse HEAD)

    mkdir -p "$CONSUMER/.context/working"
    git clone -q "$UP" "$VENDORED"
    git clone -q --branch v1.0.0 "$UP" "$SRC" 2>/dev/null
    printf 'project_name: consumer\nversion_sha: unset\nupstream_repo: %s\n' "$UP" > "$CONSUMER/.framework.yaml"
}

teardown() {
    [ -n "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

_clean() {
    env -u CLAUDE_PROJECT_DIR -u PROJECT_ROOT -u FRAMEWORK_ROOT \
        -u FW_REEXEC_DEPTH -u FW_NO_REEXEC "$@"
}

_pin() { grep "^version_sha:" "$CONSUMER/.framework.yaml" | sed 's/^version_sha:[[:space:]]*//'; }

@test "fixture sanity: the tag, the vendored copy and the in-tree clone are what they claim" {
    [ "$TAG_SHA" != "$HEAD_SHA" ]
    [ "$(git -C "$SRC" rev-parse HEAD)" = "$TAG_SHA" ]
    [ "$(git -C "$VENDORED" rev-parse HEAD)" = "$HEAD_SHA" ]
}

@test "in-tree clone, consumer agent env (inherited vendored FRAMEWORK_ROOT): upgrades from the clone, pins the tag" {
    run _clean env FRAMEWORK_ROOT="$VENDORED" PROJECT_ROOT="$CONSUMER" \
        bash -c "cd '$CONSUMER' && '$SRC/bin/fw' upgrade '$CONSUMER' 2>&1"
    [[ "$output" == *"UPGRADE-FRAMEWORK_ROOT=$SRC"* ]]
    [[ "$output" == *"upgrading from the framework checkout inside the project: $SRC"* ]]
    [ "$(_pin)" = "$TAG_SHA" ]
}

@test "in-tree clone, inherited env, run from inside the clone: pins the tag" {
    run _clean env FRAMEWORK_ROOT="$VENDORED" PROJECT_ROOT="$CONSUMER" \
        bash -c "cd '$SRC' && ./bin/fw upgrade '$CONSUMER' 2>&1"
    [[ "$output" == *"UPGRADE-FRAMEWORK_ROOT=$SRC"* ]]
    [ "$(_pin)" = "$TAG_SHA" ]
}

@test "in-tree clone, plain shell (no inherited env), from the consumer: pins the tag with the notice" {
    run _clean bash -c "cd '$CONSUMER' && '$SRC/bin/fw' upgrade '$CONSUMER' 2>&1"
    [[ "$output" == *"UPGRADE-FRAMEWORK_ROOT=$SRC"* ]]
    [[ "$output" == *"upgrading from the framework checkout inside the project: $SRC"* ]]
    [ "$(_pin)" = "$TAG_SHA" ]
}

@test "control: the consumer's vendored bin/fw still resolves to the vendored copy (bare-from-consumer path)" {
    run _clean env FRAMEWORK_ROOT="$VENDORED" PROJECT_ROOT="$CONSUMER" \
        bash -c "cd '$CONSUMER' && '$VENDORED/bin/fw' upgrade '$CONSUMER' 2>&1"
    [[ "$output" == *"UPGRADE-FRAMEWORK_ROOT=$VENDORED"* ]]
    [[ "$output" != *"checkout inside the project"* ]] || false
    run _clean bash -c "cd '$CONSUMER' && '$VENDORED/bin/fw' upgrade '$CONSUMER' 2>&1"
    [[ "$output" == *"UPGRADE-FRAMEWORK_ROOT=$VENDORED"* ]]
}
