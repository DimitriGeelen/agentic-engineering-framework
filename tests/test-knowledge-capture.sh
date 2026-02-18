#!/bin/bash
# Test script: Knowledge capture commands (add-learning, add-pattern, add-decision)
# Verifies T-141 fixes: YAML format, migration, parse correctness
# Usage: ./tests/test-knowledge-capture.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR=$(mktemp -d)
TEST_PROJECT="$TEST_DIR/test-project"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

pass() {
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} $1"
}

setup_project() {
    mkdir -p "$TEST_PROJECT/.context/project"
    mkdir -p "$TEST_PROJECT/.context/working"
    mkdir -p "$TEST_PROJECT/.context/episodic"
    mkdir -p "$TEST_PROJECT/.tasks/active"
}

echo "=== Knowledge Capture Tests ==="
echo ""

# --- Test 1: init.sh creates correct formats ---
echo "Test 1: init.sh creates compatible YAML formats"
setup_project

# Simulate init.sh patterns format
cat > "$TEST_PROJECT/.context/project/patterns.yaml" << 'EOF'
# Project Patterns
failure_patterns: []

success_patterns: []

workflow_patterns: []
EOF

cat > "$TEST_PROJECT/.context/project/learnings.yaml" << 'EOF'
# Project Learnings
learnings:
EOF

cat > "$TEST_PROJECT/.context/project/decisions.yaml" << 'EOF'
# Project Decisions
decisions:
EOF

python3 -c "import yaml; yaml.safe_load(open('$TEST_PROJECT/.context/project/patterns.yaml'))" 2>/dev/null && pass "patterns.yaml parses" || fail "patterns.yaml parse error"
python3 -c "import yaml; yaml.safe_load(open('$TEST_PROJECT/.context/project/learnings.yaml'))" 2>/dev/null && pass "learnings.yaml parses" || fail "learnings.yaml parse error"
python3 -c "import yaml; yaml.safe_load(open('$TEST_PROJECT/.context/project/decisions.yaml'))" 2>/dev/null && pass "decisions.yaml parses" || fail "decisions.yaml parse error"

# --- Test 2: add-pattern writes and parses ---
echo ""
echo "Test 2: add-pattern writes to file and produces valid YAML"

PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-pattern failure "Test failure" --task T-001 --mitigation "Fix it" >/dev/null 2>&1
count=$(python3 -c "import yaml; d=yaml.safe_load(open('$TEST_PROJECT/.context/project/patterns.yaml')); print(len(d.get('failure_patterns', [])))" 2>/dev/null)
[ "$count" = "1" ] && pass "failure pattern written (count=$count)" || fail "failure pattern not written (count=$count)"

PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-pattern success "Test success" --task T-002 >/dev/null 2>&1
count=$(python3 -c "import yaml; d=yaml.safe_load(open('$TEST_PROJECT/.context/project/patterns.yaml')); print(len(d.get('success_patterns', [])))" 2>/dev/null)
[ "$count" = "1" ] && pass "success pattern written (count=$count)" || fail "success pattern not written (count=$count)"

PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-pattern workflow "Test workflow" --task T-003 >/dev/null 2>&1
count=$(python3 -c "import yaml; d=yaml.safe_load(open('$TEST_PROJECT/.context/project/patterns.yaml')); print(len(d.get('workflow_patterns', [])))" 2>/dev/null)
[ "$count" = "1" ] && pass "workflow pattern written (count=$count)" || fail "workflow pattern not written (count=$count)"

# --- Test 3: add-pattern migration from old format ---
echo ""
echo "Test 3: add-pattern migrates old patterns: [] format"

cat > "$TEST_PROJECT/.context/project/patterns.yaml" << 'EOF'
# Old format
patterns: []
EOF

PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-pattern failure "Migration test" --task T-004 --mitigation "Migrate" >/dev/null 2>&1
count=$(python3 -c "import yaml; d=yaml.safe_load(open('$TEST_PROJECT/.context/project/patterns.yaml')); print(len(d.get('failure_patterns', [])))" 2>/dev/null)
[ "$count" = "1" ] && pass "migration: old format converted and pattern written" || fail "migration: pattern not written (count=$count)"

grep -q "failure_patterns:" "$TEST_PROJECT/.context/project/patterns.yaml" && pass "migration: failure_patterns section exists" || fail "migration: failure_patterns section missing"
grep -q "success_patterns:" "$TEST_PROJECT/.context/project/patterns.yaml" && pass "migration: success_patterns section exists" || fail "migration: success_patterns section missing"
grep -q "workflow_patterns:" "$TEST_PROJECT/.context/project/patterns.yaml" && pass "migration: workflow_patterns section exists" || fail "migration: workflow_patterns section missing"

# --- Test 4: add-learning writes and parses ---
echo ""
echo "Test 4: add-learning writes to file and produces valid YAML"

cat > "$TEST_PROJECT/.context/project/learnings.yaml" << 'EOF'
# Project Learnings
learnings:
EOF

PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-learning "Test learning one" --task T-005 --source P-001 >/dev/null 2>&1
count=$(python3 -c "import yaml; d=yaml.safe_load(open('$TEST_PROJECT/.context/project/learnings.yaml')); print(len(d.get('learnings', [])))" 2>/dev/null)
[ "$count" = "1" ] && pass "learning written (count=$count)" || fail "learning not written (count=$count)"

PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-learning "Test learning two" --task T-006 >/dev/null 2>&1
count=$(python3 -c "import yaml; d=yaml.safe_load(open('$TEST_PROJECT/.context/project/learnings.yaml')); print(len(d.get('learnings', [])))" 2>/dev/null)
[ "$count" = "2" ] && pass "second learning appended (count=$count)" || fail "second learning not appended (count=$count)"

# --- Test 5: add-learning migrates old learnings: [] format ---
echo ""
echo "Test 5: add-learning migrates old learnings: [] format"

cat > "$TEST_PROJECT/.context/project/learnings.yaml" << 'EOF'
# Old format
learnings: []
EOF

PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-learning "Migration learning" --task T-007 >/dev/null 2>&1
count=$(python3 -c "import yaml; d=yaml.safe_load(open('$TEST_PROJECT/.context/project/learnings.yaml')); print(len(d.get('learnings', [])))" 2>/dev/null)
[ "$count" = "1" ] && pass "migration: learnings: [] converted and learning written" || fail "migration: learning not written after migration (count=$count)"

# --- Test 6: add-decision writes and parses ---
echo ""
echo "Test 6: add-decision writes to file and produces valid YAML"

cat > "$TEST_PROJECT/.context/project/decisions.yaml" << 'EOF'
# Project Decisions
decisions:
EOF

PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-decision "Test decision" --task T-008 --rationale "Because reasons" >/dev/null 2>&1
count=$(python3 -c "import yaml; d=yaml.safe_load(open('$TEST_PROJECT/.context/project/decisions.yaml')); print(len(d.get('decisions', [])))" 2>/dev/null)
[ "$count" = "1" ] && pass "decision written (count=$count)" || fail "decision not written (count=$count)"

# --- Test 7: add-decision migrates old decisions: [] format ---
echo ""
echo "Test 7: add-decision migrates old decisions: [] format"

cat > "$TEST_PROJECT/.context/project/decisions.yaml" << 'EOF'
# Old format
decisions: []
EOF

PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-decision "Migration decision" --task T-009 --rationale "Migrated" >/dev/null 2>&1
count=$(python3 -c "import yaml; d=yaml.safe_load(open('$TEST_PROJECT/.context/project/decisions.yaml')); print(len(d.get('decisions', [])))" 2>/dev/null)
[ "$count" = "1" ] && pass "migration: decisions: [] converted and decision written" || fail "migration: decision not written after migration (count=$count)"

# --- Test 8: Multiple patterns maintain correct IDs ---
echo ""
echo "Test 8: Sequential ID numbering"

cat > "$TEST_PROJECT/.context/project/patterns.yaml" << 'EOF'
failure_patterns: []
success_patterns: []
workflow_patterns: []
EOF

PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-pattern failure "First" --task T-010 --mitigation "m1" >/dev/null 2>&1
PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/context/context.sh" add-pattern failure "Second" --task T-010 --mitigation "m2" >/dev/null 2>&1

grep -q "FP-001" "$TEST_PROJECT/.context/project/patterns.yaml" && pass "FP-001 exists" || fail "FP-001 missing"
grep -q "FP-002" "$TEST_PROJECT/.context/project/patterns.yaml" && pass "FP-002 exists" || fail "FP-002 missing"

count=$(python3 -c "import yaml; d=yaml.safe_load(open('$TEST_PROJECT/.context/project/patterns.yaml')); print(len(d.get('failure_patterns', [])))" 2>/dev/null)
[ "$count" = "2" ] && pass "two failure patterns in parsed YAML" || fail "expected 2 failure patterns, got $count"

# --- Test 9: create-task.sh uses default.md template ---
echo ""
echo "Test 9: create-task.sh produces tasks with Decisions and Verification sections"

mkdir -p "$TEST_PROJECT/.tasks/active" "$TEST_PROJECT/.tasks/templates"
cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_PROJECT/.tasks/templates/default.md" 2>/dev/null || true
if [ -f "$TEST_PROJECT/.tasks/templates/default.md" ]; then
    PROJECT_ROOT="$TEST_PROJECT" "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" --name "Template test" --type build --owner human --description "Verify template" >/dev/null 2>&1
    TASK_FILE=$(ls "$TEST_PROJECT/.tasks/active/"T-*.md 2>/dev/null | head -1)
    if [ -n "$TASK_FILE" ]; then
        grep -q "## Decisions" "$TASK_FILE" && pass "task has Decisions section" || fail "task missing Decisions section"
        grep -q "## Verification" "$TASK_FILE" && pass "task has Verification section" || fail "task missing Verification section"
        grep -q "## Acceptance Criteria" "$TASK_FILE" && pass "task has AC section" || fail "task missing AC section"
    else
        fail "no task file created"
    fi
else
    echo "  SKIP default.md template not found"
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
