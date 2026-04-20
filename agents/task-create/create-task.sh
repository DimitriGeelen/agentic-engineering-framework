#!/bin/bash
# Task Creation Agent - Mechanical Operations
# Creates properly structured tasks following the framework specification

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"

# Source enumerations (single source of truth)
# Note: lib/errors.sh already sourced via lib/paths.sh (die, warn, error, info, success)
source "$FRAMEWORK_ROOT/lib/enums.sh"

# T-1279: serialize ID allocation to prevent concurrent invocations from
# colliding on the same T-NNNN. Without this, 4+ parallel `fw work-on`
# calls all read the same max_id and all write T-${max+1}. See G-052.
source "$FRAMEWORK_ROOT/lib/keylock.sh" 2>/dev/null || true

# Colors provided by lib/colors.sh (via paths.sh chain)

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

# T-555: Reject template placeholder names
_name_lower=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
case "$_name_lower" in
    "task name"|"name"|"description"|"first criterion"|"second criterion"|\
    "task"|"my task"|"new task"|"test task"|"todo"|"fix bug"|"implement feature"|\
    "criterion"|"placeholder"|"example task"|"untitled")
        echo "ERROR: '$NAME' looks like a template placeholder, not a real task name." >&2
        echo "" >&2
        echo "  Provide a specific, descriptive name. Examples:" >&2
        echo "    --name \"Fix login timeout on slow connections\"" >&2
        echo "    --name \"Add retry logic to API client\"" >&2
        echo "    --name \"Inception: Evaluate caching strategy\"" >&2
        echo "" >&2
        exit 1
        ;;
esac

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
    die "Missing required fields"
fi

# Validate workflow type
if ! is_valid_type "$WORKFLOW_TYPE"; then
    error "Invalid workflow type '$WORKFLOW_TYPE'"
    die "Valid types: $VALID_TYPES"
fi

# Validate horizon
if ! is_valid_horizon "$HORIZON"; then
    error "Invalid horizon '$HORIZON'"
    die "Valid horizons: $VALID_HORIZONS"
fi

# Generate next task ID
generate_id() {
    local max_id=0
    shopt -s nullglob
    for f in "$TASKS_DIR"/active/T-*.md "$TASKS_DIR"/completed/T-*.md; do
        [ -f "$f" ] || continue
        local id
        id=$(basename "$f" | grep -oE 'T-[0-9]+' | grep -oE '[0-9]+')
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

# T-1279: Acquire lock BEFORE reading max_id; release AFTER file write.
# Without this, concurrent calls all observe the same max_id and collide.
if type keylock_acquire &>/dev/null; then
    keylock_acquire "task-id-allocation"
    trap 'keylock_release "task-id-allocation" 2>/dev/null' EXIT
fi

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
# All vars passed via env to avoid shell interpolation into Python source (T-595)
if [ "$WORKFLOW_TYPE" = "inception" ] && [ -f "$TASKS_DIR/templates/inception.md" ]; then
    TC_TEMPLATE="$TASKS_DIR/templates/inception.md" \
    TC_TASK_ID="$TASK_ID" TC_STATUS="$STATUS" TC_HORIZON="$HORIZON" \
    TC_OWNER="$OWNER" TC_TAGS_YAML="$TAGS_YAML" TC_RELATED_YAML="$RELATED_YAML" \
    TC_TIMESTAMP="$TIMESTAMP" TC_FILEPATH="$FILEPATH" \
    python3 -c "
import sys, os
e = os.environ
with open(e['TC_TEMPLATE']) as f:
    t = f.read()
name, desc = sys.argv[1], sys.argv[2]
t = t.replace('id: T-XXX', 'id: ' + e['TC_TASK_ID'])
t = t.replace('name:', 'name: \"' + name.replace('\"', '\\\\\"') + '\"', 1)
t = t.replace('description: >', 'description: >\n  ' + desc, 1)
t = t.replace('status: captured', 'status: ' + e['TC_STATUS'])
t = t.replace('horizon: now', 'horizon: ' + e['TC_HORIZON'])
t = t.replace('owner:', 'owner: ' + e['TC_OWNER'], 1)
t = t.replace('tags: []', 'tags: ' + e['TC_TAGS_YAML'])
t = t.replace('related_tasks: []', 'related_tasks: ' + e['TC_RELATED_YAML'])
t = t.replace('created:', 'created: ' + e['TC_TIMESTAMP'], 1)
t = t.replace('last_update:', 'last_update: ' + e['TC_TIMESTAMP'], 1)
t = t.replace('# T-XXX: [Inception Name]', '# ' + e['TC_TASK_ID'] + ': ' + name)
t = t.replace('[Chronological log', '### ' + e['TC_TIMESTAMP'] + ' — task-created [task-create-agent]\n- **Action:** Created inception task\n- **Output:** ' + e['TC_FILEPATH'] + '\n- **Context:** Initial task creation\n\n[Chronological log')
with open(e['TC_FILEPATH'], 'w') as f:
    f.write(t)
" "$NAME" "$DESCRIPTION"
elif [ -f "$TASKS_DIR/templates/default.md" ]; then
    TC_TEMPLATE="$TASKS_DIR/templates/default.md" \
    TC_TASK_ID="$TASK_ID" TC_STATUS="$STATUS" TC_WORKFLOW_TYPE="$WORKFLOW_TYPE" \
    TC_HORIZON="$HORIZON" TC_OWNER="$OWNER" TC_TAGS_YAML="$TAGS_YAML" \
    TC_RELATED_YAML="$RELATED_YAML" TC_TIMESTAMP="$TIMESTAMP" TC_FILEPATH="$FILEPATH" \
    python3 -c "
import sys, os
e = os.environ
with open(e['TC_TEMPLATE']) as f:
    t = f.read()
name, desc = sys.argv[1], sys.argv[2]
t = t.replace('id: T-XXX', 'id: ' + e['TC_TASK_ID'])
t = t.replace('name:', 'name: \"' + name.replace('\"', '\\\\\"') + '\"', 1)
t = t.replace('description: >', 'description: >\n  ' + desc, 1)
t = t.replace('status: captured', 'status: ' + e['TC_STATUS'])
t = t.replace('workflow_type:', 'workflow_type: ' + e['TC_WORKFLOW_TYPE'], 1)
t = t.replace('owner:', 'owner: ' + e['TC_OWNER'], 1)
t = t.replace('horizon: now', 'horizon: ' + e['TC_HORIZON'])
t = t.replace('tags: []', 'tags: ' + e['TC_TAGS_YAML'])
t = t.replace('related_tasks: []', 'related_tasks: ' + e['TC_RELATED_YAML'])
t = t.replace('created:', 'created: ' + e['TC_TIMESTAMP'], 1)
t = t.replace('last_update:', 'last_update: ' + e['TC_TIMESTAMP'], 1)
t = t.replace('# T-XXX: [Task Name]', '# ' + e['TC_TASK_ID'] + ': ' + name)
t = t.replace('<!-- Auto-populated by git mining at task completion.\\n     Manual entries optional during execution. -->', '### ' + e['TC_TIMESTAMP'] + ' — task-created [task-create-agent]\n- **Action:** Created task via task-create agent\n- **Output:** ' + e['TC_FILEPATH'] + '\n- **Context:** Initial task creation')
with open(e['TC_FILEPATH'], 'w') as f:
    f.write(t)
" "$NAME" "$DESCRIPTION"
else
    # Fallback: minimal inline template (only if default.md missing)
    cat > "$FILEPATH" << EOF
---
id: $TASK_ID
name: "$NAME"
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

# T-1263: Inception tasks must have ## Recommendation and ## Decision sections
# Fail-fast at creation time rather than blocking late at fw inception decide
if [ "$WORKFLOW_TYPE" = "inception" ]; then
    _missing=""
    grep -qE '^## Recommendation[[:space:]]*$' "$FILEPATH" || _missing="## Recommendation"
    grep -qE '^## Decision[[:space:]]*$' "$FILEPATH" || _missing="${_missing:+$_missing, }## Decision"
    if [ -n "$_missing" ]; then
        echo -e "${RED}ERROR: Inception template missing required sections: $_missing${NC}" >&2
        echo "The inception decide pipeline requires both ## Recommendation and ## Decision." >&2
        echo "Fix the template at: $TASKS_DIR/templates/inception.md" >&2
        rm -f "$FILEPATH"
        exit 1
    fi
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

# If --start was used, also set focus (T-297)
if [ "$START_WORK" = true ]; then
    "$SCRIPT_DIR/../context/context.sh" focus "$TASK_ID" 2>/dev/null || true
fi
