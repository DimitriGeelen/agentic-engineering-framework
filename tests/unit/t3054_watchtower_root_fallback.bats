#!/usr/bin/env bats
# T-3054 — the PROJECT_ROOT -> FRAMEWORK_ROOT fallback must be audible, and the
# identity check must not compute its expected value from the same expression.
#
# The original defect was not the fallback. It was that the fallback was silent
# in two places at once: the launcher used it to decide what to serve, and the
# identity check used it to decide what "ours" means — so a server that fell
# back matched itself and passed `fw doctor`. Every test below therefore
# exercises the UNSET case, which is the only one that could ever have failed.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    FAKE_FW="$TEST_TEMP_DIR/framework"
    FAKE_PROJ="$TEST_TEMP_DIR/project"
    mkdir -p "$FAKE_FW" "$FAKE_PROJ"
}

teardown() {
    rm -rf "${TEST_TEMP_DIR:?}"
}

# Source lib/watchtower.sh in a subshell with a controlled environment and run
# the resolver. Prints "<stdout>||<stderr>".
_resolve() {
    # $1 = value for PROJECT_ROOT, or the literal string UNSET
    local pr="$1"
    # Source against the REAL framework (lib/watchtower.sh pulls in siblings),
    # then swap the roots. Sourcing under a synthetic FRAMEWORK_ROOT emits its
    # own "No such file" noise, which would land in $output and be indis-
    # tinguishable from the warning under test.
    bash -c '
        set +e
        FRAMEWORK_ROOT="'"$FRAMEWORK_ROOT"'"; export FRAMEWORK_ROOT
        source "$FRAMEWORK_ROOT/lib/colors.sh" 2>/dev/null
        source "$FRAMEWORK_ROOT/lib/watchtower.sh" 2>/dev/null
        FRAMEWORK_ROOT="'"$FAKE_FW"'"; export FRAMEWORK_ROOT
        if [ "'"$pr"'" != "UNSET" ]; then PROJECT_ROOT="'"$pr"'"; export PROJECT_ROOT; else unset PROJECT_ROOT; fi
        out=$(_watchtower_our_root 2>"'"$TEST_TEMP_DIR"'/err")
        printf "%s||%s" "$out" "$(cat "'"$TEST_TEMP_DIR"'/err")"
    '
}

@test "A1/A3 — an unset PROJECT_ROOT warns, and names the root it fell back to" {
    run _resolve UNSET
    [ "$status" -eq 0 ]
    [[ "$output" == *"$FAKE_FW||"* ]]           # still returns the fallback value
    [[ "$output" == *"PROJECT_ROOT is unset"* ]]
    [[ "$output" == *"$FAKE_FW"* ]]
    [[ "$output" == *"T-3054"* ]]
}

@test "A3 — the pre-fix expression is silent on the same input (guard is load-bearing)" {
    # Without this, the warning above could be coming from anywhere. Run the
    # exact expression the code used before and prove it says nothing.
    run bash -c "unset PROJECT_ROOT; FRAMEWORK_ROOT='$FAKE_FW'; \
                 out=\"\${PROJECT_ROOT:-\$FRAMEWORK_ROOT}\"; \
                 printf '%s||' \"\$out\""
    [ "$status" -eq 0 ]
    [[ "$output" == "$FAKE_FW||" ]]             # same value, and nothing on stderr
    [[ "$output" != *"PROJECT_ROOT is unset"* ]]
}

@test "A5 — an explicitly-set PROJECT_ROOT is silent" {
    run _resolve "$FAKE_PROJ"
    [ "$status" -eq 0 ]
    [[ "$output" == "$FAKE_PROJ||" ]]
}

@test "A5 — explicitly serving the framework repo itself is also silent" {
    # The legitimate case the fallback exists for. Setting PROJECT_ROOT to
    # FRAMEWORK_ROOT on purpose must not be nagged at.
    run _resolve "$FAKE_FW"
    [ "$status" -eq 0 ]
    [[ "$output" == "$FAKE_FW||" ]]
}

@test "A2 — neither identity site still spells the fallback inline" {
    cd "$FRAMEWORK_ROOT"
    if grep -n 'PROJECT_ROOT:-${FRAMEWORK_ROOT:-}' lib/watchtower.sh; then false; fi
    # both sites now go through the shared resolver
    [ "$(grep -c '_our_root=$(_watchtower_our_root)' lib/watchtower.sh)" -eq 2 ]
}

@test "A2 — the launcher routes through the resolver too" {
    cd "$FRAMEWORK_ROOT"
    grep -q 'PROJECT_ROOT="$(_watchtower_our_root)"' bin/watchtower.sh
}

@test "A4 — the identity check reports non-matching when the served root is not ours" {
    # A server answering with FRAMEWORK_ROOT while we are configured for a real
    # project must NOT match. Previously, with PROJECT_ROOT unset on the caller
    # side, both sides collapsed to FRAMEWORK_ROOT and this returned 0.
    port=$((21000 + RANDOM % 2000))
    python3 - "$port" "$FAKE_FW" &>/dev/null <<'PY' &
import sys, json
from http.server import BaseHTTPRequestHandler, HTTPServer
port, root = int(sys.argv[1]), sys.argv[2]
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        b=json.dumps({"service":"watchtower","project_root":root}).encode()
        self.send_response(200); self.send_header("Content-Type","application/json")
        self.send_header("Content-Length",str(len(b))); self.end_headers(); self.wfile.write(b)
    def log_message(self,*a): pass
HTTPServer(("127.0.0.1",port),H).serve_forever()
PY
    srv=$!
    for _ in $(seq 1 40); do curl -sf "http://127.0.0.1:$port/api/_identity" >/dev/null 2>&1 && break; sleep 0.1; done

    run bash -c "
        FRAMEWORK_ROOT='$FAKE_FW'; export FRAMEWORK_ROOT
        PROJECT_ROOT='$FAKE_PROJ'; export PROJECT_ROOT
        source '$FRAMEWORK_ROOT/lib/colors.sh' 2>/dev/null
        source '$FRAMEWORK_ROOT/lib/watchtower.sh'
        _watchtower_identity_matches 'http://127.0.0.1:$port'
    "
    kill "$srv" 2>/dev/null || true
    [ "$status" -ne 0 ]
}
