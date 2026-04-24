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
PICKUP_AUTO_DEFERRED="$PICKUP_DIR/auto-deferred"
PICKUP_DEDUP_LOG="$PICKUP_DIR/dedup.log"

# --- Directory setup ---

pickup_ensure_dirs() {
    mkdir -p "$PICKUP_INBOX" "$PICKUP_PROCESSED" "$PICKUP_REJECTED"
}

# --- G-046: auto-defer self-pickup of already-completed source tasks ---

pickup_is_self_completed() {
    local file="$1"
    local source_project source_task local_project
    source_project=$(grep "^  project:" "$file" | head -1 | sed 's/^  project:[[:space:]]*//' | tr -d '"' | tr -d "'")
    source_task=$(grep "^  task_id:" "$file" 2>/dev/null | head -1 | sed 's/^  task_id:[[:space:]]*//' | tr -d '"' | tr -d "'")
    local_project=$(basename "${PROJECT_ROOT:-.}")

    [ "$source_project" = "$local_project" ] || return 1
    [ -n "$source_task" ] || return 1

    # Check .tasks/completed/ for source_task
    if compgen -G "${PROJECT_ROOT:-.}/.tasks/completed/${source_task}-"*.md >/dev/null 2>&1 \
        || [ -f "${PROJECT_ROOT:-.}/.tasks/completed/${source_task}.md" ]; then
        return 0
    fi
    return 1
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

# T-1425 / G-059: Second-pass triple dedup.
# Catches cross-project retries of the same logical concern when the byte-level
# hash misses (refined summary, new timestamp, added evidence line).
# Key: (source.project, source.task_id, type). Matches an existing active
# inception task created from a prior envelope with the same triple.
#
# Returns 0 ("is triple-collision") and echoes the blocking T-XXX to stdout
# when a match is found. Returns 1 ("not a triple-collision") otherwise.
# Falls through (returns 1) when source.task_id is empty — unreliable key.
# Bypassed (returns 1) when the envelope carries `supersedes: T-XXX` at
# top-level — explicit operator intent to replace a prior pickup.
pickup_dedup_triple_check() {
    local file="$1"

    local source_project source_task pickup_type supersedes
    source_project=$(grep "^  project:" "$file" | head -1 | sed 's/^  project:[[:space:]]*//' | tr -d '"' | tr -d "'")
    source_task=$(grep "^  task_id:" "$file" 2>/dev/null | head -1 | sed 's/^  task_id:[[:space:]]*//' | tr -d '"' | tr -d "'")
    pickup_type=$(grep "^type:" "$file" | head -1 | sed 's/^type:[[:space:]]*//' | tr -d '"' | tr -d "'")
    supersedes=$(grep "^supersedes:" "$file" 2>/dev/null | head -1 | sed 's/^supersedes:[[:space:]]*//' | tr -d '"' | tr -d "'")

    # Empty source_task → triple key is unreliable → fall through to hash-only
    [ -z "$source_task" ] && return 1

    # Explicit supersedes: T-XXX → operator intent to replace a prior pickup → bypass
    [ -n "$supersedes" ] && return 1

    # Scan active tasks for a prior inception with matching triple
    local active_dir="${PROJECT_ROOT:-.}/.tasks/active"
    [ -d "$active_dir" ] || return 1

    local task_file
    for task_file in "$active_dir"/*.md; do
        [ -f "$task_file" ] || continue
        # Fast reject: envelope's source_task must appear in frontmatter at all
        grep -q "^source_task_id_in_origin: ${source_task}$" "$task_file" 2>/dev/null || continue
        grep -q "^source_project_in_origin: \"${source_project}\"$" "$task_file" 2>/dev/null || continue
        # Type check via tags line: `tags: [pickup, <type>]`
        grep -qE "^tags: \[.*\b${pickup_type}\b.*\]" "$task_file" 2>/dev/null || continue
        # Match — emit the T-XXX id and return collision
        local blocking_id
        blocking_id=$(grep "^id:" "$task_file" | head -1 | sed 's/^id:[[:space:]]*//' | tr -d '"' | tr -d "'")
        echo "$blocking_id"
        return 0
    done

    return 1
}

# T-1425: Write a breadcrumb next to an auto-deferred envelope pointing at
# the blocking local inception task. Lets operators (and `fw pickup auto-deferred list`)
# trace why the envelope was deferred instead of processed.
pickup_write_breadcrumb() {
    local deferred_file="$1"
    local blocking_task="$2"
    local reason="${3:-triple-dedup}"

    local breadcrumb="${deferred_file}.breadcrumb.yaml"
    {
        echo "reason: ${reason}"
        echo "blocking_task: ${blocking_task}"
        echo "deferred_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "envelope: $(basename "$deferred_file")"
    } > "$breadcrumb"
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
        local create_out
        create_out=$(fw task create \
            --name "$task_name" \
            --type inception \
            --owner agent \
            --description "Auto-created from pickup envelope. Source: ${source_project}${source_task:+, task ${source_task}}. Type: ${pickup_type}." \
            --horizon next \
            --tags "pickup,${pickup_type}" 2>&1)
        echo "$create_out"
        # G-047: inject source_task_id_in_origin and source_project_in_origin into frontmatter
        if [ -n "$source_task" ]; then
            local new_file
            new_file=$(echo "$create_out" | grep -oE '^File:[[:space:]]+\S+' | awk '{print $2}' | head -1)
            if [ -n "$new_file" ] && [ -f "$new_file" ]; then
                pickup_inject_origin_frontmatter "$new_file" "$source_task" "$source_project"
            fi
        fi
    else
        echo "WARN: fw not on PATH — cannot create task for: $task_name" >&2
        echo "$task_name"
        return 1
    fi
}

# G-047 / T-1342: Inject source_task_id_in_origin + source_project_in_origin into
# a task file's YAML frontmatter. Idempotent. Pure function — no shell-out,
# no environment assumptions. Testable in isolation without triggering
# fw task create (which would leak tasks into the real project during tests).
pickup_inject_origin_frontmatter() {
    local file="$1" src_task="$2" src_proj="$3"
    [ -f "$file" ] || return 1
    python3 - "$file" "$src_task" "$src_proj" <<'PYEOF'
import sys, re
path, src_task, src_proj = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f: txt = f.read()
m = re.match(r'(---\n.*?\n)(---\n)', txt, re.DOTALL)
if not m: sys.exit(0)
fm, closer = m.group(1), m.group(2)
if 'source_task_id_in_origin:' not in fm:
    fm += f'source_task_id_in_origin: {src_task}\nsource_project_in_origin: "{src_proj}"\n'
with open(path, 'w') as f: f.write(fm + closer + txt[m.end():])
PYEOF
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

    # G-046: auto-defer self-pickup of already-completed source tasks
    if pickup_is_self_completed "$file"; then
        echo -e "${YELLOW}AUTO-DEFER${NC}  $basename_f — source task already completed in this project"
        if [ "$dry_run" != true ]; then
            mkdir -p "$PICKUP_AUTO_DEFERRED"
            mv "$file" "$PICKUP_AUTO_DEFERRED/" 2>/dev/null || true
        fi
        return 0
    fi

    # T-1425 / G-059: second-pass triple dedup — cross-project retry of same logical concern
    local blocking_task
    if blocking_task=$(pickup_dedup_triple_check "$file"); then
        echo -e "${YELLOW}AUTO-DEFER${NC}  $basename_f — triple collision with active $blocking_task"
        if [ "$dry_run" != true ]; then
            mkdir -p "$PICKUP_AUTO_DEFERRED"
            if mv "$file" "$PICKUP_AUTO_DEFERRED/" 2>/dev/null; then
                pickup_write_breadcrumb "$PICKUP_AUTO_DEFERRED/$basename_f" "$blocking_task" "triple-dedup"
            fi
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

    # Notify human
    if type fw_notify >/dev/null 2>&1; then
        local source_project
        source_project=$(grep "^  project:" "$file" | head -1 | sed 's/^  project:[[:space:]]*//' | tr -d '"' | tr -d "'")
        fw_notify "Pickup: $summary" "From $source_project — inception task created" 2>/dev/null || true
    fi

    # Record dedup hash
    pickup_record_dedup "$file"

    # Move to processed
    mv "$file" "$PICKUP_PROCESSED/" 2>/dev/null || true

    # T-1165: mirror envelope to channel bus (one-way, non-fatal).
    # Shell pickup stays portable — bridge silently no-ops on any failure.
    local processed_path="$PICKUP_PROCESSED/$basename_f"
    local bridge="${FRAMEWORK_ROOT:-}/lib/pickup-channel-bridge.sh"
    if [ -f "$processed_path" ] && [ -x "$bridge" ]; then
        "$bridge" "$processed_path" 2>/dev/null || true
    fi

    return 0
}

# --- Send (create envelope) ---

do_pickup_send() {
    local pickup_type="" summary="" detail="" priority="medium"
    local source_project="" task_id="" tags="" remote=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --type) pickup_type="$2"; shift 2 ;;
            --summary) summary="$2"; shift 2 ;;
            --detail) detail="$2"; shift 2 ;;
            --priority) priority="$2"; shift 2 ;;
            --source-project) source_project="$2"; shift 2 ;;
            --task-id) task_id="$2"; shift 2 ;;
            --tags) tags="$2"; shift 2 ;;
            --remote) remote="$2"; shift 2 ;;
            -h|--help)
                echo -e "${BOLD}fw pickup send${NC} — Create and deliver a pickup envelope"
                echo ""
                echo "Usage: fw pickup send --type TYPE --summary TEXT [options]"
                echo ""
                echo "Required:"
                echo "  --type TYPE           bug-report, learning, feature-proposal, or pattern"
                echo "  --summary TEXT        One-line description"
                echo ""
                echo "Optional:"
                echo "  --detail TEXT         Multi-line explanation"
                echo "  --priority LEVEL      low, medium (default), or high"
                echo "  --source-project NAME Project name (default: basename of PROJECT_ROOT)"
                echo "  --task-id T-NNN       Originating task ID"
                echo "  --tags TAG1,TAG2      Comma-separated tags"
                echo "  --remote HOST         Push via termlink remote push to HOST"
                echo "  -h, --help            Show this help"
                return 0
                ;;
            -*) echo -e "${RED}Unknown option: $1${NC}" >&2; return 1 ;;
            *) echo -e "${RED}Unexpected argument: $1${NC}" >&2; return 1 ;;
        esac
    done

    # Validate required
    if [ -z "$pickup_type" ]; then
        echo -e "${RED}--type is required${NC}" >&2
        return 1
    fi
    case "$pickup_type" in
        bug-report|learning|feature-proposal|pattern) ;;
        *) echo -e "${RED}Invalid type: $pickup_type (must be bug-report, learning, feature-proposal, or pattern)${NC}" >&2; return 1 ;;
    esac
    if [ -z "$summary" ]; then
        echo -e "${RED}--summary is required${NC}" >&2
        return 1
    fi

    # Defaults
    source_project="${source_project:-$(basename "${PROJECT_ROOT:-.}")}"

    pickup_ensure_dirs

    local pickup_id
    pickup_id=$(pickup_next_id)

    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Build tag list
    local tag_yaml="[]"
    if [ -n "$tags" ]; then
        tag_yaml="[${tags//,/, }]"
    fi

    local filename="${pickup_id}-${pickup_type}.yaml"
    local filepath="$PICKUP_INBOX/$filename"

    # Write envelope
    cat > "$filepath" <<EOF
pickup_id: $pickup_id
version: 1
type: $pickup_type
source:
  project: "$source_project"
  task_id: "${task_id:-}"
  agent: "claude-code"
  timestamp: "$ts"
payload:
  summary: "$summary"
  detail: "${detail:-}"
  priority: $priority
  tags: $tag_yaml
EOF

    echo -e "${GREEN}Created${NC} $filename"

    # Remote push if requested
    if [ -n "$remote" ]; then
        if command -v termlink >/dev/null 2>&1; then
            echo -e "Pushing to ${BOLD}$remote${NC} via termlink..."
            termlink remote push "$remote" "$filepath" 2>&1
        else
            echo -e "${YELLOW}WARN: termlink not installed — envelope saved locally only${NC}" >&2
            echo "  Install: brew install DimitriGeelen/termlink/termlink"
        fi
    fi

    echo "$filepath"
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
            echo "  send            Create and deliver a pickup envelope"
            echo "  process         Process all envelopes in the inbox"
            echo "  status          Show inbox/processed/rejected/auto-deferred counts"
            echo "  list            List inbox contents"
            echo "  auto-deferred   List auto-deferred envelopes with their blocking tasks (G-059)"
            echo ""
            echo "Options:"
            echo "  --dry-run   Show what would be processed without acting"
            echo "  -h, --help  Show this help"
            return 0
            ;;
        send)
            do_pickup_send "$@"
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
            mkdir -p "$PICKUP_AUTO_DEFERRED" 2>/dev/null
            local inbox_count processed_count rejected_count deferred_count
            inbox_count=$(find "$PICKUP_INBOX" -maxdepth 1 \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | wc -l)
            processed_count=$(find "$PICKUP_PROCESSED" -maxdepth 1 \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | wc -l)
            rejected_count=$(find "$PICKUP_REJECTED" -maxdepth 1 \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | wc -l)
            # Auto-deferred envelopes are .yaml but NOT .breadcrumb.yaml
            deferred_count=$(find "$PICKUP_AUTO_DEFERRED" -maxdepth 1 \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null \
                | grep -v '\.breadcrumb\.yaml$' | grep -c . || true)

            echo -e "${BOLD}Pickup pipeline status${NC}"
            echo "  Inbox:         $inbox_count"
            echo "  Processed:     $processed_count"
            echo "  Rejected:      $rejected_count"
            echo "  Auto-deferred: $deferred_count"
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
        auto-deferred)
            # Optional sub-subcommand: default is 'list'
            local action="${1:-list}"
            case "$action" in
                list|"")
                    mkdir -p "$PICKUP_AUTO_DEFERRED" 2>/dev/null
                    local f found=false
                    for f in "$PICKUP_AUTO_DEFERRED"/*.yaml "$PICKUP_AUTO_DEFERRED"/*.yml; do
                        [ -f "$f" ] || continue
                        # Skip breadcrumb sidecars — we'll print them alongside their envelope
                        case "$(basename "$f")" in *.breadcrumb.yaml) continue ;; esac
                        found=true
                        local crumb="${f}.breadcrumb.yaml"
                        local blocking reason deferred_at
                        if [ -f "$crumb" ]; then
                            blocking=$(grep "^blocking_task:" "$crumb" | head -1 | sed 's/^blocking_task:[[:space:]]*//')
                            reason=$(grep "^reason:" "$crumb" | head -1 | sed 's/^reason:[[:space:]]*//')
                            deferred_at=$(grep "^deferred_at:" "$crumb" | head -1 | sed 's/^deferred_at:[[:space:]]*//')
                        fi
                        printf "  %-40s  blocked-by=%-8s  reason=%-14s  at=%s\n" \
                            "$(basename "$f")" \
                            "${blocking:-?}" \
                            "${reason:-?}" \
                            "${deferred_at:-?}"
                    done
                    if [ "$found" = false ]; then
                        echo "  Empty — no envelopes auto-deferred"
                    fi
                    ;;
                -h|--help)
                    echo -e "${BOLD}fw pickup auto-deferred${NC} — List envelopes routed to auto-deferred/"
                    echo ""
                    echo "Usage: fw pickup auto-deferred [list]"
                    echo ""
                    echo "Shows each envelope with the local T-XXX that blocked it (triple-dedup),"
                    echo "the defer reason, and the timestamp. Breadcrumbs live next to the envelope"
                    echo "as <envelope>.breadcrumb.yaml."
                    ;;
                *)
                    echo -e "${RED}Unknown auto-deferred action: $action${NC}" >&2
                    echo "Use: fw pickup auto-deferred [list]" >&2
                    return 1
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}Unknown pickup command: $subcmd${NC}" >&2
            echo "Run 'fw pickup' for usage" >&2
            return 1
            ;;
    esac
}
