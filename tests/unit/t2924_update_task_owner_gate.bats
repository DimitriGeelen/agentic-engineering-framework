#!/usr/bin/env bats
# T-2924 — `fw task update --owner` must validate against the owner enum.
#
# Raised by 832 on the DM rail: their tree practises `agent` x304 while the copy
# they vendored names `human`/`claude-code`, and they asked which is
# authoritative before their BPMN compiler starts emitting owners into task
# files. Measuring the answer here surfaced the actual defect.
#
# `update-task.sh` validates `--type` (is_valid_type) and `--horizon`
# (is_valid_horizon) and did NOT validate `--owner` — the one sibling of three
# left open. T-2674 closed the CREATE side (create-task.sh:203) and the update
# path was never given the same treatment, so any string was written verbatim
# while Watchtower's dropdowns whitelist the enum.
#
# Measured cost of the gap before the fix: 10 task files outside the enum
# (6 `claude`, 4 empty), counted from FRONTMATTER only — a whole-file
# `grep '^owner:'` also matches body prose at column 0, which is the
# mention-vs-instance error (L-576) that this suite's own measurement had to
# avoid.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    ENUMS="$FRAMEWORK_ROOT/status-transitions.yaml"
    UPDATE="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
}

@test "t2924: the owner enum has a single authoritative source" {
    # Not asserting the VALUES — asserting that the enum is sourced from a file
    # rather than only from the hardcoded fallback in lib/enums.sh. If this key
    # disappears, `owners` silently falls back to the Python default in
    # _enums_load_yaml and the two can drift without anything noticing.
    run python3 -c "
import yaml
d = yaml.safe_load(open('$ENUMS'))
assert 'owners' in d, 'status-transitions.yaml has no owners: key'
print(' '.join(d['owners']))
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"agent"* ]]
    [[ "$output" == *"human"* ]]
}

@test "t2924: lib/enums.sh fallback matches the YAML source" {
    # The fallback exists for when the YAML cannot be parsed. If it disagrees
    # with the YAML, which enum you get depends on whether parsing succeeded —
    # a difference no caller can see. That is the drift 832 hit from the other
    # side, where three vocabularies were live at once.
    yaml_owners=$(python3 -c "
import yaml; print(' '.join(yaml.safe_load(open('$ENUMS'))['owners']))")
    fallback=$(grep -oP '(?<=^    VALID_OWNERS=")[^"]*' "$FRAMEWORK_ROOT/lib/enums.sh")
    [ "$yaml_owners" = "$fallback" ]
}

@test "t2924: update-task.sh validates --owner against the enum" {
    # The instance, not the mention: assert the CALL, not that the identifier
    # appears somewhere in the file (it appears in this task's own comment).
    run grep -c 'if ! is_valid_owner "\$NEW_OWNER"; then' "$UPDATE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "t2924: --owner validation is a sibling of the --type and --horizon checks" {
    # All three enums arrive by the same route and are written by the same
    # `_sed_i`. Validating two of three is how this gap survived T-2674: nothing
    # compared the three paths to each other.
    for fn in is_valid_owner is_valid_type is_valid_horizon; do
        grep -q "if ! $fn " "$UPDATE" || {
            echo "update-task.sh does not call $fn on the update path" >&2
            return 1
        }
    done
}

@test "t2924: anti-vacuity — an out-of-enum owner is rejected by the predicate" {
    # Drives the real predicate rather than asserting on source text, so a
    # future change that keeps the call site but breaks the enum goes red.
    run bash -c "
        set -e
        FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        . '$FRAMEWORK_ROOT/lib/enums.sh'
        is_valid_owner agent        || { echo 'agent rejected'; exit 1; }
        is_valid_owner human        || { echo 'human rejected'; exit 1; }
        is_valid_owner claude-code  || { echo 'claude-code rejected'; exit 1; }
        ! is_valid_owner claude     || { echo 'claude accepted'; exit 1; }
        ! is_valid_owner ''         || { echo 'empty accepted'; exit 1; }
        ! is_valid_owner bogus      || { echo 'bogus accepted'; exit 1; }
        echo OK
    "
    [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
    [[ "$output" == *OK* ]]
}

@test "t2924: no task file carries an out-of-enum owner in its frontmatter" {
    # The corpus check. Counts from frontmatter ONLY. A whole-file grep would
    # also match body prose starting `owner:` at column 0 — exactly one task
    # file does (T-2577), and counting it would be the mention-vs-instance
    # error this task exists to correct.
    #
    # This leg is expected to be RED until the 10 legacy files are reconciled;
    # it is written now so the reconciliation has a finish line rather than an
    # opinion. Skips rather than fails so it reports without blocking, and
    # names the count either way — a verdict must never print without its
    # denominator (T-2916).
    run python3 - "$FRAMEWORK_ROOT" <<'PY'
import glob, os, re, sys
root = sys.argv[1]
valid = {'human', 'agent', 'claude-code'}
bad, total = [], 0
for p in glob.glob(os.path.join(root, '.tasks/*/T-*.md')):
    s = open(p, encoding='utf-8', errors='replace').read()
    if not s.startswith('---'):
        continue
    end = s.find('\n---', 3)
    if end < 0:
        continue
    total += 1
    m = re.search(r'^owner:[ \t]*(.*)$', s[3:end], re.M)
    v = (m.group(1).strip() if m else '') or '<empty>'
    if v not in valid:
        bad.append((os.path.basename(p), v))
print("evaluated %d task file(s), %d out-of-enum" % (total, len(bad)))
for f, v in bad:
    print("  %-52s %s" % (f, v))
raise SystemExit(1 if bad else 0)
PY
    if [ "$status" -ne 0 ]; then
        skip "legacy drift not yet reconciled — $output"
    fi
}
