#!/usr/bin/env bats
# T-5354 (G-139, reported by 0506): right after a compaction the token counter has fewer
# than 2 usage entries since the compact_boundary and returns status `young`. `checkpoint.sh
# status` printed only "unavailable (no usage data)", so the agent fell back to the stale
# budget figure in the compaction summary ("~81% of 800k" while the real figure was ~15%).
# These tests run the REAL checkpoint.sh status against transcript fixtures.

load ../test_helper

setup() {
    ROOT="$(mktemp -d -t fw-t5354-XXXXXX)"
    PROJ="$ROOT/proj"
    mkdir -p "$PROJ/.context/working"
    git init -q "$PROJ"
    T="$ROOT/t.jsonl"
}

teardown() {
    cd /
    rm -rf "$ROOT"
}

run_status() {
    run env PROJECT_ROOT="$PROJ" FW_TRANSCRIPT_PATH="$T" bash "$FRAMEWORK_ROOT/agents/context/checkpoint.sh" status
}

@test "young (compact_boundary + one usage entry): says not yet measured and not to use earlier figures" {
    printf '%s\n%s\n%s\n' \
        '{"timestamp":"2026-01-01T00:00:00Z","message":{"model":"claude","usage":{"input_tokens":790000}}}' \
        '{"timestamp":"2026-01-01T00:01:00Z","type":"system","subtype":"compact_boundary"}' \
        '{"timestamp":"2026-01-01T00:01:05Z","message":{"model":"claude","usage":{"input_tokens":42000}}}' > "$T"
    run_status
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Context tokens: not yet measured since this session (re)started"
    echo "$output" | grep -q "newest provisional reading: 42000"
    echo "$output" | grep -q "Do NOT use budget figures from before the restart"
    # the pre-compaction 790000 must not be reported as the reading
    ! echo "$output" | grep -q "Context tokens: 790000"
}

@test "young with no usage at all after the boundary: same guidance, no provisional figure" {
    printf '%s\n%s\n' \
        '{"timestamp":"2026-01-01T00:00:00Z","message":{"model":"claude","usage":{"input_tokens":790000}}}' \
        '{"timestamp":"2026-01-01T00:01:00Z","type":"system","subtype":"compact_boundary"}' > "$T"
    run_status
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "not yet measured since this session (re)started\. Do NOT use"
    ! echo "$output" | grep -q "provisional reading"
}

@test "measured (two entries since the boundary): unchanged output" {
    printf '%s\n%s\n%s\n' \
        '{"timestamp":"2026-01-01T00:01:00Z","type":"system","subtype":"compact_boundary"}' \
        '{"timestamp":"2026-01-01T00:01:05Z","message":{"model":"claude","usage":{"input_tokens":150000}}}' \
        '{"timestamp":"2026-01-01T00:01:09Z","message":{"model":"claude","usage":{"input_tokens":150000}}}' > "$T"
    run_status
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Context tokens: 150000"
    echo "$output" | grep -q "^Band: "
    ! echo "$output" | grep -q "not yet measured"
}
