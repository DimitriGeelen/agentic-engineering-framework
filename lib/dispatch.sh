#!/bin/bash
# fw dispatch - SSH-based cross-machine communication
#
# Sends bus envelopes to remote machines via SSH pipe.
# Uses ~/.ssh/config for host resolution and authentication.
#
# Commands:
#   fw dispatch send --host REMOTE --task T-XXX --agent TYPE --summary "text" [--result "text"]
#   fw dispatch hosts    # List configured SSH hosts
#
# Integration with fw bus:
#   fw bus post --remote REMOTE --task T-XXX --agent TYPE --summary "text"
#
# Part of: Agentic Engineering Framework (T-517: SSH-based cross-machine comms)

do_dispatch() {
    local subcmd="${1:-}"
    shift 2>/dev/null || true

    case "$subcmd" in
        send) do_dispatch_send "$@" ;;
        hosts) do_dispatch_hosts ;;
        -h|--help|"") do_dispatch_help ;;
        *)
            echo -e "${RED}Unknown dispatch command: $subcmd${NC}" >&2
            do_dispatch_help >&2
            return 1
            ;;
    esac
}

do_dispatch_help() {
    echo -e "${BOLD}fw dispatch${NC} - SSH-based cross-machine communication"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}send${NC}      Send a result envelope to a remote host"
    echo -e "  ${GREEN}hosts${NC}     List configured SSH hosts from ~/.ssh/config"
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo '  fw dispatch send --host dev-server --task T-XXX --agent explore --summary "Found 3 issues"'
    echo '  fw dispatch hosts'
    echo ""
    echo -e "${BOLD}Integration:${NC}"
    echo '  fw bus post --remote dev-server --task T-XXX --agent TYPE --summary "text"'
    echo ""
    echo -e "${BOLD}Requirements:${NC}"
    echo "  - SSH access to remote host (via ~/.ssh/config or direct)"
    echo "  - Agentic Framework installed on remote host"
    echo "  - Remote user has write access to framework .context/bus/"
}

do_dispatch_send() {
    local remote_host="" task_id="" agent_type="" summary="" result_text=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --host) remote_host="$2"; shift 2 ;;
            --task) task_id="$2"; shift 2 ;;
            --agent) agent_type="$2"; shift 2 ;;
            --summary) summary="$2"; shift 2 ;;
            --result) result_text="$2"; shift 2 ;;
            -h|--help) do_dispatch_help; return 0 ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                return 1
                ;;
        esac
    done

    # Validation
    if [ -z "$remote_host" ]; then
        echo -e "${RED}ERROR: --host is required${NC}" >&2
        return 1
    fi
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

    # Build envelope as JSON (safer for SSH pipe than YAML)
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local hostname
    hostname=$(hostname -s 2>/dev/null || echo "unknown")

    local envelope
    envelope=$(cat <<EOF
{
  "task_id": "$task_id",
  "agent_type": "$agent_type",
  "timestamp": "$timestamp",
  "source_host": "$hostname",
  "summary": $(printf '%s' "$summary" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
  "payload": $(printf '%s' "${result_text:-}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
}
EOF
)

    # Test SSH connectivity first
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$remote_host" "echo ok" &>/dev/null; then
        echo -e "${RED}ERROR: Cannot connect to $remote_host via SSH${NC}" >&2
        echo "  Check ~/.ssh/config or ssh-add your key" >&2
        return 1
    fi

    # Send envelope via SSH pipe to remote fw bus receive
    echo "$envelope" | ssh "$remote_host" "fw bus receive" 2>&1
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}Dispatched${NC} to $remote_host"
        echo "  Task: $task_id"
        echo "  Agent: $agent_type"
        echo "  Summary: $summary"
    else
        echo -e "${RED}ERROR: Dispatch failed (exit code $exit_code)${NC}" >&2
        return $exit_code
    fi
}

do_dispatch_hosts() {
    local ssh_config="$HOME/.ssh/config"

    if [ ! -f "$ssh_config" ]; then
        echo -e "${YELLOW}No ~/.ssh/config found${NC}"
        echo "  Add SSH hosts to enable dispatch."
        return 0
    fi

    echo -e "${BOLD}SSH Hosts (from ~/.ssh/config)${NC}"
    echo ""

    # Parse Host entries from SSH config
    grep -E "^Host\s+" "$ssh_config" | grep -v '\*' | awk '{print $2}' | while read -r host; do
        # Check if host has HostName (not just an alias)
        local hostname
        hostname=$(ssh -G "$host" 2>/dev/null | grep "^hostname " | head -1 | awk '{print $2}')
        if [ -n "$hostname" ] && [ "$hostname" != "$host" ]; then
            echo -e "  ${GREEN}$host${NC} → $hostname"
        else
            echo -e "  ${GREEN}$host${NC}"
        fi
    done

    echo ""
    echo "Test connectivity: ssh -o BatchMode=yes HOST 'fw version'"
}
