#!/bin/bash
# Context Agent - add-decision command
# Add a decision to project memory

# Escape a string for safe interpolation into a YAML double-quoted scalar.
# YAML 1.2 only permits a fixed set of escape sequences after `\`; anything
# else (e.g. `\s`, `\``, `\'`) causes a parse error. This helper doubles
# every backslash and escapes every double-quote, leaving the result safe
# inside `"..."`. Origin: T-1543 / OBS-033 (recurrence of L-294, D-036, D-038).
_yaml_escape_dquoted() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

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
            --switch-focus)
                shift  # T-1890: focus-drift hook sentinel; consumed silently
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

    # Get next ID — use PD- prefix in consumer projects to avoid collision with framework D-/FD- IDs
    local id_prefix="D"
    if [ -n "$PROJECT_ROOT" ] && [ -n "$FRAMEWORK_ROOT" ] && [ "$PROJECT_ROOT" != "$FRAMEWORK_ROOT" ]; then
        id_prefix="PD"
    fi
    local next_id=1
    if [ -f "$decisions_file" ]; then
        local max_id=$(grep "^  - id: ${id_prefix}-" "$decisions_file" | sed "s/.*${id_prefix}-0*//" | sort -n | tail -1)
        [ -n "$max_id" ] && next_id=$((max_id + 1))
    fi
    local id=$(printf "${id_prefix}-%03d" $next_id)

    # Ensure decisions file exists with correct format
    if [ ! -f "$decisions_file" ]; then
        cat > "$decisions_file" << 'EOF'
# Project Decisions - Architectural choices with rationale
# Added via: fw context add-decision "description" --task T-XXX --rationale "why"
decisions:
EOF
    elif grep -q '^decisions: \[\]' "$decisions_file"; then
        # Migrate old empty-array format: decisions: [] -> decisions:
        _sed_i 's/^decisions: \[\]/decisions:/' "$decisions_file"
    fi

    # Build YAML entry — every interpolated value passes through
    # _yaml_escape_dquoted so backslashes and quotes inside the input cannot
    # break the YAML parse (T-1543).
    local esc_decision esc_rationale
    esc_decision="$(_yaml_escape_dquoted "$decision")"
    esc_rationale="$(_yaml_escape_dquoted "${rationale:-Not specified}")"
    local entry="
  - id: $id
    decision: \"$esc_decision\"
    scope: project
    date: $date
    task: ${task:-unknown}
    rationale: \"$esc_rationale\""

    if [ -n "$source" ]; then
        local esc_source
        esc_source="$(_yaml_escape_dquoted "$source")"
        entry="$entry
    source: \"$esc_source\""
    fi

    if [ -n "$recommendation_type" ]; then
        local esc_rec
        esc_rec="$(_yaml_escape_dquoted "$recommendation_type")"
        entry="$entry
    recommendation_type: \"$esc_rec\""
    fi

    if [ -n "$rejected" ]; then
        # Convert comma-separated to YAML array — escape each item.
        local rejected_yaml=""
        local IFS_ORIG="$IFS"
        IFS=','
        for item in $rejected; do
            # Trim leading/trailing whitespace
            item="${item#"${item%%[![:space:]]*}"}"
            item="${item%"${item##*[![:space:]]}"}"
            local esc_item
            esc_item="$(_yaml_escape_dquoted "$item")"
            rejected_yaml="${rejected_yaml}      - \"$esc_item\""$'\n'
        done
        IFS="$IFS_ORIG"
        # Strip final newline
        rejected_yaml="${rejected_yaml%$'\n'}"
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
