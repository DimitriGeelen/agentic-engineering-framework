#!/usr/bin/env bats
# T-3698: fw init / fw upgrade wrote a consumer .mcp.json whose termlink server
# had no env.TERMLINK_RUNTIME_DIR. Claude launched without the variable (T-3779)
# then ran `termlink mcp serve` on /tmp/termlink-$UID: channel posts landed in a
# store no hub reads and read back as delivered. Both producers now pin the live
# hub dir, add-only. Fake hubs: a real AF_UNIX socket plus a pidfile naming a
# live ($$) pid, as in t3779_termlink_runtime.bats.

load ../test_helper
load ../fresh_machine_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FWROOT="${BATS_TEST_DIRNAME}/../.."
    unset TERMLINK_RUNTIME_DIR TERMLINK_SESSION_ID
    export FW_TERMLINK_DEFAULT_RUNTIME_DIR="$TEST_TEMP_DIR/default"
    export TERMLINK_RUNTIME_DIR_FALLBACK="$TEST_TEMP_DIR/canon"
    mkdir -p "$TEST_TEMP_DIR/default" "$TEST_TEMP_DIR/canon" "$TEST_TEMP_DIR/home"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_hub() {   # _hub <dir> — a live fake hub
    python3 -c "import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])" "$1/hub.sock"
    echo $$ > "$1/hub.pid"
}

_tl_env() {   # _tl_env <mcp.json> → the termlink server's TERMLINK_RUNTIME_DIR, or ""
    python3 -c "import json,sys; s=json.load(open(sys.argv[1]))['mcpServers']['termlink']; print((s.get('env') or {}).get('TERMLINK_RUNTIME_DIR',''))" "$1"
}

_init_mcp() {   # _init_mcp <dir> [force] — run the real init generator
    (
        export FRAMEWORK_ROOT="$FWROOT" PROJECT_ROOT="$1" FW_LIB_DIR="$FWROOT/lib" FW_VERSION=1.0.0 NO_COLOR=1
        source "$FWROOT/lib/colors.sh"; source "$FWROOT/lib/errors.sh"; source "$FWROOT/lib/init.sh"
        force="${2:-false}"
        generate_claude_code_config "$1"
    ) >/dev/null 2>&1
}

# ── helpers ────────────────────────────────────────────────────────────────

@test "t3698: mcp_runtime_dir pins the supplied canonical hub dir" {
    source "$FWROOT/lib/termlink-runtime.sh"
    _hub "$TEST_TEMP_DIR/canon"
    run fw_termlink_mcp_runtime_dir
    [ "$output" = "$TEST_TEMP_DIR/canon" ]
}

@test "t3698: mcp_runtime_dir prints nothing when the default dir is the hub, or no hub exists" {
    source "$FWROOT/lib/termlink-runtime.sh"
    run fw_termlink_mcp_runtime_dir
    [ -z "$output" ]
    _hub "$TEST_TEMP_DIR/default"
    run fw_termlink_mcp_runtime_dir
    [ -z "$output" ]
}

@test "t3698: mcp_runtime_dir pins an explicit TERMLINK_RUNTIME_DIR only when its hub is live" {
    source "$FWROOT/lib/termlink-runtime.sh"
    mkdir -p "$TEST_TEMP_DIR/explicit"
    TERMLINK_RUNTIME_DIR="$TEST_TEMP_DIR/explicit" run fw_termlink_mcp_runtime_dir
    [ -z "$output" ]
    _hub "$TEST_TEMP_DIR/explicit"
    TERMLINK_RUNTIME_DIR="$TEST_TEMP_DIR/explicit" run fw_termlink_mcp_runtime_dir
    [ "$output" = "$TEST_TEMP_DIR/explicit" ]
}

@test "t3698: pin adds the key, keeps other env, never overwrites, dry-run writes nothing" {
    source "$FWROOT/lib/termlink-runtime.sh"
    local f="$TEST_TEMP_DIR/m.json"
    echo '{"mcpServers":{"termlink":{"command":"termlink","env":{"TERMLINK_TASK_GOVERNANCE":"1"}},"x":{"command":"y"}}}' > "$f"
    run fw_mcp_pin_termlink_runtime "$f" /hub/a 1
    [ "$output" = "would-pin /hub/a" ]
    [ -z "$(_tl_env "$f")" ]
    run fw_mcp_pin_termlink_runtime "$f" /hub/a
    [ "$output" = "pinned /hub/a" ]
    [ "$(_tl_env "$f")" = /hub/a ]
    python3 -c "import json,sys; d=json.load(open(sys.argv[1]))['mcpServers']; assert d['termlink']['env']['TERMLINK_TASK_GOVERNANCE']=='1'; assert d['x']=={'command':'y'}" "$f"
    run fw_mcp_pin_termlink_runtime "$f" /hub/b
    [ -z "$output" ]
    [ "$(_tl_env "$f")" = /hub/a ]
}

# ── fw init producer ───────────────────────────────────────────────────────

@test "t3698: fw init pins the hub dir into a freshly written .mcp.json" {
    _hub "$TEST_TEMP_DIR/canon"
    local proj="$TEST_TEMP_DIR/p1"; mkdir -p "$proj"
    _init_mcp "$proj"
    [ -f "$proj/.mcp.json" ]
    [ "$(_tl_env "$proj/.mcp.json")" = "$TEST_TEMP_DIR/canon" ]
}

@test "t3698: fw init leaves the termlink server unpinned when the default dir is the hub" {
    _hub "$TEST_TEMP_DIR/default"
    local proj="$TEST_TEMP_DIR/p2"; mkdir -p "$proj"
    _init_mcp "$proj"
    [ -z "$(_tl_env "$proj/.mcp.json")" ]
}

@test "t3698: fw init (force merge) pins an existing file but never changes a set value" {
    _hub "$TEST_TEMP_DIR/canon"
    local proj="$TEST_TEMP_DIR/p3"; mkdir -p "$proj"
    echo '{"mcpServers":{"termlink":{"command":"termlink","args":["mcp","serve"]}}}' > "$proj/.mcp.json"
    _init_mcp "$proj" true
    [ "$(_tl_env "$proj/.mcp.json")" = "$TEST_TEMP_DIR/canon" ]
    echo '{"mcpServers":{"termlink":{"command":"termlink","env":{"TERMLINK_RUNTIME_DIR":"/mine"}}}}' > "$proj/.mcp.json"
    _init_mcp "$proj" true
    [ "$(_tl_env "$proj/.mcp.json")" = /mine ]
}

# ── fw upgrade producer (end to end, scrubbed env, real vendored bin/fw) ────

# T-4617: push to an explicit branch and point the bare's HEAD at it (same fix
# T-4587 made to overlay_upstream). From a detached-HEAD checkout (CI, cloud
# clones) the bare's HEAD is a bare sha, `push origin HEAD` has no branch to
# update and fails, and the consumer's clone never sees the overlay.
_overlay() {   # _overlay <bare> <paths…> — commit working-tree files into the upstream
    local bare="$1"; shift
    local wc="$TEST_TEMP_DIR/overlay-wc" f
    git clone --quiet "$bare" "$wc" 2>/dev/null
    for f in "$@"; do cp "$FWROOT/$f" "$wc/$f"; done
    git -C "$wc" add -- "$@"
    git -C "$wc" -c user.name=t -c user.email=t@t commit --quiet --no-gpg-sign -m overlay >/dev/null 2>&1 || true
    git -C "$wc" push --quiet origin HEAD:refs/heads/fw-test-overlay
    git --git-dir="$bare" symbolic-ref HEAD refs/heads/fw-test-overlay
    rm -rf "$wc"
}

@test "T-4617: _overlay lands the overlay when the upstream bare's HEAD is detached" {
    FRAMEWORK_ROOT="$FWROOT"
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    make_upstream_bare "$upstream_bare"
    # The shape a detached-HEAD checkout produces: the bare's HEAD is a bare sha.
    git --git-dir="$upstream_bare" update-ref --no-deref HEAD "$(git --git-dir="$upstream_bare" rev-parse HEAD)"
    ! git --git-dir="$upstream_bare" symbolic-ref -q HEAD || false

    # Overlay source is a scratch dir, so the test never writes into the checkout.
    local f=t4617-overlay-probe
    mkdir -p "$TEST_TEMP_DIR/src"
    echo "t4617-overlay-marker" > "$TEST_TEMP_DIR/src/$f"
    FWROOT="$TEST_TEMP_DIR/src" run _overlay "$upstream_bare" "$f"
    [ "$status" -eq 0 ] || { echo "$output"; false; }

    git clone --quiet "$upstream_bare" "$TEST_TEMP_DIR/check" 2>/dev/null
    [ "$(cat "$TEST_TEMP_DIR/check/$f")" = "t4617-overlay-marker" ]
}

_upgrade() {   # _upgrade <proj> [args…] — env -i, only the test's hub dirs passed through
    local proj="$1"; shift
    (cd "$proj" && env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" \
        FW_TERMLINK_DEFAULT_RUNTIME_DIR="$FW_TERMLINK_DEFAULT_RUNTIME_DIR" \
        TERMLINK_RUNTIME_DIR_FALLBACK="$TERMLINK_RUNTIME_DIR_FALLBACK" \
        "$proj/.agentic-framework/bin/fw" upgrade "$proj" "$@")
}

@test "t3698: fw upgrade pins an existing unpinned termlink server, keeping its other env" {
    FRAMEWORK_ROOT="$FWROOT"
    _hub "$TEST_TEMP_DIR/canon"
    local upstream_bare="$TEST_TEMP_DIR/upstream.git" proj="$TEST_TEMP_DIR/up"
    make_upstream_bare "$upstream_bare"
    _overlay "$upstream_bare" bin/fw lib/upgrade.sh lib/init.sh lib/termlink-runtime.sh
    "$FWROOT/bin/fw" vendor --target "$proj" --source "$FWROOT" >/dev/null
    cat > "$proj/.framework.yaml" <<YAML
project_name: up
version: $(tr -d '\n' < "$proj/.agentic-framework/VERSION")
provider: claude
upstream_repo: file://$upstream_bare
YAML
    cat > "$proj/.mcp.json" <<'JSON'
{"mcpServers": {
  "context7": {"command": "npx", "args": ["-y", "@upstash/context7-mcp"]},
  "playwright": {"command": "npx", "args": ["@playwright/mcp@latest", "--no-sandbox"]},
  "termlink": {"command": "termlink", "args": ["mcp", "serve"], "env": {"TERMLINK_TASK_GOVERNANCE": "1"}},
  "fw": {"command": "python3", "args": [".agentic-framework/agents/mcp/framework_mcp_server.py"]}
}}
JSON
    # (A consumer-side --dry-run stops at the auto-clone plan before step 6, so
    # the dry path is pinned by the helper test above, not here.)
    run _upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [ "$(_tl_env "$proj/.mcp.json")" = "$TEST_TEMP_DIR/canon" ] || { cat "$proj/.mcp.json"; false; }
    python3 -c "import json,sys; e=json.load(open(sys.argv[1]))['mcpServers']['termlink']['env']; assert e['TERMLINK_TASK_GOVERNANCE']=='1', e" "$proj/.mcp.json"
}
