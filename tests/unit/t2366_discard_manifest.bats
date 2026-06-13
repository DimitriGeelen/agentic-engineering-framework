#!/usr/bin/env bats
# T-2366 (T-2158 arc-012 S4): discard manifest enhancement.
#
# Surfaces under test:
#   - agents/handover/discard-manifest.sh — standalone category-level manifest
#   - agents/handover/handover.sh — normal path wires manifest + body reference
#
# AC mapping (per .tasks/active/T-2366-*.md):
#   handover writes <SESSION>.discard-manifest.yaml          — t1, t7
#   manifest enumerates category-level discards (3 keys)     — t2, t3
#   manifest is human-readable + parseable YAML              — t2
#   referenced from handover body via "Discard Manifest:"    — t7
#   generation overhead negligible (<500ms)                  — t6
#   transcript-parse correctness (counts/dedup/filters)      — t3, t4
#   graceful degradation when no transcript                  — t5
#   deprecated --emergency alias still produces manifest     — t8

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HELPER="$FRAMEWORK_ROOT/agents/handover/discard-manifest.sh"
HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2366-XXXXXX)"
    export NO_COLOR=1
    FIX="$TEST_TEMP_DIR/jsonl"
    mkdir -p "$FIX"
    # Synthetic transcript: 2 real assistant turns (1 <synthetic> skipped),
    # 3 tool_results, 2 distinct file-touching tool_uses (foo.py appears twice).
    cat > "$FIX/session.jsonl" <<'JSONL'
{"message":{"role":"user","content":[{"type":"text","text":"hi"}]}}
{"message":{"role":"assistant","model":"claude-opus-4-8","content":[{"type":"text","text":"working"},{"type":"tool_use","name":"Read","input":{"file_path":"/a/foo.py"}},{"type":"tool_use","name":"Edit","input":{"file_path":"/a/bar.py"}}]}}
{"message":{"role":"user","content":[{"type":"tool_result","content":"ok1"},{"type":"tool_result","content":"ok2"}]}}
{"message":{"role":"assistant","model":"claude-opus-4-8","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/a/foo.py"}}]}}
{"message":{"role":"user","content":[{"type":"tool_result","content":"ok3"}]}}
{"message":{"role":"assistant","model":"<synthetic>","content":[{"type":"text","text":"skip me"}]}}
JSONL
    # An agent- transcript that MUST be ignored.
    echo '{"message":{"role":"assistant","model":"claude-opus-4-8","content":[{"type":"tool_result"}]}}' > "$FIX/agent-ignored.jsonl"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "t1: helper writes <SESSION>.discard-manifest.yaml and prints its path" {
    run env FW_DISCARD_JSONL_DIR="$FIX" HANDOVER_DIR="$TEST_TEMP_DIR" "$HELPER" S-T1
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/S-T1.discard-manifest.yaml" ]
    [[ "$output" == *"S-T1.discard-manifest.yaml" ]]
}

@test "t2: manifest is parseable YAML with all required category keys" {
    env FW_DISCARD_JSONL_DIR="$FIX" HANDOVER_DIR="$TEST_TEMP_DIR" "$HELPER" S-T2 >/dev/null
    run python3 -c "
import yaml
d = yaml.safe_load(open('$TEST_TEMP_DIR/S-T2.discard-manifest.yaml'))
for k in ('tool_results_compressed_count','turns_summarized_count','files_dropped_from_working_set'):
    assert k in d, k
assert isinstance(d['files_dropped_from_working_set'], list)
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "t3: transcript branch counts tool_results, turns, and working-set files" {
    env FW_DISCARD_JSONL_DIR="$FIX" HANDOVER_DIR="$TEST_TEMP_DIR" "$HELPER" S-T3 >/dev/null
    run python3 -c "
import yaml
d = yaml.safe_load(open('$TEST_TEMP_DIR/S-T3.discard-manifest.yaml'))
assert d['source'] == 'transcript', d['source']
assert d['tool_results_compressed_count'] == 3, d['tool_results_compressed_count']
assert d['turns_summarized_count'] == 2, d['turns_summarized_count']
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "t4: files deduped+sorted, agent- transcript ignored, <synthetic> skipped" {
    env FW_DISCARD_JSONL_DIR="$FIX" HANDOVER_DIR="$TEST_TEMP_DIR" "$HELPER" S-T4 >/dev/null
    run python3 -c "
import yaml
d = yaml.safe_load(open('$TEST_TEMP_DIR/S-T4.discard-manifest.yaml'))
assert d['files_dropped_from_working_set'] == ['/a/bar.py','/a/foo.py'], d['files_dropped_from_working_set']
# agent-ignored.jsonl had a tool_result; if it had leaked, count would be 4.
assert d['tool_results_compressed_count'] == 3
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "t5: graceful degradation to valid YAML when no transcript is reachable" {
    EMPTY="$TEST_TEMP_DIR/empty"
    mkdir -p "$EMPTY"
    run env FW_DISCARD_JSONL_DIR="$EMPTY" HANDOVER_DIR="$TEST_TEMP_DIR" "$HELPER" S-T5
    [ "$status" -eq 0 ]
    run python3 -c "
import yaml
d = yaml.safe_load(open('$TEST_TEMP_DIR/S-T5.discard-manifest.yaml'))
assert d['source'] in ('unavailable','metrics-fallback'), d['source']
assert d['tool_results_compressed_count'] == 0
assert d['files_dropped_from_working_set'] == []
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "t6: manifest generation completes well under the 500ms budget" {
    start=$(date +%s%N)
    env FW_DISCARD_JSONL_DIR="$FIX" HANDOVER_DIR="$TEST_TEMP_DIR" "$HELPER" S-T6 >/dev/null
    end=$(date +%s%N)
    ms=$(( (end - start) / 1000000 ))
    echo "elapsed ${ms}ms"
    [ "$ms" -lt 500 ]
}

@test "t7: handover.sh normal path writes manifest + body reference line" {
    run env HANDOVER_DIR="$TEST_TEMP_DIR" "$HANDOVER" --no-commit --session S-T7
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/S-T7.discard-manifest.yaml" ]
    run grep -q "Discard Manifest:" "$TEST_TEMP_DIR/S-T7.md"
    [ "$status" -eq 0 ]
}

@test "t8: deprecated --emergency alias still produces the manifest (D-028 normal path)" {
    run env HANDOVER_DIR="$TEST_TEMP_DIR" "$HANDOVER" --emergency --no-commit --session S-T8
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/S-T8.discard-manifest.yaml" ]
}
