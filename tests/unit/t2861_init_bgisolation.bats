#!/usr/bin/env bats
# T-2861: generate_claude_code_config (lib/init.sh) — the generator behind `fw init`
# and `fw upgrade` step 5 — must emit worktree.bgIsolation=none. T-3263 set it in
# the framework repo's own .claude/settings.json by hand; consumers never got it,
# so a background session refused the first Write of an inception (C-001 artifact)
# until it entered a worktree, which forks tracked governance state (T-2821/T-2822).

load ../test_helper

_bg_isolation() {   # _bg_isolation <settings.json> -> prints the value or "MISSING"
    python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('worktree', {}).get('bgIsolation', 'MISSING'))" "$1"
}

_consumer() {
    local d="$TEST_TEMP_DIR/consumer"
    mkdir -p "$d/.agentic-framework/bin"
    cp "$FRAMEWORK_ROOT/bin/fw" "$d/.agentic-framework/bin/fw"
    echo "$d"
}

@test "consumer-mode init emits worktree.bgIsolation=none" {
    local d; d=$(_consumer)
    bash -c "source '$FRAMEWORK_ROOT/lib/init.sh' && generate_claude_code_config '$d'" >/dev/null
    run _bg_isolation "$d/.claude/settings.json"
    [ "$output" = "none" ]
}

@test "framework-mode init emits worktree.bgIsolation=none" {
    local d="$TEST_TEMP_DIR/fw-repo"
    mkdir -p "$d/bin"
    touch "$d/FRAMEWORK.md"
    cp "$FRAMEWORK_ROOT/bin/fw" "$d/bin/fw"
    bash -c "source '$FRAMEWORK_ROOT/lib/init.sh' && generate_claude_code_config '$d'" >/dev/null
    run _bg_isolation "$d/.claude/settings.json"
    [ "$output" = "none" ]
}

@test "forced regenerate (fw upgrade path) adds the key to a consumer that lacked it" {
    local d; d=$(_consumer)
    mkdir -p "$d/.claude"
    echo '{"hooks": {}, "permissions": {"allow": ["Bash(ls:*)"]}}' > "$d/.claude/settings.json"
    bash -c "source '$FRAMEWORK_ROOT/lib/init.sh' && force=true generate_claude_code_config '$d'" >/dev/null
    run _bg_isolation "$d/.claude/settings.json"
    [ "$output" = "none" ]
    run python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['permissions']['allow'][0])" "$d/.claude/settings.json"
    [ "$output" = "Bash(ls:*)" ]
}

@test "forced regenerate keeps an operator's explicit worktree value and sibling sub-keys" {
    local d; d=$(_consumer)
    mkdir -p "$d/.claude"
    echo '{"hooks": {}, "worktree": {"bgIsolation": "worktree", "symlinkDirectories": ["node_modules"]}}' > "$d/.claude/settings.json"
    bash -c "source '$FRAMEWORK_ROOT/lib/init.sh' && force=true generate_claude_code_config '$d'" >/dev/null
    run _bg_isolation "$d/.claude/settings.json"
    [ "$output" = "worktree" ]
    run python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['worktree']['symlinkDirectories'][0])" "$d/.claude/settings.json"
    [ "$output" = "node_modules" ]
}

@test "framework repo's own settings.json still sets bgIsolation=none" {
    run _bg_isolation "$FRAMEWORK_ROOT/.claude/settings.json"
    [ "$output" = "none" ]
}

# ── fw upgrade path: a hook-converged consumer never takes step 5's regenerate
# branch, so step 5 must top the key up on its own. Real `fw upgrade` subprocess
# under env -i against a vendored consumer cloned from FRAMEWORK_ROOT's committed
# HEAD (same harness as t3712_upgrade_step5_field_hooks.bats).

_fresh_run() {
    local proj="$1"; shift
    (cd "$proj" && env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        GIT_CEILING_DIRECTORIES="$(dirname "$TEST_TEMP_DIR")" \
        "$proj/.agentic-framework/bin/fw" "$@")
}

_upgraded_consumer() {   # vendored consumer after one upgrade, with worktree.* rewritten to $2
    local proj="$1" worktree_json="$2"
    local bare="$TEST_TEMP_DIR/upstream.git"
    git clone --quiet --bare --shared "$FRAMEWORK_ROOT" "$bare" 2>/dev/null
    mkdir -p "$proj"
    git clone --quiet --depth=1 "file://$bare" "$proj/.agentic-framework" 2>/dev/null
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.0.0
provider: claude
upstream_repo: file://$bare
YAML
    _fresh_run "$proj" upgrade "$proj" >/dev/null 2>&1 || true
    [ -f "$proj/.claude/settings.json" ]
    python3 - "$proj/.claude/settings.json" "$worktree_json" <<'PY'
import json, sys
p, wt = sys.argv[1], json.loads(sys.argv[2])
d = json.load(open(p))
d.pop("worktree", None)
if wt is not None:
    d["worktree"] = wt
json.dump(d, open(p, "w"), indent=2)
PY
}

@test "fw upgrade sets bgIsolation=none on a hook-converged consumer that lacks it" {
    local proj="$TEST_TEMP_DIR/consumer-up"
    _upgraded_consumer "$proj" 'null'
    run _bg_isolation "$proj/.claude/settings.json"
    [ "$output" = "MISSING" ]
    run _fresh_run "$proj" upgrade "$proj"
    echo "$output" | grep -q 'worktree.bgIsolation=none'
    run _bg_isolation "$proj/.claude/settings.json"
    [ "$output" = "none" ]
}

@test "fw upgrade leaves an operator's explicit bgIsolation value alone" {
    local proj="$TEST_TEMP_DIR/consumer-keep"
    _upgraded_consumer "$proj" '{"bgIsolation": "worktree"}'
    _fresh_run "$proj" upgrade "$proj" >/dev/null 2>&1 || true
    run _bg_isolation "$proj/.claude/settings.json"
    [ "$output" = "worktree" ]
}
