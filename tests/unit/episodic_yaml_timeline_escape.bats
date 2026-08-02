#!/usr/bin/env bats
# T-2729 — the episodic generator's git-timeline rows must survive a commit
# subject containing YAML-hostile characters.
#
# Origin: closing T-2728 produced .context/episodic/T-2728.yaml that PyYAML
# refused to load. The mined subject contained `\x` (from "reviewer crashes on
# \x in task text") and the emitter wrote it into a DOUBLE-quoted YAML scalar
# after escaping only the double quote. In a double-quoted scalar backslash is
# the escape introducer: `\x` is an invalid escape (hard parser error) and `\n`
# would silently become a newline instead of the two literal characters.
#
# This is the FIFTH emission site in this one writer. T-1871 converted
# decisions; T-1873 converted outcomes, challenges and artifacts — both for
# exactly this reason (L-392) — and the sibling sweep stopped one block short.
#
# WHY THIS FILE EXISTS SEPARATELY FROM episodic_yaml_decision_escape.bats:
# that suite's behavioural tests re-type the emitter's sed chain into a local
# `_emit_and_parse` helper. A test that reimplements the writer can only ever
# check the sites its author already knew about — it stayed green through all
# of T-2728's corruption because it never ran the writer. The tests below drive
# the REAL generator end-to-end (`fw context generate-episodic`) against a
# fixture repo, so a sixth divergent site cannot hide from them.

load ../test_helper

# Build a throwaway project whose single commit subject carries every character
# class that distinguishes a single- from a double-quoted YAML scalar.
#   \x  invalid double-quote escape  -> hard parser error
#   \n  valid double-quote escape    -> silent corruption (becomes a newline)
#   "   needs escaping in double     -> passes through single verbatim
#   '   passes through double        -> needs '' doubling in single
_make_fixture() {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj/.tasks/completed" "$proj/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$proj/.framework.yaml"

    cat > "$proj/.tasks/completed/T-9999-fixture.md" <<'TASK'
---
id: T-9999
name: "yaml hostile timeline fixture"
description: fixture
status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-08-02T00:00:00Z
last_update: '2026-08-02T01:00:00Z'
---

## Acceptance Criteria

### Agent
- [x] fixture criterion

## Updates
TASK

    git -C "$proj" init -q
    git -C "$proj" -c user.email=t@t -c user.name=t add -A
    git -C "$proj" -c user.email=t@t -c user.name=t commit -q \
        -m 'T-9999: hazard \x plus \n plus "dq" plus '"'"'sq'"'"' tail'
    echo "$proj"
}

# Run the real generator. Returns the episodic path.
#
# PROJECT_ROOT and its derivatives must be unset. update-task.sh EXPORTS
# PROJECT_ROOT when it runs this file as a P-011 verification command; inherited,
# it points `fw` at the real repo, T-9999 is not found there, and the fixture
# episodic is never written — the tests below then fail for a reason that has
# nothing to do with escaping. Caught by test 1's `[ -f "$ep" ]` when the suite
# was first run under the completion gate. Same measuring-the-wrong-object trap
# as the T-2726 fixtures; update-task.sh:1018 unsets the other three for exactly
# this reason and cannot unset PROJECT_ROOT because it needs it to cd.
_generate() {
    local proj="$1"
    ( unset PROJECT_ROOT TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED
      cd "$proj" && "$FRAMEWORK_ROOT/bin/fw" context generate-episodic T-9999 >/dev/null 2>&1 )
    echo "$proj/.context/episodic/T-9999.yaml"
}

@test "T-2729: generated episodic parses when the commit subject carries \\x" {
    local proj ep
    proj="$(_make_fixture)"
    ep="$(_generate "$proj")"
    [ -f "$ep" ]
    run python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$ep"
    [ "$status" -eq 0 ]
}

@test "T-2729: the timeline action round-trips the git subject byte-for-byte" {
    # Compared against `git log` itself, never against a literal re-typed here —
    # a hand-written expectation is a second instrument that can drift from the
    # fixture and agree with a broken writer.
    local proj ep
    proj="$(_make_fixture)"
    ep="$(_generate "$proj")"
    git -C "$proj" log --format='%s' --reverse > "$TEST_TEMP_DIR/subjects.txt"

    run python3 - "$ep" "$TEST_TEMP_DIR/subjects.txt" <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
got = [r["action"] for r in doc["git_timeline"]]
want = open(sys.argv[2]).read().splitlines()
assert got == want, "round-trip mismatch\n got: %r\nwant: %r" % (got, want)
print("EXACT")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXACT"* ]]
}

@test "T-2729 control: the fixture is genuinely hostile to the pre-fix shape" {
    # Without this, a fixture that happens to contain nothing special would make
    # the two tests above pass against ANY emitter. Here the emitted line is
    # transformed back into the pre-fix form (double-quoted, only `"` escaped)
    # and must be REJECTED. If this control ever goes green, the fixture has
    # lost its teeth and the tests above are decoration.
    local proj ep
    proj="$(_make_fixture)"
    ep="$(_generate "$proj")"

    run python3 - "$ep" <<'PY'
import re, sys, yaml
src = open(sys.argv[1]).read()
def to_double(m):
    body = m.group(1).replace("''", "'")
    return '    action: "%s"' % body.replace('"', '\\"')
mutated, n = re.subn(r"^    action: '(.*)'$", to_double, src, flags=re.M)
assert n > 0, "no single-quoted action rows found — fixture produced no timeline"
try:
    yaml.safe_load(mutated)
except yaml.YAMLError:
    print("CONTROL OK")
    sys.exit(0)
sys.exit("CONTROL FAILED — pre-fix shape parsed, fixture is toothless")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"CONTROL OK"* ]]
}

@test "T-2729 guard: no interpolated double-quoted YAML scalar in the writer" {
    # Derived from source in both directions, with no maintained allowlist: any
    # line that writes `key: "$var"` into the episodic is by construction
    # exposed to backslash-escape processing. The four surviving double-quoted
    # emissions in this file are literal [TODO] placeholders with no `$`, so the
    # predicate is exactly "interpolation inside a double-quoted scalar".
    #
    # This is the check that would have caught the T-2728 corruption at author
    # time rather than at close time, and the one that catches a sixth site.
    local writer="$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    run grep -nE ':[[:space:]]*\\"\$' "$writer"
    [ "$status" -ne 0 ] || {
        echo "double-quoted interpolated scalar(s) still present:" >&2
        echo "$output" >&2
        false
    }
}

@test "T-2729 guard control: the guard detects a reintroduced double-quoted scalar" {
    # Proves the grep above can fail. Runs against a COPY, never the real file.
    local copy="$TEST_TEMP_DIR/episodic-regressed.sh"
    cp "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh" "$copy"
    printf '    echo "    action: \\"$escaped_msg\\"" >> "$episodic_file"\n' >> "$copy"
    run grep -nE ':[[:space:]]*\\"\$' "$copy"
    [ "$status" -eq 0 ]
}

@test "T-2729: every episodic in the corpus parses (blast radius)" {
    # OBS-129 (T-100202, multi-line task_name capture) is a DIFFERENT generator
    # defect found by this same sweep and is excluded by name, not by silence.
    run python3 - "$FRAMEWORK_ROOT" <<'PY'
import glob, os, sys, yaml
known = {"T-100202.yaml"}          # OBS-129 — tracked separately
bad = []
for f in sorted(glob.glob(os.path.join(sys.argv[1], ".context/episodic/*.yaml"))):
    if os.path.basename(f) in known:
        continue
    try:
        yaml.safe_load(open(f))
    except Exception as e:
        bad.append((os.path.basename(f), str(e).splitlines()[0][:70]))
if bad:
    sys.exit("unparseable episodics: %r" % bad)
print("corpus clean")
PY
    [ "$status" -eq 0 ]
}

@test "T-2729: bash -n clean on the writer" {
    run bash -n "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    [ "$status" -eq 0 ]
}
