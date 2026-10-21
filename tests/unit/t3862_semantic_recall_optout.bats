#!/usr/bin/env bats
# T-3862: semantic recall deliberately absent on a host (SEMANTIC_RECALL=0) is
# "not configured on this host", not 7 FAILs; and fw upgrade names the missing
# prerequisites (sqlite-vec, a reachable embed host) instead of staying silent.
#
# Hermetic: temp project, no index, embed host pointed at a closed port.

ROOT="${BATS_TEST_DIRNAME}/../.."
CHECK="$ROOT/lib/vector_index_health.py"

setup() {
    TMPD="$(mktemp -d)"
    P="$TMPD/proj"
    mkdir -p "$P/.tasks/active" "$P/.context/working"
    unset FW_SEMANTIC_RECALL VECTOR_DB_PATH
    export FW_CRON_INSTALL_DIR="$TMPD/cron.d"
    export FW_EMBED_HOST="http://127.0.0.1:9"   # closed port: unreachable, fast
    export FW_PREREQ_CURL_TIMEOUT=2
    export FRAMEWORK_ROOT="$ROOT" PROJECT_ROOT="$P"
}
teardown() { rm -rf "$TMPD"; }

prereqs() {
    bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; source "$FRAMEWORK_ROOT/lib/vector-index-health.sh"; vector_recall_prereqs'
}

@test "opt-out: no index at all reports one SKIP 'not configured on this host', status OK" {
    run env FW_SEMANTIC_RECALL=0 python3 "$CHECK" --project-root "$P" --framework-root "$ROOT"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "OK" ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "${lines[1]}" == "SKIP|index: semantic recall not configured on this host"* ]]
    ! echo "$output" | grep -q "^FAIL" || false
}

@test "opt-out is read from the project's .framework.yaml through _vih_env" {
    echo "SEMANTIC_RECALL: 0" > "$P/.framework.yaml"
    run bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; source "$FRAMEWORK_ROOT/lib/vector-index-health.sh"; vector_index_health --no-canary'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "OK" ]
    echo "$output" | grep -q "^SKIP|index: semantic recall not configured on this host"
}

@test "no opt-out: a missing index still FAILs (absence is never inferred)" {
    run python3 "$CHECK" --project-root "$P" --framework-root "$ROOT" --no-canary
    [ "$status" -eq 2 ]
    [ "${lines[0]}" = "FAIL" ]
    ! echo "$output" | grep -q "not configured on this host" || false
}

@test "prereqs: unreachable embed host WARNs with configure hint and the opt-out" {
    run prereqs
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^WARN|embed host not reachable (http://127.0.0.1:9)|.*ollama_host.*fw config set SEMANTIC_RECALL 0"
}

@test "prereqs: sqlite-vec not importable WARNs with the install command" {
    mkdir -p "$TMPD/bin"
    real="$(command -v python3)"
    cat > "$TMPD/bin/python3" <<SH
#!/usr/bin/env bash
case "\$*" in *"import sqlite_vec"*) exit 1 ;; esac
exec "$real" "\$@"
SH
    chmod +x "$TMPD/bin/python3"
    run env PATH="$TMPD/bin:$PATH" bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; source "$FRAMEWORK_ROOT/lib/vector-index-health.sh"; vector_recall_prereqs'
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^WARN|sqlite-vec not importable.*|Install: python3 -m pip install sqlite-vec"
}

@test "prereqs: opt-out SKIPs both probes" {
    run env FW_SEMANTIC_RECALL=0 bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; source "$FRAMEWORK_ROOT/lib/vector-index-health.sh"; vector_recall_prereqs'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == "SKIP|semantic recall not configured on this host"* ]]
}

@test "fw upgrade summary runs the prerequisite check, advisory" {
    grep -q '^        _t3862_recall_prereqs "\$target_dir"$' "$ROOT/lib/upgrade.sh"
    run bash -c 'GREEN= NC= BOLD= CYAN= YELLOW= RED=; source "$FRAMEWORK_ROOT/lib/upgrade.sh" >/dev/null 2>&1; _t3862_recall_prereqs "$PROJECT_ROOT"'
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Semantic recall prerequisites (advisory):"
    echo "$output" | grep -q "embed host not reachable"
}

@test "fw index reindex with the opt-out exits 0 without embedding" {
    cd "$P" && git init -q
    run env FW_SEMANTIC_RECALL=0 "$ROOT/bin/fw" index reindex
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"status": "disabled"'
}
