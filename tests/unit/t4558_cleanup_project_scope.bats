#!/usr/bin/env bats
# T-4558 — `fw termlink cleanup`:
#   (a) acts only on dispatch dirs whose meta.json "project" is this project — /tmp/tl-dispatch
#       is shared by every project on the host;
#   (b) treats a live worker of EVERY kind dispatch accepts (DISPATCH_WORKER_KINDS) as active,
#       not only claude / ollama-loop;
#   (c) never removes an uncollected result, but still stops that finished worker's endpoint.
# Sandbox only: FW_DISPATCH_DIR is under BATS_TEST_TMPDIR, termlink is a stub, and the only
# processes signalled are the fakes these tests spawn (killed in teardown).

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TL="$ROOT/agents/termlink/termlink.sh"
    T="$BATS_TEST_TMPDIR"
    D="$T/dispatch"; P="$T/proj-here"; Q="$T/proj-other"
    mkdir -p "$D" "$P" "$Q"
    STUB="$T/stub"; mkdir -p "$STUB"
    echo '{"ok":true,"sessions":[]}' > "$T/list.json"
    cat > "$STUB/termlink" <<EOF
#!/bin/sh
case "\$1" in
  list) cat "$T/list.json" ;;
  signal) echo "\$*" >> "$T/signals.log" ;;
esac
exit 0
EOF
    chmod +x "$STUB/termlink"
    PIDS_FILE="$T/pids"; : > "$PIDS_FILE"
}

teardown() {
    local pid
    while read -r pid; do
        [ -n "$pid" ] || continue
        pkill -KILL -P "$pid" 2>/dev/null || true
        kill -KILL "$pid" 2>/dev/null || true
    done < "$PIDS_FILE"
}

mk_worker() {  # name project [finished] [collected] [run]
    local n="$1" proj="$2"; shift 2
    mkdir -p "$D/$n"
    printf '{\n  "name": "%s",\n  "project": "%s",\n  "timeout": 60\n}\n' "$n" "$proj" > "$D/$n/meta.json"
    local k
    for k in "$@"; do
        case "$k" in
            finished) echo 0 > "$D/$n/exit_code"; echo "result text" > "$D/$n/result.md" ;;
            collected) date > "$D/$n/collected" ;;
            run) : > "$D/$n/run.sh" ;;
        esac
    done
}

cl() {  # args...
    run env PATH="$STUB:$PATH" FW_DISPATCH_DIR="$D" PROJECT_ROOT="$P" bash "$TL" cleanup "$@" < /dev/null
}

# A live worker of a given argv: a parent whose args hold <wdir>/run.sh (like run.sh) spawning
# a child whose argv[0..] is the worker's command line (args do not hold <wdir>).
spawn_live() {  # name argv-string
    local w="$D/$1"
    python3 -c 'import subprocess,sys; subprocess.run(["bash","-c","exec -a \"$0\" sleep 300", sys.argv[1]])' "$2" "$w/run.sh" &
    echo $! >> "$PIDS_FILE"
    local i
    for i in $(seq 1 50); do
        [ -n "$(ps --ppid "$!" -o pid= 2>/dev/null)" ] && return 0
        sleep 0.1
    done
    return 1
}

# The command line each worker kind actually runs as (agents/termlink/termlink.sh run.sh,
# policy/review-backends.yaml binaries). A kind not listed here is spawned under its own name.
kind_argv() {
    case "$1" in
        claude)       echo "claude -p --output-format json" ;;
        ollama-loop)  echo "python3 /opt/fw/tools/ollama-tool-loop.py --prompt-file x" ;;
        codex)        echo "/root/.nvm/versions/node/v22/bin/codex exec -s workspace-write --json" ;;
        opencode)     echo "/root/.opencode/bin/opencode run --agent plan --pure --format json" ;;
        antigravity)  echo "/usr/bin/sudo -n -u someone -H /home/someone/.local/bin/agy -p review --mode plan" ;;
        *)            echo "$1" ;;
    esac
}

# ---- (a) project scope ----

@test "(a) another project's finished worker: dir kept, endpoint not signalled" {
    mk_worker mine "$P" finished collected run
    mk_worker theirs "$Q" finished collected run
    echo '{"ok":true,"sessions":[{"id":"tl-mine","display_name":"mine"},{"id":"tl-theirs","display_name":"theirs"}]}' > "$T/list.json"
    cl --yes
    [ "$status" -eq 0 ]
    [ ! -e "$D/mine" ]
    [ -f "$D/theirs/result.md" ]
    [ -f "$D/theirs/meta.json" ]
    run cat "$T/signals.log"
    [ "$output" = "signal tl-mine HUP" ]
}

@test "(a) another project's orphan is neither planned nor signalled" {
    mk_worker stray "$Q"
    python3 -c 'import time; time.sleep(300)' "$D/stray/run.sh" &
    local pid=$!; echo "$pid" >> "$PIDS_FILE"; sleep 0.3
    cl --dry-run
    [ "$status" -eq 0 ]
    if [[ "$output" == *"stray"* ]]; then echo "other project's worker planned: $output"; false; fi
    [[ "$output" == *"1 other project(s)' worker dir(s) not touched"* ]]
    cl --yes
    kill -0 "$pid"
    [ -d "$D/stray" ]
}

@test "(a) a dir with no meta.json is not this project's and is left alone" {
    mkdir -p "$D/legacy"; echo 0 > "$D/legacy/exit_code"
    cl --yes
    [ "$status" -eq 0 ]
    [ -d "$D/legacy" ]
}

# ---- (b) every worker kind is live ----

@test "(b) a live worker of every kind in 'fw termlink worker-kinds' is ACTIVE, not orphaned" {
    run bash "$TL" worker-kinds
    [ "$status" -eq 0 ]
    local kinds="$output" k n=0
    [[ "$kinds" == *codex* && "$kinds" == *opencode* && "$kinds" == *antigravity* ]]
    for k in $kinds; do
        mk_worker "live-$k" "$P"
        spawn_live "live-$k" "$(kind_argv "$k")"
        n=$((n + 1))
    done
    cl --yes
    [ "$status" -eq 0 ]
    for k in $kinds; do
        [[ "$output" == *"ACTIVE"*"live-$k"* ]] || { echo "kind $k not ACTIVE: $output"; false; }
        [ -d "$D/live-$k" ]
    done
    if [[ "$output" == *ORPHAN* ]]; then echo "$output"; false; fi
    [ "$n" -ge 5 ]
}

@test "(b) the live regex is derived from DISPATCH_WORKER_KINDS, not a literal" {
    ! grep -q "active_re='claude|ollama-tool-loop'" "$TL" || false
    run bash -c "source '$TL' >/dev/null 2>&1; DISPATCH_WORKER_KINDS='claude newkind'; _active_worker_re"
    [ "$output" = "claude|newkind" ]
}

@test "(b) control: the pre-fix literal regex misses codex, opencode and antigravity" {
    local k
    for k in codex opencode antigravity; do
        ! echo "$(kind_argv "$k")" | grep -qE 'claude|ollama-tool-loop' || false
        run bash -c "source '$TL' >/dev/null 2>&1; echo '$(kind_argv "$k")' | { re=\$(_active_worker_re); [ -n \"\$re\" ] && grep -qE \"\$re\"; }"
        [ "$status" -eq 0 ]
    done
}

# ---- (c) uncollected results ----

@test "(c) uncollected result survives --yes; its finished endpoint is still stopped" {
    mk_worker unread "$P" finished run
    mk_worker read "$P" finished collected run
    echo '{"ok":true,"sessions":[{"id":"tl-unread","display_name":"unread"},{"id":"tl-read","display_name":"read"}]}' > "$T/list.json"
    cl --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"KEPT"*"unread"*"uncollected result"* ]]
    [ -f "$D/unread/result.md" ]
    [ -f "$D/unread/exit_code" ]
    [ ! -e "$D/read" ]
    run sort "$T/signals.log"
    [ "$output" = "$(printf 'signal tl-read HUP\nsignal tl-unread HUP')" ]
}

@test "(c) once collected, the same worker is removed" {
    mk_worker w "$P" finished
    cl --yes
    [ -f "$D/w/result.md" ]
    date > "$D/w/collected"
    cl --yes
    [ "$status" -eq 0 ]
    [ ! -e "$D/w" ]
}
