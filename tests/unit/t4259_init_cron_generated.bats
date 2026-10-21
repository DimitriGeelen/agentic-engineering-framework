#!/usr/bin/env bats
# T-4259: `fw init` seeds framework cron jobs (T-3673, T-3783) into the registry
# but never generated .context/cron/agentic-audit.crontab, so the first `fw
# doctor` on a fresh project WARNed "Cron registry present but not generated" —
# a registry→generated drift that init itself created.
#   (a) fresh init leaves a generated crontab that matches the registry
#   (b) fresh init does not install anything (generate only)
#   (c) doctor on a fresh init has no "not generated" / "edited but not generated" WARN
#   (d) init's next steps name `fw cron install`
#   (e) cron_fw_path — the one fw-path rule generate and the doctor/audit
#       dry-runs share — names the consumer's vendored fw for any outside root

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"; export TEST_TEMP_DIR
    export CONSUMER="$TEST_TEMP_DIR/proj4259"
    mkdir -p "$CONSUMER"
    git -C "$CONSUMER" init -q
    git -C "$CONSUMER" config user.email t@example.com
    git -C "$CONSUMER" config user.name t
    # Never touch the real /etc/cron.d from a test.
    export FW_CRON_INSTALL_DIR="$TEST_TEMP_DIR/cron.d"
    mkdir -p "$FW_CRON_INSTALL_DIR"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "T-4259 (a): fresh init generates the crontab from the seeded registry" {
    run timeout 180 "$FRAMEWORK_ROOT/bin/fw" init "$CONSUMER" --no-first-run
    [ -f "$CONSUMER/.context/cron/agentic-audit.crontab" ]
    grep -q "sidecar sweep" "$CONSUMER/.context/cron/agentic-audit.crontab"
    grep -q "index reindex" "$CONSUMER/.context/cron/agentic-audit.crontab"
    dry=$(python3 "$FRAMEWORK_ROOT/lib/cron_dry_run.py" "$CONSUMER" "$CONSUMER/.context/cron-registry.yaml" "$CONSUMER/.agentic-framework/bin/fw")
    [ "$dry" = "$(cat "$CONSUMER/.context/cron/agentic-audit.crontab")" ]
}

@test "T-4259 (b): fresh init installs nothing" {
    run timeout 180 "$FRAMEWORK_ROOT/bin/fw" init "$CONSUMER" --no-first-run
    [ -z "$(ls -A "$FW_CRON_INSTALL_DIR")" ]
}

@test "T-4259 (c): doctor on a fresh init reports no registry→generated drift" {
    run timeout 180 "$FRAMEWORK_ROOT/bin/fw" init "$CONSUMER" --no-first-run
    # Through the consumer's own vendored fw, as an operator runs it — with the
    # framework repo's FRAMEWORK_ROOT inherited (test_helper exports it; so does
    # an agent session). 2026-10-22 integration: doctor dry-ran with
    # $FRAMEWORK_ROOT/bin/fw while generate wrote .agentic-framework/bin/fw, so
    # this leg reported "edited but not generated" on a fresh init.
    run bash -c "cd '$CONSUMER' && FRAMEWORK_ROOT='$FRAMEWORK_ROOT' timeout 300 '$CONSUMER/.agentic-framework/bin/fw' doctor 2>&1"
    ! echo "$output" | grep -q "Cron registry present but not generated" || false
    ! echo "$output" | grep -q "Cron registry edited but not generated" || false
    echo "$output" | grep -q "Run: fw cron install"
}

@test "T-4259 (d): init next steps name fw cron install" {
    run timeout 180 "$FRAMEWORK_ROOT/bin/fw" init "$CONSUMER" --no-first-run
    echo "$output" | grep -q "fw cron install"
}

@test "T-4259 (e): cron_fw_path is the generator's rule, used by doctor and audit dry-runs" {
    source "$FRAMEWORK_ROOT/lib/cron-registry.sh"
    mkdir -p "$CONSUMER/.agentic-framework/bin"
    printf '#!/bin/sh\n' > "$CONSUMER/.agentic-framework/bin/fw"; chmod +x "$CONSUMER/.agentic-framework/bin/fw"
    # Outside root (framework repo, temp upstream clone) → the consumer's durable copy.
    [ "$(cron_fw_path "$FRAMEWORK_ROOT" "$CONSUMER")" = "$CONSUMER/.agentic-framework/bin/fw" ]
    [ "$(cron_fw_path "$CONSUMER/.agentic-framework" "$CONSUMER")" = "$CONSUMER/.agentic-framework/bin/fw" ]
    # The framework repo itself keeps bin/fw.
    [ "$(cron_fw_path "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT")" = "$FRAMEWORK_ROOT/bin/fw" ]
    # No dry-run may render with a bare $FRAMEWORK_ROOT/bin/fw again.
    ! grep -n 'cron_dry_run.py.*"\$FRAMEWORK_ROOT/bin/fw"' "$FRAMEWORK_ROOT/bin/fw" "$FRAMEWORK_ROOT/agents/audit/audit.sh" || false
    grep -q 'cron_dry_run.py.*cron_fw_path' "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'cron_dry_run.py.*cron_fw_path' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q '_cron_fw=$(cron_fw_path' "$FRAMEWORK_ROOT/bin/fw"
}
