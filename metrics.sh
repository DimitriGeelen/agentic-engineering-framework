#!/bin/bash
# metrics.sh - Framework health snapshot
# Run from project root: ./metrics.sh

set -e

TASKS_DIR=".tasks"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

echo "=== AGENTIC ENGINEERING FRAMEWORK - METRICS ==="
echo "Timestamp: $(date -Iseconds)"
echo ""

# Check if .tasks exists
if [ ! -d "$TASKS_DIR" ]; then
    echo "ERROR: $TASKS_DIR directory does not exist"
    echo "Adoption: NO"
    exit 1
fi

echo "=== TASK COUNTS ==="
echo "Active:    $(find "$TASKS_DIR/active" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
echo "Completed: $(find "$TASKS_DIR/completed" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
echo "Templates: $(find "$TASKS_DIR/templates" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

echo ""
echo "=== STATUS BREAKDOWN ==="
for status in captured refined started-work issues blocked work-completed; do
    count=$(grep -rl "^status: $status" "$TASKS_DIR/active" "$TASKS_DIR/completed" 2>/dev/null | wc -l | tr -d ' ')
    printf "%-16s %s\n" "$status:" "$count"
done

echo ""
echo "=== GIT TRACEABILITY ==="
total_commits=$(git log --oneline 2>/dev/null | wc -l | tr -d ' ')
task_commits=$(git log --oneline 2>/dev/null | grep -E "T-[0-9]+" | wc -l | tr -d ' ')
echo "Total commits:      $total_commits"
echo "With task ref:      $task_commits"
if [ "$total_commits" -gt 0 ]; then
    pct=$((task_commits * 100 / total_commits))
    echo "Traceability:       ${pct}%"
fi

echo ""
echo "=== RECENT TASK ACTIVITY ==="
echo "Tasks modified in last 7 days:"
find "$TASKS_DIR" -name "*.md" -mtime -7 -type f 2>/dev/null | head -10 || echo "  (none)"

echo ""
echo "=== ACTIVE TASKS ==="
shopt -s nullglob
for f in "$TASKS_DIR/active"/*.md; do
    [ -f "$f" ] || continue
    id=$(grep "^id:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
    name=$(grep "^name:" "$f" | head -1 | cut -d: -f2- | sed 's/^ *//')
    status=$(grep "^status:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
    printf "  [%s] %s - %s\n" "$status" "$id" "$name"
done
shopt -u nullglob

echo ""
echo "=== END METRICS ==="
