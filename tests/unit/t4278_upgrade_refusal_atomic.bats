#!/usr/bin/env bats
# T-4278: an upgrade that refuses must leave the consumer byte-identical.
#
# Origin: ring20 (ed683536a -> 112c098b9). The vendor step refused (T-3850: two
# local files under .agentic-framework/ not in .fwvendor-preserve.yaml) and wrote
# nothing — but step [1/10] had already rewritten the CLAUDE.md governance
# sections, so CLAUDE.md described the new budget ladder over the old code. The
# vendor refusal was also only a WARN, so steps 5-10 ran on top.
#
# Contract under test: do_upgrade runs the vendor's local-file verdict
# (do_vendor --precheck) before any step writes. Whole-tree hash, not a CLAUDE.md
# cmp, so a refusing check placed after ANY writing step fails here.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export NO_COLOR=1
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    git -C "$PROJ" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init
    _fw vendor --target "$PROJ" >/dev/null 2>&1
    [ -f "$PROJ/.agentic-framework/.fw-vendor-stamp.json" ]

    local ver
    ver=$(grep -m1 '^version:' "$FRAMEWORK_ROOT/.framework.yaml" 2>/dev/null | sed 's/^version:[[:space:]]*//')
    printf 'project_name: proj\nversion: %s\n' "${ver:-1.0.0}" > "$PROJ/.framework.yaml"

    # Stale governance: step 1 would want to rewrite it. Old template = stock, so
    # T-4232 does not refuse — only the vendor check can.
    {
        printf '# CLAUDE.md\n\n## Project Overview\n\n**Project:** proj\n\n'
        sed -n '/^## Core Principle$/,$ p' "$FRAMEWORK_ROOT/lib/templates/claude-project.md" | sed '$d'
    } > "$PROJ/CLAUDE.md"
    { sed -n '1,/^## Core Principle$/{ /^## Core Principle$/d; p; }' "$FRAMEWORK_ROOT/lib/templates/claude-project.md"
      sed -n '/^## Core Principle$/,$ p' "$PROJ/CLAUDE.md"; } > "$PROJ/.agentic-framework/lib/templates/claude-project.md"
    mkdir -p "$PROJ/.claude"
    printf '{\n  "hooks": {}\n}\n' > "$PROJ/.claude/settings.json"

    # The consumer-local file T-3850 protects (not in .fwvendor-preserve.yaml).
    echo "ring20 local blueprint" > "$PROJ/.agentic-framework/web/ring20_local.py"
}

teardown() {
    export HOME="$REAL_HOME"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_fw() {
    ( cd "$FRAMEWORK_ROOT" && env -u PROJECT_ROOT FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        FW_UNDECIDABLE_VERSION_PROCEED=1 "$FRAMEWORK_ROOT/bin/fw" "$@" )
}

# Every file and directory under the consumer (except .git), with content hashes.
_tree_hash() {
    ( cd "$PROJ" && find . -path ./.git -prune -o -print | LC_ALL=C sort | while IFS= read -r p; do
        if [ -f "$p" ]; then printf '%s %s\n' "$(sha256sum < "$p" | cut -d' ' -f1)" "$p"
        else printf 'dir %s\n' "$p"; fi
      done ) | sha256sum | cut -d' ' -f1
}

@test "T-4278: vendor local-file refusal refuses the whole upgrade before step 1 writes" {
    local before after
    before=$(_tree_hash)
    cp "$PROJ/CLAUDE.md" "$TEST_TEMP_DIR/claude.before"
    cp "$PROJ/.claude/settings.json" "$TEST_TEMP_DIR/settings.before"

    run _fw upgrade "$PROJ"
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"ring20_local.py"* ]]
    [[ "$output" != *"[1/10]"* ]]

    cmp "$PROJ/CLAUDE.md" "$TEST_TEMP_DIR/claude.before"
    cmp "$PROJ/.claude/settings.json" "$TEST_TEMP_DIR/settings.before"
    [ ! -e "$PROJ/CLAUDE.md.bak" ]
    after=$(_tree_hash)
    [ "$before" = "$after" ]
}

@test "T-4278: --allow-delete-locals passes the precheck and the upgrade runs step 1" {
    run _fw upgrade "$PROJ" --allow-delete-locals
    [[ "$output" == *"[1/10]"* ]]
    [[ "$output" != *"refused before any step"* ]]
    [ ! -e "$PROJ/.agentic-framework/web/ring20_local.py" ]
}

@test "T-4278: preserved local file passes the precheck" {
    # The stale vendored template (setup) is a local edit too; keep both.
    printf 'files:\n  - web/ring20_local.py\n  - lib/templates/claude-project.md\n' > "$PROJ/.fwvendor-preserve.yaml"
    run _fw upgrade "$PROJ"
    [[ "$output" == *"[1/10]"* ]]
    [ -f "$PROJ/.agentic-framework/web/ring20_local.py" ]
}

@test "T-4278: do_vendor --precheck writes nothing and reports the verdict" {
    local before
    before=$(_tree_hash)
    run _fw vendor --target "$PROJ" --precheck
    [ "$status" -ne 0 ]
    [ "$before" = "$(_tree_hash)" ]
    run _fw vendor --target "$PROJ" --precheck --allow-delete-locals
    [ "$status" -eq 0 ]
    [ "$before" = "$(_tree_hash)" ]
}
