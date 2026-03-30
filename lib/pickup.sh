#!/bin/bash
# fw pickup — Cross-project pickup pipeline core
#
# Functions:
#   pickup_ensure_dirs       Create pickup directories if needed
#   pickup_validate_envelope Validate YAML envelope has required fields
#   pickup_dedup_check       SHA256-based dedup with 7-day cooldown
#   pickup_next_id           Generate next P-NNN pickup ID
#   pickup_create_inception  Create inception task from pickup envelope
#   pickup_process_one       Process a single inbox envelope
#   do_pickup                Main entry point (subcommand router)

# Colors (inherited from caller, define fallbacks)
RED="${RED:-}"
GREEN="${GREEN:-}"
YELLOW="${YELLOW:-}"
CYAN="${CYAN:-}"
BOLD="${BOLD:-}"
NC="${NC:-}"

# Directories
PICKUP_DIR="${PROJECT_ROOT:-.}/.context/pickup"
PICKUP_INBOX="$PICKUP_DIR/inbox"
PICKUP_PROCESSED="$PICKUP_DIR/processed"
PICKUP_REJECTED="$PICKUP_DIR/rejected"
PICKUP_DEDUP_LOG="$PICKUP_DIR/dedup.log"

# --- Directory setup ---

pickup_ensure_dirs() {
    mkdir -p "$PICKUP_INBOX" "$PICKUP_PROCESSED" "$PICKUP_REJECTED"
}

# --- Envelope validation ---

pickup_validate_envelope() {
    local file="$1"

    if [ ! -f "$file" ]; then
        echo "File not found: $file" >&2
        return 1
    fi

    local missing=""

    # Check required fields using grep
    if ! grep -q "^version:" "$file" 2>/dev/null; then
        missing="${missing:+$missing, }version"
    fi
    if ! grep -q "^type:" "$file" 2>/dev/null; then
        missing="${missing:+$missing, }type"
    fi
    if ! grep -q "^  project:" "$file" 2>/dev/null; then
        missing="${missing:+$missing, }source.project"
    fi

    # Check payload.summary (indented under payload:)
    if ! grep -q "^  summary:" "$file" 2>/dev/null; then
        missing="${missing:+$missing, }payload.summary"
    fi

    if [ -n "$missing" ]; then
        echo "Missing required fields: $missing" >&2
        return 1
    fi

    # Validate type value
    local pickup_type
    pickup_type=$(grep "^type:" "$file" | head -1 | sed 's/^type:[[:space:]]*//' | tr -d '"' | tr -d "'")
    case "$pickup_type" in
        bug-report|learning|feature-proposal|pattern) ;;
        *)
            echo "Invalid type: $pickup_type (must be bug-report, learning, feature-proposal, or pattern)" >&2
            return 1
            ;;
    esac

    return 0
}

# --- Dedup ---

pickup_dedup_hash() {
    local file="$1"

    local pickup_type source_project summary
    pickup_type=$(grep "^type:" "$file" | head -1 | sed 's/^type:[[:space:]]*//' | tr -d '"' | tr -d "'")
    source_project=$(grep "^  project:" "$file" | head -1 | sed 's/^  project:[[:space:]]*//' | tr -d '"' | tr -d "'")
    summary=$(grep "^  summary:" "$file" | head -1 | sed 's/^  summary:[[:space:]]*//' | tr -d '"' | tr -d "'")

    # Normalize: lowercase, collapse whitespace
    local normalized
    normalized=$(echo "${pickup_type}|${summary}|${source_project}" | tr '[:upper:]' '[:lower:]' | tr -s ' ')

    echo -n "$normalized" | sha256sum | cut -d' ' -f1
}

pickup_dedup_check() {
    local file="$1"
    local cooldown_days="${2:-7}"

    local hash
    hash=$(pickup_dedup_hash "$file")

    if [ ! -f "$PICKUP_DEDUP_LOG" ]; then
        return 1  # No log = not a dupe
    fi

    local cutoff
    cutoff=$(date -u -d "$cooldown_days days ago" +%Y-%m-%dT%H:%M:%S 2>/dev/null || \
             date -u -v-"${cooldown_days}"d +%Y-%m-%dT%H:%M:%S 2>/dev/null || \
             echo "1970-01-01T00:00:00")

    # Check if hash exists within cooldown window
    while IFS='|' read -r ts stored_hash _rest; do
        [ -z "$stored_hash" ] && continue
        if [ "$stored_hash" = "$hash" ] && [[ "$ts" > "$cutoff" ]]; then
            return 0  # Found = is a dupe
        fi
    done < "$PICKUP_DEDUP_LOG"

    return 1  # Not found = not a dupe
}

pickup_record_dedup() {
    local file="$1"
    local hash
    hash=$(pickup_dedup_hash "$file")
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "${ts}|${hash}|$(basename "$file")" >> "$PICKUP_DEDUP_LOG"
}

# --- ID generation ---

pickup_next_id() {
    local max_id=0

    # Scan inbox, processed, and rejected for highest P-NNN
    local dir
    for dir in "$PICKUP_INBOX" "$PICKUP_PROCESSED" "$PICKUP_REJECTED"; do
        [ -d "$dir" ] || continue
        local f
        for f in "$dir"/*.yaml "$dir"/*.yml; do
            [ -f "$f" ] || continue
            local pid
            pid=$(grep "^pickup_id:" "$f" 2>/dev/null | head -1 | sed 's/.*P-0*//' | tr -d '"' | tr -d "'" | tr -d '[:space:]')
            if [ -n "$pid" ] && [ "$pid" -gt "$max_id" ] 2>/dev/null; then
                max_id=$pid
            fi
        done
    done

    local next=$((max_id + 1))
    printf "P-%03d" "$next"
}

# --- Inception task creation ---

pickup_create_inception() {
    local file="$1"

    local summary source_project pickup_type source_task
    pickup_type=$(grep "^type:" "$file" | head -1 | sed 's/^type:[[:space:]]*//' | tr -d '"' | tr -d "'")
    source_project=$(grep "^  project:" "$file" | head -1 | sed 's/^  project:[[:space:]]*//' | tr -d '"' | tr -d "'")
    summary=$(grep "^  summary:" "$file" | head -1 | sed 's/^  summary:[[:space:]]*//' | tr -d '"' | tr -d "'")
    source_task=$(grep "^  task_id:" "$file" 2>/dev/null | head -1 | sed 's/^  task_id:[[:space:]]*//' | tr -d '"' | tr -d "'")

    local task_name="Pickup: ${summary} (from ${source_project})"

    # Create inception task (not build — T-469 lesson)
    if command -v fw >/dev/null 2>&1; then
        fw task create \
            --name "$task_name" \
            --type inception \
            --description "Auto-created from pickup envelope. Source: ${source_project}${source_task:+, task ${source_task}}. Type: ${pickup_type}." \
            --horizon next \
            --tags "pickup,${pickup_type}" 2>&1
    else
        echo "WARN: fw not on PATH — cannot create task for: $task_name" >&2
        echo "$task_name"
        return 1
    fi
}

# --- Process one envelope ---

pickup_process_one() {
    local file="$1"
    local dry_run="${2:-false}"

    pickup_ensure_dirs

    local basename_f
    basename_f=$(basename "$file")

    # Validate
    if ! pickup_validate_envelope "$file"; then
        echo -e "${RED}REJECT${NC}  $basename_f — invalid envelope" >&2
        if [ "$dry_run" != true ]; then
            mv "$file" "$PICKUP_REJECTED/" 2>/dev/null || true
        fi
        return 1
    fi

    # Dedup
    if pickup_dedup_check "$file"; then
        echo -e "${YELLOW}DEDUP${NC}   $basename_f — seen within cooldown window"
        if [ "$dry_run" != true ]; then
            mv "$file" "$PICKUP_REJECTED/" 2>/dev/null || true
        fi
        return 0
    fi

    # Process
    local summary
    summary=$(grep "^  summary:" "$file" | head -1 | sed 's/^  summary:[[:space:]]*//' | tr -d '"' | tr -d "'")

    if [ "$dry_run" = true ]; then
        echo -e "${CYAN}WOULD PROCESS${NC}  $basename_f — $summary"
        return 0
    fi

    echo -e "${GREEN}PROCESS${NC} $basename_f — $summary"

    # Create inception task
    pickup_create_inception "$file"

    # Record dedup hash
    pickup_record_dedup "$file"

    # Move to processed
    mv "$file" "$PICKUP_PROCESSED/" 2>/dev/null || true

    return 0
}

# --- Main entry point ---

do_pickup() {
    local subcmd="${1:-}"
    shift 2>/dev/null || true

    case "$subcmd" in
        -h|--help|"")
            echo -e "${BOLD}fw pickup${NC} — Cross-project pickup pipeline"
            echo ""
            echo "Commands:"
            echo "  process     Process all envelopes in the inbox"
            echo "  status      Show inbox/processed/rejected counts"
            echo "  list        List inbox contents"
            echo ""
            echo "Options:"
            echo "  --dry-run   Show what would be processed without acting"
            echo "  -h, --help  Show this help"
            return 0
            ;;
        process)
            local dry_run=false
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --dry-run) dry_run=true; shift ;;
                    *) echo -e "${RED}Unknown option: $1${NC}" >&2; return 1 ;;
                esac
            done

            pickup_ensure_dirs

            local count=0 processed=0 rejected=0
            local f
            for f in "$PICKUP_INBOX"/*.yaml "$PICKUP_INBOX"/*.yml; do
                [ -f "$f" ] || continue
                count=$((count + 1))

                if pickup_process_one "$f" "$dry_run"; then
                    processed=$((processed + 1))
                else
                    rejected=$((rejected + 1))
                fi
            done

            echo ""
            echo -e "${BOLD}Pickup summary:${NC} $count found, $processed processed, $rejected rejected"
            if [ "$count" -eq 0 ]; then
                echo "  Inbox is empty"
            fi
            ;;
        status)
            pickup_ensure_dirs
            local inbox_count processed_count rejected_count
            inbox_count=$(find "$PICKUP_INBOX" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)
            processed_count=$(find "$PICKUP_PROCESSED" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)
            rejected_count=$(find "$PICKUP_REJECTED" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)

            echo -e "${BOLD}Pickup pipeline status${NC}"
            echo "  Inbox:     $inbox_count"
            echo "  Processed: $processed_count"
            echo "  Rejected:  $rejected_count"
            ;;
        list)
            pickup_ensure_dirs
            local f
            local found=false
            for f in "$PICKUP_INBOX"/*.yaml "$PICKUP_INBOX"/*.yml; do
                [ -f "$f" ] || continue
                found=true
                local summary pickup_type source_project
                pickup_type=$(grep "^type:" "$f" 2>/dev/null | head -1 | sed 's/^type:[[:space:]]*//' | tr -d '"')
                summary=$(grep "^  summary:" "$f" 2>/dev/null | head -1 | sed 's/^  summary:[[:space:]]*//' | tr -d '"')
                source_project=$(grep "^  project:" "$f" 2>/dev/null | head -1 | sed 's/^  project:[[:space:]]*//' | tr -d '"')
                echo "  $(basename "$f")  [$pickup_type]  $summary  (from $source_project)"
            done
            if [ "$found" = false ]; then
                echo "  Inbox is empty"
            fi
            ;;
        *)
            echo -e "${RED}Unknown pickup command: $subcmd${NC}" >&2
            echo "Run 'fw pickup' for usage" >&2
            return 1
            ;;
    esac
}
