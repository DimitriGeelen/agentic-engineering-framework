#!/usr/bin/env bats
# T-2067: pin the components:-replacement regex in update-task.sh against all
# 5 historical shapes (the bug was that flow-style continuation lines weren't
# captured, leaving orphan closing-bracket continuations that produced
# invalid YAML and 404'd /review/T-XXX).

# The function under test is inlined inside update-task.sh as a python3 -c
# block. We extract just the regex+replacement logic into a standalone helper
# here so we can drive it from bats with synthetic frontmatters.

setup() {
    PROJECT_ROOT="${PROJECT_ROOT:-$BATS_TEST_DIRNAME/../..}"
    cd "$PROJECT_ROOT"
    TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMPDIR"
}

# Helper: run the production regex+replacement against an input file and a
# resolved component list, printing the result. Mirrors update-task.sh:1731
# (with the T-2067 fix applied).
run_replacement() {
    local input_file="$1"
    local resolved="$2"
    python3 -c "
import re, sys
resolved = sys.argv[1]
path = sys.argv[2]
with open(path) as f:
    content = f.read()
pattern = re.compile(
    r'^components:[^\n]*\n'
    r'(?:[ \t]+(?!\w+:)[^\n]*\n)*',
    re.MULTILINE,
)
new_block = 'components: [' + resolved + ']\n'
if pattern.search(content):
    content = pattern.sub(new_block, content, count=1)
sys.stdout.write(content)
" "$resolved" "$input_file"
}

# Helper: assert the output parses as YAML frontmatter
assert_parses() {
    local output="$1"
    echo "$output" > "$TMPDIR/check.md"
    python3 -c "
import sys
sys.path.insert(0, '.')
from web.shared import parse_frontmatter
with open('$TMPDIR/check.md') as f:
    content = f.read()
fm, body = parse_frontmatter(content)
assert fm is not False and fm is not None, 'frontmatter failed to parse'
" || return 1
}

@test "flat single-line flow-style components replaced cleanly" {
    cat > "$TMPDIR/t.md" <<'EOF'
---
id: T-9001
components: [old1, old2]
related_tasks: [T-001]
---
body
EOF
    result=$(run_replacement "$TMPDIR/t.md" "new1, new2, new3")
    [[ "$result" == *"components: [new1, new2, new3]"* ]]
    [[ "$result" != *"old1"* ]]
    [[ "$result" == *"related_tasks: [T-001]"* ]]
    assert_parses "$result"
}

@test "wrapped flow-style components (T-2067 origin bug) replaced cleanly" {
    cat > "$TMPDIR/t.md" <<'EOF'
---
id: T-9002
components: [old1, old2,
      old3]
related_tasks: [T-001]
---
body
EOF
    result=$(run_replacement "$TMPDIR/t.md" "new1, new2")
    [[ "$result" == *"components: [new1, new2]"* ]]
    # No orphan continuation line
    [[ "$result" != *"old3]"* ]]
    [[ "$result" != *"old1"* ]]
    [[ "$result" == *"related_tasks: [T-001]"* ]]
    assert_parses "$result"
}

@test "pre-mangled orphan continuation (the existing corpus victims) cleaned on next write" {
    # This is what T-2018/T-2059/T-2060/T-2061 looked like before manual repair.
    cat > "$TMPDIR/t.md" <<'EOF'
---
id: T-9003
components: [a, b, c, d]
      d]
related_tasks: [T-001]
---
body
EOF
    result=$(run_replacement "$TMPDIR/t.md" "new1, new2")
    [[ "$result" == *"components: [new1, new2]"* ]]
    # Orphan removed
    [[ "$result" != *"      d]"* ]]
    assert_parses "$result"
}

@test "block-style components replaced cleanly (T-1469 origin shape)" {
    cat > "$TMPDIR/t.md" <<'EOF'
---
id: T-9004
components:
  - old1
  - old2
related_tasks: [T-001]
---
body
EOF
    result=$(run_replacement "$TMPDIR/t.md" "new1, new2")
    [[ "$result" == *"components: [new1, new2]"* ]]
    [[ "$result" != *"  - old1"* ]]
    [[ "$result" == *"related_tasks: [T-001]"* ]]
    assert_parses "$result"
}

@test "empty flow components replaced cleanly" {
    cat > "$TMPDIR/t.md" <<'EOF'
---
id: T-9005
components: []
related_tasks: [T-001]
---
body
EOF
    result=$(run_replacement "$TMPDIR/t.md" "new1")
    [[ "$result" == *"components: [new1]"* ]]
    assert_parses "$result"
}

@test "next YAML key not eaten by continuation match" {
    # Regression guard: '(?!\w+:)' negative lookahead must protect against
    # eating the next key (e.g. 'related_tasks: [...]' line).
    cat > "$TMPDIR/t.md" <<'EOF'
---
id: T-9006
components: [a, b]
related_tasks: [T-001, T-002]
arc_id: arc-007
---
body
EOF
    result=$(run_replacement "$TMPDIR/t.md" "new")
    [[ "$result" == *"components: [new]"* ]]
    [[ "$result" == *"related_tasks: [T-001, T-002]"* ]]
    [[ "$result" == *"arc_id: arc-007"* ]]
    assert_parses "$result"
}
