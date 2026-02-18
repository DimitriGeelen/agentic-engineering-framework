#!/bin/bash
# Task Creation Agent - Mechanical Operations
# Creates properly structured tasks following the framework specification

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
TASKS_DIR="$PROJECT_ROOT/.tasks"
TEMPLATE="$TASKS_DIR/templates/default.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Valid workflow types
VALID_TYPES="specification design build test refactor decommission inception"
VALID_HORIZONS="now next later"

# Parse arguments
NAME=""
DESCRIPTION=""
WORKFLOW_TYPE=""
OWNER=""
TAGS=""
RELATED=""
HORIZON="now"
START_WORK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --name) NAME="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --type) WORKFLOW_TYPE="$2"; shift 2 ;;
        --owner) OWNER="$2"; shift 2 ;;
        --tags) TAGS="$2"; shift 2 ;;
        --related) RELATED="$2"; shift 2 ;;
        --horizon) HORIZON="$2"; shift 2 ;;
        --start) START_WORK=true; shift ;;
        -h|--help)
            echo "Usage: create-task.sh [options]"
            echo ""
            echo "Options:"
            echo "  --name        Task name (required)"
            echo "  --description Task description (required)"
            echo "  --type        Workflow type: $VALID_TYPES"
            echo "  --owner       Task owner (required)"
            echo "  --tags        Comma-separated tags (e.g. \"watchtower,ui,inception\")"
            echo "  --related     Comma-separated related task IDs (e.g. \"T-084,T-085\")"
            echo "  --horizon     Priority horizon: now (default), next, later"
            echo "  --start       Set status to started-work instead of captured"
            echo "  -h, --help    Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Interactive mode if required fields missing
if [ -z "$NAME" ]; then
    echo -e "${YELLOW}Task name:${NC}"
    read -r NAME
fi

if [ -z "$DESCRIPTION" ]; then
    echo -e "${YELLOW}Task description:${NC}"
    read -r DESCRIPTION
fi

if [ -z "$WORKFLOW_TYPE" ]; then
    echo -e "${YELLOW}Workflow type ($VALID_TYPES):${NC}"
    read -r WORKFLOW_TYPE
fi

if [ -z "$OWNER" ]; then
    echo -e "${YELLOW}Owner (human or agent name):${NC}"
    read -r OWNER
fi

# Validate required fields
if [ -z "$NAME" ] || [ -z "$DESCRIPTION" ] || [ -z "$WORKFLOW_TYPE" ] || [ -z "$OWNER" ]; then
    echo -e "${RED}ERROR: Missing required fields${NC}"
    exit 1
fi

# Validate workflow type
if ! echo "$VALID_TYPES" | grep -qw "$WORKFLOW_TYPE"; then
    echo -e "${RED}ERROR: Invalid workflow type '$WORKFLOW_TYPE'${NC}"
    echo "Valid types: $VALID_TYPES"
    exit 1
fi

# Validate horizon
if ! echo "$VALID_HORIZONS" | grep -qw "$HORIZON"; then
    echo -e "${RED}ERROR: Invalid horizon '$HORIZON'${NC}"
    echo "Valid horizons: $VALID_HORIZONS"
    exit 1
fi

# Generate next task ID
generate_id() {
    local max_id=0
    shopt -s nullglob
    for f in "$TASKS_DIR"/active/T-*.md "$TASKS_DIR"/completed/T-*.md; do
        [ -f "$f" ] || continue
        local id=$(basename "$f" | grep -oE 'T-[0-9]+' | grep -oE '[0-9]+')
        # Use 10# to force base-10 interpretation (avoids octal issues with 008, 009)
        if [ -n "$id" ] && [ "$((10#$id))" -gt "$max_id" ]; then
            max_id=$((10#$id))
        fi
    done
    shopt -u nullglob
    printf "T-%03d" $((max_id + 1))
}

# Generate slug from name
generate_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-40
}

# Generate timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Generate ID and filename
TASK_ID=$(generate_id)
SLUG=$(generate_slug "$NAME")
FILENAME="$TASK_ID-$SLUG.md"
FILEPATH="$TASKS_DIR/active/$FILENAME"

# Determine initial status
if [ "$START_WORK" = true ]; then
    STATUS="started-work"
else
    STATUS="captured"
fi

# Format tags and related_tasks as YAML arrays
format_yaml_array() {
    local input="$1"
    if [ -z "$input" ]; then
        echo "[]"
        return
    fi
    local result="["
    local first=true
    IFS=',' read -ra items <<< "$input"
    for item in "${items[@]}"; do
        item=$(echo "$item" | xargs)  # trim whitespace
        [ -z "$item" ] && continue
        if [ "$first" = true ]; then
            result="${result}${item}"
            first=false
        else
            result="${result}, ${item}"
        fi
    done
    echo "${result}]"
}

TAGS_YAML=$(format_yaml_array "$TAGS")
RELATED_YAML=$(format_yaml_array "$RELATED")

# Select template content based on workflow type
if [ "$WORKFLOW_TYPE" = "inception" ] && [ -f "$TASKS_DIR/templates/inception.md" ]; then
    # Use inception template — replace placeholders via Python (safe with special chars)
    python3 -c "
import sys
with open('$TASKS_DIR/templates/inception.md') as f:
    t = f.read()
t = t.replace('id: T-XXX', 'id: $TASK_ID')
t = t.replace('name:', 'name: ' + sys.argv[1], 1)
t = t.replace('description: >', 'description: >\n  ' + sys.argv[2], 1)
t = t.replace('status: captured', 'status: $STATUS')
t = t.replace('horizon: now', 'horizon: $HORIZON')
t = t.replace('owner:', 'owner: $OWNER', 1)
t = t.replace('tags: []', 'tags: $TAGS_YAML')
t = t.replace('related_tasks: []', 'related_tasks: $RELATED_YAML')
t = t.replace('created:', 'created: $TIMESTAMP', 1)
t = t.replace('last_update:', 'last_update: $TIMESTAMP', 1)
t = t.replace('# T-XXX: [Inception Name]', '# $TASK_ID: ' + sys.argv[1])
t = t.replace('[Chronological log', '### $TIMESTAMP — task-created [task-create-agent]\n- **Action:** Created inception task\n- **Output:** $FILEPATH\n- **Context:** Initial task creation\n\n[Chronological log')
with open('$FILEPATH', 'w') as f:
    f.write(t)
" "$NAME" "$DESCRIPTION"
elif [ -f "$TASKS_DIR/templates/default.md" ]; then
    # Use default template — replace placeholders via Python (safe with special chars)
    python3 -c "
import sys
with open('$TASKS_DIR/templates/default.md') as f:
    t = f.read()
t = t.replace('id: T-XXX', 'id: $TASK_ID')
t = t.replace('name:', 'name: ' + sys.argv[1], 1)
t = t.replace('description: >', 'description: >\n  ' + sys.argv[2], 1)
t = t.replace('status: captured', 'status: $STATUS')
t = t.replace('workflow_type:', 'workflow_type: $WORKFLOW_TYPE', 1)
t = t.replace('owner:', 'owner: $OWNER', 1)
t = t.replace('horizon: now', 'horizon: $HORIZON')
t = t.replace('tags: []', 'tags: $TAGS_YAML')
t = t.replace('related_tasks: []', 'related_tasks: $RELATED_YAML')
t = t.replace('created:', 'created: $TIMESTAMP', 1)
t = t.replace('last_update:', 'last_update: $TIMESTAMP', 1)
t = t.replace('# T-XXX: [Task Name]', '# $TASK_ID: ' + sys.argv[1])
t = t.replace('<!-- Auto-populated by git mining at task completion.\\n     Manual entries optional during execution. -->', '### $TIMESTAMP — task-created [task-create-agent]\n- **Action:** Created task via task-create agent\n- **Output:** $FILEPATH\n- **Context:** Initial task creation')
with open('$FILEPATH', 'w') as f:
    f.write(t)
" "$NAME" "$DESCRIPTION"
else
    # Fallback: minimal inline template (only if default.md missing)
    cat > "$FILEPATH" << EOF
---
id: $TASK_ID
name: $NAME
description: >
  $DESCRIPTION
status: $STATUS
workflow_type: $WORKFLOW_TYPE
horizon: $HORIZON
owner: $OWNER
tags: $TAGS_YAML
related_tasks: $RELATED_YAML
created: $TIMESTAMP
last_update: $TIMESTAMP
date_finished: null
---

# $TASK_ID: $NAME

## Context

## Acceptance Criteria

- [ ] [Criterion]

## Verification

## Updates

### $TIMESTAMP — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** $FILEPATH
- **Context:** Initial task creation
EOF
fi

# Validate the created file
if ! grep -q "^id: $TASK_ID" "$FILEPATH"; then
    echo -e "${RED}ERROR: Task file validation failed${NC}"
    exit 1
fi

# Success output
echo ""
echo -e "${GREEN}=== Task Created ===${NC}"
echo "ID:       $TASK_ID"
echo "Name:     $NAME"
echo "Type:     $WORKFLOW_TYPE"
echo "Status:   $STATUS"
echo "Owner:    $OWNER"
echo "File:     $FILEPATH"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Add context (design docs, specs, predecessor tasks) to the task file"
echo "2. Reference this task in commits: git commit -m \"$TASK_ID: description\""
echo "3. Update task status as work progresses"
