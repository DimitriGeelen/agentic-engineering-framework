#!/bin/bash
# fw consumer-recover - one-command recovery for legacy vendored consumers
#
# Wraps the 4-step recipe documented in feedback_t2232_forward_looking_recovery
# (SSH to host, clone upstream, env-scoped fw upgrade, cleanup) behind a single
# verb. Dry-run by default — operator must pass --apply to execute.
#
# Authorised under T-2233 GO (2026-06-07). Full design spec:
#   docs/reports/T-2233-consumer-recover-design.md
#
# Exit codes:
#   0   dry-run printed OR --apply succeeded
#   1   precondition failed (unreachable / missing tooling / project not found)
#   2   consumer is post-T-2232 — refused with redirect to plain fw upgrade
#   3   --apply ran but post-upgrade doctor reported FAIL

set -uo pipefail

# Prefer 'github' remote (canonical public mirror) over 'origin' (often a private
# dev forge with embedded PAT credentials). This prevents credentials from
# leaking into the dry-run recipe and matches T-2232's documented canonical
# upstream (https://github.com/DimitriGeelen/agentic-engineering-framework.git).
CR_PREFERRED_UPSTREAM_REMOTES=(github origin)

# Colors (NC-safe; bin/fw exports these but the lib can also be invoked standalone)
: "${RED:=\033[0;31m}"
: "${GREEN:=\033[0;32m}"
: "${YELLOW:=\033[1;33m}"
: "${BLUE:=\033[0;34m}"
: "${NC:=\033[0m}"

_cr_die() {
    echo -e "${RED}consumer-recover: $*${NC}" >&2
    exit "${2:-1}"
}

_cr_log() {
    echo -e "${BLUE}consumer-recover:${NC} $*" >&2
}

# Strip embedded user[:password]@ from an HTTPS URL.
# https://TOKEN@host/path  → https://host/path
# Leaves SSH-style URLs (git@host:path) untouched.
#
# T-2693: the implementation moved to lib/url-credentials.sh so the vendor
# write path in bin/fw uses the SAME transformation instead of a second sed
# dialect. This stays as the local name so existing callers here are unchanged.
# shellcheck source=url-credentials.sh
source "$(dirname "${BASH_SOURCE[0]}")/url-credentials.sh"
_cr_strip_credentials() {
    fw_strip_url_credentials "$1"
}

# Resolve the canonical upstream URL.
# Order: --upstream flag > first credential-free remote in CR_PREFERRED_UPSTREAM_REMOTES
#        (stripped of credentials if any) > error.
_cr_resolve_upstream() {
    local override="$1"
    if [[ -n "$override" ]]; then
        _cr_strip_credentials "$override"
        return 0
    fi
    local fw_root="${FRAMEWORK_ROOT:-}"
    if [[ -z "$fw_root" ]]; then
        _cr_die "FRAMEWORK_ROOT not set and --upstream not passed — cannot resolve upstream"
    fi
    local remote url
    for remote in "${CR_PREFERRED_UPSTREAM_REMOTES[@]}"; do
        url=$(cd "$fw_root" && git remote get-url "$remote" 2>/dev/null || true)
        if [[ -n "$url" ]]; then
            _cr_strip_credentials "$url"
            return 0
        fi
    done
    _cr_die "Could not auto-detect upstream from $fw_root (no ${CR_PREFERRED_UPSTREAM_REMOTES[*]} remote). Pass --upstream URL."
}

# Pick transport: explicit --via wins, else TermLink if the hub has a ready
# session for the host, else SSH. T-2236: real CLI is
# `termlink remote list <HUB>` (HUB positional arg required) — earlier code
# omitted HUB and matched against header row by accident.
_cr_pick_transport() {
    local forced="$1"
    local host="$2"
    if [[ -n "$forced" ]]; then
        case "$forced" in
            ssh|termlink) echo "$forced"; return 0 ;;
            *) _cr_die "--via must be ssh or termlink (got '$forced')" ;;
        esac
    fi
    if command -v termlink >/dev/null 2>&1; then
        # `termlink remote list <hub>` returns rows when the hub profile resolves.
        # Use it as the existence probe — a ready session means TermLink is viable.
        if termlink remote list "$host" 2>/dev/null | grep -q "ready"; then
            echo "termlink"
            return 0
        fi
    fi
    echo "ssh"
}

# Auto-discover a ready session on a TermLink hub. Args: hub.
# Returns: first STATE=ready session ID from `termlink remote list HUB`,
# preferring sessions tagged with project=<basename of CR_PROJECT_PATH> if set.
# Empty output if none found.
_cr_discover_session() {
    local hub="$1"
    command -v termlink >/dev/null 2>&1 || return 0
    local list
    list=$(termlink remote list "$hub" 2>/dev/null) || return 0
    # Skip the 2-line header (column row + separator); pick the first
    # STATE=ready row's ID (first column).
    echo "$list" | awk 'NR>2 && /ready/ {print $1; exit}'
}

# Transport: exec a single command. Args: transport, host, session, cmd...
# session is ignored for SSH. T-2236: real CLI is
# `termlink remote exec <HUB> <SESSION> <COMMAND>` (3 positional args, not
# `<HOST> -- <CMD>` which was the earlier bug).
_cr_remote_exec() {
    local transport="$1" host="$2" session="$3"
    shift 3
    case "$transport" in
        ssh)
            ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$host" "$@"
            ;;
        termlink)
            [[ -z "$session" ]] && _cr_die "TermLink transport needs --session ID (or auto-discover failed for hub '$host')"
            termlink remote exec "$host" "$session" "$@"
            ;;
        *)
            _cr_die "Unknown transport: $transport"
            ;;
    esac
}

# Transport: feed a script on stdin to bash on the remote.
# Args: transport, host, session, positional args.
_cr_remote_script() {
    local transport="$1" host="$2" session="$3"
    shift 3
    case "$transport" in
        ssh)
            ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$host" bash -s -- "$@"
            ;;
        termlink)
            [[ -z "$session" ]] && _cr_die "TermLink transport needs --session ID (or auto-discover failed for hub '$host')"
            # `termlink remote exec` doesn't pass stdin to the remote command,
            # so pipe the script in via base64 to avoid heredoc quoting.
            local encoded
            encoded=$(base64 -w0)
            termlink remote exec "$host" "$session" \
                bash -c "echo '$encoded' | base64 -d | bash -s -- $*"
            ;;
        *)
            _cr_die "Unknown transport: $transport"
            ;;
    esac
}

# Probe: is the consumer post-T-2232? Check for .upstream sentinel file.
_cr_sentinel_present() {
    local transport="$1" host="$2" session="$3" project_path="$4"
    local sentinel="$project_path/.agentic-framework/.upstream"
    _cr_remote_exec "$transport" "$host" "$session" "test -s '$sentinel'" >/dev/null 2>&1
}

# Probe: does the project path exist and contain .framework.yaml?
_cr_project_path_valid() {
    local transport="$1" host="$2" session="$3" project_path="$4"
    _cr_remote_exec "$transport" "$host" "$session" "test -f '$project_path/.framework.yaml'" >/dev/null 2>&1
}

# Generate the recovery heredoc that runs on the consumer host.
# Args: project_path, upstream_url, keep_temp (0/1)
_cr_generate_script() {
    local project_path="$1" upstream="$2" keep_temp="$3"
    local trap_line="trap 'rm -rf \"\$TMPDIR\"' EXIT"
    if [[ "$keep_temp" == "1" ]]; then
        trap_line="# --keep-temp: tempdir left on host for inspection"
    fi
    cat <<SCRIPT
set -euo pipefail

PROJECT_PATH="$project_path"
UPSTREAM="$upstream"

if [[ ! -d "\$PROJECT_PATH" ]]; then
    echo "consumer-recover: project path '\$PROJECT_PATH' not found on \$(hostname)" >&2
    exit 1
fi

TMPDIR=\$(mktemp -d /tmp/fw-fresh.XXXXXX)
$trap_line

echo "consumer-recover: cloning \$UPSTREAM into \$TMPDIR" >&2
git clone --depth 1 "\$UPSTREAM" "\$TMPDIR" >&2

echo "consumer-recover: running env-scoped upgrade" >&2
env FRAMEWORK_ROOT="\$TMPDIR" PROJECT_ROOT="\$PROJECT_PATH" \\
    "\$TMPDIR/bin/fw" upgrade "\$PROJECT_PATH"

echo "consumer-recover: post-upgrade doctor" >&2
env FRAMEWORK_ROOT="\$TMPDIR" PROJECT_ROOT="\$PROJECT_PATH" \\
    "\$TMPDIR/bin/fw" doctor
SCRIPT
}

# Print the dry-run teaching artifact.
_cr_print_recipe() {
    local host="$1" project_path="$2" upstream="$3" transport="$4" keep_temp="$5"
    cat <<EOF
=== fw consumer-recover — DRY RUN ===

Host:          $host
Project path:  $project_path
Upstream URL:  $upstream
Transport:     $transport

Would execute on host:

$(_cr_generate_script "$project_path" "$upstream" "$keep_temp" | sed 's/^/  /')

To execute, re-run with --apply.
EOF
}

_cr_usage() {
    cat <<EOF
fw consumer-recover - one-command recovery for legacy vendored consumers

Usage:
  fw consumer-recover <host> [<project-path>] [options]

Arguments:
  <host>           SSH host or TermLink-registered host name
  <project-path>   Consumer project path on the host

Options:
  --apply              Execute (default is dry-run; print recipe only)
  --upstream URL       Override auto-detected upstream URL
  --via {ssh,termlink} Force transport (default: termlink if a ready session
                       exists on hub <host>, else ssh)
  --session ID         TermLink session ID on hub <host> (required when --via
                       termlink and auto-discovery finds no ready session)
  --keep-temp          Leave /tmp/fw-fresh.* on consumer after upgrade
  --dry-run            Explicit dry-run (default; included for symmetry)
  --json               Emit structured result to stdout
  -h, --help           This help

Exit codes:
  0  dry-run printed OR --apply succeeded
  1  precondition failed
  2  consumer is post-T-2232 — use plain fw upgrade
  3  post-upgrade doctor reported FAIL

Authorised: T-2233 GO. Spec: docs/reports/T-2233-consumer-recover-design.md
EOF
}

# JSON outcome envelope (no jq dependency — manual emit).
_cr_emit_json() {
    local host="$1" project="$2" upstream="$3" transport="$4" outcome="$5" exit_code="$6"
    cat <<JSON
{
  "host": "$host",
  "project_path": "$project",
  "upstream": "$upstream",
  "transport": "$transport",
  "outcome": "$outcome",
  "exit_code": $exit_code
}
JSON
}

do_consumer_recover() {
    # Flag defaults
    local apply=0
    local upstream_override=""
    local via_forced=""
    local keep_temp=0
    local emit_json=0
    local host=""
    local project_path=""
    local session=""   # T-2236: explicit TermLink session ID

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help|help)
                _cr_usage
                return 0
                ;;
            --apply|--execute)
                apply=1
                shift
                ;;
            --dry-run)
                apply=0
                shift
                ;;
            --upstream)
                upstream_override="${2:-}"
                [[ -z "$upstream_override" ]] && _cr_die "--upstream requires a URL"
                shift 2
                ;;
            --via)
                via_forced="${2:-}"
                [[ -z "$via_forced" ]] && _cr_die "--via requires ssh or termlink"
                shift 2
                ;;
            --session)
                session="${2:-}"
                [[ -z "$session" ]] && _cr_die "--session requires a session ID"
                shift 2
                ;;
            --keep-temp)
                keep_temp=1
                shift
                ;;
            --json)
                emit_json=1
                shift
                ;;
            --*)
                _cr_die "Unknown flag: $1 (try --help)"
                ;;
            *)
                if [[ -z "$host" ]]; then
                    host="$1"
                elif [[ -z "$project_path" ]]; then
                    project_path="$1"
                else
                    _cr_die "Too many positional arguments at '$1'"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$host" ]]; then
        _cr_usage >&2
        return 1
    fi

    # Resolve upstream + transport
    local upstream transport
    upstream=$(_cr_resolve_upstream "$upstream_override") || return 1
    transport=$(_cr_pick_transport "$via_forced" "$host") || return 1

    # T-2236: auto-discover TermLink session if not explicitly passed.
    # Empty session for SSH transport is fine — the functions ignore it.
    if [[ "$transport" == "termlink" ]] && [[ -z "$session" ]]; then
        session=$(_cr_discover_session "$host")
        if [[ -z "$session" ]]; then
            _cr_die "TermLink transport selected but no ready session on hub '$host' — pass --session ID or --via ssh"
        fi
    fi

    # Resolve project path if missing
    if [[ -z "$project_path" ]]; then
        if [[ -n "${FW_CONSUMER_PATH:-}" ]]; then
            project_path="$FW_CONSUMER_PATH"
        else
            _cr_die "project path not given and FW_CONSUMER_PATH not set — pass <project-path> explicitly"
        fi
    fi

    # Precondition checks via the chosen transport (skipped in pure dry-run if host probe fails;
    # we still want a printable recipe even for a host we can't reach right now).
    local can_probe=1
    if [[ "$apply" == "0" ]] && [[ "${FW_CONSUMER_RECOVER_NO_PROBE:-0}" == "1" ]]; then
        can_probe=0
    fi

    if [[ "$can_probe" == "1" ]]; then
        # Sentinel idempotency check
        if _cr_sentinel_present "$transport" "$host" "$session" "$project_path"; then
            echo -e "${YELLOW}consumer-recover: $host:$project_path is post-T-2232 (sentinel present).${NC}" >&2
            echo "Use plain fw upgrade instead:" >&2
            echo "  ssh $host 'cd $project_path && .agentic-framework/bin/fw upgrade'" >&2
            if [[ "$emit_json" == "1" ]]; then
                _cr_emit_json "$host" "$project_path" "$upstream" "$transport" "refused-post-t2232" 2
            fi
            return 2
        fi
        # Project path validity (only when applying — dry-run should print the recipe regardless)
        if [[ "$apply" == "1" ]] && ! _cr_project_path_valid "$transport" "$host" "$session" "$project_path"; then
            _cr_die "$host:$project_path does not contain .framework.yaml — wrong path?"
        fi
    fi

    # Dry-run path (default)
    if [[ "$apply" == "0" ]]; then
        _cr_print_recipe "$host" "$project_path" "$upstream" "$transport" "$keep_temp"
        if [[ "$emit_json" == "1" ]]; then
            _cr_emit_json "$host" "$project_path" "$upstream" "$transport" "dry-run" 0
        fi
        return 0
    fi

    # --apply path: execute the script via the transport
    _cr_log "executing recovery via $transport against $host${session:+ (session $session)}"
    local script
    script=$(_cr_generate_script "$project_path" "$upstream" "$keep_temp")
    local rc=0
    echo "$script" | _cr_remote_script "$transport" "$host" "$session" || rc=$?

    if [[ "$rc" != "0" ]]; then
        echo -e "${RED}consumer-recover: recovery failed (exit $rc)${NC}" >&2
        if [[ "$emit_json" == "1" ]]; then
            _cr_emit_json "$host" "$project_path" "$upstream" "$transport" "failed" "$rc"
        fi
        # rc 3 = doctor failed post-upgrade; other non-zero = recovery itself failed (rc 1)
        if [[ "$rc" == "3" ]]; then
            return 3
        fi
        return 1
    fi

    echo -e "${GREEN}consumer-recover: $host:$project_path recovered successfully${NC}" >&2
    if [[ "$emit_json" == "1" ]]; then
        _cr_emit_json "$host" "$project_path" "$upstream" "$transport" "success" 0
    fi
    return 0
}

# Allow direct invocation for testing: bash lib/consumer-recover.sh <args>
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    do_consumer_recover "$@"
fi
