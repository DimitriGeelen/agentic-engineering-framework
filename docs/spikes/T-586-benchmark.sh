#!/usr/bin/env bash
# T-586 Phase 2: Head-to-head benchmark — TypeScript vs bash+Python loop detector
set -euo pipefail

SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS_DIR="$SPIKE_DIR/T-586-loop-detect-ts"
BASH_DIR="$SPIKE_DIR/T-586-loop-detect-bash"
RESULTS_FILE="$SPIKE_DIR/benchmark-results.txt"

# Temp directories for isolated state
TS_TMPDIR=$(mktemp -d)
BASH_TMPDIR=$(mktemp -d)
mkdir -p "$TS_TMPDIR/.context/working" "$BASH_TMPDIR/.context/working"

cleanup() { rm -rf "$TS_TMPDIR" "$BASH_TMPDIR"; }
trap cleanup EXIT

# --- Test Data ---
SIMPLE_INPUT='{"tool_name":"Read","tool_input":{"file_path":"/tmp/test.txt"},"tool_result":"hello world"}'
COMPLEX_INPUT='{"tool_name":"Bash","tool_input":{"command":"grep -r \"pattern\" /opt/project/src/","description":"Search for pattern"},"tool_result":"src/main.ts:42: const pattern = \"hello\";\nsrc/util.ts:10: // pattern match"}'

# Input with quotes (shell escaping stress test)
QUOTES_INPUT='{"tool_name":"Write","tool_input":{"file_path":"/tmp/user'\''s file.txt","content":"He said \"hello\" and '\''goodbye'\''"},"tool_result":"ok"}'

# Input with newlines and special chars
SPECIAL_INPUT='{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.py","old_string":"def foo():\n    return \"bar\"","new_string":"def foo():\n    return \"baz\""}}'

echo "========================================" | tee "$RESULTS_FILE"
echo "T-586 Phase 2: Prototype Benchmark"      | tee -a "$RESULTS_FILE"
echo "$(date -Iseconds)"                        | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# --- Test 1: Cold start (first invocation) ---
echo "### Test 1: Cold Start (single invocation)" | tee -a "$RESULTS_FILE"

# TS cold start
rm -f "$TS_TMPDIR/.context/working/.loop-detect.json"
TS_START=$(date +%s%N)
echo "$SIMPLE_INPUT" | PROJECT_ROOT="$TS_TMPDIR" node "$TS_DIR/loop-detect.js" 2>/dev/null || true
TS_END=$(date +%s%N)
TS_COLD_MS=$(( (TS_END - TS_START) / 1000000 ))

# Bash+Python cold start
rm -f "$BASH_TMPDIR/.context/working/.loop-detect.json"
BASH_START=$(date +%s%N)
echo "$SIMPLE_INPUT" | PROJECT_ROOT="$BASH_TMPDIR" bash "$BASH_DIR/loop-detect.sh" 2>/dev/null || true
BASH_END=$(date +%s%N)
BASH_COLD_MS=$(( (BASH_END - BASH_START) / 1000000 ))

echo "  TypeScript (node):  ${TS_COLD_MS}ms" | tee -a "$RESULTS_FILE"
echo "  Bash+Python:        ${BASH_COLD_MS}ms" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# --- Test 2: Warm run (10 sequential invocations) ---
echo "### Test 2: 10 Sequential Invocations (warm)" | tee -a "$RESULTS_FILE"

rm -f "$TS_TMPDIR/.context/working/.loop-detect.json"
TS_START=$(date +%s%N)
for i in $(seq 1 10); do
    echo "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/tmp/file${i}.txt\"},\"tool_result\":\"content ${i}\"}" | \
        PROJECT_ROOT="$TS_TMPDIR" node "$TS_DIR/loop-detect.js" 2>/dev/null || true
done
TS_END=$(date +%s%N)
TS_WARM_MS=$(( (TS_END - TS_START) / 1000000 ))

rm -f "$BASH_TMPDIR/.context/working/.loop-detect.json"
BASH_START=$(date +%s%N)
for i in $(seq 1 10); do
    echo "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/tmp/file${i}.txt\"},\"tool_result\":\"content ${i}\"}" | \
        PROJECT_ROOT="$BASH_TMPDIR" bash "$BASH_DIR/loop-detect.sh" 2>/dev/null || true
done
BASH_END=$(date +%s%N)
BASH_WARM_MS=$(( (BASH_END - BASH_START) / 1000000 ))

echo "  TypeScript (10x):   ${TS_WARM_MS}ms  ($(( TS_WARM_MS / 10 ))ms/call)" | tee -a "$RESULTS_FILE"
echo "  Bash+Python (10x):  ${BASH_WARM_MS}ms  ($(( BASH_WARM_MS / 10 ))ms/call)" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# --- Test 3: Loop Detection (6 identical calls → should trigger warning) ---
echo "### Test 3: Loop Detection (6 identical calls)" | tee -a "$RESULTS_FILE"

rm -f "$TS_TMPDIR/.context/working/.loop-detect.json"
TS_DETECTED="no"
for i in $(seq 1 6); do
    OUTPUT=$(echo "$SIMPLE_INPUT" | PROJECT_ROOT="$TS_TMPDIR" node "$TS_DIR/loop-detect.js" 2>&1 || true)
    if echo "$OUTPUT" | grep -q "loop_detected"; then
        TS_DETECTED="yes (call $i)"
    fi
done

rm -f "$BASH_TMPDIR/.context/working/.loop-detect.json"
BASH_DETECTED="no"
for i in $(seq 1 6); do
    OUTPUT=$(echo "$SIMPLE_INPUT" | PROJECT_ROOT="$BASH_TMPDIR" bash "$BASH_DIR/loop-detect.sh" 2>&1 || true)
    if echo "$OUTPUT" | grep -q "loop_detected"; then
        BASH_DETECTED="yes (call $i)"
    fi
done

echo "  TypeScript detected loop: $TS_DETECTED" | tee -a "$RESULTS_FILE"
echo "  Bash+Python detected loop: $BASH_DETECTED" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# --- Test 4: Shell Escaping (quotes in input) ---
echo "### Test 4: Shell Escaping (quotes in tool input)" | tee -a "$RESULTS_FILE"

rm -f "$TS_TMPDIR/.context/working/.loop-detect.json"
TS_ESCAPE="PASS"
echo "$QUOTES_INPUT" | PROJECT_ROOT="$TS_TMPDIR" node "$TS_DIR/loop-detect.js" 2>/dev/null
TS_EXIT=$?
if [ $TS_EXIT -ne 0 ]; then
    TS_ESCAPE="FAIL (exit $TS_EXIT)"
fi

rm -f "$BASH_TMPDIR/.context/working/.loop-detect.json"
BASH_ESCAPE="PASS"
echo "$QUOTES_INPUT" | PROJECT_ROOT="$BASH_TMPDIR" bash "$BASH_DIR/loop-detect.sh" 2>/dev/null
BASH_EXIT=$?
if [ $BASH_EXIT -ne 0 ]; then
    BASH_ESCAPE="FAIL (exit $BASH_EXIT)"
fi

echo "  TypeScript:   $TS_ESCAPE" | tee -a "$RESULTS_FILE"
echo "  Bash+Python:  $BASH_ESCAPE" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# --- Test 5: Complex JSON with special characters ---
echo "### Test 5: Special Characters (newlines, backslashes)" | tee -a "$RESULTS_FILE"

rm -f "$TS_TMPDIR/.context/working/.loop-detect.json"
TS_SPECIAL="PASS"
echo "$SPECIAL_INPUT" | PROJECT_ROOT="$TS_TMPDIR" node "$TS_DIR/loop-detect.js" 2>/dev/null
TS_EXIT=$?
if [ $TS_EXIT -ne 0 ]; then
    TS_SPECIAL="FAIL (exit $TS_EXIT)"
fi

rm -f "$BASH_TMPDIR/.context/working/.loop-detect.json"
BASH_SPECIAL="PASS"
echo "$SPECIAL_INPUT" | PROJECT_ROOT="$BASH_TMPDIR" bash "$BASH_DIR/loop-detect.sh" 2>/dev/null
BASH_EXIT=$?
if [ $BASH_EXIT -ne 0 ]; then
    BASH_SPECIAL="FAIL (exit $BASH_EXIT)"
fi

echo "  TypeScript:   $TS_SPECIAL" | tee -a "$RESULTS_FILE"
echo "  Bash+Python:  $BASH_SPECIAL" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# --- Test 6: State file integrity ---
echo "### Test 6: State File Integrity" | tee -a "$RESULTS_FILE"

TS_STATE=$(cat "$TS_TMPDIR/.context/working/.loop-detect.json" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'valid JSON, {len(d.get(\"history\",[]))} entries')" 2>/dev/null || echo "INVALID/MISSING")
BASH_STATE=$(cat "$BASH_TMPDIR/.context/working/.loop-detect.json" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'valid JSON, {len(d.get(\"history\",[]))} entries')" 2>/dev/null || echo "INVALID/MISSING")

echo "  TypeScript state:   $TS_STATE" | tee -a "$RESULTS_FILE"
echo "  Bash+Python state:  $BASH_STATE" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# --- Test 7: Compilation time ---
echo "### Test 7: Compilation (esbuild)" | tee -a "$RESULTS_FILE"

COMPILE_START=$(date +%s%N)
npx esbuild "$TS_DIR/loop-detect.ts" --bundle --platform=node --outfile=/tmp/loop-detect-bench.js --format=cjs 2>/dev/null
COMPILE_END=$(date +%s%N)
COMPILE_MS=$(( (COMPILE_END - COMPILE_START) / 1000000 ))
rm -f /tmp/loop-detect-bench.js

echo "  esbuild compile:  ${COMPILE_MS}ms" | tee -a "$RESULTS_FILE"
echo "  Bash+Python:      0ms (no compilation)" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# --- LOC comparison ---
echo "### LOC Comparison" | tee -a "$RESULTS_FILE"
TS_LOC=$(wc -l < "$TS_DIR/loop-detect.ts")
BASH_LOC=$(wc -l < "$BASH_DIR/loop-detect.sh")
JS_LOC=$(wc -l < "$TS_DIR/loop-detect.js")

echo "  TypeScript source: ${TS_LOC} lines" | tee -a "$RESULTS_FILE"
echo "  Compiled JS:       ${JS_LOC} lines" | tee -a "$RESULTS_FILE"
echo "  Bash+Python:       ${BASH_LOC} lines" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

echo "========================================" | tee -a "$RESULTS_FILE"
echo "Benchmark complete. Results: $RESULTS_FILE" | tee -a "$RESULTS_FILE"
