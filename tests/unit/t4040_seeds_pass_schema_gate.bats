#!/usr/bin/env bats
# T-4040 (GitHub #86) — every seed under lib/seeds/tasks/ that is workflow_type: inception
# must pass the inception schema gate (T-2188), the same check the PreToolUse hook runs on
# a Write/Edit. A fresh `fw init` copies the seeds without the upgrade backfill, so a seed
# that lacks target_blast_radius/voi_score blocks the project's first edit to it.
#
# Generic over the seed tree: a future inception seed is covered without editing this file.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    unset FW_ALLOW_INCEPTION_SCHEMA_DRIFT
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.context/working"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-inception-schema.py"
    SEED_ROOT="$FRAMEWORK_ROOT/lib/seeds/tasks"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    unset FW_ALLOW_INCEPTION_SCHEMA_DRIFT
}

_inception_seeds() {
    grep -rl '^workflow_type: inception' "$SEED_ROOT" | sort
}

@test "t4040: the seed tree has at least one inception seed to check (no vacuous pass)" {
    n=$(_inception_seeds | wc -l)
    [ "$n" -ge 1 ]
}

@test "t4040: every inception seed passes the schema gate when written as a task" {
    checked=0
    failures=""
    while IFS= read -r seed; do
        checked=$((checked + 1))
        # The hook only judges .tasks/{active,completed}/T-*.md, and it lets a path with no
        # file on disk through (no frontmatter to read). So place the seed at a path it will
        # judge, then send a Write whose content is that same seed.
        target="$TEST_TEMP_DIR/.tasks/active/$(basename "$seed")"
        cp "$seed" "$target"
        payload=$(python3 -I -c 'import json,sys; print(json.dumps({"tool_input": {"file_path": sys.argv[1], "content": open(sys.argv[2], encoding="utf-8").read()}}))' "$target" "$seed")
        rc=0
        out=$(echo "$payload" | python3 "$HOOK" 2>&1) || rc=$?
        if [ "$rc" -ne 0 ]; then
            failures+="${seed#"$FRAMEWORK_ROOT"/} (rc=$rc): $(echo "$out" | grep -- '- ' | tr -s ' ' | tr '\n' ' ')"$'\n'
        fi
    done < <(_inception_seeds)
    [ "$checked" -ge 1 ]
    if [ -n "$failures" ]; then
        echo "$failures"
        false
    fi
}
