#!/usr/bin/env bats
# T-4647 (SEV-1 T-4635, G-116 close condition) — a dispatch's child environment is built from an
# ALLOW-LIST. Before: cmd_spawn ran `env -u PROJECT_ROOT -u … termlink spawn` (a deny-list), and
# run.sh ran with whatever the session shell carried, so a dispatcher (or tmux server) exporting
# another project's CONTEXT_DIR/TASKS_DIR, or any FW_*, seeded every worker.
#
# Sandbox only: termlink is a stub. `spawn` records the environment it was started with (what a
# tmux server it starts would keep as its global env); `pty inject` runs the injected command in
# a background shell that carries the dispatcher's FULL polluted environment — the worst case of a
# polluted tmux server. claude is a stub that copies its own /proc/<pid>/environ.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TL="$ROOT/agents/termlink/termlink.sh"
    T="$BATS_TEST_TMPDIR"
    STUB="$T/stub"; P="$T/proj"; DD="$T/dispatch"
    mkdir -p "$STUB" "$P" "$DD"
    cat > "$STUB/termlink" <<EOF
#!/bin/bash
case "\$1" in
    spawn) env > "$T/spawn.env" ;;
    pty) [ "\$2" = inject ] && { setsid bash -c "\$4" > "$T/inject.out" 2>&1 < /dev/null 3>&- 4>&- & } ;;
    --version) echo "termlink stub" ;;
esac
exit 0
EOF
    cat > "$STUB/claude" <<EOF
#!/bin/bash
tr '\0' '\n' < /proc/\$\$/environ > "$T/worker.env"
echo '{"type":"result","result":"done"}'
EOF
    chmod +x "$STUB/termlink" "$STUB/claude"
}

FOREIGN='^(PROJECT_ROOT=/opt/foreign|FRAMEWORK_ROOT=/opt/foreign|CONTEXT_DIR=|TASKS_DIR=|FW_FOO=|_FW_PATHS_DERIVED_BY=|FW_ROUTED_FROM=)'

wait_for_file() { local i; for i in $(seq 1 150); do [ -s "$1" ] && return 0; sleep 0.2; done; return 1; }

@test "T-4647: a dispatch from a polluted shell — spawn env and worker /proc environ hold no foreign path and no FW_FOO" {
    run env PATH="$STUB:$PATH" FW_DISPATCH_DIR="$DD" \
        PROJECT_ROOT=/opt/foreign FRAMEWORK_ROOT=/opt/foreign/.agentic-framework \
        CONTEXT_DIR=/opt/foreign/.context TASKS_DIR=/opt/foreign/.tasks FW_FOO=leak \
        _FW_PATHS_DERIVED_BY=test FW_ROUTED_FROM=/opt/foreign FW_AGENT_SCOPE=0 \
        timeout 120 bash "$TL" dispatch --task T-4647 --name t4647-w --project "$P" --prompt "noop"
    echo "$output"
    [ "$status" -eq 0 ]
    [ -s "$T/spawn.env" ]
    if grep -E "$FOREIGN" "$T/spawn.env"; then echo "leaked into spawn env"; false; fi
    wait_for_file "$T/worker.env" || { cat "$T/inject.out" "$DD/t4647-w/stderr.log" 2>/dev/null; false; }
    if grep -E "$FOREIGN" "$T/worker.env"; then echo "leaked into worker environ"; false; fi
    # The worker's paths are its own --project, never inherited.
    grep -qx "PROJECT_ROOT=$P" "$T/worker.env"
    # And the worker still has what it needs (allow-listed host variables, its own FW_ vars).
    grep -q '^PATH=' "$T/worker.env"
    grep -q '^HOME=' "$T/worker.env"
    grep -qx 'FW_DISPATCHED_WORKER=1' "$T/worker.env"
}

@test "T-4647: run.sh carries exactly lib/spawn-env.sh's allow-list" {
    lib=$(sed -n "s/^FW_SPAWN_ENV_ALLOW='\(.*\)'$/\1/p" "$ROOT/lib/spawn-env.sh")
    rt=$(sed -n "s/^    FW_SPAWN_ENV_ALLOW='\(.*\)'$/\1/p" "$TL")
    [ -n "$lib" ]
    [ "$lib" = "$rt" ]
}

@test "T-4647: cmd_spawn starts termlink spawn under env -i, not a deny-list" {
    grep -q 'env -i "\${FW_SPAWN_ENV\[@\]}"' "$TL"
    ! grep -qE '^ *env -u PROJECT_ROOT .*termlink spawn|^ *env -u PROJECT_ROOT -u FRAMEWORK_ROOT .*\\$' "$TL" || false
}

@test "T-4647: fw_spawn_env keeps allow-listed names and drops everything else" {
    run env -i PATH=/usr/bin:/bin HOME=/root LC_ALL=C TERMLINK_RUNTIME_DIR=/x \
        CONTEXT_DIR=/f/.context TASKS_DIR=/f/.tasks FW_FOO=1 GIT_DIR=/g PYTHONPATH=/p \
        bash -c '. "$1"; fw_spawn_env; printf "%s\n" "${FW_SPAWN_ENV[@]}"' _ "$ROOT/lib/spawn-env.sh"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx 'HOME=/root'
    echo "$output" | grep -qx 'LC_ALL=C'
    echo "$output" | grep -qx 'TERMLINK_RUNTIME_DIR=/x'
    ! echo "$output" | grep -qE '^(CONTEXT_DIR|TASKS_DIR|FW_FOO|GIT_DIR|PYTHONPATH)=' || false
}

# T-4665: TermLink variables are allow-listed by exact name. The old TERMLINK_[A-Z0-9_]+ prefix
# handed a worker the spawning agent's sidecar socket and agent id (read its mail, sign as it).
@test "T-4665: fw_spawn_env drops TermLink identity/socket canaries, keeps the named hub settings" {
    run env -i PATH=/usr/bin:/bin HOME=/root \
        TERMLINK_RUNTIME_DIR=/rt TERMLINK_RUNTIME_DIR_FALLBACK=/fb TERMLINK_BIN=/b/termlink \
        TERMLINK_SIDECAR_SOCKET=/s.sock TERMLINK_SIDECAR_STATUS_SOCKET=/st.sock \
        TERMLINK_AGENT_ID=parent TERMLINK_IDENTITY_FILE=/id TERMLINK_SESSION_ID=tl-parent \
        TERMLINK_SESSION=parent TERMLINK_ZZ_CANARY=1 \
        bash -c '. "$1"; fw_spawn_env; printf "%s\n" "${FW_SPAWN_ENV[@]}"' _ "$ROOT/lib/spawn-env.sh"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx 'TERMLINK_RUNTIME_DIR=/rt'
    echo "$output" | grep -qx 'TERMLINK_RUNTIME_DIR_FALLBACK=/fb'
    echo "$output" | grep -qx 'TERMLINK_BIN=/b/termlink'
    ! echo "$output" | grep -qE '^TERMLINK_(SIDECAR_SOCKET|SIDECAR_STATUS_SOCKET|AGENT_ID|IDENTITY_FILE|SESSION_ID|SESSION|ZZ_CANARY)=' || false
}

@test "T-4665: no TERMLINK_ prefix pattern in either allow-list copy" {
    ! grep -n 'TERMLINK_\[A-Z0-9_\]+' "$ROOT/lib/spawn-env.sh" "$TL" || false
}

# T-4666: PATH is built, never copied. A caller PATH with another project's .agentic-framework/bin
# (or any other foreign bin) first made the worker run that project's fw.
_foreign_bins() {
    mkdir -p "$T/other/.agentic-framework/bin" "$T/junk/bin"
    printf '#!/bin/sh\necho foreign\n' > "$T/other/.agentic-framework/bin/fw"
    cp "$T/other/.agentic-framework/bin/fw" "$T/junk/bin/fw"
    chmod +x "$T/other/.agentic-framework/bin/fw" "$T/junk/bin/fw"
}

@test "T-4666: fw_spawn_env builds PATH — foreign bins dropped, this framework's fw first, tools still found" {
    _foreign_bins
    run env -i PATH="$T/other/.agentic-framework/bin:$T/junk/bin:$STUB:/usr/local/bin:/usr/bin:/bin" HOME="$HOME" \
        bash -c '. "$1"; fw_spawn_env; printf "%s\n" "${FW_SPAWN_ENV[@]}"' _ "$ROOT/lib/spawn-env.sh"
    [ "$status" -eq 0 ]
    p=$(echo "$output" | sed -n 's/^PATH=//p')
    echo "PATH=$p"
    [ "$(echo "$output" | grep -c '^PATH=')" -eq 1 ]
    case ":$p:" in *":$T/other/"*|*":$T/junk/bin:"*) echo "foreign bin kept"; false ;; esac
    [ "${p%%:*}" = "$ROOT/bin" ]
    [ "$(PATH="$p" command -v fw)" = "$ROOT/bin/fw" ]
    # The resolved claude/termlink stay reachable (their dir is added), and so do the host tools.
    [ "$(PATH="$p" command -v claude)" = "$STUB/claude" ]
    [ "$(PATH="$p" command -v termlink)" = "$STUB/termlink" ]
    for b in git python3 bash; do PATH="$p" command -v "$b" >/dev/null || { echo "no $b"; false; }; done
}

@test "T-4666: a dispatch with a foreign fw first on PATH — the worker resolves its own project's fw" {
    _foreign_bins
    C="$T/consumer"; mkdir -p "$C"; ln -s "$ROOT" "$C/.agentic-framework"
    cat > "$STUB/claude" <<EOS
#!/bin/bash
tr '\0' '\n' < /proc/\$\$/environ > "$T/worker.env"
for b in fw termlink git python3 bats; do printf '%s=%s\n' "\$b" "\$(command -v \$b)"; done > "$T/worker.which"
echo '{"type":"result","result":"done"}'
EOS
    chmod +x "$STUB/claude"
    run env PATH="$T/other/.agentic-framework/bin:$T/junk/bin:$STUB:$PATH" FW_DISPATCH_DIR="$DD" \
        timeout 120 bash "$TL" dispatch --task T-4666 --name t4666-w --project "$C" --prompt "noop"
    echo "$output"
    [ "$status" -eq 0 ]
    wait_for_file "$T/worker.which" || { cat "$T/inject.out" "$DD/t4666-w/stderr.log" 2>/dev/null; false; }
    cat "$T/worker.which"
    ! grep -E "^PATH=.*$T/(other|junk)/" "$T/worker.env" "$T/spawn.env" || false
    grep -qx "fw=$C/.agentic-framework/bin/fw" "$T/worker.which"
    grep -qx "termlink=$STUB/termlink" "$T/worker.which"
    grep -qE '^git=/' "$T/worker.which"
    grep -qE '^python3=/' "$T/worker.which"
    if command -v bats >/dev/null; then grep -qE '^bats=/' "$T/worker.which"; fi
}
