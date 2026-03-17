#!/usr/bin/env bash
# Tier A Tests: Commit Traceability (A3, A4)
# Tests commit-msg hook requires T-XXX reference.
#
# A3: Commit without T-XXX reference is rejected
# A4: Commit with T-XXX reference passes

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/setup.sh"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/teardown.sh"

SUITE_NAME="tier-a-commit-hook"

setup_test_dir

# Initialize git repo with the commit-msg hook
cd "$TEST_DIR"
git init -q
git config user.email "test@e2e.local"
git config user.name "E2E Test"
mkdir -p .git/hooks

# Copy framework libs the hook depends on
cp -r "$FRAMEWORK_ROOT/lib" "$TEST_DIR/" 2>/dev/null || true

# Install the commit-msg hook from the framework
cp "$FRAMEWORK_ROOT/.git/hooks/commit-msg" .git/hooks/commit-msg 2>/dev/null || {
    skip "A3" "Commit hook rejects without T-XXX" "No commit-msg hook found"
    skip "A4" "Commit hook accepts with T-XXX" "No commit-msg hook found"
    cd "$FRAMEWORK_ROOT"
    if [ "${JSON_OUTPUT:-false}" = true ]; then
        print_json_summary
    else
        print_summary
    fi
    exit 0
}
chmod +x .git/hooks/commit-msg

# Create task dir structure (hook checks task existence)
mkdir -p .tasks/active
cat > .tasks/active/T-999-test.md << 'TASK'
---
id: T-999
name: "Test task"
status: started-work
---
TASK

# Initial commit (needed for subsequent commits)
echo "init" > init.txt
git add init.txt
git commit -q -m "T-999: init" --allow-empty 2>/dev/null || git commit -q --allow-empty -m "init" 2>/dev/null || true

# Stage a new file for the test commits
echo "test" > testfile.txt
git add testfile.txt

# ── A3: Commit without T-XXX reference is rejected ──

assert_exit_code \
    "cd '$TEST_DIR' && git commit -m 'Fix a bug without task ref' 2>&1" \
    1 "A3" "Commit hook rejects without T-XXX"

# ── A4: Commit with T-XXX reference passes ──

assert_exit_code \
    "cd '$TEST_DIR' && git commit -m 'T-999: Fix a bug with task ref' 2>&1" \
    0 "A4" "Commit hook accepts with T-XXX"

cd "$FRAMEWORK_ROOT"

# ── Report ──

if [ "${JSON_OUTPUT:-false}" = true ]; then
    print_json_summary
else
    print_summary
fi
