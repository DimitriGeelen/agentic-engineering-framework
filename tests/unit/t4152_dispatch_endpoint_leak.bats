#!/usr/bin/env bats
# T-4152 — `fw termlink dispatch` typed `bash run.sh …` into a persistent interactive shell,
# so the shell outlived run.sh at its prompt and the TermLink session stayed 'ready' forever
# (106 here, 43 on ring20). The fix injects `exec bash run.sh …`; cleanup stops endpoints a
# finished worker left behind. Sandbox only: the "session" is a bash reading a FIFO (what a
# PTY shell is to `pty inject`), DISPATCH_DIR is under BATS_TEST_TMPDIR, and termlink is a stub.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TL="$ROOT/agents/termlink/termlink.sh"
    T="$BATS_TEST_TMPDIR"
    STUB="$T/stub"; mkdir -p "$STUB"
    printf '#!/bin/sh\necho "{\\"type\\":\\"result\\",\\"result\\":\\"done\\"}"\n' > "$STUB/claude"
    printf '#!/bin/sh\nexit 0\n' > "$STUB/termlink"
    chmod +x "$STUB/claude" "$STUB/termlink"
    SH=""
}

teardown() {
    [ -z "$SH" ] || kill -9 "$SH" 2>/dev/null || true
    [ -z "${STUCK:-}" ] || kill -9 "$STUCK" 2>/dev/null || true
}

# The run.sh cmd_dispatch writes, extracted verbatim from termlink.sh.
write_run_sh() {
    awk '/cat > "\$wdir\/run.sh" <<'"'"'RUNEOF'"'"'/{f=1;next} /^RUNEOF$/{f=0} f' "$TL" > "$1/run.sh"
    [ -s "$1/run.sh" ]
}

# The exact command string cmd_dispatch injects, with its variables bound.
inject_cmd() {  # name wdir project_dir task_type
    local name="$1" wdir="$2" project_dir="$3" task_type="$4" timeout=20 model="" fw_bin="" tmpl
    tmpl=$(sed -n 's/^ *termlink pty inject "\$name" "\(.*\)" --enter.*/\1/p' "$TL")
    [ -n "$tmpl" ]
    eval "printf '%s\n' \"$tmpl\""
}

# Start a "session shell" reading commands from a FIFO; type <cmd> into it.
start_session_and_type() {  # cmd
    mkfifo "$T/pty"
    exec 9<>"$T/pty"
    PATH="$STUB:$PATH" bash -s < "$T/pty" > "$T/shell.out" 2>&1 &
    SH=$!
    printf '%s\n' "$1" >&9
}

wait_for_file() { local i; for i in $(seq 1 100); do [ -e "$1" ] && return 0; sleep 0.2; done; return 1; }
wait_dead() { local i; for i in $(seq 1 50); do kill -0 "$1" 2>/dev/null || return 0; sleep 0.2; done; return 1; }

@test "cmd_dispatch injects run.sh with exec (the shell ends with the worker)" {
    run grep -cE '^ *termlink pty inject "\$name" "exec bash \$wdir/run.sh ' "$TL"
    [ "$output" = "1" ]
    # and no non-exec injection of run.sh remains
    run grep -cE 'pty inject "\$name" "bash \$wdir/run.sh' "$TL"
    [ "$output" = "0" ]
}

@test "a dispatched build worker's session ends when run.sh finishes" {
    W="$T/dispatch/w-build"; P="$T/proj"; mkdir -p "$W" "$P"
    write_run_sh "$W"
    echo "say done" > "$W/prompt.md"
    start_session_and_type "$(inject_cmd w-build "$W" "$P" build)"
    wait_for_file "$W/exit_code"
    wait_dead "$SH"
    [ "$(cat "$W/exit_code")" = "0" ]
    [ -s "$W/result.md" ]
    [ -f "$W/close_state" ]   # run.sh ran to its end, not cut short
}

@test "control: typed WITHOUT exec, the shell outlives run.sh (the leak)" {
    W="$T/dispatch/w-leak"; P="$T/proj"; mkdir -p "$W" "$P"
    write_run_sh "$W"
    echo "say done" > "$W/prompt.md"
    cmd=$(inject_cmd w-leak "$W" "$P" build)
    start_session_and_type "${cmd#exec }"
    wait_for_file "$W/close_state"
    sleep 1
    kill -0 "$SH"
}

@test "a review worker's session ends only after run.sh has finalised it" {
    W="$T/dispatch/w-review"; P="$T/proj"; mkdir -p "$W" "$P"
    write_run_sh "$W"
    echo "review" > "$W/prompt.md"
    : > "$W/finalise_required"
    start_session_and_type "$(inject_cmd w-review "$W" "$P" review)"
    wait_dead "$SH"
    # the session is gone; the finalisation it must not outrun is already on disk
    [ -f "$W/exit_code" ]
    run head -1 "$W/finalised"
    [[ "$output" == unsigned:* || "$output" == signed:* ]]
}

@test "run.sh writes exit_code and finalised before any exit after the worker launches" {
    awk '/cat > "\$wdir\/run.sh" <<'"'"'RUNEOF'"'"'/{f=1;next} /^RUNEOF$/{f=0} f' "$TL" > "$T/run.sh"
    fin=$(grep -n '> "\$WDIR/finalised"' "$T/run.sh" | head -1 | cut -d: -f1)
    [ -n "$fin" ]
    # every exit after the launch section (past line 20, the cd guard) comes after finalised
    run awk -v fin="$fin" 'NR>20 && /^[[:space:]]*exit[[:space:]]+[0-9]/ && NR<fin {print NR": "$0}' "$T/run.sh"
    [ -z "$output" ]
    # record-outcome cannot block on the session PTY
    grep -q '< /dev/null >/dev/null 2>&1 || true' "$T/run.sh"
}

# ---- cleanup of leaked endpoints ----

cleanup_fixture() {
    D="$T/dispatch"; mkdir -p "$D"
    mk() {  # name kind...
        local n="$1"; shift; mkdir -p "$D/$n"
        # T-4558: cleanup acts only on this project's workers (meta.json "project").
        printf '{\n  "name": "%s",\n  "project": "%s",\n  "timeout": 60\n}\n' "$n" "$T/proj" > "$D/$n/meta.json"
        for k in "$@"; do
            case "$k" in
                run) : > "$D/$n/run.sh" ;;
                done) echo 0 > "$D/$n/exit_code"; date > "$D/$n/collected" ;;
                review) : > "$D/$n/finalise_required" ;;
            esac
        done
    }
    mk w-done run done
    mk w-running run
    mk w-review-unfinal run done review
    mk w-norun done                 # a plain `fw termlink spawn` session: no run.sh
    mk w-stuck run done             # exit_code written, run.sh still running
    mk w-dup run done
    mk claude-master-77 run done
    mk fleet-x run done
    cat > "$T/list.json" <<'J'
{"ok":true,"sessions":[
 {"id":"tl-done","display_name":"w-done"},
 {"id":"tl-running","display_name":"w-running"},
 {"id":"tl-revu","display_name":"w-review-unfinal"},
 {"id":"tl-norun","display_name":"w-norun"},
 {"id":"tl-stuck","display_name":"w-stuck"},
 {"id":"tl-dup1","display_name":"w-dup"},
 {"id":"tl-dup2","display_name":"w-dup"},
 {"id":"tl-cm","display_name":"claude-master-77"},
 {"id":"tl-fleet","display_name":"fleet-x"}]}
J
    cat > "$STUB/termlink" <<EOF
#!/bin/sh
case "\$1" in
  list) cat "$T/list.json" ;;
  signal) echo "\$*" >> "$T/signals.log" ;;
esac
exit 0
EOF
    chmod +x "$STUB/termlink"
    bash -c 'exec -a "bash '"$D"'/w-stuck/run.sh" sleep 60' &
    STUCK=$!
    export FW_DISPATCH_DIR="$D"
    export PROJECT_ROOT="$T/proj"; mkdir -p "$PROJECT_ROOT"
}

@test "cleanup --dry-run lists only the finished dispatch worker's leaked endpoint, signals nothing" {
    cleanup_fixture
    run env PATH="$STUB:$PATH" bash "$TL" cleanup --dry-run < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"stop endpoint w-done (tl-done)"* ]]
    [[ "$output" == *"stop 1 leaked endpoint(s)"* ]]
    for n in w-running w-review-unfinal w-norun w-stuck w-dup claude-master-77 fleet-x; do
        if [[ "$output" == *"stop endpoint $n "* ]]; then echo "wrongly planned: $n"; false; fi
    done
    [ ! -e "$T/signals.log" ]
    [ -d "$D/w-done" ]
}

@test "cleanup without consent and no tty refuses and signals nothing" {
    cleanup_fixture
    run env PATH="$STUB:$PATH" bash "$TL" cleanup < /dev/null
    [ "$status" -eq 3 ]
    [ ! -e "$T/signals.log" ]
}

@test "cleanup --yes HUPs exactly the finished worker's endpoint and keeps running ones" {
    cleanup_fixture
    run env PATH="$STUB:$PATH" bash "$TL" cleanup --yes < /dev/null
    [ "$status" -eq 0 ]
    run cat "$T/signals.log"
    [ "$output" = "signal tl-done HUP" ]
    [ -d "$D/w-running" ]
    [ -d "$D/w-review-unfinal" ]
}
