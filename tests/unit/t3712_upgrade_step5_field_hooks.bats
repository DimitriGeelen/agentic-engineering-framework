#!/usr/bin/env bats
# T-3712 — `fw upgrade` step 5 reported PARTIAL "missing check-paid-backend,
# check-worktree-governance-write, Stop:stop-driver.sh" and left the three
# hooks missing, while `fw hook-enable` registered them fine (055 field report,
# 2026-10-02; same report from 010 as T-3815). Root cause: the consumer
# template (lib/init.sh generate_claude_code_config) did not write them, and
# the framework's Stop hook is spelled agents/context/stop-driver.sh while the
# template spells 'fw hook stop-driver'. Fixed by T-3881 (69e87852f).
#
# t3881_template_hook_parity.bats pins the template/detector parity statically.
# This pins the end-to-end symptom the field saw: a REAL `fw upgrade`
# subprocess, under env -i, against a vendored consumer whose settings.json
# lacks exactly those three hooks, must converge (UPDATED, not PARTIAL/FAILED)
# and leave all three registered.
# Rehearsed RED with lib/init.sh + lib/hook_parity.py at 69e87852f^ in the
# upstream: step 5 prints PARTIAL naming the three hooks.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t3712-XXXXXX)"
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

# Vendored consumer from FRAMEWORK_ROOT's committed HEAD (or $T3712_UPSTREAM,
# for the RED rehearsal), whose settings.json is the template's own output
# minus the three hooks from the field report.
make_consumer_missing_field_hooks() {
    local proj="$1"
    local bare="$TEST_TEMP_DIR/upstream.git"
    git clone --quiet --bare --shared "${T3712_UPSTREAM:-$FRAMEWORK_ROOT}" "$bare" 2>/dev/null
    mkdir -p "$proj"
    git clone --quiet --depth=1 "file://$bare" "$proj/.agentic-framework" 2>/dev/null
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.0.0
provider: claude
upstream_repo: file://$bare
YAML
    # First upgrade writes the template's settings.json.
    fresh_run "$proj" upgrade "$proj" >/dev/null 2>&1 || true
    [ -f "$proj/.claude/settings.json" ]
    python3 - "$proj/.claude/settings.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
drop = ("check-paid-backend", "check-worktree-governance-write", "stop-driver")
for event, entries in list(d.get("hooks", {}).items()):
    kept = []
    for e in entries:
        e["hooks"] = [h for h in e.get("hooks", [])
                      if not any(x in h.get("command", "") for x in drop)]
        if e["hooks"]:
            kept.append(e)
    d["hooks"][event] = kept
json.dump(d, open(p, "w"), indent=2)
PY
    rm -f "$proj/.claude/settings.json.bak"
}

field_hooks_present() {
    local f="$1"
    grep -q 'hook check-paid-backend"' "$f" \
        && grep -q 'hook check-worktree-governance-write"' "$f" \
        && grep -q 'stop-driver' "$f"
}

@test "T-3712: the seeded consumer really lacks the three field-report hooks (fixture control)" {
    local proj="$TEST_TEMP_DIR/proj0"
    make_consumer_missing_field_hooks "$proj"
    ! field_hooks_present "$proj/.claude/settings.json" || false
}

@test "T-3712: fw upgrade step 5 converges on the three field-report hooks (UPDATED, not PARTIAL)" {
    local proj="$TEST_TEMP_DIR/proj1"
    make_consumer_missing_field_hooks "$proj"

    run fresh_run "$proj" upgrade "$proj"
    [ "$status" -eq 0 ]
    step5=$(printf '%s\n' "$output" | sed -n '/\[5\/10\]/,/\[6\/10\]/p')
    [[ "$step5" == *"UPDATED"* ]]
    [[ "$step5" != *"PARTIAL"* ]]
    [[ "$step5" != *"FAILED"* ]]
    field_hooks_present "$proj/.claude/settings.json"
}

@test "T-3712: a second fw upgrade reports step 5 OK (no perpetual regeneration)" {
    local proj="$TEST_TEMP_DIR/proj2"
    make_consumer_missing_field_hooks "$proj"
    fresh_run "$proj" upgrade "$proj" >/dev/null 2>&1 || true

    run fresh_run "$proj" upgrade "$proj"
    [ "$status" -eq 0 ]
    step5=$(printf '%s\n' "$output" | sed -n '/\[5\/10\]/,/\[6\/10\]/p')
    [[ "$step5" == *"OK"* ]]
    [[ "$step5" != *"PARTIAL"* ]]
    [[ "$step5" != *"missing"* ]]
}
