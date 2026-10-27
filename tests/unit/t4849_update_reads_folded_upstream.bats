#!/usr/bin/env bats
# T-4849: the upstream_repo readers grepped `^upstream_repo:` and sed-stripped
# the key, so a value that `fw config set` (pre-T-3735) folded onto a
# continuation line read as '' and `fw update` failed "No upstream_repo". Since
# T-4847 a later `fw config set` no longer re-dumps (and so unfolds) the file,
# so a still-folded file stays folded. The readers must return the full value
# however the line is laid out.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LONG_URL="https://example.invalid/some/very/long/path/to/the/agentic-engineering-framework-repository.git"

setup() {
    TEST_DIR="$(mktemp -d "${BATS_TMPDIR:-/tmp}/t4849.XXXXXX")"
    export FRAMEWORK_ROOT PROJECT_ROOT="$TEST_DIR" NO_COLOR=1
}

teardown() {
    rm -rf "$TEST_DIR"
}

_folded()  { printf 'project_name: t4849\nupstream_repo:\n  %s\nversion: 1.0.0\n' "$LONG_URL" > "$TEST_DIR/.framework.yaml"; }
_quoted()  { printf 'project_name: t4849\nupstream_repo: "%s"\nversion: 1.0.0\n' "$LONG_URL" > "$TEST_DIR/.framework.yaml"; }
_squoted() { printf "project_name: t4849\nupstream_repo: '%s'\nversion: 1.0.0\n" "$LONG_URL" > "$TEST_DIR/.framework.yaml"; }
_plain()   { printf 'project_name: t4849\nupstream_repo: %s\nversion: 1.0.0\n' "$LONG_URL" > "$TEST_DIR/.framework.yaml"; }

_run_update() {
    mkdir -p "$TEST_DIR/.agentic-framework"
    echo 1.0.0 > "$TEST_DIR/.agentic-framework/VERSION"
    bash -c 'source "$FRAMEWORK_ROOT/lib/colors.sh"; source "$FRAMEWORK_ROOT/lib/errors.sh";
             source "$FRAMEWORK_ROOT/lib/compat.sh"; source "$FRAMEWORK_ROOT/lib/update.sh";
             do_update --check' 2>&1
}

@test "fw update finds a folded upstream_repo (continuation line)" {
    _folded
    out=$(_run_update || true)
    [[ "$out" != *"No upstream_repo"* ]]
    [[ "$out" == *"$LONG_URL"* ]]
}

@test "fw update finds plain, double- and single-quoted upstream_repo" {
    for layout in _plain _quoted _squoted; do
        $layout
        out=$(_run_update || true)
        [[ "$out" != *"No upstream_repo"* ]]
        [[ "$out" == *"$LONG_URL"* ]]
        [[ "$out" != *"\"$LONG_URL"* ]]
        [[ "$out" != *"'$LONG_URL"* ]]
    done
}

@test "fw update still reports a genuinely missing upstream_repo" {
    printf 'project_name: t4849\n' > "$TEST_DIR/.framework.yaml"
    out=$(_run_update || true)
    [[ "$out" == *"No upstream_repo"* ]]
}

@test "fw upstream resolves a folded upstream_repo" {
    _folded
    run bash -c 'source "$FRAMEWORK_ROOT/lib/colors.sh" 2>/dev/null; source "$FRAMEWORK_ROOT/lib/upstream.sh"; _upstream_resolve_repo'
    [ "$output" = "$LONG_URL" ]
}

@test "no line-wise grep|sed reader of upstream_repo remains in lib/ or bin/fw" {
    run grep -nE "grep [\"']\^upstream_repo:[\"'] .*\| *sed" "$FRAMEWORK_ROOT/lib" -r "$FRAMEWORK_ROOT/bin/fw"
    [ "$status" -eq 1 ]
}
