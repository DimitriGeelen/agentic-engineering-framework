#!/usr/bin/env bats
# T-4555: ring20 upgraded 1.8.12 -> v1.8.15-be.2 and doctor reported "Cron
# registry edited but not generated" on a registry nobody edited. The renderer
# changed (T-3162 appends '; exit ${PIPESTATUS[0]}'), and fw upgrade only
# regenerated the crontab when it ADDED a job. Now it regenerates any existing
# source, so the doctor/audit registry->generated check is clean after upgrade.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"; export TEST_TEMP_DIR
    export CONSUMER="$TEST_TEMP_DIR/proj"
    mkdir -p "$CONSUMER"
    git -C "$CONSUMER" init -q
    git -C "$CONSUMER" config user.email t@example.com
    git -C "$CONSUMER" config user.name t
    SRC="$CONSUMER/.context/cron/agentic-audit.crontab"
    REG="$CONSUMER/.context/cron-registry.yaml"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

# What the consumer's durable fw would generate now (same call doctor makes).
dry_run() {
    python3 "$FRAMEWORK_ROOT/lib/cron_dry_run.py" "$CONSUMER" "$REG" "$CONSUMER/.agentic-framework/bin/fw"
}

@test "T-4555: upgrade regenerates a crontab rendered by an older framework (no job added)" {
    run timeout 300 "$FRAMEWORK_ROOT/bin/fw" init "$CONSUMER" --no-first-run
    [ -f "$REG" ]
    if [ ! -f "$SRC" ]; then
        run bash -c "cd '$CONSUMER' && PROJECT_ROOT='$CONSUMER' '$FRAMEWORK_ROOT/bin/fw' cron generate"
    fi
    [ -f "$SRC" ]
    grep -q 'PIPESTATUS' "$SRC"
    # Simulate the 1.8.12 renderer: no '; exit ${PIPESTATUS[0]}' suffix.
    sed -i 's/; exit \${PIPESTATUS\[0\]}$//' "$SRC"
    ! grep -q 'PIPESTATUS' "$SRC" || false
    [ "$(dry_run)" != "$(cat "$SRC")" ]   # control: doctor would WARN here

    run timeout 300 "$FRAMEWORK_ROOT/bin/fw" upgrade "$CONSUMER"
    echo "$output" | grep -q 'REGENERATED.*Cron source' || { echo "$output" | tail -40; false; }
    grep -q 'PIPESTATUS' "$SRC"
    [ "$(dry_run)" = "$(cat "$SRC")" ]
}

@test "T-4555: doctor's cron WARN and task-debt line name what they measure" {
    grep -q "or the framework's cron renderer changed since the last generate" "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'debt_what="active tasks with last_update older than 7 days or unreadable"' "$FRAMEWORK_ROOT/bin/fw"
}
