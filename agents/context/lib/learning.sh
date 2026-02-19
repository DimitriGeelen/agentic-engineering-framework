#!/bin/bash
# Context Agent - add-learning command
# Add a learning to project memory

do_add_learning() {
    ensure_context_dirs

    local learning=""
    local task=""
    local source=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --task)
                task="$2"
                shift 2
                ;;
            --source)
                source="$2"
                shift 2
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
            *)
                learning="$1"
                shift
                ;;
        esac
    done

    if [ -z "$learning" ]; then
        echo -e "${RED}Error: Learning text required${NC}"
        echo "Usage: $0 add-learning 'Learning text' --task T-XXX --source P-001"
        exit 1
    fi

    local learnings_file="$CONTEXT_DIR/project/learnings.yaml"
    local date=$(date -u +"%Y-%m-%d")

    # Get next ID
    local next_id=1
    if [ -f "$learnings_file" ]; then
        local max_id=$(grep "^- id: L-" "$learnings_file" | sed 's/.*L-0*//' | sort -n | tail -1)
        [ -n "$max_id" ] && next_id=$((max_id + 1))
    fi
    local id=$(printf "L-%03d" $next_id)

    # Ensure learnings file exists with correct format
    if [ ! -f "$learnings_file" ]; then
        cat > "$learnings_file" << EOF
# Project Learnings - Knowledge gained during development
# Added via: fw context add-learning "description" --task T-XXX
learnings:
EOF
    elif grep -q '^learnings: \[\]' "$learnings_file"; then
        # Migrate old empty-array format: learnings: [] -> learnings:
        sed -i 's/^learnings: \[\]/learnings:/' "$learnings_file"
    fi

    # Insert new learning before the candidates section
    local temp_file=$(mktemp)
    awk -v id="$id" -v learning="$learning" -v source="${source:-unknown}" -v task="${task:-unknown}" -v date="$date" '
        /^# Candidate learnings/ || /^candidates:/ {
            print "- id: " id
            print "  learning: \"" learning "\""
            print "  source: " source
            print "  task: " task
            print "  date: " date
            print "  context: Added via context agent"
            print "  application: TBD"
            found=1
        }
        { print }
        END {
            if (!found) {
                print "- id: " id
                print "  learning: \"" learning "\""
                print "  source: " source
                print "  task: " task
                print "  date: " date
                print "  context: Added via context agent"
                print "  application: TBD"
            }
        }
    ' "$learnings_file" > "$temp_file"

    mv "$temp_file" "$learnings_file"

    echo -e "${GREEN}Learning added: $id${NC}"
    echo "  $learning"
    [ -n "$task" ] && echo "  Task: $task"
    [ -n "$source" ] && echo "  Source: $source"
    return 0
}
