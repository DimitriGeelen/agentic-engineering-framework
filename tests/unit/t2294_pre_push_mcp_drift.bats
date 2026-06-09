#!/usr/bin/env bats
# T-2294 (arc-010 sibling to T-2240): pre-push MCP manifest drift gate.
#
# Origin: T-2293 commit 7e647bd1e accidentally committed a bats test artefact
# (fake_drift_tool_t2290) into agents/mcp/framework-mcp-manifest.json because
# a prior bats crash polluted tool-set.yaml and the pre-push gate had no MCP
# drift check. This gate runs `fw mcp check` (T-2293) and refuses push on
# non-zero exit.
#
# Surface under test: pre-push hook body installed by `fw git install-hooks`
# (agents/git/lib/hooks.sh — VERSION=1.5). The hook copy at .git/hooks/pre-push
# in the framework repo IS the same content; this test copies it into a temp
# repo and feeds synthetic stdin (mirrors t2240_pre_push_self_vendor_gate.bats).
#
# AC mapping (per .tasks/active/T-2294-*.md):
#   (a) clean state → push allowed                       — t1
#   (b) drift state → push BLOCKED with canonical msg    — t2
#   (c) FW_SKIP_MCP_DRIFT_CHECK=1 → allowed + WARN       — t3

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_REPO="$(mktemp -d -t fw-t2294-XXXXXX)"
    cd "$TMP_REPO"
    git init -q
    git config user.email "test@local"
    git config user.name "test"
    git config commit.gpgsign false
    # Stub audit so the hook's audit step doesn't fail in the temp repo
    mkdir -p agents/audit
    cat > agents/audit/audit.sh <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x agents/audit/audit.sh
    # Copy the framework's installed pre-push hook directly
    mkdir -p .git/hooks
    cp "$FRAMEWORK_ROOT/.git/hooks/pre-push" .git/hooks/pre-push
    chmod +x .git/hooks/pre-push
    # Synthetic VERSION push so the version-monotonicity gate has shape
    echo "1.0.0" > VERSION
    git add VERSION agents/audit/audit.sh
    git commit -q -m "T-0: init"
    REMOTE_SHA="$(git rev-parse HEAD)"
    echo "1.1.0" > VERSION
    git add VERSION
    git -c commit.gpgsign=false commit -q -m "T-0: bump 1.1.0"
    LOCAL_SHA="$(git rev-parse HEAD)"
    PUSH_STDIN="refs/heads/master $LOCAL_SHA refs/heads/master $REMOTE_SHA"
    export REMOTE_SHA LOCAL_SHA PUSH_STDIN
}

teardown() {
    cd /
    rm -rf "$TMP_REPO"
}

# Build a stub bin/fw that handles BOTH `vendor self --dry-run` (always clean
# so the T-2240 gate passes) AND `mcp check` (controlled by FW_STUB_MCP_DRIFT).
# All other subcommands exit 0 silently so the hook's other steps don't trip.
_install_fw_stub() {
    mkdir -p "$TMP_REPO/bin"
    cat > "$TMP_REPO/bin/fw" <<'STUB'
#!/bin/bash
case "$1" in
    vendor)
        # T-2240 gate's verb — always print clean (no "would sync") so we test
        # ONLY the T-2294 gate.
        exit 0
        ;;
    mcp)
        shift
        case "$1" in
            check)
                # FW_STUB_MCP_DRIFT=1 → simulate drift, exit 1.
                # FW_STUB_MCP_DRIFT=2 → simulate absent manifest, exit 2.
                # default → sync, exit 0.
                case "${FW_STUB_MCP_DRIFT:-0}" in
                    1)
                        echo "DRIFT: manifest differs from tool-set.yaml — regenerate via \`fw mcp emit-manifest\`" >&2
                        exit 1
                        ;;
                    2)
                        echo "ABSENT: agents/mcp/framework-mcp-manifest.json — run \`fw mcp emit-manifest\`" >&2
                        exit 2
                        ;;
                    *)
                        echo "OK: manifest in sync (22 tools)"
                        exit 0
                        ;;
                esac
                ;;
        esac
        ;;
esac
exit 0
STUB
    chmod +x "$TMP_REPO/bin/fw"
    # Create the manifest.py guard so the T-2294 block fires (it tests for
    # agents/mcp/manifest.py to gate consumer-vs-framework).
    mkdir -p "$TMP_REPO/agents/mcp"
    : > "$TMP_REPO/agents/mcp/manifest.py"
    # The T-2240 gate also needs .agentic-framework/lib/ to NOT exist (so it
    # skips), OR it needs a clean vendor self response. We've stubbed vendor
    # self to always exit 0 with empty output, but the hook's grep for
    # "would sync" will still not match — so the gate is satisfied either way.
}

# ─────────────────────────────────────────────────────────────────────────
# (a) clean state → push allowed
# ─────────────────────────────────────────────────────────────────────────

@test "t2294 t1: clean MCP manifest state → push allowed" {
    _install_fw_stub
    # FW_STUB_MCP_DRIFT unset → stub exits 0 → hook allows push
    run bash -c "echo '$PUSH_STDIN' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
    [[ "$output" != *"MCP manifest drift detected"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# (b) drift state → push blocked with canonical message
# ─────────────────────────────────────────────────────────────────────────

@test "t2294 t2: drift state → push BLOCKED with canonical message" {
    _install_fw_stub
    run bash -c "echo '$PUSH_STDIN' | FW_STUB_MCP_DRIFT=1 .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 1 ]
    # Block message body
    [[ "$output" == *"MCP manifest drift detected"* ]]
    [[ "$output" == *"T-2294"* ]]
    [[ "$output" == *"framework-mcp-manifest.json"* ]]
    [[ "$output" == *"tool-set.yaml"* ]]
    # Both bypass mechanisms must be named in the block message (L-399 parity / T-1890)
    [[ "$output" == *"FW_SKIP_MCP_DRIFT_CHECK=1"* ]]
    [[ "$output" == *"--no-verify"* ]]
    # Fix command must be copy-pasteable
    [[ "$output" == *"bin/fw mcp emit-manifest"* ]]
    [[ "$output" == *"git add agents/mcp/framework-mcp-manifest.json"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# (c) FW_SKIP_MCP_DRIFT_CHECK=1 → push allowed with WARN
# ─────────────────────────────────────────────────────────────────────────

@test "t2294 t3: FW_SKIP_MCP_DRIFT_CHECK=1 bypass → push allowed + WARN" {
    _install_fw_stub
    # Drift IS present, but bypass is set — must allow and emit WARN
    run bash -c "echo '$PUSH_STDIN' | FW_STUB_MCP_DRIFT=1 FW_SKIP_MCP_DRIFT_CHECK=1 .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FW_SKIP_MCP_DRIFT_CHECK=1"* ]]
    [[ "$output" == *"WARN"* ]]
    [[ "$output" != *"Push blocked — MCP manifest drift detected"* ]]
}
