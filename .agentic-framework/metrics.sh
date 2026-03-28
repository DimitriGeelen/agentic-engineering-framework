#!/bin/bash
# metrics.sh - Framework health snapshot
# Run from project root: ./metrics.sh

set -e

TASKS_DIR=".tasks"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
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
echo "=== QUALITY METRICS ==="

# Description quality
total_tasks=0
quality_descriptions=0
total_desc_length=0

shopt -s nullglob
for f in "$TASKS_DIR/active"/*.md "$TASKS_DIR/completed"/*.md; do
    [ -f "$f" ] || continue
    total_tasks=$((total_tasks + 1))
    # Handle both inline and multiline (>) descriptions
    desc=$(sed -n '/^description:/,/^[a-z_]*:/p' "$f" | head -n -1 | sed 's/^description: //' | sed 's/^> *//' | sed 's/^  //' | tr '\n' ' ')
    desc_len=${#desc}
    total_desc_length=$((total_desc_length + desc_len))
    [ "$desc_len" -ge 50 ] && quality_descriptions=$((quality_descriptions + 1))
done

if [ "$total_tasks" -gt 0 ]; then
    avg_desc_len=$((total_desc_length / total_tasks))
    quality_pct=$((quality_descriptions * 100 / total_tasks))
    echo "Description quality:  ${quality_pct}% (${quality_descriptions}/${total_tasks} >= 50 chars)"
    echo "Avg description len:  ${avg_desc_len} chars"
fi

# Updates health (active tasks only)
total_active=0
total_updates=0
stale_count=0
seven_days_ago=$(date -d "7 days ago" +%s 2>/dev/null || date -v-7d +%s 2>/dev/null || echo 0)

for f in "$TASKS_DIR/active"/*.md; do
    [ -f "$f" ] || continue
    total_active=$((total_active + 1))

    # Count updates
    updates=$(grep -c "^### " "$f" 2>/dev/null || true)
    updates=$(echo "$updates" | tr -d '[:space:]')
    total_updates=$((total_updates + updates))

    # Check for stale (>7 days old with <2 updates)
    last_update=$(grep "^last_update:" "$f" | sed 's/last_update: //' | cut -dT -f1)
    if [ -n "$last_update" ]; then
        last_ts=$(date -d "$last_update" +%s 2>/dev/null || echo 0)
        if [ "$last_ts" -lt "$seven_days_ago" ] && [ "$updates" -lt 2 ]; then
            stale_count=$((stale_count + 1))
        fi
    fi
done

if [ "$total_active" -gt 0 ]; then
    avg_updates=$((total_updates / total_active))
    echo "Avg updates/task:     $avg_updates"
    echo "Stale tasks (>7d):    $stale_count"
fi

# Acceptance criteria coverage
tasks_with_ac=0
total_ac=0
completed_ac=0

for f in "$TASKS_DIR/active"/*.md "$TASKS_DIR/completed"/*.md; do
    [ -f "$f" ] || continue
    # Check for acceptance criteria (lines with [ ] or [x])
    ac_lines=$(grep -cE "^\s*-\s*\[[x ]\]" "$f" 2>/dev/null || true)
    ac_lines=$(echo "$ac_lines" | tr -d '[:space:]')
    if [ "$ac_lines" -gt 0 ]; then
        tasks_with_ac=$((tasks_with_ac + 1))
        total_ac=$((total_ac + ac_lines))
        done_ac=$(grep -cE "^\s*-\s*\[x\]" "$f" 2>/dev/null || true)
        done_ac=$(echo "$done_ac" | tr -d '[:space:]')
        completed_ac=$((completed_ac + done_ac))
    fi
done

if [ "$total_tasks" -gt 0 ]; then
    ac_coverage=$((tasks_with_ac * 100 / total_tasks))
    echo "AC coverage:          ${ac_coverage}% (${tasks_with_ac}/${total_tasks} have criteria)"
fi
if [ "$total_ac" -gt 0 ]; then
    ac_completion=$((completed_ac * 100 / total_ac))
    echo "AC completion:        ${ac_completion}% (${completed_ac}/${total_ac} complete)"
fi
shopt -u nullglob

# Context Fabric health
echo ""
echo "=== CONTEXT FABRIC ==="
CONTEXT_DIR=".context"
patterns_count=0
learnings_count=0
episodic_count=0
decisions_count=0

if [ -f "$CONTEXT_DIR/project/patterns.yaml" ]; then
    patterns_count=$(grep -c "^  - id: [FSW]P-" "$CONTEXT_DIR/project/patterns.yaml" 2>/dev/null || true)
fi
if [ -f "$CONTEXT_DIR/project/learnings.yaml" ]; then
    learnings_count=$(grep -c "^  - id: L-" "$CONTEXT_DIR/project/learnings.yaml" 2>/dev/null || true)
fi
if [ -f "$CONTEXT_DIR/project/decisions.yaml" ]; then
    decisions_count=$(grep -c "^  - id: D-" "$CONTEXT_DIR/project/decisions.yaml" 2>/dev/null || true)
fi
if [ -d "$CONTEXT_DIR/episodic" ]; then
    episodic_count=$(find "$CONTEXT_DIR/episodic" -name "T-*.yaml" 2>/dev/null | wc -l | tr -d ' ')
fi

echo "Patterns:             $patterns_count"
echo "Learnings:            $learnings_count"
echo "Decisions:            $decisions_count"
echo "Episodic summaries:   $episodic_count"

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
