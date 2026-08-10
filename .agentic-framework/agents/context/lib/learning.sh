#!/bin/bash
# Context Agent - add-learning command
# Add a learning to project memory

# Escape a string for safe interpolation into a YAML double-quoted scalar.
# Doubles backslashes and escapes double-quotes — YAML 1.2 rejects any
# `\` followed by an unrecognised character. T-1543 / OBS-033.
_yaml_escape_dquoted() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

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
            --switch-focus)
                shift  # T-1890: focus-drift hook sentinel; consumed silently
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

    # Get next ID — use PL- prefix in consumer projects to avoid collision with framework L- IDs
    local id_prefix="L"
    if [ -n "$PROJECT_ROOT" ] && [ -n "$FRAMEWORK_ROOT" ] && [ "$PROJECT_ROOT" != "$FRAMEWORK_ROOT" ]; then
        id_prefix="PL"
    fi
    # T-2902: max-id comes from a YAML parse, not a grep. The previous two versions
    # of this line were both pattern scans, and both minted a live id when the corpus
    # changed shape underneath them — `^- id: L-` missed the sort_keys=True rewrite
    # (24 duplicate ids), and T-1369's widened `^[- ]+id:` still misses any third
    # serialisation. A scan that matches nothing is indistinguishable from an empty
    # corpus, so the allocator returned 1 with full confidence. corpus_max_id has no
    # pattern to widen on the authoritative path and REFUSES (exit 2) rather than
    # seeding 1 when its degraded path cannot tell the two cases apart.
    # Do not replace this with a grep. See lib/corpus-id.sh header.
    if ! declare -F corpus_max_id >/dev/null 2>&1; then
        source "${FRAMEWORK_ROOT:-${PROJECT_ROOT:-$PWD}}/lib/corpus-id.sh"
    fi
    local next_id=1 max_id rc
    max_id=$(corpus_max_id "$learnings_file" "$id_prefix"); rc=$?
    if [ $rc -ne 0 ]; then
        echo -e "${RED}Error: cannot determine the next ${id_prefix}- id — refusing to allocate.${NC}" >&2
        echo "Allocating anyway would risk reissuing a live id (T-2902)." >&2
        exit 1
    fi
    [ -n "$max_id" ] && next_id=$((max_id + 1))
    local id=$(printf "${id_prefix}-%03d" $next_id)

    # Ensure learnings file exists with correct format
    if [ ! -f "$learnings_file" ]; then
        cat > "$learnings_file" << EOF
# Project Learnings - Knowledge gained during development
# Added via: fw context add-learning "description" --task T-XXX
learnings:
EOF
    elif grep -q '^learnings: \[\]' "$learnings_file"; then
        # Migrate old empty-array format: learnings: [] -> learnings:
        _sed_i 's/^learnings: \[\]/learnings:/' "$learnings_file"
    fi

    # Insert new learning before the candidates section.
    # T-1543: escape via shell helper, then pass through environment instead
    # of `-v`. awk's `-v` flag interprets backslash escapes in the value
    # (so `\\` collapses back to `\`), undoing the YAML escape. ENVIRON
    # passes the raw value untouched.
    local esc_learning
    esc_learning="$(_yaml_escape_dquoted "$learning")"
    local temp_file=$(mktemp)
    L_ESC="$esc_learning" \
    awk -v id="$id" -v src="${source:-unknown}" -v task="${task:-unknown}" -v date="$date" '
        /^# Candidate learnings/ || /^candidates:/ {
            print "- id: " id
            print "  learning: \"" ENVIRON["L_ESC"] "\""
            print "  source: " src
            print "  task: " task
            print "  date: " date
            print "  context: Added via context agent"
            # T-2901: no `application:` placeholder at birth. A field born
            # populated makes "nobody filled this in" textually identical to
            # "someone considered it" — measured 572/604 (94.7%) literal "TBD",
            # 3.48% genuinely hand-written. Omit it; absence is the honest
            # signal and `fw learnings --unfilled` reads absence. 832 measured
            # 2.3% on their side from the same shape (rail 491 §1).
            found=1
        }
        { print }
        END {
            if (!found) {
                print "- id: " id
                print "  learning: \"" ENVIRON["L_ESC"] "\""
                print "  source: " src
                print "  task: " task
                print "  date: " date
                print "  context: Added via context agent"
                # T-2901: no `application:` placeholder at birth. A field born
                # populated makes "nobody filled this in" textually identical to
                # "someone considered it" — measured 572/604 (94.7%) literal "TBD",
                # 3.48% genuinely hand-written. Omit it; absence is the honest
                # signal and `fw learnings --unfilled` reads absence. 832 measured
                # 2.3% on their side from the same shape (rail 491 §1).
            }
        }
    ' "$learnings_file" > "$temp_file"

    mv "$temp_file" "$learnings_file"

    # T-1168: publish learning to bus (one-way, non-fatal).
    # Shell flow stays safe — publisher silently no-ops on any failure.
    local publisher="${FRAMEWORK_ROOT:-}/lib/publish-learning-to-bus.sh"
    if [ -x "$publisher" ]; then
        L_ID="$id" L_LEARNING="$learning" L_TASK="$task" \
            L_SOURCE="$source" L_DATE="$date" \
            "$publisher" 2>/dev/null || true
    fi

    echo -e "${GREEN}Learning added: $id${NC}"
    echo "  $learning"
    [ -n "$task" ] && echo "  Task: $task"
    [ -n "$source" ] && echo "  Source: $source"
    return 0
}
