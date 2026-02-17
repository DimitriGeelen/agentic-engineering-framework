#!/bin/bash
# fw bus - Task-scoped result ledger for sub-agent communication
#
# Provides structured, size-gated result storage for sub-agent dispatch.
# Results are written as typed YAML envelopes in .context/bus/results/T-XXX/.
# Payloads >2KB are auto-moved to .context/bus/blobs/T-XXX/.
#
# This prevents T-073-class context explosions by formalizing the
# "write to disk, return path + summary" convention into a protocol.
#
# Commands:
#   fw bus post --task T-XXX --agent TYPE --summary "text" [--result "text" | --blob PATH]
#   fw bus read T-XXX [R-NNN]
#   fw bus manifest T-XXX
#   fw bus clear T-XXX
#
# Part of: Agentic Engineering Framework (T-109: Structured Result Ledger)

# Size gate threshold (bytes). Payloads >= this are auto-moved to blobs.
BUS_SIZE_GATE=2048

do_bus() {
    local subcmd="${1:-}"
    shift 2>/dev/null || true

    case "$subcmd" in
        post) do_bus_post "$@" ;;
        read) do_bus_read "$@" ;;
        manifest) do_bus_manifest "$@" ;;
        clear) do_bus_clear "$@" ;;
        -h|--help|"") do_bus_help ;;
        *)
            echo -e "${RED}Unknown bus command: $subcmd${NC}" >&2
            do_bus_help >&2
            return 1
            ;;
    esac
}

do_bus_help() {
    echo -e "${BOLD}fw bus${NC} - Task-scoped result ledger"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}post${NC}      Post a result to a task channel"
    echo -e "  ${GREEN}read${NC}      Read results from a task channel"
    echo -e "  ${GREEN}manifest${NC}  Show summary of all results for a task"
    echo -e "  ${GREEN}clear${NC}     Clear results for a completed task"
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo '  fw bus post --task T-XXX --agent explore --summary "Found 3 issues"'
    echo '  fw bus post --task T-XXX --agent explore --summary "Full report" --result "inline text"'
    echo '  fw bus post --task T-XXX --agent code --summary "Wrote file" --blob /path/to/file'
    echo "  fw bus read T-XXX              # Read all results"
    echo "  fw bus read T-XXX R-003        # Read specific result"
    echo "  fw bus manifest T-XXX          # Summary view"
    echo "  fw bus clear T-XXX             # Clear channel"
    echo ""
    echo -e "${BOLD}Size gating:${NC}"
    echo "  Payloads < ${BUS_SIZE_GATE}B are stored inline in the YAML envelope."
    echo "  Payloads >= ${BUS_SIZE_GATE}B are auto-moved to .context/bus/blobs/ and referenced."
}

do_bus_post() {
    local task_id="" agent_type="" msg_type="artifact" summary=""
    local result_text="" blob_path="" agent_id_val=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --task) task_id="$2"; shift 2 ;;
            --agent) agent_type="$2"; shift 2 ;;
            --type) msg_type="$2"; shift 2 ;;
            --summary) summary="$2"; shift 2 ;;
            --result) result_text="$2"; shift 2 ;;
            --blob) blob_path="$2"; shift 2 ;;
            --agent-id) agent_id_val="$2"; shift 2 ;;
            -h|--help) do_bus_help; return 0 ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                return 1
                ;;
        esac
    done

    # Validation
    if [ -z "$task_id" ]; then
        echo -e "${RED}ERROR: --task is required${NC}" >&2
        return 1
    fi
    if [ -z "$agent_type" ]; then
        echo -e "${RED}ERROR: --agent is required${NC}" >&2
        return 1
    fi
    if [ -z "$summary" ]; then
        echo -e "${RED}ERROR: --summary is required${NC}" >&2
        return 1
    fi

    # Setup directories
    local bus_dir="$PROJECT_ROOT/.context/bus/results/$task_id"
    local blob_dir="$PROJECT_ROOT/.context/bus/blobs/$task_id"
    mkdir -p "$bus_dir"

    # Auto-increment result ID
    local count
    count=$(find "$bus_dir" -maxdepth 1 -name "R-*.yaml" 2>/dev/null | wc -l)
    count=$((count + 1))
    local result_id
    result_id=$(printf "R-%03d" "$count")

    local result_file="$bus_dir/$result_id.yaml"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Determine payload handling
    local payload_ref="" payload_inline="" size_bytes=0

    if [ -n "$blob_path" ]; then
        # Explicit blob reference
        if [ ! -f "$blob_path" ]; then
            echo -e "${RED}ERROR: Blob file not found: $blob_path${NC}" >&2
            return 1
        fi
        size_bytes=$(wc -c < "$blob_path")
        payload_ref="$blob_path"
    elif [ -n "$result_text" ]; then
        size_bytes=${#result_text}
        if [ "$size_bytes" -ge "$BUS_SIZE_GATE" ]; then
            # Auto-gate: write to blob directory
            mkdir -p "$blob_dir"
            local blob_file="$blob_dir/$result_id.blob"
            printf '%s' "$result_text" > "$blob_file"
            payload_ref="$blob_file"
        else
            payload_inline="$result_text"
        fi
    fi

    # Write envelope using Python for safe YAML serialization
    BUS_RESULT_ID="$result_id" BUS_TASK_ID="$task_id" BUS_AGENT_TYPE="$agent_type" \
    BUS_AGENT_ID="${agent_id_val:-}" BUS_TIMESTAMP="$timestamp" BUS_MSG_TYPE="$msg_type" \
    BUS_SUMMARY="$summary" BUS_SIZE_BYTES="$size_bytes" \
    BUS_PAYLOAD_REF="$payload_ref" BUS_PAYLOAD_INLINE="$payload_inline" \
    BUS_RESULT_FILE="$result_file" \
    python3 << 'PYEOF'
import yaml, os

envelope = {
    'id': os.environ['BUS_RESULT_ID'],
    'task_id': os.environ['BUS_TASK_ID'],
    'agent_type': os.environ['BUS_AGENT_TYPE'],
    'timestamp': os.environ['BUS_TIMESTAMP'],
    'type': os.environ['BUS_MSG_TYPE'],
    'summary': os.environ['BUS_SUMMARY'],
    'size_bytes': int(os.environ['BUS_SIZE_BYTES']),
}

agent_id = os.environ.get('BUS_AGENT_ID', '')
if agent_id:
    envelope['agent_id'] = agent_id

payload_ref = os.environ.get('BUS_PAYLOAD_REF', '')
payload_inline = os.environ.get('BUS_PAYLOAD_INLINE', '')

if payload_ref:
    envelope['payload_ref'] = payload_ref
elif payload_inline:
    envelope['payload'] = payload_inline

with open(os.environ['BUS_RESULT_FILE'], 'w') as f:
    yaml.dump(envelope, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
PYEOF

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to write result envelope${NC}" >&2
        return 1
    fi

    # Verify the file was actually written (L-035: never trust success without verification)
    if [ ! -s "$result_file" ]; then
        echo -e "${RED}ERROR: Result envelope is empty after write — data may be lost${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}Posted${NC} $result_id to $task_id channel"
    echo "  Agent: $agent_type"
    echo "  Summary: $summary"
    if [ -n "$payload_ref" ]; then
        echo "  Storage: blob (${size_bytes}B) → $payload_ref"
    elif [ "$size_bytes" -gt 0 ]; then
        echo "  Storage: inline (${size_bytes}B)"
    else
        echo "  Storage: summary only (no payload)"
    fi
    echo "  File: $result_file"
}

do_bus_read() {
    local task_id="${1:-}"
    local result_id="${2:-}"

    if [ -z "$task_id" ]; then
        echo -e "${RED}ERROR: Task ID required${NC}" >&2
        echo "Usage: fw bus read T-XXX [R-NNN]"
        return 1
    fi

    local bus_dir="$PROJECT_ROOT/.context/bus/results/$task_id"

    if [ ! -d "$bus_dir" ]; then
        echo -e "${YELLOW}No results for $task_id${NC}"
        return 0
    fi

    if [ -n "$result_id" ]; then
        # Read specific result
        local file="$bus_dir/$result_id.yaml"
        if [ ! -f "$file" ]; then
            echo -e "${RED}ERROR: Result not found: $result_id${NC}" >&2
            return 1
        fi

        python3 << PYEOF
import yaml

with open("$file") as f:
    data = yaml.safe_load(f)

print(f"ID:      {data.get('id', '?')}")
print(f"Agent:   {data.get('agent_type', '?')}")
print(f"Type:    {data.get('type', '?')}")
print(f"Time:    {data.get('timestamp', '?')}")
print(f"Summary: {data.get('summary', '?')}")
print(f"Size:    {data.get('size_bytes', 0)}B")

payload = data.get('payload', '')
payload_ref = data.get('payload_ref', '')

if payload:
    print(f"\n--- Payload (inline) ---")
    print(payload)
elif payload_ref:
    print(f"\n--- Payload (blob: {payload_ref}) ---")
    try:
        with open(payload_ref) as bf:
            print(bf.read())
    except FileNotFoundError:
        print(f"[blob file not found: {payload_ref}]")
PYEOF
    else
        # Read all results (summaries only for context efficiency)
        local file_count
        file_count=$(find "$bus_dir" -maxdepth 1 -name "R-*.yaml" 2>/dev/null | wc -l)
        echo -e "${BOLD}$task_id${NC} — $file_count results"
        echo ""

        for f in "$bus_dir"/R-*.yaml; do
            [ -f "$f" ] || continue
            python3 << PYEOF
import yaml

with open("$f") as fh:
    data = yaml.safe_load(fh)

rid = data.get('id', '?')
agent = data.get('agent_type', '?')
summary = data.get('summary', '?')
size = data.get('size_bytes', 0)
has_blob = bool(data.get('payload_ref'))
storage = 'blob' if has_blob else ('inline' if data.get('payload') else 'summary-only')

print(f"  {rid} ({agent}) — {summary}  [{size}B, {storage}]")
PYEOF
        done
    fi
}

do_bus_manifest() {
    local task_id="${1:-}"

    if [ -z "$task_id" ]; then
        # Show all active channels
        local bus_root="$PROJECT_ROOT/.context/bus/results"
        if [ ! -d "$bus_root" ]; then
            echo -e "${YELLOW}No bus channels exist${NC}"
            return 0
        fi

        echo -e "${BOLD}Active Bus Channels${NC}"
        echo ""
        for channel_dir in "$bus_root"/T-*; do
            [ -d "$channel_dir" ] || continue
            local tid
            tid=$(basename "$channel_dir")
            local cnt
            cnt=$(find "$channel_dir" -maxdepth 1 -name "R-*.yaml" 2>/dev/null | wc -l)
            echo -e "  ${GREEN}$tid${NC} — $cnt results"
        done
        return 0
    fi

    local bus_dir="$PROJECT_ROOT/.context/bus/results/$task_id"

    if [ ! -d "$bus_dir" ]; then
        echo -e "${YELLOW}No results for $task_id${NC}"
        return 0
    fi

    local count
    count=$(find "$bus_dir" -maxdepth 1 -name "R-*.yaml" 2>/dev/null | wc -l)

    echo -e "${BOLD}Result Manifest: $task_id${NC} ($count results)"
    echo ""

    local total_bytes=0

    for f in "$bus_dir"/R-*.yaml; do
        [ -f "$f" ] || continue
        python3 << PYEOF
import yaml

with open("$f") as fh:
    data = yaml.safe_load(fh)

rid = data.get('id', '?')
agent = data.get('agent_type', '?')
ts = data.get('timestamp', '?')
msg_type = data.get('type', '?')
summary = data.get('summary', '?')
size = data.get('size_bytes', 0)
has_blob = bool(data.get('payload_ref'))
storage = 'blob' if has_blob else ('inline' if data.get('payload') else 'summary')

# Truncate summary for display
if len(summary) > 80:
    summary = summary[:77] + '...'

print(f"  {rid}  {agent:<12} {msg_type:<12} {size:>6}B {storage:<8} {summary}")
PYEOF
    done
}

do_bus_clear() {
    local task_id="${1:-}"

    if [ -z "$task_id" ]; then
        echo -e "${RED}ERROR: Task ID required${NC}" >&2
        echo "Usage: fw bus clear T-XXX"
        return 1
    fi

    local bus_dir="$PROJECT_ROOT/.context/bus/results/$task_id"
    local blob_dir="$PROJECT_ROOT/.context/bus/blobs/$task_id"
    local cleared=0

    if [ -d "$bus_dir" ]; then
        cleared=$(find "$bus_dir" -maxdepth 1 -name "R-*.yaml" 2>/dev/null | wc -l)
        rm -rf "$bus_dir"
    fi
    if [ -d "$blob_dir" ]; then
        rm -rf "$blob_dir"
    fi

    echo -e "${GREEN}Cleared${NC} $task_id channel ($cleared results removed)"
}
