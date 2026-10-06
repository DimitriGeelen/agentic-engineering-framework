#!/usr/bin/env bats
# T-3965 (010 finding 17): `fw upgrade` step 2 copied .tasks/templates/*.md with a bare cp
# whenever they differed, so a consumer's customised default.md was lost on every upgrade.
# It now goes through lib/upgrade_template_sync.py (T-3955/T-3956). The shipped-hash list
# keeps the old behaviour for the case that needs it: an unstamped stale STOCK copy (every
# existing consumer, first time round) is still updated, because schema fields arrive that way.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export NO_COLOR=1
    UTS="$FRAMEWORK_ROOT/lib/upgrade_template_sync.py"
    KNOWN="$FRAMEWORK_ROOT/lib/upgrade_template_shipped.py"
    TPL="$FRAMEWORK_ROOT/.tasks/templates"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_old_default() {   # an earlier shipped default.md, different from the current one
    local rev
    for rev in $(git -C "$FRAMEWORK_ROOT" log --format=%H -- .tasks/templates/default.md); do
        git -C "$FRAMEWORK_ROOT" show "$rev:.tasks/templates/default.md" > "$1"
        cmp -s "$1" "$TPL/default.md" || return 0
    done
    return 1
}

@test "T-3965: the shipped-hash list holds the current hash of every task template" {
    run python3 - "$KNOWN" "$TPL" <<'PY'
import ast, hashlib, sys
from pathlib import Path
src = open(sys.argv[1]).read()
known = ast.literal_eval(src[src.index("{"):])
for f in sorted(Path(sys.argv[2]).glob("*.md")):
    rel = f".tasks/templates/{f.name}"
    assert hashlib.sha256(f.read_bytes()).hexdigest() in known.get(rel, []), rel
PY
    [ "$status" -eq 0 ]
}

@test "T-3965: helper — an unstamped earlier shipped version is UPDATED, not KEPT" {
    mkdir -p "$TEST_TEMP_DIR/.tasks/templates"
    _old_default "$TEST_TEMP_DIR/.tasks/templates/default.md" || skip "no earlier default.md in history"
    run python3 "$UTS" "$TEST_TEMP_DIR" "$TPL/default.md" .tasks/templates/default.md "--known=$KNOWN"
    [[ "$output" == "UPDATED "* ]]
    cmp -s "$TEST_TEMP_DIR/.tasks/templates/default.md" "$TPL/default.md"
}

@test "T-3965/control: without --known the same file is KEPT (the transition hazard)" {
    mkdir -p "$TEST_TEMP_DIR/.tasks/templates"
    _old_default "$TEST_TEMP_DIR/.tasks/templates/default.md" || skip "no earlier default.md in history"
    run python3 "$UTS" "$TEST_TEMP_DIR" "$TPL/default.md" .tasks/templates/default.md
    [[ "$output" == "KEPT "* ]]
}

@test "T-3965: fw upgrade keeps a customised template, updates a stale stock one, honours project_files" {
    C="$TEST_TEMP_DIR/consumer"
    mkdir -p "$C" && cd "$C" && git init -q && git config user.email t@t && git config user.name t
    "$FRAMEWORK_ROOT/bin/fw" init . >/dev/null 2>&1 || true
    [ -f "$C/.tasks/templates/inception.md" ] || { echo "fw init created no task templates"; false; }
    _old_default "$C/.tasks/templates/default.md"
    printf '\n<!-- 010: our own section -->\n' >> "$C/.tasks/templates/inception.md"
    printf '\n<!-- claimed -->\n' >> "$C/.tasks/templates/path-c-deep-dive.md"
    printf 'project_files:\n  - .tasks/templates/path-c-deep-dive.md\n' > "$C/.fwvendor-preserve.yaml"
    rm -f "$C/.context/upgrade-template-stamp.json"   # an existing consumer: nothing stamped yet

    run env PROJECT_ROOT="$C" timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$C"
    [[ "$output" == *"UPDATED"*".tasks/templates/default.md"* ]]
    [[ "$output" == *"KEPT"*".tasks/templates/inception.md"* ]]
    [[ "$output" == *"PRESERVED"*".tasks/templates/path-c-deep-dive.md"* ]]
    cmp -s "$C/.tasks/templates/default.md" "$TPL/default.md"
    grep -q '010: our own section' "$C/.tasks/templates/inception.md"
    cmp -s "$C/.tasks/templates/inception.md.upstream" "$TPL/inception.md"
    grep -q 'claimed' "$C/.tasks/templates/path-c-deep-dive.md"
}
