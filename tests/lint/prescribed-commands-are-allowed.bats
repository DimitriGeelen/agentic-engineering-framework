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
# The test exercises budget-gate's ACTUAL decision function rather than restating
# it. A copy would drift from the thing it guards, and would then agree with
# itself while the gate disagreed — the same false green this directory exists to
# catch.
#
# T-2919 moved that decision out of an inline regex and into lib/cmd_classify.py
# (the regex answered "does this string mention wrap-up?" when the question is
# "is this command wrap-up?"; 5/9 of a composition probe were misclassified).
# This test followed it, per its own instruction below: update, do not delete.
# It is now stronger than it was — it calls the function the gate calls, instead
# of re-compiling a pattern lifted out of the gate's source.

GATE="$BATS_TEST_DIRNAME/../../agents/context/budget-gate.sh"
BLOCKER="$BATS_TEST_DIRNAME/../../agents/context/check-active-task.sh"
CLASSIFY="$BATS_TEST_DIRNAME/../../lib/cmd_classify.py"

@test "every fw command prescribed in a block message is allowed by budget-gate" {
    run python3 - "$CLASSIFY" "$BLOCKER" "$GATE" <<'PY'
import importlib.util, re, sys

spec = importlib.util.spec_from_file_location("cmd_classify", sys.argv[1])
if spec is None or spec.loader is None:
    print("FAIL: could not load the classifier at " + sys.argv[1])
    print("If it was renamed or restructured, update this test — do not delete it.")
    sys.exit(1)
cc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cc)

blocker_src = open(sys.argv[2]).read()
gate_src = open(sys.argv[3]).read()

# The gate must actually be wired to the classifier we just loaded. Without
# this, the check below could pass against a module the gate no longer calls.
if "from cmd_classify import classify" not in gate_src:
    print("FAIL: budget-gate.sh no longer imports cmd_classify.classify")
    print("If the wiring moved, update this test — do not delete it.")
    sys.exit(1)


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

denied = [c for c in sorted(prescribed) if not cc.classify("fw " + c)[0]]
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

@test "the classifier is still locatable and still wired into budget-gate.sh" {
    # Guards the extraction itself. If the decision point is restructured and
    # this test silently stops finding it, the check above would pass by not
    # checking — which is the failure mode this whole directory exists for.
    #
    # Two halves, because either alone can go stale: the module must exist, AND
    # the gate must still call it. A classifier nobody calls passes any test
    # written about the classifier.
    [ -f "$CLASSIFY" ]
    grep -q "from cmd_classify import classify" "$GATE"
}

@test "the prescribed-command check fails loudly if the classifier goes missing" {
    # Negative control on this file's own machinery (T-2916 class): a guard that
    # cannot read its input must not report the same thing as one that read it
    # and found nothing. Point the check at a non-existent classifier and it has
    # to fail, not pass vacuously.
    run python3 - "$BATS_TEST_DIRNAME/does-not-exist.py" "$BLOCKER" "$GATE" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("cmd_classify", sys.argv[1])
try:
    cc = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cc)
except Exception:
    print("FAIL: could not load the classifier")
    sys.exit(1)
sys.exit(0)
PY
    [ "$status" -ne 0 ]
}
