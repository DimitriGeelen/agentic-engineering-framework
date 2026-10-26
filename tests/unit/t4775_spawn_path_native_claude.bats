#!/usr/bin/env bats
# T-4775 (055 field finding, msg 3d70e92d) — a dispatch from a caller whose PATH lacks
# ~/.local/bin resolved the stale npm claude in /usr/local/bin (2.1.27). T-4666's constructed
# PATH put that dir AHEAD of ~/.local/bin, the native install (2.1.310), so the worker ran the old
# binary, which refused ~/.claude/settings.json (permissions.defaultMode auto) with a blocking
# dialog and never started.
#
# Sandbox only: HOME is a scratch dir holding a native claude stub in .local/bin; the "npm" claude
# is a symlink into a node_modules/@anthropic-ai/claude-code tree, the shape npm installs.
# termlink is a stub (`pty inject` runs the injected command in a background shell).

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TL="$ROOT/agents/termlink/termlink.sh"
    T="$BATS_TEST_TMPDIR"
    H="$T/home"; STUB="$T/stub"; NPM="$T/npm"; DD="$T/dispatch"; P="$T/proj"
    mkdir -p "$H/.local/bin" "$STUB" "$NPM/bin" "$NPM/lib/node_modules/@anthropic-ai/claude-code" "$DD" "$P"
    cat > "$H/.local/bin/claude" <<EOF
#!/bin/bash
[ "\$1" = --version ] && { echo "2.1.310 (Claude Code)"; exit 0; }
echo native > "$T/ran"
echo '{"type":"result","result":"done"}'
EOF
    cat > "$NPM/lib/node_modules/@anthropic-ai/claude-code/cli.js" <<EOF
#!/bin/bash
[ "\$1" = --version ] && { echo "2.1.27 (Claude Code)"; exit 0; }
echo npm > "$T/ran"
echo '{"type":"result","result":"done"}'
EOF
    chmod +x "$H/.local/bin/claude" "$NPM/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    ln -s ../lib/node_modules/@anthropic-ai/claude-code/cli.js "$NPM/bin/claude"
    cat > "$STUB/termlink" <<EOF
#!/bin/bash
case "\$1" in
    spawn) : ;;
    pty) [ "\$2" = inject ] && { setsid bash -c "\$4" > "$T/inject.out" 2>&1 < /dev/null 3>&- 4>&- & } ;;
    --version) echo "termlink stub" ;;
esac
exit 0
EOF
    chmod +x "$STUB/termlink"
}

spawn_path() {
    env -i PATH="$1" HOME="$H" bash -c '. "$1"; fw_spawn_path' _ "$ROOT/lib/spawn-env.sh"
}

wait_for_file() { local i; for i in $(seq 1 150); do [ -s "$1" ] && return 0; sleep 0.2; done; return 1; }

@test "T-4775: caller PATH resolves an npm claude, no ~/.local/bin — the spawn PATH resolves the native claude" {
    run spawn_path "$STUB:$NPM/bin:/usr/bin:/bin"
    [ "$status" -eq 0 ]
    echo "PATH=$output"
    [ "$(PATH="$output" command -v claude)" = "$H/.local/bin/claude" ]
    # The npm dir is not dropped (other tools may live there), only ranked after the native one.
    case ":$output:" in *":$NPM/bin:"*) : ;; *) echo "npm dir dropped"; false ;; esac
    [ "${output%%:*}" = "$ROOT/bin" ]
}

@test "T-4775: a caller-chosen claude that is not an npm install still wins (stubs, pinned builds)" {
    printf '#!/bin/sh\necho stub\n' > "$STUB/claude"; chmod +x "$STUB/claude"
    run spawn_path "$STUB:$NPM/bin:/usr/bin:/bin"
    [ "$status" -eq 0 ]
    [ "$(PATH="$output" command -v claude)" = "$STUB/claude" ]
}

@test "T-4775: an npm claude with no native install stays reachable" {
    rm "$H/.local/bin/claude"
    run spawn_path "$NPM/bin:/usr/bin:/bin"
    [ "$status" -eq 0 ]
    [ "$(PATH="$output" command -v claude)" = "$NPM/bin/claude" ]
}

@test "T-4775: a dispatch from such a caller runs the native claude and logs which binary ran" {
    run env -i PATH="$STUB:$NPM/bin:/usr/bin:/bin" HOME="$H" FW_DISPATCH_DIR="$DD" FW_AGENT_SCOPE=0 \
        timeout 120 bash "$TL" dispatch --task T-4775 --name t4775-w --project "$P" --prompt "noop"
    echo "$output"
    [ "$status" -eq 0 ]
    wait_for_file "$T/ran" || { cat "$T/inject.out" "$DD/t4775-w/stderr.log" 2>/dev/null; false; }
    [ "$(cat "$T/ran")" = native ]
    wait_for_file "$DD/t4775-w/exit_code" || true
    cat "$DD/t4775-w/stderr.log"
    grep -qF "worker binary: $H/.local/bin/claude (2.1.310 (Claude Code))" "$DD/t4775-w/stderr.log"
}
