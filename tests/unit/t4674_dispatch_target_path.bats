#!/usr/bin/env bats
# T-4674 (TermLink be.4 field report) — T-4666's constructed PATH (lib/spawn-env.sh
# fw_spawn_path) starts with the CALLER's fw bin. For `fw termlink dispatch --project <other>`
# the worker must run the TARGET project's fw: run.sh re-derives the bin from its PROJECT_DIR
# ($2) before it re-execs under env -i. Two-project fixture: consumer A (the caller, running its
# own vendored termlink.sh) dispatches into B (consumer), F (framework-repo shaped) or a bare dir.
#
# Sandbox only: termlink is a stub (`spawn` records its env, `pty inject` runs the command in a
# background shell); claude is a stub that records its environ and which fw it resolves.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$BATS_TEST_TMPDIR"
    STUB="$T/stub"; DD="$T/dispatch"
    A="$T/caller"; B="$T/target"
    mkdir -p "$STUB" "$DD" "$A" "$B"
    ln -s "$ROOT" "$A/.agentic-framework"
    ln -s "$ROOT" "$B/.agentic-framework"
    TL="$A/.agentic-framework/agents/termlink/termlink.sh"
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
printf 'fw=%s\n' "\$(command -v fw)" > "$T/worker.which"
echo '{"type":"result","result":"done"}'
EOF
    chmod +x "$STUB/termlink" "$STUB/claude"
}

wait_for_file() { local i; for i in $(seq 1 150); do [ -s "$1" ] && return 0; sleep 0.2; done; return 1; }

dispatch_into() {  # <target project> <name>
    run bash -c "cd '$A' && env PATH='$STUB:$PATH' PROJECT_ROOT='$A' FW_DISPATCH_DIR='$DD' FW_AGENT_SCOPE=0 \
        timeout 120 bash '$TL' dispatch --task T-4674 --name '$2' --project '$1' --prompt noop </dev/null"
    echo "$output"
    [ "$status" -eq 0 ]
    wait_for_file "$T/worker.which" || { cat "$T/inject.out" "$DD/$2/stderr.log" 2>/dev/null; false; }
    WPATH=$(sed -n 's/^PATH=//p' "$T/worker.env")
    echo "worker PATH=$WPATH"; cat "$T/worker.which"
}

@test "T-4674: the spawn session's PATH starts with the CALLER's bin (what the field report saw)" {
    dispatch_into "$B" t4674-spawn
    sp=$(sed -n 's/^PATH=//p' "$T/spawn.env")
    [ "${sp%%:*}" = "$A/.agentic-framework/bin" ]
}

@test "T-4674: consumer -> consumer: the worker's PATH starts with the TARGET's bin, none of the caller's" {
    dispatch_into "$B" t4674-cc
    [ "${WPATH%%:*}" = "$B/.agentic-framework/bin" ]
    case ":$WPATH:" in *":$A/"*) echo "caller bin leaked into worker PATH"; false ;; esac
    grep -qx "fw=$B/.agentic-framework/bin/fw" "$T/worker.which"
    grep -qx "PROJECT_ROOT=$B" "$T/worker.env"
}

@test "T-4674: consumer -> framework repo: the worker runs the target's bin/fw" {
    F="$T/fwrepo"; mkdir -p "$F/bin"
    : > "$F/FRAMEWORK.md"
    printf '#!/bin/sh\necho target-fw\n' > "$F/bin/fw"; chmod +x "$F/bin/fw"
    dispatch_into "$F" t4674-cf
    [ "${WPATH%%:*}" = "$F/bin" ]
    case ":$WPATH:" in *":$A/"*) echo "caller bin leaked into worker PATH"; false ;; esac
    grep -qx "fw=$F/bin/fw" "$T/worker.which"
}

@test "T-4674: bare target (no framework wiring): the dispatching framework's fw is the fallback" {
    N="$T/bare"; mkdir -p "$N"
    dispatch_into "$N" t4674-cb
    [ "${WPATH%%:*}" = "$A/.agentic-framework/bin" ]
    grep -qx "fw=$A/.agentic-framework/bin/fw" "$T/worker.which"
}
