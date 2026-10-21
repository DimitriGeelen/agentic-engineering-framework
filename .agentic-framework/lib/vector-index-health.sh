#!/usr/bin/env bash
# Vector-index (semantic recall) health — bash side of lib/vector_index_health.py.
# T-3783. ONE predicate, called by fw doctor, fw audit (corpus-health section),
# the handover, the hourly `fw index reindex` cron and the fw recall / fw ask banner.
#
# Needs FRAMEWORK_ROOT and PROJECT_ROOT; uses fw_config when lib/config.sh is loaded.

# _vih_env — resolve the thresholds once, from the config registry chain.
_vih_env() {
    if declare -F fw_config >/dev/null 2>&1; then
        FW_INDEX_MAX_AGE_HOURS="$(fw_config INDEX_MAX_AGE_HOURS 2>/dev/null || echo 24)"
        FW_INDEX_MAX_LAG="$(fw_config INDEX_MAX_LAG 2>/dev/null || echo 50)"
        FW_RECALL_FAIL_PCT_WARN="$(fw_config RECALL_FAIL_PCT_WARN 2>/dev/null || echo 10)"
        FW_SEMANTIC_RECALL="$(fw_config SEMANTIC_RECALL 2>/dev/null || echo 1)"
    fi
    export FW_INDEX_MAX_AGE_HOURS FW_INDEX_MAX_LAG FW_RECALL_FAIL_PCT_WARN FW_SEMANTIC_RECALL
}

# vector_recall_disabled — true when SEMANTIC_RECALL=0 (deliberately absent, T-3862).
vector_recall_disabled() {
    _vih_env
    [ "${FW_SEMANTIC_RECALL:-1}" = "0" ]
}

# vector_recall_prereqs — T-3862: can this host run semantic recall at all?
# Prints one VERDICT|message|hint line per prerequisite (sqlite-vec importable,
# embed host reachable), the same shape as vector_index_health. Advisory: always
# returns 0. The embed host is resolved through web/config.py, like fw doctor.
vector_recall_prereqs() {
    local optout="Or declare it absent on this host: fw config set SEMANTIC_RECALL 0"
    if vector_recall_disabled; then
        echo "SKIP|semantic recall not configured on this host (SEMANTIC_RECALL=0)|Enable: fw config set SEMANTIC_RECALL 1"
        return 0
    fi
    if python3 -c "import sqlite_vec" >/dev/null 2>&1; then
        echo "OK|sqlite-vec importable|"
    else
        echo "WARN|sqlite-vec not importable by python3 — the vector index cannot be built|Install: python3 -m pip install sqlite-vec. $optout"
    fi
    local host
    host="$(PROJECT_ROOT="${PROJECT_ROOT:-$PWD}" PYTHONPATH="$FRAMEWORK_ROOT/web" python3 -c "
try:
    from config import Config
    print(Config.EMBED_HOST or '')
except Exception:
    print('')
" 2>/dev/null)"
    if [ -z "$host" ]; then
        echo "WARN|no embed host configured (no embed_host, no ollama_host)|Set ollama_host: <url> in .context/settings.yaml (or FW_EMBED_HOST). $optout"
    elif curl -sf --max-time "${FW_PREREQ_CURL_TIMEOUT:-3}" "${host%/}/api/tags" >/dev/null 2>&1; then
        echo "OK|embed host reachable ($host)|"
    else
        echo "WARN|embed host not reachable ($host)|Start Ollama there, or set ollama_host/embed_host in .context/settings.yaml. $optout"
    fi
    return 0
}

# vector_index_health [--no-canary]
# Prints the status line (OK|WARN|FAIL) then one VERDICT|check: message|hint line
# per check. Full runs (canary on) record the verdict and push the operator via
# fw_notify exactly when it turns red. Return: 0 OK, 1 WARN, 2 FAIL.
vector_index_health() {
    local canary_flag="" record_flag="--record"
    if [ "${1:-}" = "--no-canary" ]; then
        canary_flag="--no-canary"; record_flag=""
    fi
    _vih_env
    local out rc=0
    out=$(python3 "$FRAMEWORK_ROOT/lib/vector_index_health.py" \
            --project-root "${PROJECT_ROOT:-$PWD}" --framework-root "$FRAMEWORK_ROOT" \
            $canary_flag $record_flag 2>/dev/null) || rc=$?
    if [ -z "$out" ]; then
        # The checker itself could not run — that is a FAIL, never a skip.
        out="FAIL"$'\n'"FAIL|check: vector index health check did not run (python3 missing?)|Run: python3 $FRAMEWORK_ROOT/lib/vector_index_health.py"
        rc=2
        # Review final round: a checker that cannot START must still be recorded and
        # pushed once on the transition — without python, since python is what failed.
        if [ -n "$record_flag" ] && _vih_record_fail_without_python; then
            out="$out"$'\n'"TURNED_RED"
        fi
    fi
    if printf '%s\n' "$out" | grep -qx "TURNED_RED"; then
        out=$(printf '%s\n' "$out" | grep -vx "TURNED_RED")
        _vih_notify_red "$out"
    fi
    printf '%s\n' "$out"
    return "$rc"
}

# _vih_record_fail_without_python — record a FAIL verdict in the same state file the
# python recorder uses (.context/working/vector-index-health.json), atomically.
# Returns 0 only when this call turned the state red (previous status not FAIL).
_vih_record_fail_without_python() {
    local dir="${PROJECT_ROOT:-$PWD}/.context/working" prev tmp
    local state="$dir/vector-index-health.json"
    mkdir -p "$dir" 2>/dev/null || return 1
    prev=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[A-Z]*"' "$state" 2>/dev/null | head -1 | grep -o '[A-Z]*"$' | tr -d '"')
    tmp="$state.tmp.$$"
    printf '{\n  "status": "FAIL",\n  "ts": %s,\n  "previous": "%s",\n  "reasons": ["vector index health check did not run (python3 missing?)"]\n}\n' \
        "$(date +%s)" "${prev:-UNKNOWN}" > "$tmp" 2>/dev/null && mv -f "$tmp" "$state" 2>/dev/null || { rm -f "$tmp"; return 1; }
    [ "${prev:-}" != "FAIL" ]
}

_vih_notify_red() {
    local out="$1" reasons
    reasons=$(printf '%s\n' "$out" | awk -F'|' '$1=="FAIL"{print $2}' | head -3 | paste -sd ';' -)
    if ! declare -F fw_notify >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "$FRAMEWORK_ROOT/lib/notify.sh" 2>/dev/null || return 0
    fi
    fw_notify "Semantic recall RED: $(basename "${PROJECT_ROOT:-$PWD}")" \
        "${reasons:-vector index check failed}. Fix: fw index reindex; details: fw doctor" \
        "health_check_failed" "framework" 2>/dev/null || true
}

# vector_index_health_summary — one line for the handover; empty unless red.
# Runs the full check (records + notifies on transition like any full run).
vector_index_health_summary() {
    local out reasons
    out=$(vector_index_health) && return 0
    [ "$(printf '%s\n' "$out" | head -1)" = "FAIL" ] || return 0
    reasons=$(printf '%s\n' "$out" | awk -F'|' '$1=="FAIL"{print $2}' | head -3 | paste -sd ';' -)
    echo "**⚠ Semantic recall is RED:** ${reasons} — fix: \`fw index reindex\`; details: \`fw doctor\` (T-3783)."
}
