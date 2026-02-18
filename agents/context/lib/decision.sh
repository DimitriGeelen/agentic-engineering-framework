#!/bin/bash
# Context Agent - add-decision command
# Add a decision to project memory

do_add_decision() {
    ensure_context_dirs

    local decision=""
    local task=""
    local rationale=""
    local rejected=""
    local source=""
    local recommendation_type=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --task)
                task="$2"
                shift 2
                ;;
            --rationale)
                rationale="$2"
                shift 2
                ;;
            --rejected)
                rejected="$2"
                shift 2
                ;;
            --source)
                source="$2"
                shift 2
                ;;
            --recommendation-type)
                recommendation_type="$2"
                shift 2
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
            *)
                decision="$1"
                shift
                ;;
        esac
    done

    if [ -z "$decision" ]; then
        echo -e "${RED}Error: Decision text required${NC}"
        echo "Usage: $0 add-decision 'Decision text' --task T-XXX --rationale 'Why' [--rejected 'alt1,alt2']"
        exit 1
    fi

    local decisions_file="$CONTEXT_DIR/project/decisions.yaml"
    local date=$(date -u +"%Y-%m-%d")

    # Get next ID
    local next_id=1
    if [ -f "$decisions_file" ]; then
        local max_id=$(grep "^  - id: D-" "$decisions_file" | sed 's/.*D-0*//' | sort -n | tail -1)
        [ -n "$max_id" ] && next_id=$((max_id + 1))
    fi
    local id=$(printf "D-%03d" $next_id)

    # Ensure decisions file exists with correct format
    if [ ! -f "$decisions_file" ]; then
        cat > "$decisions_file" << 'EOF'
# Project Decisions - Architectural choices with rationale
# Added via: fw context add-decision "description" --task T-XXX --rationale "why"
decisions:
EOF
    elif grep -q '^decisions: \[\]' "$decisions_file"; then
        # Migrate old empty-array format: decisions: [] -> decisions:
        sed -i 's/^decisions: \[\]/decisions:/' "$decisions_file"
    fi

    # Build YAML entry
    local entry="
  - id: $id
    decision: \"$decision\"
    date: $date
    task: ${task:-unknown}
    rationale: \"${rationale:-Not specified}\""

    if [ -n "$source" ]; then
        entry="$entry
    source: \"$source\""
    fi

    if [ -n "$recommendation_type" ]; then
        entry="$entry
    recommendation_type: \"$recommendation_type\""
    fi

    if [ -n "$rejected" ]; then
        # Convert comma-separated to YAML array
        local rejected_yaml=$(echo "$rejected" | sed 's/,/\n      - "/g' | sed 's/^/      - "/' | sed 's/$/"/')
        entry="$entry
    alternatives_rejected:
$rejected_yaml"
    fi

    # Append to decisions
    echo "$entry" >> "$decisions_file"

    echo -e "${GREEN}Decision recorded: $id${NC}"
    echo "  $decision"
    [ -n "$task" ] && echo "  Task: $task"
    [ -n "$rationale" ] && echo "  Rationale: $rationale"
    return 0
}
