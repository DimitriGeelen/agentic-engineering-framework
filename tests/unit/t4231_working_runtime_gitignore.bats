#!/usr/bin/env bats
# T-4231 — runtime state that hooks, doctor, audit and Watchtower write under
# .context/working/ (counters, locks, pid/url, cursors, logs, telemetry) must be
# gitignored in consumers. `fw init` wrote a .context/working/.gitignore naming
# five files, so a fresh consumer's bootstrap commit tracked .verb-counter and
# its lock, and the rest showed up in the audit's uncommitted-changes rail
# (1023 msg cc1a5259 item 6). Same for .context/sidecar/ (1023 msg d6a3a865 (a)).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/working-gitignore.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_repo() {
    local p="$TEST_TEMP_DIR/proj"
    mkdir -p "$p/.context/working"
    git -C "$p" init -q
    echo "$p"
}

# Every name 1023 reported, plus the other runtime writers found in the code.
_runtime_names() {
    printf '%s\n' .verb-counter .verb-counter.lock .tool-counter .hook-counter \
        .hook-counter.lock .budget-gate-counter .hook-failure-counter .edit-counter \
        .session-baseline .session-start-ts .budget-status .loop-detect.json \
        recall-telemetry.jsonl continuous-run.jsonl watchtower-ensure.log \
        watchtower.log watchtower.pid watchtower.url watchtower.port notify.log \
        .hook-crashes.log framework-mcp.pid vector-index-health.json.lock \
        .subscribe-learnings-bus.cursor .pre-compact.lock .obs-highwater \
        .verify-queue-state.json tier0-action-approvals.json .restart-requested
}

# Records a project keeps in git: these must stay visible.
_record_names() {
    printf '%s\n' .gate-bypass-log.yaml feedback-stream.yaml reviewer-overrides.yaml \
        delegations.jsonl tier0-action-events.jsonl pending-updates.yaml arc-focus.yaml
}

@test "negative control: the pre-T-4231 init list leaves runtime files committable" {
    p=$(_repo)
    printf '.tool-counter\n.prev-token-reading\nsession.yaml\nfocus.yaml\ntier0-approval\n.fw-secret-key\n' \
        > "$p/.context/working/.gitignore"
    : > "$p/.context/working/.verb-counter"
    ! git -C "$p" check-ignore -q .context/working/.verb-counter || false
}

@test "ensure_ignored covers every runtime file and leaves records visible" {
    p=$(_repo)
    printf '.tool-counter\n' > "$p/.context/working/.gitignore"
    [ "$(fw_working_ensure_ignored "$p")" -gt 0 ]
    while IFS= read -r n; do
        : > "$p/.context/working/$n"
        git -C "$p" check-ignore -q ".context/working/$n" || { echo "not ignored: $n"; false; }
    done < <(_runtime_names)
    while IFS= read -r n; do
        : > "$p/.context/working/$n"
        ! git -C "$p" check-ignore -q ".context/working/$n" || { echo "record ignored: $n"; false; }
    done < <(_record_names)
}

@test "ensure_ignored is idempotent; --dry-run writes nothing" {
    p=$(_repo)
    printf 'session.yaml' > "$p/.context/working/.gitignore"   # no trailing newline
    n=$(fw_working_ensure_ignored "$p" --dry-run)
    [ "$n" -gt 0 ]
    [ "$(cat "$p/.context/working/.gitignore")" = "session.yaml" ]
    [ "$(fw_working_ensure_ignored "$p")" -eq "$n" ]
    grep -qx 'session.yaml' "$p/.context/working/.gitignore"
    cp "$p/.context/working/.gitignore" "$TEST_TEMP_DIR/first"
    [ "$(fw_working_ensure_ignored "$p")" -eq 0 ]
    cmp "$p/.context/working/.gitignore" "$TEST_TEMP_DIR/first"
}

@test "tracked_runtime names a runtime file a project already committed" {
    p=$(_repo)
    : > "$p/.context/working/.verb-counter"
    git -C "$p" add .context/working/.verb-counter
    fw_working_ensure_ignored "$p" >/dev/null
    run fw_working_tracked_runtime "$p"
    [ "$status" -eq 0 ]
    [ "$output" = ".context/working/.verb-counter" ]
}

@test "fw init and fw upgrade both call the shared helper" {
    grep -q 'fw_working_ensure_ignored "\$target_dir"' "$FRAMEWORK_ROOT/lib/init.sh"
    grep -q 'fw_working_ensure_ignored "\$target_dir"' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "sidecar receiver ignores its pid/port/url and caches, keeps ledgers" {
    p=$(_repo)
    d="$p/.context/sidecar"
    mkdir -p "$d/waiting"
    PYTHONPATH="$FRAMEWORK_ROOT/lib" python3 -c \
        "import sys; from pathlib import Path; from sidecar import lifecycle; lifecycle._ensure_runtime_ignored(Path(sys.argv[1]))" "$d"
    for n in receiver.pid receiver.port receiver.url inbox-state.json inbox-state.json.lock \
             hub-id peers.json waiting/epoch waiting/escalations.jsonl liveness.yaml.123.tmp; do
        : > "$d/$n"
        git -C "$p" check-ignore -q ".context/sidecar/$n" || { echo "not ignored: $n"; false; }
    done
    for n in direct-ack.jsonl receipts.jsonl receipts-sent.jsonl refusals.jsonl awaiting-ack.jsonl; do
        : > "$d/$n"
        ! git -C "$p" check-ignore -q ".context/sidecar/$n" || { echo "ledger ignored: $n"; false; }
    done
}

@test "end-to-end: a fresh fw init tracks no runtime file and leaves .context/working clean" {
    proj="$TEST_TEMP_DIR/fresh"
    mkdir -p "$proj"
    git -C "$proj" init -q
    run timeout 300 "$FRAMEWORK_ROOT/bin/fw" init "$proj" --provider claude --no-first-run
    [ -f "$proj/.context/working/.gitignore" ] || { echo "$output" | tail -20; false; }
    run git -C "$proj" ls-files -ci --exclude-standard -- .context/working
    [ -z "$output" ] || { echo "tracked runtime: $output"; false; }
    while IFS= read -r n; do : > "$proj/.context/working/$n"; done < <(_runtime_names)
    run git -C "$proj" status --porcelain --untracked-files=all -- .context/working
    [ -z "$output" ] || { echo "dirty: $output"; false; }
}
