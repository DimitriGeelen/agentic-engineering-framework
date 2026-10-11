#!/usr/bin/env bats
#
# T-4067 (010): cmd_spawn in agents/termlink/termlink.sh ended with
#   [ -n "$task_type" ] && echo "  Task-type: $task_type"
# With task_type empty that list returns 1, so the function returns 1 and
# `fw termlink dispatch` (set -euo pipefail) aborted silently right after
# "Tagged:" — session registered, worker never started, no error message.
#
# The class: a function whose LAST statement is a `[ … ] && cmd` list returns
# the test's failure as its own status. This file asserts no function in
# termlink.sh ends that way, plus a control showing the shape returns 1.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TL="$ROOT/agents/termlink/termlink.sh"
}

@test "no function in termlink.sh ends with a [ … ] && … list" {
    run python3 - "$TL" <<'PY'
import re, sys
lines = open(sys.argv[1]).read().split("\n")
bad, fn, last = [], None, None
for i, line in enumerate(lines, 1):
    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\(\)\s*\{\s*$", line)
    if m:
        fn, last = m.group(1), None
        continue
    if fn and line == "}":
        if last and re.match(r"^\s*(\[\[?|test )[^&|]*\]?\]?\s*&&", last[1]):
            bad.append(f"{fn} (line {last[0]}): {last[1].strip()}")
        fn = None
        continue
    if fn and line.strip() and not line.strip().startswith("#"):
        last = (i, line)
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "control: the shape really returns 1 when the test is false" {
    f() { local x=""; echo hi; [ -n "$x" ] && echo "x: $x"; }
    run f
    [ "$status" -eq 1 ]
}
