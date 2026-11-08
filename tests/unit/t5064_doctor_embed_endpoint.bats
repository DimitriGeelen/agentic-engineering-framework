#!/usr/bin/env bats
# T-5064 (GitHub issue #98, follow-up): fw doctor's embed endpoint check (T-3045).
#
# Reported on a container without network, SEMANTIC_RECALL=0: doctor still printed
#   WARN [host] embed endpoint not reachable on http://localhost:11434; embeds still
#   succeed via T-3017 failover, so nothing else will report this
# Two faults: the check ignored SEMANTIC_RECALL (the index check, T-3862, honours it),
# and it claimed failover that only exists when a DIFFERENT EMBED_BULK_HOST answers.
# These run the real `fw doctor` on a fixture project, one case each.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.tasks/active" "$PROJ/.tasks/completed" "$PROJ/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    DEAD="http://127.0.0.1:9"      # discard port: nothing answers
}

teardown() {
    [ -n "${SRV_PID:-}" ] && kill "$SRV_PID" 2>/dev/null
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_doctor() {   # extra env assignments as arguments
    run env -u CONTEXT_DIR FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJ" "$@" \
        timeout 300 "$FRAMEWORK_ROOT/bin/fw" doctor
    line=$(grep -i 'embed endpoint' <<< "$output" || true)
}

@test "T-5064: SEMANTIC_RECALL=0 makes the embed endpoint line a SKIP, not a WARN" {
    echo "SEMANTIC_RECALL: 0" >> "$PROJ/.framework.yaml"
    _doctor OLLAMA_HOST="$DEAD" FW_EMBED_HOST="$DEAD" FW_EMBED_BULK_HOST="$DEAD"
    [[ "$line" == *"SKIP"*"SEMANTIC_RECALL=0"* ]]
    [[ "$line" != *"WARN"* ]]
    [[ "$line" != *"failover"* ]]
}

@test "T-5064: one dead host and no alternative — no failover claim, says embeds fail" {
    _doctor OLLAMA_HOST="$DEAD" FW_EMBED_HOST="$DEAD" FW_EMBED_BULK_HOST="$DEAD"
    [[ "$line" == *"not reachable on $DEAD and no other embed host answers"* ]]
    [[ "$line" == *"embedding calls will fail"* ]]
    [[ "$line" != *"failover"* ]]
    [[ "$output" == *"fw config set SEMANTIC_RECALL 0"* ]]
}

@test "T-5064: dead primary, live different bulk host — failover named with its host" {
    port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')
    mkdir -p "$TEST_TEMP_DIR/www/api"; echo '{"models":[]}' > "$TEST_TEMP_DIR/www/api/tags"
    python3 -m http.server "$port" --bind 127.0.0.1 --directory "$TEST_TEMP_DIR/www" >/dev/null 2>&1 &
    SRV_PID=$!
    for i in $(seq 1 50); do curl -sf "http://127.0.0.1:$port/api/tags" >/dev/null && break; sleep 0.1; done
    _doctor OLLAMA_HOST="$DEAD" FW_EMBED_HOST="$DEAD" FW_EMBED_BULK_HOST="http://127.0.0.1:$port"
    [[ "$line" == *"via T-3017 failover to http://127.0.0.1:$port"* ]]
}
