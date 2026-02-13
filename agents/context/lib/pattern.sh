#!/bin/bash
# Context Agent - add-pattern command
# Add a pattern to project memory

do_add_pattern() {
    ensure_context_dirs

    local pattern_type=""
    local pattern_name=""
    local task=""
    local mitigation=""
    local description=""

    # First arg is pattern type
    if [ $# -gt 0 ]; then
        pattern_type="$1"
        shift
    fi

    # Second arg is pattern name
    if [ $# -gt 0 ]; then
        pattern_name="$1"
        shift
    fi

    # Parse remaining arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --task)
                task="$2"
                shift 2
                ;;
            --mitigation)
                mitigation="$2"
                shift 2
                ;;
            --description)
                description="$2"
                shift 2
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
            *)
                shift
                ;;
        esac
    done

    # Validate pattern type
    case "$pattern_type" in
        failure|success|workflow) ;;
        *)
            echo -e "${RED}Error: Pattern type must be 'failure', 'success', or 'workflow'${NC}"
            echo "Usage: $0 add-pattern <type> 'Pattern name' --task T-XXX [--mitigation 'text']"
            exit 1
            ;;
    esac

    if [ -z "$pattern_name" ]; then
        echo -e "${RED}Error: Pattern name required${NC}"
        exit 1
    fi

    local patterns_file="$CONTEXT_DIR/project/patterns.yaml"
    local date=$(date -u +"%Y-%m-%d")

    # Determine ID prefix
    local prefix=""
    local section=""
    case "$pattern_type" in
        failure) prefix="FP"; section="failure_patterns" ;;
        success) prefix="SP"; section="success_patterns" ;;
        workflow) prefix="WP"; section="workflow_patterns" ;;
    esac

    # Get next ID for this type
    local next_id=1
    if [ -f "$patterns_file" ]; then
        local max_id=$(grep "^  - id: ${prefix}-" "$patterns_file" | sed "s/.*${prefix}-0*//" | sort -n | tail -1)
        [ -n "$max_id" ] && next_id=$((max_id + 1))
    fi
    local id=$(printf "%s-%03d" "$prefix" $next_id)

    # Ensure patterns file exists
    if [ ! -f "$patterns_file" ]; then
        cat > "$patterns_file" << 'EOF'
# Project Memory - Patterns

failure_patterns: []

success_patterns: []

workflow_patterns: []
EOF
    fi

    # Build YAML entry
    local entry="  - id: $id
    pattern: \"$pattern_name\"
    description: \"${description:-$pattern_name}\"
    learned_from: ${task:-unknown}
    date_learned: $date"

    if [ "$pattern_type" = "failure" ] && [ -n "$mitigation" ]; then
        entry="$entry
    mitigation: \"$mitigation\""
    elif [ "$pattern_type" = "success" ] || [ "$pattern_type" = "workflow" ]; then
        entry="$entry
    context: \"Added via context agent\""
    fi

    # Append to the correct section
    local temp_file=$(mktemp)
    awk -v section="${section}:" -v entry="$entry" '
        $0 ~ section {
            print
            getline
            if ($0 ~ /^\[\]$/) {
                # Empty array, replace with entry
                print ""
                print entry
            } else {
                print
            }
            next
        }
        /^[a-z_]+_patterns:$/ && prev ~ section {
            # Found next section, insert entry before
            print entry
            print ""
        }
        { prev=$0; print }
    ' "$patterns_file" > "$temp_file"

    # If section wasn't empty, we need different logic
    if grep -q "^  - id: " "$temp_file"; then
        mv "$temp_file" "$patterns_file"
    else
        # Simpler approach: find section and append
        rm "$temp_file"
        sed -i "/${section}:/a\\
\\
$entry" "$patterns_file"
    fi

    echo -e "${GREEN}Pattern added: $id ($pattern_type)${NC}"
    echo "  $pattern_name"
    [ -n "$task" ] && echo "  From: $task"
    [ -n "$mitigation" ] && echo "  Mitigation: $mitigation"
}
