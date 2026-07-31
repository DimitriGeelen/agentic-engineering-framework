#!/usr/bin/env bats
# T-2702 — a command one gate PRESCRIBES must be one the budget gate ALLOWS.
#
# Origin: check-active-task.sh blocks when focus is empty (the state a
# just-completed task leaves behind) and prints `fw context focus T-XXX` as the
# remedy. budget-gate.sh's allowed-command allowlist carried `context init` but
# not `context focus`, so at critical budget the agent was told the remedy and
# denied it in the same breath — a hard deadlock at exactly the moment the
# session is trying to wrap up.
#
# Reported by a consumer (832) who hit it and could NOT file it, because filing
# required the blocked path. A defect that suppresses its own bug report will not
# arrive through the usual channel, so it needs a standing check rather than a
# reliance on someone getting through to report it.
#
# The test reads budget-gate's ACTUAL regex rather than restating it. A copy would
# drift from the thing it guards, and would then agree with itself while the gate
# disagreed — the same false green this directory exists to catch.

GATE="$BATS_TEST_DIRNAME/../../agents/context/budget-gate.sh"
BLOCKER="$BATS_TEST_DIRNAME/../../agents/context/check-active-task.sh"

@test "every fw command prescribed in a block message is allowed by budget-gate" {
    run python3 - "$GATE" "$BLOCKER" <<'PY'
import re, sys

gate_src = open(sys.argv[1]).read()
blocker_src = open(sys.argv[2]).read()

# The live allowlist, lifted verbatim from the gate.
m = re.search(r"is_allowed_cmd = bool\(re\.search\(r'(.+?)', command\)\)", gate_src)
if not m:
    print("FAIL: could not locate the allowlist regex in budget-gate.sh")
    print("If it was renamed or restructured, update this test — do not delete it.")
    sys.exit(1)
allow = re.compile(m.group(1))

# Commands the blocker tells the agent to run — POSITIONAL, not lexical.
#
# A first cut matched any `fw <verb>` inside an echoed string and pulled in
# "fw command" from the sentence "Append --switch-focus to a fw command", plus
# "fw context add-" from "Works for: fw task update, fw context add-*". Prose
# naming a verb is not an instruction to run it. Same correction T-2700 made to
# the bare-fw detector, and the same reason: a guard that fires on prose is not
# a stricter guard, it is one that gets ignored (L-527).
#
# A prescribed remedy has a recognisable shape — a numbered step, an optional
# "Label:" and then the command. That shape is what we extract.
prescribed = set()
for line in blocker_src.splitlines():
    line = re.sub(r'#.*', '', line)                       # comments are not remedies (L-519)
    for s in re.findall(r'"([^"]*)"', line):
        s = s.strip()
        m2 = re.match(r'^\d+\.\s+(?:[A-Z][^:]{0,30}:\s*)?(.+)$', s)
        if not m2:
            continue
        raw = m2.group(1).strip()
        # Must actually BE an fw invocation. "Edit the task file: replace [X]
        # with real ACs" is a numbered remedy step, but not a command to run.
        if not re.match(r'^(?:\$\(_fw_cmd\)|(?:bin/|\.agentic-framework/bin/)?fw)\s', raw):
            continue
        cmd = re.sub(r'^(?:\$\(_fw_cmd\)|(?:bin/|\.agentic-framework/bin/)?fw)\s+', '', raw)
        verb = re.match(r'^([a-z][a-z-]*(?:\s+[a-z][a-z-]*)?)', cmd)
        if verb:
            prescribed.add(verb.group(1).strip())

if not prescribed:
    print("FAIL: extracted no prescribed commands — the extraction broke, not the gate.")
    sys.exit(1)

denied = [c for c in sorted(prescribed) if not allow.search("fw " + c)]
if denied:
    print("Commands a block message tells the agent to run, which budget-gate")
    print("refuses at critical (deadlock — prescribed and denied at once):")
    for c in denied:
        print("  fw " + c)
    sys.exit(1)
print("checked %d prescribed command(s), all allowed" % len(prescribed))
PY
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "the allowlist regex is still locatable in budget-gate.sh" {
    # Guards the extraction itself. If the regex is restructured and this test
    # silently stops finding it, the check above would pass by not checking —
    # which is the failure mode this whole directory exists for.
    grep -q "is_allowed_cmd = bool(re.search(r'" "$GATE"
}
