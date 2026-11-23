#!/usr/bin/env bats
# T-5372 — equal version strings are decided by commit ancestry.
#
# be-tags keep VERSION at the last release (T-3821), so a be-tag consumer and
# master share one version string. Before T-5372 fw_version_relation returned
# `same` on equal strings without looking at the recorded version_sha, and the
# direct-path precheck in lib/upgrade.sh was skipped on equal strings: a plain
# fw upgrade from master could silently roll a be-tag consumer back.
#
# Hermetic: the relation cases run against a throwaway git repo; the do_upgrade
# cases use a scratch commit reached through GIT_ALTERNATE_OBJECT_DIRECTORIES so
# the live repo's object store is never written. No network.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t5372-XXXXXX)"
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/version-relation.sh"

    # Repo layout:   c1 -- c2 (main HEAD)
    #                  \-- c3 (side)          c4 = child of c2 (ahead)
    R="$TEST_TEMP_DIR/repo"
    mkdir -p "$R"
    _g() { GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t git -C "$R" "$@"; }
    _g init -q -b main
    echo 1.8.15 > "$R/VERSION"
    _g add VERSION && _g commit -q -m c1
    C1=$(_g rev-parse HEAD)
    echo a > "$R/a" && _g add a && _g commit -q -m c2
    C2=$(_g rev-parse HEAD)
    _g checkout -q -b side "$C1"
    echo b > "$R/b" && _g add b && _g commit -q -m c3
    C3=$(_g rev-parse HEAD)
    _g checkout -q -b ahead "$C2"
    echo c > "$R/c" && _g add c && _g commit -q -m c4
    C4=$(_g rev-parse HEAD)
    _g checkout -q main
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ── Relation cases (equal version strings) ──

@test "T-5372: equal strings, sha == HEAD -> same" {
    fw_version_relation 1.8.15 1.8.15 "$C2" "$R" >/dev/null
    [ "$FW_VERSION_RELATION" = same ]
}

@test "T-5372: equal strings, sha ancestor of HEAD -> behind" {
    fw_version_relation 1.8.15 1.8.15 "$C1" "$R" >/dev/null
    [ "$FW_VERSION_RELATION" = behind ]
}

@test "T-5372: equal strings, HEAD ancestor of sha -> ahead (the be-tag-from-master case)" {
    fw_version_relation 1.8.15 1.8.15 "$C4" "$R" >/dev/null
    [ "$FW_VERSION_RELATION" = ahead ]
    fw_version_relation_should_refuse "$FW_VERSION_RELATION"
}

@test "T-5372: equal strings, neither contains the other -> diverged" {
    fw_version_relation 1.8.15 1.8.15 "$C3" "$R" >/dev/null
    [ "$FW_VERSION_RELATION" = diverged ]
}

@test "T-5372: equal strings, no sha -> same (legacy consumers unchanged)" {
    fw_version_relation 1.8.15 1.8.15 "" "$R" >/dev/null
    [ "$FW_VERSION_RELATION" = same ]
}

@test "T-5372: equal strings, sha the source cannot resolve -> same (no new refusal)" {
    fw_version_relation 1.8.15 1.8.15 0123456789abcdef0123456789abcdef01234567 "$R" >/dev/null
    [ "$FW_VERSION_RELATION" = same ]
}

@test "T-5372: pin line names the commit when strings are equal" {
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
    run fw_upgrade_render_pin_line 1.8.15 1.8.15 ahead false
    [[ "$output" == *"AHEAD of v1.8.15 by commit; same version string"* ]]
    [[ "$output" == *"upgrade will refuse"* ]]
}

# ── Direct-path do_upgrade (live framework as an older same-VERSION source) ──

# Consumer pinned at the framework's own VERSION string, with a version_sha
# that is a CHILD of framework HEAD — i.e. the source is older than the consumer.
make_same_string_ahead_consumer() {
    local proj="$1"
    export PROJECT_ROOT="$proj"
    export FW_VERSION="1.8.15"
    mkdir -p "$proj/.agentic-framework/lib"
    echo "MARKER" > "$proj/.agentic-framework/lib/marker.sh"
    local objs="$TEST_TEMP_DIR/objects"
    mkdir -p "$objs"
    local live_objs
    live_objs="$(cd "$FRAMEWORK_ROOT" && cd "$(git rev-parse --git-common-dir)" && pwd)/objects"
    local sha
    sha=$(GIT_OBJECT_DIRECTORY="$objs" GIT_ALTERNATE_OBJECT_DIRECTORIES="$live_objs" \
          GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
          git -C "$FRAMEWORK_ROOT" commit-tree "HEAD^{tree}" -p HEAD -m "t5372 be-tag ahead")
    [ -n "$sha" ]
    export GIT_ALTERNATE_OBJECT_DIRECTORIES="$objs"
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.8.15
version_sha: $sha
provider: claude
YAML
}

@test "T-5372: direct fw upgrade --dry-run from an older same-VERSION source is REFUSED naming --force-downgrade" {
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
    local proj="$TEST_TEMP_DIR/consumer"
    make_same_string_ahead_consumer "$proj"
    run do_upgrade "$proj" --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"ahead"* ]]
    [[ "$output" == *"--force-downgrade"* ]]
    [ "$(cat "$proj/.agentic-framework/lib/marker.sh")" = MARKER ]
}

@test "T-5372: same source with --force-downgrade proceeds past the precheck" {
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
    local proj="$TEST_TEMP_DIR/consumer"
    make_same_string_ahead_consumer "$proj"
    run do_upgrade "$proj" --dry-run --force-downgrade
    [[ "$output" != *"REFUSED"* ]]
    [[ "$output" == *"--force-downgrade given, proceeding anyway"* ]]
    [[ "$output" == *"DRY RUN"* ]]
}

@test "T-5372: consumer on framework HEAD with equal strings is not refused" {
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
    local proj="$TEST_TEMP_DIR/consumer"
    export PROJECT_ROOT="$proj" FW_VERSION="1.8.15"
    mkdir -p "$proj/.agentic-framework/lib"
    cat > "$proj/.framework.yaml" <<YAML
project_name: consumer
version: 1.8.15
version_sha: $(git -C "$FRAMEWORK_ROOT" rev-parse HEAD)
provider: claude
YAML
    run do_upgrade "$proj" --dry-run
    [[ "$output" != *"REFUSED  Consumer"* ]]
    [[ "$output" == *"(current)"* ]]
}
