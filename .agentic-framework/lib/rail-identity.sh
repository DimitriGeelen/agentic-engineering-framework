#!/usr/bin/env bash
# rail-identity.sh — project-scoped signing identity for outbound rail posts (T-2904)
#
# WHY THIS EXISTS
#
# `termlink channel post` signs with whatever identity termlink resolves, and on a
# host whose ~/.termlink identity is shared across sessions that is the HOST key.
# Every co-resident agent then signs identically, so a peer gating on producer
# identity cannot tell "AEF posted this" from "something else on AEF's host posted
# this". Measured on this host at T-2904: our rail post landed signed as the host
# key while the doorbell path signed as the project key — same rail, same peer, two
# different producers depending on which code path we happened to use.
#
# The signing key is selected by ENV PRECEDENCE, not by post flags (termlink
# PL-236 / their T-2324):
#
#     TERMLINK_IDENTITY_FILE > TERMLINK_AGENT_ID > TERMLINK_IDENTITY_DIR > host default
#
# So a project can own its signing identity without touching host config, which is
# also what D-377 (total isolation — nothing of the project lives in $HOME) wants.
#
# TWO THINGS THAT WILL BITE WHOEVER EDITS THIS
#
# 1. TERMLINK_IDENTITY_FILE AUTO-CREATES the keypair when the path does not exist.
#    It is not a read-only selector. Never point it at a guessed path to "discover"
#    an existing key — on a shared host that mints a new identity rather than
#    reading one. Same reason we never probe TERMLINK_AGENT_ID=<guess>.
#
# 2. The host-default fingerprint is NOT hard-coded here. We detect "you are still
#    signing as the host" by comparing the resolved fingerprint against the bare
#    one, so this works on any host and cannot rot the way a literal would. This is
#    the same anti-pattern the port-3000 rule exists to prevent: a host-specific
#    literal that reads as a constant.

set -o pipefail

# bin/fw sources lib/config.sh only in a couple of subcommands, not globally, so
# fw_config is NOT guaranteed to exist here. Source it ourselves (idempotent).
# Do not paper over its absence: the first cut of this file called fw_config with
# 2>/dev/null, so a missing dependency printed nothing and resolved to "" — which
# is byte-identical to "no project identity configured", i.e. the guard reported
# the plausible answer for the wrong reason. Absence must be loud.
if ! declare -F fw_config >/dev/null 2>&1; then
    _rail_cfg="${FRAMEWORK_ROOT:-${PROJECT_ROOT:-$PWD}}/lib/config.sh"
    # shellcheck source=/dev/null
    [ -f "$_rail_cfg" ] && source "$_rail_cfg"
    unset _rail_cfg
fi

# ── resolution ───────────────────────────────────────────────────────────────

# rail_identity_configured_path — the project's configured identity file, if any.
# Empty when unset. 4-tier: FW_RAIL_IDENTITY_FILE env > .framework.yaml > (none).
rail_identity_configured_path() {
    local p
    if declare -F fw_config >/dev/null 2>&1; then
        p="$(fw_config "RAIL_IDENTITY_FILE" "")"
    else
        # Degraded, but honestly: env tier only, and say so rather than
        # silently reporting "no identity configured".
        echo "rail-identity: WARNING — fw_config unavailable; env tier only" >&2
        p="${FW_RAIL_IDENTITY_FILE:-}"
    fi
    # Relative paths resolve against PROJECT_ROOT so .framework.yaml stays portable.
    if [ -n "$p" ] && [ "${p#/}" = "$p" ]; then
        p="${PROJECT_ROOT:-$PWD}/$p"
    fi
    printf '%s' "$p"
}

# rail_identity_fingerprint [identity_file] — fingerprint termlink WOULD sign with.
# With no argument, reports the host default (no env override applied).
rail_identity_fingerprint() {
    local idfile="${1:-}"
    local out
    if [ -n "$idfile" ]; then
        out="$(TERMLINK_IDENTITY_FILE="$idfile" termlink agent identity --resolve --json 2>/dev/null)"
    else
        out="$(termlink agent identity --resolve --json 2>/dev/null)"
    fi
    [ -n "$out" ] || return 1
    printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("fingerprint",""))' 2>/dev/null
}

# rail_identity_status — prints: <state> <fingerprint> <path>
#   state=project  : signing as a project-owned key, distinguishable from the host
#   state=host     : signing as the host default — indistinguishable from co-residents
#   state=unknown  : termlink absent or identity unresolvable
rail_identity_status() {
    local configured host_fp proj_fp
    configured="$(rail_identity_configured_path)"
    host_fp="$(rail_identity_fingerprint || true)"

    if [ -z "$host_fp" ]; then
        printf 'unknown  \n'
        return 0
    fi

    if [ -z "$configured" ]; then
        printf 'host %s \n' "$host_fp"
        return 0
    fi

    proj_fp="$(rail_identity_fingerprint "$configured" || true)"
    if [ -z "$proj_fp" ]; then
        printf 'unknown  %s\n' "$configured"
    elif [ "$proj_fp" = "$host_fp" ]; then
        # Configured, but resolves to the same key — a project identity that is
        # the host key is not a project identity, it is a longer way to say "host".
        printf 'host %s %s\n' "$proj_fp" "$configured"
    else
        printf 'project %s %s\n' "$proj_fp" "$configured"
    fi
}

# ── the guard ────────────────────────────────────────────────────────────────

# rail_identity_guard — 0 when safe to post, 2 when the post would be host-signed.
# FW_ALLOW_HOST_SIGNED_RAIL=1 bypasses (logged Tier-2 by the caller).
rail_identity_guard() {
    local state
    state="$(rail_identity_status | awk '{print $1}')"

    case "$state" in
        project) return 0 ;;
        unknown)
            # Fail OPEN on an unresolvable identity: refusing to post because we
            # could not introspect termlink would turn a diagnostic gap into an
            # outage. Warn loudly instead — the failure mode we care about is a
            # confidently WRONG producer, not an unknown one.
            echo "rail-identity: WARNING — could not resolve signing identity; posting unverified" >&2
            return 0
            ;;
    esac

    if [ "${FW_ALLOW_HOST_SIGNED_RAIL:-0}" = "1" ]; then
        echo "rail-identity: host-signed post allowed via FW_ALLOW_HOST_SIGNED_RAIL=1 (Tier-2)" >&2
        return 0
    fi

    cat >&2 <<'EOF'
BLOCKED: this rail post would be signed by the HOST key, not a project key.

Every agent on this host signs identically, so a peer gating on producer identity
cannot tell your project's posts from any co-resident agent's. Measured live in
T-2904: the same rail carried our posts under two different producers depending on
which code path sent them.

Fix (pick one):

  1. Point the project at its own signing identity:
       bin/fw config set RAIL_IDENTITY_FILE .context/rail-identity.key
     The key is created on first use (chmod 600). NOTE: this mints a NEW
     fingerprint — peers who know you by an existing one must be told, so treat
     adopting it as a coordination event, not a config tweak.

  2. Re-use an existing project key by pointing at its file:
       bin/fw config set RAIL_IDENTITY_FILE /path/to/existing-identity.key

  3. Post anyway, accepting host attribution (logged):
       FW_ALLOW_HOST_SIGNED_RAIL=1 bin/fw rail post ...

Do NOT try to discover an existing key by guessing TERMLINK_AGENT_ID values —
termlink CREATES an identity for an unknown id rather than reporting a miss, so
guessing mints keys on a shared host instead of finding one.
EOF
    return 2
}

# ── project label (T-2905) ───────────────────────────────────────────────────
#
# 832 measured 474 envelopes on our shared rails and found ONE fingerprint
# carrying SIX from_project values, three of which are this project spelled three
# ways (999-Agentic-Engineering-Framework, 999-agentic-engineering-framework,
# 999-AEF). A label that is present but inconsistent does not group, so it buys
# nothing over absence — and 400 of those 474 carried no label at all, which is
# the larger half.
#
# Their ask was "pick one spelling". Asking every session to remember one is the
# thing that already failed three times, so the label is EMITTED from a single
# source and never typed at a call site. Case and separators are normalised
# because 999-AEF vs 999-aef is the same split one layer down.
#
# Deliberately NOT authentication. 832's 511 puts it exactly: from_project is
# unsigned free text in a metadata map — it distinguishes cooperating
# co-residents and authenticates nobody. It is a grouping key, and a grouping key
# is only worth having if it groups.

rail_project_label() {
    local label
    if declare -F fw_config >/dev/null 2>&1; then
        label="$(fw_config "RAIL_PROJECT_LABEL" "")"
    else
        label="${FW_RAIL_PROJECT_LABEL:-}"
    fi
    [ -n "$label" ] || label="$(basename "${PROJECT_ROOT:-$PWD}")"
    printf '%s' "$label" \
        | tr '[:upper:]' '[:lower:]' \
        | tr ' _' '--' \
        | tr -cd 'a-z0-9.-'
}

# ── command surface ──────────────────────────────────────────────────────────

_rail_log_bypass() {
    # T-2908: $2 lets a second gate (check-rail-mcp-label.sh's file-token
    # bypass) reuse this logger instead of forking a near-duplicate — the
    # gate name is now a parameter, defaulting to the original T-2904 caller's
    # value so that call site needs no change.
    local logf="${PROJECT_ROOT:-$PWD}/.context/working/.gate-bypass-log.yaml"
    [ -f "$logf" ] || return 0
    printf -- '- ts: "%s"\n  gate: %s\n  tier: 2\n  mechanism: %s\n  detail: "%s"\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${2:-rail-identity}" "${3:-FW_ALLOW_HOST_SIGNED_RAIL}" "${1:-host-signed rail post}" >> "$logf" 2>/dev/null || true
}

do_rail() {
    local sub="${1:-identity}"
    shift 2>/dev/null || true

    case "$sub" in
        identity|status)
            local line state fp path
            line="$(rail_identity_status)"
            state="$(echo "$line" | awk '{print $1}')"
            fp="$(echo "$line" | awk '{print $2}')"
            path="$(echo "$line" | awk '{print $3}')"
            echo "Rail signing identity"
            echo "  state:       $state"
            echo "  fingerprint: ${fp:-<unresolved>}"
            echo "  identity:    ${path:-<host default>}"
            case "$state" in
                host)
                    echo "  ⚠ posts are attributed to the HOST — indistinguishable from co-resident agents."
                    echo "    Set one with: bin/fw config set RAIL_IDENTITY_FILE .context/rail-identity.key"
                    ;;
                project) echo "  ✓ posts carry a project-owned producer identity." ;;
            esac
            ;;
        post)
            rail_identity_guard || return 2
            if [ "${FW_ALLOW_HOST_SIGNED_RAIL:-0}" = "1" ]; then
                _rail_log_bypass "fw rail post $*"
            fi
            local idfile
            idfile="$(rail_identity_configured_path)"

            # Attach the canonical label unless the caller set one explicitly.
            # A caller passing from_project wins: this sets a floor, it does not
            # seize the field.
            local -a extra=()
            case " $* " in
                *" --metadata from_project="*) : ;;
                *) extra=(--metadata "from_project=$(rail_project_label)") ;;
            esac

            if [ -n "$idfile" ]; then
                TERMLINK_IDENTITY_FILE="$idfile" termlink channel post "${extra[@]}" "$@"
            else
                termlink channel post "${extra[@]}" "$@"
            fi
            ;;
        allow-unlabeled-mcp)
            # T-2908: one-shot bypass token for check-rail-mcp-label.sh — the
            # MCP producer surface (mcp__termlink__termlink_channel_post) has
            # no command-line surface a flag or env-var prefix could reach, so
            # the L-399 bypass contract here is a file token instead of
            # FW_ALLOW_HOST_SIGNED_RAIL's env var. Consumed (deleted) by the
            # hook on first use; logged Tier-2 at consumption, not here.
            local bf="${PROJECT_ROOT:-$PWD}/.context/working/.rail-mcp-label-bypass"
            mkdir -p "$(dirname "$bf")" 2>/dev/null
            date +%s > "$bf"
            echo "rail: one-shot MCP label bypass armed for ${FW_RAIL_MCP_BYPASS_TTL:-300}s — the next unlabeled mcp__termlink__termlink_channel_post call is allowed through and logged Tier-2."
            ;;
        -h|--help|help)
            cat <<'EOF'
Usage: fw rail <command>

  identity              Show which key outbound rail posts are signed with
  post <topic> ...      Post to a topic, refusing if the post would be
                        host-signed (payload on stdin; remaining args pass
                        through to termlink)
  allow-unlabeled-mcp   Arm a one-shot bypass for the next unlabeled
                        mcp__termlink__termlink_channel_post call (T-2908)

Why: on a host with a shared termlink identity, every agent signs the same, so
peers cannot attribute posts. See lib/rail-identity.sh for the measurement.

T-2908: 'fw rail post' is not the only producer that reaches a rail topic.
The MCP tool mcp__termlink__termlink_channel_post reaches the same topics and
carries neither this file's identity guard nor its label auto-attach — see
agents/context/check-rail-mcp-label.sh for the (label-only) gate on that
surface, and its header comment for why identity is not re-gated there.
EOF
            ;;
        *)
            echo "fw rail: unknown subcommand '$sub' (try: fw rail --help)" >&2
            return 1
            ;;
    esac
}
