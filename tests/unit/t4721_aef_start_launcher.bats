#!/usr/bin/env bats
# T-4721 — the P-01 one-click launcher (install/launcher/aef-start.sh) continues the
# project's last conversation by default (055, 'greenfield': after a restart the
# icon opened a NEW conversation and the operator could not get back into his
# work), and `--new` opens a fresh one.
#
# The fallback is pinned leg by leg, because 055's `claude-fw -c || claude-fw`
# had two silent defects: it treated claude-fw's T-3890 refusal (exit 3, the
# conversation is live elsewhere) as "start a fresh one", and it started another
# session whenever a real continued session ended non-zero.
#
# A stub claude-fw / claude on PATH logs its arguments; the project dir has no
# fw, so Watchtower is skipped, and AEF_START_NO_SHELL=1 stops the final shell.

LAUNCHER="$BATS_TEST_DIRNAME/../../install/launcher/aef-start.sh"

setup() {
    T="$(mktemp -d)"
    mkdir -p "$T/bin" "$T/sys" "$T/proj"
    # A hermetic PATH: the host may have a real claude-fw in /usr/bin.
    local t
    for t in env bash date sed cat wc setsid sleep; do
        ln -s "$(command -v "$t")" "$T/sys/$t"
    done
    LOG="$T/calls.log"
    : > "$LOG"
}

teardown() {
    rm -rf "$T"
}

# stub <name> — a fake runner: logs "<name> <args>"; with -c it exits $STUB_RC_C
# (default 0), otherwise 0.
stub() {
    cat > "$T/bin/$1" <<EOF
#!/usr/bin/env bash
echo "$1 \$*" >> "$LOG"
case " \$* " in *" -c "*) exit "\${STUB_RC_C:-0}" ;; esac
exit 0
EOF
    chmod +x "$T/bin/$1"
}

launch() {
    PATH="$T/bin:$T/sys" AEF_START_NO_SHELL=1 run bash "$LAUNCHER" "$@" "$T/proj"
}

@test "T-4721: default continues the last conversation (claude-fw -c), once" {
    stub claude-fw
    launch
    [ "$status" -eq 0 ]
    [ "$(cat "$LOG")" = "claude-fw -c" ]
}

@test "T-4721: --new starts a fresh conversation (no -c)" {
    stub claude-fw
    launch --new
    [ "$status" -eq 0 ]
    [ "$(cat "$LOG")" = "claude-fw " ]
}

@test "T-4721: a -c that fails fast falls back to a fresh start" {
    stub claude-fw
    STUB_RC_C=1 launch
    [ "$status" -eq 0 ]
    [ "$(sed -n 1p "$LOG")" = "claude-fw -c" ]
    [ "$(sed -n 2p "$LOG")" = "claude-fw " ]
    [ "$(wc -l < "$LOG")" -eq 2 ]
}

@test "T-4721: exit 3 (T-3890 refusal: conversation live elsewhere) does NOT open a fresh one" {
    stub claude-fw
    STUB_RC_C=3 launch
    [ "$status" -eq 0 ]
    [ "$(cat "$LOG")" = "claude-fw -c" ]
    [[ "$output" == *"already live elsewhere"* ]]
    [[ "$output" == *"--new"* ]]
}

@test "T-4721: a continued session that ran and then exited non-zero is not followed by a second one" {
    stub claude-fw
    STUB_RC_C=1 AEF_START_FALLBACK_SECS=0 launch
    [ "$status" -eq 0 ]
    [ "$(cat "$LOG")" = "claude-fw -c" ]
}

@test "T-4721: without claude-fw on PATH it falls back to claude (and still continues)" {
    [ ! -e "$T/sys/claude-fw" ]
    stub claude
    STUB_RC_C=1 launch
    [ "$status" -eq 0 ]
    [ "$(sed -n 1p "$LOG")" = "claude -c" ]
    [ "$(sed -n 2p "$LOG")" = "claude " ]
}

@test "T-4721: exit 3 from plain claude is not treated as a claude-fw refusal" {
    stub claude
    STUB_RC_C=3 launch
    [ "$(sed -n 1p "$LOG")" = "claude -c" ]
    [ "$(sed -n 2p "$LOG")" = "claude " ]
}

@test "T-4721: runs in the project dir and rejects unknown options" {
    cat > "$T/bin/claude-fw" <<EOF
#!/usr/bin/env bash
pwd >> "$LOG"
EOF
    chmod +x "$T/bin/claude-fw"
    launch
    [ "$(cat "$LOG")" = "$T/proj" ]
    PATH="$T/bin:$T/sys" AEF_START_NO_SHELL=1 run bash "$LAUNCHER" --bogus
    [ "$status" -eq 2 ]
}

