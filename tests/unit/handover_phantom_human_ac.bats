#!/usr/bin/env bats
# T-1618 — handover scanner must strip <!-- ... --> blocks before counting
# unchecked Human ACs. The default task template includes an Example AC inside
# a comment ("- [ ] [REVIEW] Dashboard renders correctly") that the scanner
# at agents/handover/handover.sh previously counted as a real unchecked AC,
# pinning template-only tasks (e.g. T-1274) into "Awaiting Your Action" forever.
#
# Origin: T-1616 inception (GO 2026-04-30) → T-1618 build.
# Mirror of the same fix applied to bin/fw verify-acs at G-047.

load ../test_helper

# ---- Source-level invariant ----

@test "handover.sh strips <!-- ... --> before counting Human ACs (T-1618)" {
    # The comment-strip line must appear in the partial-complete scanner.
    # Pattern pinned: re.sub(r'<!--.*?-->', '', ..., flags=re.DOTALL)
    grep -q "human_section = re.sub(r'<!--.*?-->'" \
        "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "T-1618 rationale comment present in handover.sh" {
    grep -q 'T-1618' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

# ---- Behavioural ----

@test "phantom AC inside <!-- ... --> is NOT counted (T-1618)" {
    # Reproduces the canonical phantom: a Human section that is ONLY the
    # template's Example block. The scanner must report 0 unchecked ACs.
    run python3 -c '
import re
human_section = """
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
-->
"""
human_section = re.sub(r"<!--.*?-->", "", human_section, flags=re.DOTALL)
unchecked = len(re.findall(r"^\s*-\s*\[ \]", human_section, re.M))
print(unchecked)
'
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "real unchecked Human AC IS counted (T-1618)" {
    # The fix must not break legitimate Human AC detection.
    run python3 -c '
import re
human_section = """
- [ ] [REVIEW] Real human verification step
  **Steps:** 1. Do the thing
<!-- Example:
       - [ ] [REVIEW] Dashboard renders correctly
-->
"""
human_section = re.sub(r"<!--.*?-->", "", human_section, flags=re.DOTALL)
unchecked = len(re.findall(r"^\s*-\s*\[ \]", human_section, re.M))
print(unchecked)
'
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "checked AC inside comment also stripped, real checked still counted (T-1618)" {
    # Stripping must not skew the checked-count either.
    run python3 -c '
import re
human_section = """
- [x] [REVIEW] Real done step
<!-- Example:
       - [x] [REVIEW] Phantom done step
-->
"""
human_section = re.sub(r"<!--.*?-->", "", human_section, flags=re.DOTALL)
checked = len(re.findall(r"^\s*-\s*\[x\]", human_section, re.M))
print(checked)
'
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

# ---- Sanity ----

@test "handover.sh parses (bash -n) after T-1618 fix" {
    bash -n "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}
