#!/usr/bin/env bash
# T-1837 — Cross-hub agent-presence discovery.
#
# `agent-listeners.sh` reads ONE hub. G-060: channel topics (including
# agent-presence) are hub-local; there is no inter-hub federation
# primitive. This verb walks every profile in `~/.termlink/hubs.toml`,
# calls the single-hub verb per profile in parallel, and merges the
# results by `agent_id` with a deterministic preference rule:
#
#   LIVE > STALE > OFFLINE
#   (status tie) → most-recent last_seen_ts wins
#
# Each surviving row carries `hub` = the profile address that saw the
# winning heartbeat last (so the caller can route a doorbell ring to
# the right hub).
#
# Usage:
#   agent-listeners-fleet.sh [OPTIONS]
#
# Options:
#   --topic TOPIC              Source topic (default: agent-presence)
#   --limit N                  Envelopes scanned per hub (default 200, max 1000)
#   --include-offline          Include OFFLINE entries in output
#   --filter-role R            Only show listeners with metadata.role == R
#   --filter-listen-topic T    Only show listeners whose listen_topics include T
#   --filter-agent-id ID       Only show listener with metadata.agent_id == ID
#   --hubs-file PATH           Override default ~/.termlink/hubs.toml
#   --json                     Emit JSON envelope instead of fixed-width table
#   -h, --help                 Print this help and exit 0.
#
# Exit codes:
#   0  ok (incl. zero listeners; partial-failure → still 0, failed hubs listed)
#   2  usage error
#   3  every hub unreachable / unparseable
#
# Output (JSON envelope):
#   {
#     "ok": <bool>,
#     "hubs_scanned": <int>,         // succeeded
#     "hubs_failed":  [{name, address, error}],
#     "total_listeners": <int>,
#     "live": <int>, "stale": <int>, "offline": <int>,
#     "listeners": [
#       {agent_id, role, status, age_secs, last_seen_ts, listen_topics,
#        host, interval_secs, pty_session, hub}
#     ]
#   }
set -u

AGENT_LISTENERS_BIN="${AGENT_LISTENERS_BIN:-scripts/agent-listeners.sh}"
HUBS_FILE="${HOME}/.termlink/hubs.toml"
FORMAT=human

# Forwarded args (collected before fan-out).
topic=""
limit=""
include_offline=0
filter_role=""
filter_listen_topic=""
filter_agent_id=""

die() {
    if [ "$FORMAT" = json ]; then
        printf '{"ok":false,"error":"%s"}\n' "$1"
    else
        echo "agent-listeners-fleet: $1" >&2
    fi
    exit 2
}

usage() { sed -n '2,46p' "$0"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --topic)               topic="${2:-}"; shift 2 ;;
        --limit)               limit="${2:-}"; shift 2 ;;
        --include-offline)     include_offline=1; shift ;;
        --filter-role)         filter_role="${2:-}"; shift 2 ;;
        --filter-listen-topic) filter_listen_topic="${2:-}"; shift 2 ;;
        --filter-agent-id)     filter_agent_id="${2:-}"; shift 2 ;;
        --hubs-file)           HUBS_FILE="${2:-}"; shift 2 ;;
        --json)                FORMAT=json; shift ;;
        -h|--help)             usage; exit 0 ;;
        *)                     die "unknown arg: $1 (try --help)" ;;
    esac
done

command -v jq >/dev/null 2>&1 || die "jq not in PATH"
[ -f "$HUBS_FILE" ] || die "hubs file not found: $HUBS_FILE"
[ -x "$AGENT_LISTENERS_BIN" ] || die "agent-listeners verb not executable: $AGENT_LISTENERS_BIN"

# ---- Parse hubs.toml (mirror T-1831 pattern: minimal [hubs.NAME] + address = "...").
current_name=""
declare -a profile_names=()
declare -a profile_addrs=()

while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    line="${raw_line%$'\r'}"
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue

    if [[ "$line" =~ ^\[hubs\.([A-Za-z0-9_.-]+)\][[:space:]]*$ ]]; then
        current_name="${BASH_REMATCH[1]}"
    elif [ -n "$current_name" ] && [[ "$line" =~ ^address[[:space:]]*=[[:space:]]*\"([^\"]+)\"[[:space:]]*$ ]]; then
        profile_names+=("$current_name")
        profile_addrs+=("${BASH_REMATCH[1]}")
        current_name=""
    fi
done < "$HUBS_FILE"

n_profiles="${#profile_names[@]}"
if [ "$n_profiles" -eq 0 ]; then
    if [ "$FORMAT" = json ]; then
        printf '{"ok":true,"hubs_scanned":0,"hubs_failed":[],"total_listeners":0,"live":0,"stale":0,"offline":0,"listeners":[]}\n'
    else
        echo "no profiles found in $HUBS_FILE" >&2
    fi
    exit 0
fi

# ---- Fan out per-profile in parallel, capture JSON to per-profile tempfile.
workdir="$(mktemp -d -t agent-listeners-fleet.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

build_args() {
    # Echoes the forwarded args one per line so the caller can slurp into an array.
    [ -n "$topic" ]               && { printf -- '--topic\n%s\n' "$topic"; }
    [ -n "$limit" ]               && { printf -- '--limit\n%s\n' "$limit"; }
    [ "$include_offline" -eq 1 ]  && { printf -- '--include-offline\n'; }
    [ -n "$filter_role" ]         && { printf -- '--filter-role\n%s\n' "$filter_role"; }
    [ -n "$filter_listen_topic" ] && { printf -- '--filter-listen-topic\n%s\n' "$filter_listen_topic"; }
    [ -n "$filter_agent_id" ]     && { printf -- '--filter-agent-id\n%s\n' "$filter_agent_id"; }
    printf -- '--json\n'
}

mapfile -t fwd_args < <(build_args)

i=0
while [ "$i" -lt "$n_profiles" ]; do
    name="${profile_names[$i]}"
    addr="${profile_addrs[$i]}"
    out_file="$workdir/$i.json"
    err_file="$workdir/$i.err"

    (
        bash "$AGENT_LISTENERS_BIN" --hub "$addr" "${fwd_args[@]}" >"$out_file" 2>"$err_file"
        rc=$?
        printf '%d' "$rc" > "$workdir/$i.rc"
    ) &

    i=$((i + 1))
done
wait

# ---- Collect results and merge.
declare -a hubs_failed_lines=()
all_listeners='[]'
hubs_scanned=0
i=0
while [ "$i" -lt "$n_profiles" ]; do
    name="${profile_names[$i]}"
    addr="${profile_addrs[$i]}"
    rc="$(cat "$workdir/$i.rc" 2>/dev/null || echo 99)"
    out="$(cat "$workdir/$i.json" 2>/dev/null || true)"
    err="$(cat "$workdir/$i.err" 2>/dev/null || true)"

    if [ "$rc" != "0" ] || [ -z "$out" ]; then
        err_msg="$(printf '%s' "${err:-rc=$rc}" | tr '\n' ' ' | head -c 200)"
        hubs_failed_lines+=("$(jq -nc --arg n "$name" --arg a "$addr" --arg e "$err_msg" \
            '{name:$n, address:$a, error:$e}')")
    else
        if ! parsed="$(printf '%s' "$out" | jq -c . 2>/dev/null)"; then
            hubs_failed_lines+=("$(jq -nc --arg n "$name" --arg a "$addr" --arg e "non-JSON response" \
                '{name:$n, address:$a, error:$e}')")
        else
            # Decorate each listener with `hub` (profile address).
            decorated="$(printf '%s' "$parsed" | jq -c --arg hub "$addr" \
                '.listeners // [] | map(. + {hub: $hub})')"
            all_listeners="$(jq -nc --argjson a "$all_listeners" --argjson b "$decorated" '$a + $b')"
            hubs_scanned=$((hubs_scanned + 1))
        fi
    fi

    i=$((i + 1))
done

# Merge by agent_id; pick winner.
merged="$(printf '%s' "$all_listeners" | jq -c '
    def status_rank(s):
        if s == "LIVE"    then 3
        elif s == "STALE" then 2
        elif s == "OFFLINE" then 1
        else 0 end;
    group_by(.agent_id)
    | map(
        sort_by(status_rank(.status), .last_seen_ts) | last
      )
    | sort_by(.last_seen_ts) | reverse
')"

n_total=$(printf '%s' "$merged" | jq 'length')
n_live=$(printf '%s'    "$merged" | jq '[.[] | select(.status=="LIVE")]    | length')
n_stale=$(printf '%s'   "$merged" | jq '[.[] | select(.status=="STALE")]   | length')
n_offline=$(printf '%s' "$merged" | jq '[.[] | select(.status=="OFFLINE")] | length')

# Construct hubs_failed JSON array.
hubs_failed_json="[]"
if [ "${#hubs_failed_lines[@]}" -gt 0 ]; then
    hubs_failed_json="$(printf '%s\n' "${hubs_failed_lines[@]}" | jq -s '.')"
fi

# Exit code policy: all hubs failed → 3.
if [ "$hubs_scanned" -eq 0 ]; then
    exit_code=3
    ok_flag=false
else
    exit_code=0
    ok_flag=true
fi

if [ "$FORMAT" = json ]; then
    jq -n --argjson ok "$ok_flag" \
          --argjson hubs_scanned "$hubs_scanned" \
          --argjson hubs_failed "$hubs_failed_json" \
          --argjson total "$n_total" \
          --argjson live  "$n_live" \
          --argjson stale "$n_stale" \
          --argjson offline "$n_offline" \
          --argjson listeners "$merged" \
        '{ok: $ok, hubs_scanned: $hubs_scanned, hubs_failed: $hubs_failed,
          total_listeners: $total, live: $live, stale: $stale,
          offline: $offline, listeners: $listeners}'
else
    if [ "$hubs_scanned" -eq 0 ]; then
        echo "ERROR: every hub unreachable. hubs_failed=$(printf '%s' "$hubs_failed_json" | jq -r 'length')" >&2
        printf '%s\n' "$hubs_failed_json" | jq -r '.[] | "  - \(.name) (\(.address)): \(.error)"' >&2
        exit 3
    fi
    printf 'Fleet agent-presence — %d hubs scanned, %d failed, %d listeners (%d LIVE / %d STALE / %d OFFLINE)\n' \
        "$hubs_scanned" "$(printf '%s' "$hubs_failed_json" | jq 'length')" \
        "$n_total" "$n_live" "$n_stale" "$n_offline"
    if [ "$(printf '%s' "$hubs_failed_json" | jq 'length')" -gt 0 ]; then
        echo "Failed hubs:"
        printf '%s\n' "$hubs_failed_json" | jq -r '.[] | "  - \(.name) (\(.address)): \(.error)"'
    fi
    if [ "$n_total" -gt 0 ]; then
        printf '\n%-24s %-10s %-8s %-7s %-22s %s\n' "AGENT_ID" "ROLE" "STATUS" "AGE_S" "HUB" "LISTEN_TOPICS"
        printf '%s\n' "$merged" | jq -r '.[] | [
            (.agent_id // "?"),
            (.role // ""),
            (.status // "?"),
            ((.age_secs // 0) | tostring),
            (.hub // ""),
            (.listen_topics // "")
        ] | @tsv' | while IFS=$'\t' read -r aid role status age hub topics; do
            printf '%-24s %-10s %-8s %-7s %-22s %s\n' "$aid" "$role" "$status" "$age" "$hub" "$topics"
        done
    fi
fi

exit "$exit_code"
