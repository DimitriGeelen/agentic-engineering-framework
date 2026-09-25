#!/usr/bin/env bats
# T-3458 — web/shared.py:load_yaml now parses with libyaml's CSafeLoader when the
# binding is present, instead of `yaml.safe_load`'s pure-Python SafeLoader.
#
# Measured in isolation (files pre-read into memory so disk I/O is excluded):
# 800 corpus YAML files, 6.7 MB — pure-Python 16.95s, libyaml 1.39s, **12.2x**.
#
# IMPORTANT SCOPE NOTE, so nobody reads more into this than it earned: this is a
# parser change, NOT the fix for the 9-18s dashboard latency that opened the
# task. The warm in-process request measured ~1.5s under BOTH loaders. See the
# task's ## Context for what is and is not explained.
#
# What must not regress:
#   1. the C loader is selected when available (else the 12x is silently lost);
#   2. it falls back rather than raising where libyaml is absent (D4 portability —
#      a consumer host may have a source-built PyYAML);
#   3. both loaders produce EQUAL data for the same input. This is the leg that
#      makes the swap a speed change rather than a semantics change; it was
#      checked across all 5339 corpus YAML files before shipping (0 differing).
#
# No duration is pinned (T-3326): 12.2x is this host's number and would rot.
# The property is what is guarded.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "load_yaml selects the C loader when libyaml is available" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/web')
import yaml, shared
if not yaml.__with_libyaml__:
    print('SKIP'); raise SystemExit(0)
print('C' if shared._YAML_LOADER is yaml.CSafeLoader else 'PY')
"
    [ "$status" -eq 0 ]
    [[ "$output" == "C" || "$output" == "SKIP" ]]
}

@test "the loader is resolved with a fallback, not a hard reference to CSafeLoader" {
    # A bare `yaml.CSafeLoader` would raise AttributeError at import on a host
    # whose PyYAML was built without the C extension, taking the whole web app
    # down rather than losing a speedup.
    grep -q 'getattr(yaml, "CSafeLoader", yaml.SafeLoader)' "$FRAMEWORK_ROOT/web/shared.py"
}

@test "no yaml.safe_load call remains in shared.py — every site takes the C loader" {
    # This test earned its place: the first pass of the change touched only
    # load_yaml and left two sites behind, including the episodic loop that
    # parses every .context/episodic/T-*.yaml — thousands of documents, and the
    # single biggest YAML cost on a cold request. A grep scoped to one call
    # shape would have passed while the hot path stayed on the slow parser.
    run grep -c 'yaml\.safe_load(' "$FRAMEWORK_ROOT/web/shared.py"
    [ "$output" = "0" ]
}

@test "both loaders produce equal data for the same document" {
    cat > "$TEST_TEMP_DIR/fix.yaml" <<'YEOF'
id: T-1
name: "a name with: a colon"
nested:
  list: [1, 2, 3]
  flag: true
  empty:
  when: 2026-09-25
  text: |
    line one
    line two
  quoted: '0123'
YEOF
    run python3 -c "
import yaml, sys
p = '$TEST_TEMP_DIR/fix.yaml'
a = yaml.load(open(p), Loader=yaml.SafeLoader)
b = yaml.load(open(p), Loader=getattr(yaml, 'CSafeLoader', yaml.SafeLoader))
print('EQUAL' if a == b else 'DIFFER')
"
    [ "$status" -eq 0 ]
    [ "$output" = "EQUAL" ]
}

@test "a malformed document still raises YAMLError, so load_yaml's handler still fires" {
    # load_yaml catches yaml.YAMLError and collects the message. CSafeLoader must
    # raise the same exception type or the error path silently changes shape.
    printf 'a: [1, 2\nb: }{\n' > "$TEST_TEMP_DIR/bad.yaml"
    run python3 -c "
import yaml
try:
    yaml.load(open('$TEST_TEMP_DIR/bad.yaml'), Loader=getattr(yaml, 'CSafeLoader', yaml.SafeLoader))
    print('NO_RAISE')
except yaml.YAMLError:
    print('YAMLError')
"
    [ "$status" -eq 0 ]
    [ "$output" = "YAMLError" ]
}

@test "load_yaml still returns {} for a malformed file rather than propagating" {
    printf 'a: [1, 2\nb: }{\n' > "$TEST_TEMP_DIR/bad.yaml"
    # load_yaml logs the parse error before returning, and bats folds that
    # warning into $output — so assert on the RETURN VALUE line, not the whole
    # stream. The first draft compared the entire output and failed on the log
    # line, which looked exactly like the function returning the wrong thing.
    run python3 -c "
import sys, logging; logging.disable(logging.CRITICAL)
sys.path.insert(0, '$FRAMEWORK_ROOT/web')
import shared
print('RESULT=' + repr(shared.load_yaml('$TEST_TEMP_DIR/bad.yaml')))
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESULT={}"* ]]
}

@test "load_yaml still returns {} for a missing file" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/web')
import shared
print(repr(shared.load_yaml('$TEST_TEMP_DIR/nope.yaml')))
"
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

@test "a scalar top-level document still normalises to {}" {
    printf 'just a string\n' > "$TEST_TEMP_DIR/scalar.yaml"
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/web')
import shared
print(repr(shared.load_yaml('$TEST_TEMP_DIR/scalar.yaml')))
"
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}
