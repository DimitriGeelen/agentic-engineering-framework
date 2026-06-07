#!/usr/bin/env bats
# T-2240: pre-push self-vendor drift gate (F2 N×M closure).
#
# Origin: T-2095 extracted _self_vendor_libs() into `fw vendor self`; T-2232
# made the in-consumer upgrade path durable; T-2239 split dry-run wording.
# The gap T-2240 closes: editing lib/*.sh without running `fw vendor self`
# leaves .agentic-framework/lib/ stale. `fw upgrade` is the only flow that
# catches it, and upgrade isn't part of the push flow — consumers vendoring
# from origin silently inherit the divergence.
#
# Surface under test: pre-push hook body installed by `fw git install-hooks`
# (agents/git/lib/hooks.sh — VERSION=1.5). The hook copy at .git/hooks/pre-push
# in the framework repo IS the same content; this test copies it into a temp
# repo and feeds synthetic stdin (mirrors pre_push_version_monotonicity.bats).
#
# AC mapping (per .tasks/active/T-2240-*.md Slice 2):
#   (a) clean state → push allowed                      — t1
#   (b) drift state → push blocked with canonical msg   — t2
#   (c) FW_SKIP_SELF_VENDOR_CHECK=1 → allowed + WARN     — t3
#   (d) consumer-shape (no root bin/fw) → check skipped — t4

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_REPO="$(mktemp -d -t fw-t2240-XXXXXX)"
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
    # Initial commit + VERSION (so VERSION-monotonicity gate has nothing to block)
    echo "1.0.0" > VERSION
    git add VERSION agents/audit/audit.sh
    git commit -q -m "T-0: init"
    REMOTE_SHA="$(git rev-parse HEAD)"
    # Bump VERSION so the push has *something* to push (otherwise the hook's
    # VERSION gate sees equal and falls through cleanly; we still want a real
    # push-shape stdin to feed through).
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

# Build a stub bin/fw that prints either "would sync ..." or nothing on
# `fw vendor self --dry-run`, controlled by the FW_STUB_DRIFT env var.
# Other subcommands (e.g. config) exit 0 silently so the hook's other steps
# don't trip on the stub.
_install_fw_stub() {
    mkdir -p "$TMP_REPO/bin"
    cat > "$TMP_REPO/bin/fw" <<'STUB'
#!/bin/bash
# Stub: T-2240 bats fixture. Only handles `vendor self --dry-run`.
case "$1" in
    vendor)
        shift
        case "$1" in
            self)
                shift
                # FW_STUB_DRIFT=1 → simulate stale .agentic-framework/lib/
                if [ "${FW_STUB_DRIFT:-0}" = "1" ]; then
                    echo "  Self-vendor: would sync 3 file(s) to .agentic-framework/lib/"
                fi
                exit 0
                ;;
        esac
        ;;
esac
exit 0
STUB
    chmod +x "$TMP_REPO/bin/fw"
}

# ─────────────────────────────────────────────────────────────────────────
# (a) clean state → push allowed
# ─────────────────────────────────────────────────────────────────────────

@test "t2240 t1: clean self-vendor state → push allowed" {
    _install_fw_stub
    mkdir -p "$TMP_REPO/.agentic-framework/lib"
    # FW_STUB_DRIFT unset → stub prints nothing → hook sees no "would sync"
    run bash -c "echo '$PUSH_STDIN' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
    # Stderr should NOT contain the T-2240 block message
    [[ "$output" != *"self-vendor drift detected"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# (b) drift state → push blocked with canonical message
# ─────────────────────────────────────────────────────────────────────────

@test "t2240 t2: drift state → push BLOCKED with canonical message" {
    _install_fw_stub
    mkdir -p "$TMP_REPO/.agentic-framework/lib"
    export FW_STUB_DRIFT=1
    run bash -c "echo '$PUSH_STDIN' | FW_STUB_DRIFT=1 .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 1 ]
    # Canonical message components — agent reading this must see ALL three:
    [[ "$output" == *"self-vendor drift detected"* ]]
    [[ "$output" == *"would sync 3 file"* ]]
    # Both bypass mechanisms must be named in the block message (L-399 parity)
    [[ "$output" == *"FW_SKIP_SELF_VENDOR_CHECK=1"* ]]
    [[ "$output" == *"--no-verify"* ]]
    # Fix command must be copy-pasteable. T-2242: class-agnostic — `.agentic-framework/`
    # (not `.agentic-framework/lib/`) so the same fix command covers BOTH classes
    # (libs + templates, T-2241) without misdirecting the reader.
    [[ "$output" == *"bin/fw vendor self"* ]]
    [[ "$output" == *"git add .agentic-framework/ "* ]]
    # T-2242: lib-only diagnostic prose must NOT appear (regression guard)
    [[ "$output" != *"is stale relative to lib/"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# (c) FW_SKIP_SELF_VENDOR_CHECK=1 → push allowed with WARN
# ─────────────────────────────────────────────────────────────────────────

@test "t2240 t3: FW_SKIP_SELF_VENDOR_CHECK=1 bypass → push allowed + WARN" {
    _install_fw_stub
    mkdir -p "$TMP_REPO/.agentic-framework/lib"
    # Drift IS present, but bypass is set — must allow and emit WARN
    run bash -c "echo '$PUSH_STDIN' | FW_STUB_DRIFT=1 FW_SKIP_SELF_VENDOR_CHECK=1 .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
    # WARN line names the env var (so log readers can trace bypass usage)
    [[ "$output" == *"FW_SKIP_SELF_VENDOR_CHECK=1"* ]]
    [[ "$output" == *"WARN"* ]]
    # Block message MUST NOT appear (bypass = allow, not block)
    [[ "$output" != *"Push blocked — self-vendor drift detected"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# (d) consumer-shape (no root bin/fw OR no .agentic-framework/lib) → skip
# ─────────────────────────────────────────────────────────────────────────

@test "t2240 t4a: consumer shape (no root bin/fw) → check skipped, push allowed" {
    # No bin/fw installed in $TMP_REPO. Drift directory exists but the first
    # guard ([ -x \$PROJECT_ROOT/bin/fw ]) short-circuits the whole block.
    mkdir -p "$TMP_REPO/.agentic-framework/lib"
    run bash -c "echo '$PUSH_STDIN' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
    [[ "$output" != *"self-vendor drift detected"* ]]
    [[ "$output" != *"FW_SKIP_SELF_VENDOR_CHECK"* ]]
}

@test "t2240 t4b: no .agentic-framework/lib (fresh repo) → check skipped, push allowed" {
    # bin/fw exists and would drift, but no vendored lib/ to check against.
    # Second guard ([ -d \$PROJECT_ROOT/.agentic-framework/lib ]) skips block.
    _install_fw_stub
    # NOT creating .agentic-framework/lib
    run bash -c "echo '$PUSH_STDIN' | FW_STUB_DRIFT=1 .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
    [[ "$output" != *"self-vendor drift detected"* ]]
}
