#!/usr/bin/env bash
# T-1862 — per-peer DM conversation history.
#
# Read-side companion to /recent-chat (broadcast) and /check-arc (unread
# inbox) for the T-1830 doorbell+mail arc. Answers "show me the
# conversation history with peer X" without requiring the operator to know
# the canonical dm:* topic name.
#
# DM topic naming in the wild is mixed:
#   - dm:<sorted-fp-a>:<sorted-fp-b>            (older fp-pair form)
#   - dm:<agent-id>:<fp>                        (mixed name+fp)
#   - dm:<agent-id-a>:<agent-id-b>              (newer name-pair form)
#
# Rather than derive a canonical name, this script DISCOVERS matching
# dm:* topics by substring-match on the operator-provided peer handle.
# Both the local hub AND every hub in ~/.termlink/hubs.toml are scanned
# for topic listings — DM topics may not federate (PL-176 caveat) so
# topic visibility is per-hub.
#
# Once a topic is matched, this script delegates to
# `agent-chat-arc-recent.sh --topic <T>` (T-1862 added the --topic flag)
# so all envelope-parsing fixes apply uniformly.
set -u

TERMLINK="${TERMLINK_BIN:-termlink}"
HUBS_FILE_DEFAULT="${HOME}/.termlink/hubs.toml"
BE_REACHABLE_STATE="${BE_REACHABLE_STATE:-${HOME}/.termlink/be-reachable.state}"

PER_CALL_TIMEOUT="${TERMLINK_RECENT_DM_TIMEOUT:-8}"
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout $PER_CALL_TIMEOUT"
else
    TIMEOUT_CMD=""
fi

die_usage() {
    echo "recent-dm: $*" >&2
    echo "Try --help for usage." >&2
    exit 2
}

die_setup() {
    if [ "${FORMAT:-text}" = json ]; then
        printf '{"ok":false,"error":"%s"}\n' "$1"
    else
        echo "recent-dm: $1" >&2
    fi
    exit 3
}

usage() {
    cat <<'EOF'
Usage: recent-dm.sh <peer> [OPTIONS]

Show recent DM exchange between self and <peer> by discovering matching
dm:* topics across the fleet and reading them via agent-chat-arc-recent.sh.

Required:
  <peer>               Substring to match against dm:* topic names. Usually
                       a peer agent_id (e.g. ring20-management-agent) or a
                       short fingerprint (16 hex). Substring match — too-
                       generic strings (e.g. "claude") may match many topics.

Options:
  --self ID            Override self identity match (default: agent_id from
                       ~/.termlink/be-reachable.state, falls back to no
                       self-filter — every peer<->X topic shown).
  --limit N            Posts to keep per topic (default 20, max 200)
  --since N            Look-back window in hours (default 24, clamp 1..720)
  --hub addr           Restrict topic discovery to a single hub
  --topic T            Skip discovery; read this exact topic name directly.
                       Use when you already know the dm:* topic (e.g. from
                       check-arc output).
  --all-msg-types      Include receipts / heartbeats / etc. (default: turn
                       and chat msg_types only)
  --json               Emit JSON envelope
  -h, --help           Print this help and exit 0

Discovery semantics:
  - Lists dm:* topics on every hub in ~/.termlink/hubs.toml (or --hub addr).
  - Filters to topics containing the <peer> substring.
  - If --self is set or auto-detected, further filters to topics also
    containing the self substring.
  - On zero matches: prints a hint pointing at /check-arc or explicit
    --topic. Exit 0 (not an error — "no DMs" is a valid state).
  - On multiple matches: scans all matching topics and merges chronologically.

Exit codes:
  0  ok (including zero matches)
  2  usage error
  3  setup error (hubs.toml missing, jq missing, peer missing)
EOF
}

PEER=""
SELF_OVERRIDE=""
LIMIT=20
SINCE_HOURS=24
HUB=""
EXPLICIT_TOPIC=""
FILTER_MSG_TYPE=""
ALL_MSG_TYPES=0
FORMAT=text
HUBS_FILE="$HUBS_FILE_DEFAULT"

# Parse positional + flags.
while [ $# -gt 0 ]; do
    case "$1" in
        --self)             SELF_OVERRIDE="${2:-}"; shift 2 ;;
        --limit)            LIMIT="${2:-}"; shift 2 ;;
        --since)            SINCE_HOURS="${2:-}"; shift 2 ;;
        --hub)              HUB="${2:-}"; shift 2 ;;
        --topic)            EXPLICIT_TOPIC="${2:-}"; shift 2 ;;
        --hubs-file)        HUBS_FILE="${2:-}"; shift 2 ;;
        --filter-msg-type)  FILTER_MSG_TYPE="${2:-}"; shift 2 ;;
        --all-msg-types)    ALL_MSG_TYPES=1; shift ;;
        --json)             FORMAT=json; shift ;;
        -h|--help)          usage; exit 0 ;;
        --) shift; break ;;
        -*) die_usage "unknown arg: $1" ;;
        *)  if [ -z "$PEER" ]; then PEER="$1"; else die_usage "extra positional: $1"; fi; shift ;;
    esac
done

# Allow --topic to substitute for <peer>.
if [ -z "$PEER" ] && [ -z "$EXPLICIT_TOPIC" ]; then
    die_usage "<peer> (substring) is required, or pass --topic <T> explicitly"
fi

case "$LIMIT" in ''|*[!0-9]*) die_usage "--limit must be a positive integer" ;; esac
[ "$LIMIT" -ge 1 ] || die_usage "--limit must be >= 1"
[ "$LIMIT" -le 200 ] || die_usage "--limit must be <= 200"

case "$SINCE_HOURS" in ''|*[!0-9]*) die_usage "--since must be a positive integer" ;; esac
[ "$SINCE_HOURS" -ge 1 ] || die_usage "--since must be >= 1"
[ "$SINCE_HOURS" -le 720 ] || die_usage "--since must be <= 720"

command -v jq >/dev/null 2>&1 || die_setup "jq not in PATH"

# Resolve self identity.
SELF_ID=""
if [ -n "$SELF_OVERRIDE" ]; then
    SELF_ID="$SELF_OVERRIDE"
elif [ -f "$BE_REACHABLE_STATE" ]; then
    SELF_ID="$(jq -r '.agent_id // empty' "$BE_REACHABLE_STATE" 2>/dev/null || echo '')"
fi

# Helper to invoke the underlying reader for one topic.
read_one_topic() {
    local topic="$1"
    local args=(--topic "$topic" --limit "$LIMIT" --since "$SINCE_HOURS" --json)
    if [ -n "$HUB" ]; then args+=(--hub "$HUB"); fi
    # DMs carry both msg_type=chat (bare termlink agent contact) AND
    # msg_type=turn (T-1800 doorbell+mail orchestration). Default to
    # --all-msg-types so neither is hidden; operator passes --filter-msg-type
    # explicitly to narrow. Noise (receipts, topic_metadata) is minimal in
    # DM topics relative to agent-chat-arc.
    if [ -n "$FILTER_MSG_TYPE" ]; then
        args+=(--filter-msg-type "$FILTER_MSG_TYPE")
    elif [ "$ALL_MSG_TYPES" -eq 1 ]; then
        args+=(--all-msg-types)
    else
        args+=(--all-msg-types)
    fi
    bash "$(dirname "$0")/agent-chat-arc-recent.sh" "${args[@]}"
}

# --- Topic discovery ---
declare -a topics=()

if [ -n "$EXPLICIT_TOPIC" ]; then
    topics+=("$EXPLICIT_TOPIC")
else
    # Build hub address list (same logic as agent-chat-arc-recent.sh).
    declare -a hub_addrs=()
    if [ -n "$HUB" ]; then
        hub_addrs+=("$HUB")
    else
        [ -f "$HUBS_FILE" ] || die_setup "hubs file not found: $HUBS_FILE"
        current_name=""
        while IFS= read -r raw_line || [ -n "$raw_line" ]; do
            line="${raw_line%$'\r'}"
            line="${line%%#*}"
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [ -z "$line" ] && continue
            if [[ "$line" =~ ^\[hubs\.([A-Za-z0-9_.-]+)\][[:space:]]*$ ]]; then
                current_name="${BASH_REMATCH[1]}"
            elif [ -n "$current_name" ] && [[ "$line" =~ ^address[[:space:]]*=[[:space:]]*\"([^\"]+)\"[[:space:]]*$ ]]; then
                hub_addrs+=("${BASH_REMATCH[1]}")
                current_name=""
            fi
        done < "$HUBS_FILE"
    fi

    # Discover dm:* topics on each hub, filter to those matching <peer>
    # substring (and self if known).
    declare -A topic_seen=()
    for addr in "${hub_addrs[@]}"; do
        list_raw="$($TIMEOUT_CMD "$TERMLINK" channel list --hub "$addr" --json 2>/dev/null || echo '')"
        [ -z "$list_raw" ] && continue
        # Per-topic filter via jq.
        match_filter='.topics[]?.name | select(startswith("dm:"))'
        if [ -n "$PEER" ]; then
            match_filter="$match_filter | select(contains(\"$PEER\"))"
        fi
        if [ -n "$SELF_ID" ]; then
            match_filter="$match_filter | select(contains(\"$SELF_ID\"))"
        fi
        while IFS= read -r t; do
            [ -z "$t" ] && continue
            if [ -z "${topic_seen[$t]:-}" ]; then
                topic_seen["$t"]=1
                topics+=("$t")
            fi
        done < <(printf '%s' "$list_raw" | jq -r "$match_filter" 2>/dev/null)
    done
fi

# --- Empty-match fast path ---
if [ "${#topics[@]}" -eq 0 ]; then
    if [ "$FORMAT" = json ]; then
        jq -n --arg peer "$PEER" --arg self "$SELF_ID" \
            '{ok: true, summary: {topics_matched: 0, total_posts: 0, peer: $peer, self: $self}, topics: [], posts: []}'
    else
        if [ -n "$SELF_ID" ]; then
            echo "recent-dm: no dm:* topics found containing both '$PEER' and self='$SELF_ID'."
        else
            echo "recent-dm: no dm:* topics found containing '$PEER'."
        fi
        echo "  Hints:"
        echo "    - Verify peer agent_id with: /peers --all (or scripts/agent-listeners-fleet.sh)"
        echo "    - If you know the topic, pass it explicitly: --topic dm:<a>:<b>"
        echo "    - Check unread inbox: /check-arc"
    fi
    exit 0
fi

# --- Scan each matched topic, collect JSON output, merge ---
tmp_merged="$(mktemp -t recent-dm.XXXXXX)"
trap 'rm -f "$tmp_merged"' EXIT

for topic in "${topics[@]}"; do
    out="$(read_one_topic "$topic" 2>/dev/null || echo '')"
    [ -z "$out" ] && continue
    # Annotate each post with its source topic.
    printf '%s' "$out" | jq -c --arg topic "$topic" \
        '(.posts // []) | map(. + {_topic: $topic}) | .[]' >> "$tmp_merged" 2>/dev/null || true
done

# Build the merged view.
# Dedup federated copies: same envelope returned by multiple hubs presents as
# identical (ts, sender, payload_preview) — collapse to one row. (G-060 /
# PL-176: chat-arc-like topics may not federate, but DM topics that DO
# federate produce visible duplicates without this dedup.)
merged_posts="$(jq -s -c --argjson limit "$LIMIT" \
    'unique_by([.ts, .sender, .payload_preview]) | sort_by(-.ts) | .[:$limit]' \
    "$tmp_merged" 2>/dev/null || echo '[]')"
[ -z "$merged_posts" ] && merged_posts="[]"

total_posts="$(printf '%s' "$merged_posts" | jq 'length')"
topics_matched="${#topics[@]}"

if [ "$FORMAT" = json ]; then
    topics_json="$(printf '%s\n' "${topics[@]}" | jq -R . | jq -s -c .)"
    jq -n -c \
        --arg peer "$PEER" \
        --arg self "$SELF_ID" \
        --argjson topics "$topics_json" \
        --argjson posts "$merged_posts" \
        --argjson total "$total_posts" \
        --argjson matched "$topics_matched" \
        --argjson window "$SINCE_HOURS" \
        '{
            ok: true,
            window_hours: $window,
            summary: {
                topics_matched: $matched,
                total_posts: $total,
                peer: $peer,
                self: $self
            },
            topics: $topics,
            posts: $posts
        }'
else
    echo "recent-dm: peer='$PEER' self='${SELF_ID:-<no-self-filter>}' window=${SINCE_HOURS}h"
    echo "  matched topics ($topics_matched):"
    for t in "${topics[@]}"; do echo "    - $t"; done
    echo
    if [ "$total_posts" = "0" ]; then
        echo "  (no posts in window — topic exists but no recent activity)"
    else
        printf '%-20s %-44s %-32s %s\n' "TS" "TOPIC" "SENDER" "PREVIEW"
        printf '%s' "$merged_posts" | jq -r '.[] | [.ts_iso, ._topic, .sender, .payload_preview] | @tsv' \
            | awk -F'\t' '{printf "%-20s %-44s %-32s %s\n", $1, $2, $3, $4}'
    fi
fi

exit 0
