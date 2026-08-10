#!/usr/bin/env bats
# T-2912 — `fw upgrade` must report the ACTUAL effect of hook regeneration,
# not the pre-write trigger. Pre-fix, three consecutive real runs against a
# real vendored consumer all printed `UPDATED  Hooks regenerated (missing 7
# hook(s): ...)` naming the SAME 7 hooks forever — the regenerator's template
# (lib/init.sh generate_claude_code_config) did not know those hooks, so
# "regenerate" faithfully reproduced the state the detector complained about.
# The adjacent `OK .claude/settings.json (all hooks: ...)` line was a
# hardcoded string that never varied with reality, so it agreed with neither
# state.
#
# This reproduces the class without waiting for a fresh real drift: it seeds
# an upstream .claude/settings.json with ONE hook the template cannot supply
# (same shape as T-2710/T-2911's 7 — a hook registered in the framework's
# real settings.json but absent from generate_claude_code_config's fixed
# heredoc), then drives a REAL `fw upgrade` subprocess against a real
# vendored consumer under `env -i` (AC6 — this defect was invisible in-repo
# and only appeared on a real vendored consumer; a fixture that calls
# do_upgrade as a bash function in-process would not exercise the
# subshell/force=true/regeneration path the same way).
#
# Rehearsed RED against pre-T-2912 lib/upgrade.sh + lib/init.sh (both runs
# print UPDATED, same missing hook, forever; .bak written both times; OK/all
# hooks line unchanged) before this fix landed.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2912-XXXXXX)"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build an upstream bare repo (from FRAMEWORK_ROOT's committed HEAD, mirroring
# tests/unit/upgrade_fresh_machine_simulation.bats' make_upstream_bare) whose
# .claude/settings.json carries one extra hook the template does not emit.
# Returns via globals: $UPSTREAM_WORK $UPSTREAM_BARE $ORIG_SETTINGS
make_upstream_with_unmirrored_hook() {
    UPSTREAM_WORK="$TEST_TEMP_DIR/upstream-work"
    UPSTREAM_BARE="$TEST_TEMP_DIR/upstream.git"
    ORIG_SETTINGS="$TEST_TEMP_DIR/settings.orig.json"

    git clone --quiet --shared "$FRAMEWORK_ROOT" "$UPSTREAM_WORK" 2>/dev/null
    cp "$UPSTREAM_WORK/.claude/settings.json" "$ORIG_SETTINGS"
    python3 - "$UPSTREAM_WORK/.claude/settings.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.setdefault("hooks", {}).setdefault("PreToolUse", []).append({
    "matcher": "",
    "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook t2912-unmirrored-probe"
    }]
})
json.dump(d, open(p, "w"), indent=2)
PY
    (cd "$UPSTREAM_WORK" && git -c user.email=t@t -c user.name=t commit -aqm "seed unmirrored hook for T-2912 test")
    git clone --quiet --bare "$UPSTREAM_WORK" "$UPSTREAM_BARE" 2>/dev/null
}

# Real `fw init`'d-shape consumer: vendored .agentic-framework/ cloned from
# the seeded upstream, plus a PRE-EXISTING .claude/settings.json generated
# from the PRE-seed template (i.e. what a consumer's settings.json looks like
# the moment before the framework added the hook it can't yet mirror into
# its own template — the exact T-2710/T-2911 shape).
make_consumer_missing_the_hook() {
    local proj="$1"
    mkdir -p "$proj/.claude"
    cp "$ORIG_SETTINGS" "$proj/.claude/settings.json"
    git clone --quiet --depth=1 "file://$UPSTREAM_BARE" "$proj/.agentic-framework" 2>/dev/null
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.0.0
provider: claude
upstream_repo: file://$UPSTREAM_BARE
YAML
}

fresh_run() {
    local proj="$1"; shift
    (cd "$proj" && env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        "$proj/.agentic-framework/bin/fw" "$@")
}

@test "T-2912: fw upgrade does not claim UPDATED when regen cannot supply a detected-missing hook (run 1)" {
    make_upstream_with_unmirrored_hook
    local proj="$TEST_TEMP_DIR/proj1"
    make_consumer_missing_the_hook "$proj"

    run fresh_run "$proj" upgrade "$proj"
    [ "$status" -eq 0 ]
    # The pre-fix bug: this exact string, unconditionally, for a no-op.
    [[ "$output" != *"UPDATED  Hooks regenerated (missing 1 hook(s): PreToolUse:t2912-unmirrored-probe)"* ]]
    [[ "$output" == *"t2912-unmirrored-probe"* ]]
    [[ "$output" == *"FAILED"* || "$output" == *"PARTIAL"* ]]
}

@test "T-2912: non-convergence is caught on a SECOND run too, not just the first" {
    make_upstream_with_unmirrored_hook
    local proj="$TEST_TEMP_DIR/proj2"
    make_consumer_missing_the_hook "$proj"

    fresh_run "$proj" upgrade "$proj" >/dev/null 2>&1 || true

    run fresh_run "$proj" upgrade "$proj"
    [ "$status" -eq 0 ]
    # Pre-fix: run 2 printed the identical UPDATED line as run 1, forever.
    [[ "$output" != *"UPDATED  Hooks regenerated"*"t2912-unmirrored-probe"* ]]
    [[ "$output" == *"FAILED"* ]]
    [[ "$output" == *"t2912-unmirrored-probe"* ]]
}

@test "T-2912: a run that changes nothing does not write a fresh .bak" {
    make_upstream_with_unmirrored_hook
    local proj="$TEST_TEMP_DIR/proj3"
    make_consumer_missing_the_hook "$proj"

    fresh_run "$proj" upgrade "$proj" >/dev/null 2>&1 || true
    rm -f "$proj/.claude/settings.json.bak"

    run fresh_run "$proj" upgrade "$proj"
    [ "$status" -eq 0 ]
    # Second run is a pure no-op (first run's regen already reached the
    # template's ceiling) — no new backup should corroborate a mutation
    # that didn't happen.
    [ ! -f "$proj/.claude/settings.json.bak" ]
}

@test "T-2912: the adjacent settings.json OK line no longer hardcodes a stale 'all hooks' claim" {
    # Static guard: lib/init.sh's generate_claude_code_config must not print
    # a fixed friendly-name list as if it were always true. Regression guard
    # for the exact string this task removed.
    ! grep -q 'all hooks: task gate, tier0, budget, plan blocker, agent dispatch, compact, resume, checkpoint, error-watchdog, dispatch guard, loop-detect, fabric new-file, project-boundary, commit-cadence' "$FRAMEWORK_ROOT/lib/init.sh"
}

@test "T-2912: fw upgrade exercised on a REAL fw-init-shaped consumer under env -i (AC6, not a fixture)" {
    # Positive control distinct from the seeded-gap tests above: an
    # UN-seeded upstream (framework's real settings.json, no probe hook)
    # against a consumer whose settings.json already matches — must report
    # a clean OK/no-op, proving the harness itself (real subprocess, env -i,
    # vendored consumer) is not what's forcing FAILED/PARTIAL above.
    local work="$TEST_TEMP_DIR/upstream-clean"
    local bare="$TEST_TEMP_DIR/upstream-clean.git"
    local proj="$TEST_TEMP_DIR/proj-clean"
    git clone --quiet --bare --shared "$FRAMEWORK_ROOT" "$bare" 2>/dev/null
    mkdir -p "$proj"
    git clone --quiet --depth=1 "file://$bare" "$proj/.agentic-framework" 2>/dev/null
    cat > "$proj/.framework.yaml" <<YAML
project_name: proj-clean
version: 1.0.0
provider: claude
upstream_repo: file://$bare
YAML

    run fresh_run "$proj" upgrade "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" != *"t2912-unmirrored-probe"* ]]
}
