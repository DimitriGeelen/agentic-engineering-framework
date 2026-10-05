#!/usr/bin/env bats
# T-3906 — a consumer's OWN hooks are not a hook gap.
#
# 832 on 1.8.3 (2026-10-05): step 5 printed "PARTIAL  Hooks regenerated but
# gap remains: missing 0 hook(s): ." and the run ended "Upgrade PARTIAL",
# although every framework hook was present. Cause: _t2912_hook_gap added
# non-framework (project) hooks into the "stale" count; the regenerator
# CARRIES them, so every consumer with its own hooks regenerated on every
# upgrade ("N hardcoded paths") and then reported a gap it could never close,
# naming only the missing count.
#
# Real `fw upgrade` subprocess under env -i against a real vendored consumer,
# same harness shape as t2912_upgrade_hook_regen_convergence.bats. The
# upstream carries the WORKING-TREE lib/upgrade.sh so the test exercises the
# code under change, not the last commit.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t3906-XXXXXX)"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

fresh_run() {
    local proj="$1"; shift
    (cd "$proj" && env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        GIT_CEILING_DIRECTORIES="$(dirname "$TEST_TEMP_DIR")" \
        "$proj/.agentic-framework/bin/fw" "$@")
}

make_consumer() {
    WORK="$TEST_TEMP_DIR/upstream-work"
    BARE="$TEST_TEMP_DIR/upstream.git"
    PROJ="$TEST_TEMP_DIR/proj"
    git clone --quiet --shared "$FRAMEWORK_ROOT" "$WORK" 2>/dev/null
    cp "$FRAMEWORK_ROOT/lib/upgrade.sh" "$WORK/lib/upgrade.sh"
    (cd "$WORK" && git -c user.email=t@t -c user.name=t commit -qam "working-tree upgrade.sh" 2>/dev/null || true)
    git clone --quiet --bare "$WORK" "$BARE" 2>/dev/null
    mkdir -p "$PROJ"
    git clone --quiet --depth=1 "file://$BARE" "$PROJ/.agentic-framework" 2>/dev/null
    cat > "$PROJ/.framework.yaml" <<YAML
project_name: proj
version: 1.0.0
provider: claude
upstream_repo: file://$BARE
YAML
}

add_project_hook() {
    python3 - "$PROJ/.claude/settings.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.setdefault("hooks", {}).setdefault("PostToolUse", []).append(
    {"matcher": "Edit", "hooks": [{"type": "command", "command": "echo my-project-hook"}]})
json.dump(d, open(p, "w"), indent=2)
PY
}

@test "T-3906: a project hook does not make step 5 regenerate or end PARTIAL, and is kept" {
    make_consumer
    run fresh_run "$PROJ" upgrade "$PROJ"          # converge first
    [ -f "$PROJ/.claude/settings.json" ]
    add_project_hook

    run fresh_run "$PROJ" upgrade "$PROJ"
    [[ "$output" != *"hardcoded paths"* ]]
    [[ "$output" != *"gap remains"* ]]
    [[ "$output" == *"project hook(s) of your own kept as-is"* ]]
    grep -q "my-project-hook" "$PROJ/.claude/settings.json"
}

@test "T-3906: the PARTIAL line names every remaining component, not only 'missing'" {
    grep -q 'missing ${missing_count_after:-0}${missing_names_after:+ ($missing_names_after)}, stale paths ${stale_after:-0}, non-portable paths ${nonportable_after:-0}' \
        "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "T-3906: the gap detector returns project hooks as their own field, not inside stale" {
    grep -q "return stale, non_framework" "$FRAMEWORK_ROOT/lib/upgrade.sh"
    ! grep -q "return stale + non_framework" "$FRAMEWORK_ROOT/lib/upgrade.sh"
}
