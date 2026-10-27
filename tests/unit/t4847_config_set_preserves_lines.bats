#!/usr/bin/env bats
# T-4847: `fw config set` loaded .framework.yaml through ruamel and re-dumped the
# whole file, so setting one key also rewrote unrelated lines — a folded
# `upstream_repo: >-` scalar came back collapsed onto one line (832 field report,
# be.43). Setting a key must change that key's line(s) only.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TEST_DIR="$(mktemp -d "${BATS_TMPDIR:-/tmp}/t4847.XXXXXX")"
    export PROJECT_ROOT="$TEST_DIR"
    export FRAMEWORK_ROOT
    cat > "$TEST_DIR/.framework.yaml" <<'YAML'
# Agentic Engineering Framework project config
project_name: t4847
version: "1.0.0"
upstream_repo: https://example.invalid/a/very/long/path/to/the/upstream/repository
  that/was/folded/by/an/earlier/dump.git
notes: >-
  a folded block scalar
  over two lines
PORT: 3001   # trailing comment

#   indented comment block
CONTEXT_WINDOW: 975000
watchtower:
  port: 3002
YAML
    cp "$TEST_DIR/.framework.yaml" "$TEST_DIR/before.yaml"
    unset FW_PORT FW_CONTEXT_WINDOW FW_DESIGNER_FIELD_CATALOG
}

teardown() {
    rm -rf "$TEST_DIR"
}

_cfg() {
    bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; source "$FRAMEWORK_ROOT/lib/config-file.sh"; do_config "$@"' _ "$@"
}

# The diff between before and after, without the ---/+++/@@ headers.
_changed() {
    diff -u "$TEST_DIR/before.yaml" "$TEST_DIR/.framework.yaml" | grep -E '^[-+]' | grep -vE '^(---|\+\+\+)'
}

@test "setting an existing key changes only that key's line" {
    run _cfg set CONTEXT_WINDOW 500000
    [ "$status" -eq 0 ]
    run _changed
    [ "$output" = "$(printf -- '-CONTEXT_WINDOW: 975000\n+CONTEXT_WINDOW: 500000')" ]
}

@test "setting a new key appends one line and leaves every other line byte-identical" {
    run _cfg set MY_NEW_KEY hello --force
    [ "$status" -eq 0 ]
    run _changed
    [ "$output" = "+MY_NEW_KEY: hello" ]
}

@test "the folded upstream_repo scalar survives a set on an unrelated key" {
    _cfg set PORT 3005
    grep -q '^upstream_repo: https://example.invalid/a/very/long/path/to/the/upstream/repository$' "$TEST_DIR/.framework.yaml"
    grep -q '^  that/was/folded/by/an/earlier/dump.git$' "$TEST_DIR/.framework.yaml"
    grep -q '^notes: >-$' "$TEST_DIR/.framework.yaml"
    grep -q '^# Agentic Engineering Framework project config$' "$TEST_DIR/.framework.yaml"
    grep -q '^version: "1.0.0"$' "$TEST_DIR/.framework.yaml"
    grep -q '^#   indented comment block$' "$TEST_DIR/.framework.yaml"
}

@test "replacing a block-scalar key replaces all of its lines" {
    run _cfg set notes plain --force
    [ "$status" -eq 0 ]
    run _changed
    [ "$output" = "$(printf -- '-notes: >-\n-  a folded block scalar\n-  over two lines\n+notes: plain')" ]
}

@test "replacing a folded key replaces all of its continuation lines" {
    run _cfg set upstream_repo https://example.invalid/short.git
    [ "$status" -eq 0 ]
    run _changed
    [ "$output" = "$(printf -- '-upstream_repo: https://example.invalid/a/very/long/path/to/the/upstream/repository\n-  that/was/folded/by/an/earlier/dump.git\n+upstream_repo: https://example.invalid/short.git')" ]
}

@test "a value that needs YAML quoting is quoted and reads back through fw config get and fw_config" {
    run _cfg set DESIGNER_FIELD_CATALOG 'a: b #c' --force
    [ "$status" -eq 0 ]
    python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); assert d["DESIGNER_FIELD_CATALOG"]=="a: b #c", d' "$TEST_DIR/.framework.yaml"
    run _cfg get DESIGNER_FIELD_CATALOG
    [ "$output" = "a: b #c" ]
    run bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; _fw_config_file_val DESIGNER_FIELD_CATALOG'
    [ "$output" = "a: b #c" ]
    # and the rest of the file is untouched
    run _changed
    [ "$(echo "$output" | grep -c '^-')" -eq 0 ]
}

@test "numeric and boolean values keep their YAML type; fw_config reads them" {
    _cfg set PORT 3009
    _cfg set MY_FLAG yes --force
    python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); assert d["PORT"]==3009 and d["MY_FLAG"] is True, d' "$TEST_DIR/.framework.yaml"
    run bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; fw_config PORT 3000'
    [ "$output" = "3009" ]
}

@test "a file without a trailing newline gets the appended key on its own line" {
    printf 'project_name: t4847' > "$TEST_DIR/.framework.yaml"
    _cfg set PORT 3010
    [ "$(cat "$TEST_DIR/.framework.yaml")" = "$(printf 'project_name: t4847\nPORT: 3010')" ]
}

@test "dotted keys still set the nested value" {
    run _cfg set watchtower.port 3011
    [ "$status" -eq 0 ]
    run _cfg get watchtower.port
    [ "$output" = "3011" ]
}
