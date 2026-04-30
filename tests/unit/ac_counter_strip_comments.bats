#!/usr/bin/env bats
# T-1620 — `lib/inception.sh:642` and `lib/verify-acs.sh:224` must strip
# `<!-- ... -->` blocks before counting unchecked Human ACs. Same bug class as
# T-1618 (handover scanner) but in different consumers of the Human-AC counter.
#
# Witness: T-1274. Its Human section is ONLY the default-template Example
# block inside <!-- -->. Pre-fix, both consumers counted that as 1 phantom
# unchecked AC; post-fix, both must report 0.
#
# Mirrors the same fix at:
#   - bin/fw verify-acs (G-047)
#   - agents/handover/handover.sh (T-1618)

load ../test_helper

# ---- Source-level invariants ----

@test "lib/inception.sh strips <!-- ... --> before counting (T-1620)" {
    grep -q "T-1620" "$FRAMEWORK_ROOT/lib/inception.sh"
    grep -q 'flags=re.DOTALL' "$FRAMEWORK_ROOT/lib/inception.sh"
}

@test "lib/verify-acs.sh strips <!-- ... --> before counting (T-1620)" {
    grep -q "T-1620" "$FRAMEWORK_ROOT/lib/verify-acs.sh"
    grep -q "human_block = re.sub" "$FRAMEWORK_ROOT/lib/verify-acs.sh"
}

# ---- Behavioural — inception.sh:642 awk pipeline ----

@test "inception.sh awk-pipe pattern reports 0 phantom ACs (T-1620)" {
    cd "$TEST_TEMP_DIR"
    cat > task.md <<'EOF'
---
id: T-PHANTOM
---

## Acceptance Criteria

### Agent
- [x] Agent done

### Human
<!-- Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
-->

## Verification
EOF

    # The exact awk pipeline used in lib/inception.sh:642 post-T-1620.
    run bash -c '
awk "/^### Human/,/^## [A-Z]/" task.md \
    | python3 -c "import re,sys; sys.stdout.write(re.sub(r\"<!--.*?-->\", \"\", sys.stdin.read(), flags=re.DOTALL))" \
    | grep -cE "^\s*- \[ \]" || true'
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "inception.sh awk-pipe still counts real unchecked Human ACs (T-1620)" {
    cd "$TEST_TEMP_DIR"
    cat > task.md <<'EOF'
---
id: T-REAL
---

## Acceptance Criteria

### Human
- [ ] [REVIEW] Real human verification step
- [ ] [RUBBER-STAMP] Another real one
<!-- Example:
       - [ ] [REVIEW] Dashboard renders correctly
-->

## Verification
EOF

    run bash -c '
awk "/^### Human/,/^## [A-Z]/" task.md \
    | python3 -c "import re,sys; sys.stdout.write(re.sub(r\"<!--.*?-->\", \"\", sys.stdin.read(), flags=re.DOTALL))" \
    | grep -cE "^\s*- \[ \]" || true'
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

# ---- Behavioural — verify-acs.sh python pattern ----

@test "verify-acs.sh python pattern reports 0 phantom ACs (T-1620)" {
    run python3 -c '
import re
text = """
## Acceptance Criteria

### Human
<!-- Example:
       - [ ] [REVIEW] Dashboard renders correctly
-->

## Verification
"""
ac_match = re.search(r"^## Acceptance Criteria\s*\n(.*?)(?=\n## |\Z)", text, re.MULTILINE | re.DOTALL)
ac_section = ac_match.group(1)
human_match = re.search(r"### Human\s*\n(.*?)(?=\n### |\Z)", ac_section, re.DOTALL)
human_block = human_match.group(1)
human_block = re.sub(r"<!--.*?-->", "", human_block, flags=re.DOTALL)
unchecked = re.findall(r"^\s*-\s*\[ \]\s*(.*?)$", human_block, re.MULTILINE)
print(len(unchecked))
'
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "verify-acs.sh python pattern still counts real unchecked ACs (T-1620)" {
    run python3 -c '
import re
text = """
## Acceptance Criteria

### Human
- [ ] [REVIEW] Real human verification step
<!-- Example:
       - [ ] [REVIEW] Dashboard renders correctly
-->

## Verification
"""
ac_match = re.search(r"^## Acceptance Criteria\s*\n(.*?)(?=\n## |\Z)", text, re.MULTILINE | re.DOTALL)
ac_section = ac_match.group(1)
human_match = re.search(r"### Human\s*\n(.*?)(?=\n### |\Z)", ac_section, re.DOTALL)
human_block = human_match.group(1)
human_block = re.sub(r"<!--.*?-->", "", human_block, flags=re.DOTALL)
unchecked = re.findall(r"^\s*-\s*\[ \]\s*(.*?)$", human_block, re.MULTILINE)
print(len(unchecked))
'
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

# ---- Sanity ----

@test "lib/inception.sh parses (bash -n) after T-1620" {
    bash -n "$FRAMEWORK_ROOT/lib/inception.sh"
}

@test "lib/verify-acs.sh parses (bash -n) after T-1620" {
    bash -n "$FRAMEWORK_ROOT/lib/verify-acs.sh"
}
