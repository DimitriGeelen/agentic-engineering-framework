#!/usr/bin/env bats
# T-3735: `fw config set` dumped .framework.yaml at the YAML default width (80),
# so a long scalar (upstream_repo) was folded onto a continuation line. The
# line-wise reader in lib/update.sh (grep "^upstream_repo:" | sed) then read ''
# and `fw update` failed "No upstream_repo" — consumers fell releases behind.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LONG_URL="https://example.invalid/some/very/long/path/to/the/agentic-engineering-framework-repository.git"

setup() {
    TEST_DIR="$(mktemp -d "${BATS_TMPDIR:-/tmp}/t3735.XXXXXX")"
    export PROJECT_ROOT="$TEST_DIR"
    export FRAMEWORK_ROOT
    printf 'project_name: t3735\nupstream_repo: %s\n' "$LONG_URL" > "$TEST_DIR/.framework.yaml"
}

teardown() {
    rm -rf "$TEST_DIR"
}

_cfg() {
    bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; source "$FRAMEWORK_ROOT/lib/config-file.sh"; do_config "$@"' _ "$@"
}

# The exact reader lib/update.sh uses for upstream_repo.
_update_reader() {
    grep "^upstream_repo:" "$TEST_DIR/.framework.yaml" 2>/dev/null | sed 's/^upstream_repo:[[:space:]]*//' || true
}

@test "config set keeps a >80-char value on its key line (ruamel path)" {
    [ "${#LONG_URL}" -gt 80 ]
    run _cfg set CONTEXT_WINDOW 900000
    [ "$status" -eq 0 ]
    grep -q '^CONTEXT_WINDOW: 900000$' "$TEST_DIR/.framework.yaml"
    [ "$(_update_reader)" = "$LONG_URL" ]
}

@test "config set keeps a >80-char value on its key line (PyYAML fallback path)" {
    python3 -c 'import yaml' 2>/dev/null || skip "PyYAML not installed"
    # Shadow ruamel so the fallback branch runs.
    mkdir -p "$TEST_DIR/shim/ruamel"
    printf 'raise ImportError("hidden for T-3735")\n' > "$TEST_DIR/shim/ruamel/__init__.py"
    # T-4847: a flat key is now edited line-wise and never reaches the YAML dumper, so the
    # fallback dumper is exercised through a dotted (nested) key, which still round-trips.
    PYTHONPATH="$TEST_DIR/shim" run _cfg set watchtower.port 3009
    [ "$status" -eq 0 ]
    [[ "$output" == *"ruamel.yaml not installed"* ]]
    [ "$(_update_reader)" = "$LONG_URL" ]
    # ...and a flat key set under the same shadowing keeps the long value intact too.
    PYTHONPATH="$TEST_DIR/shim" run _cfg set CONTEXT_WINDOW 900000
    [ "$status" -eq 0 ]
    grep -q '^CONTEXT_WINDOW: 900000$' "$TEST_DIR/.framework.yaml"
    [ "$(_update_reader)" = "$LONG_URL" ]
}
