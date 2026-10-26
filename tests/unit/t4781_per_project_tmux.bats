#!/usr/bin/env bats
# T-4781 (dimitri-mint-dev T-188/T-190): claude-fw wrapped every project on ONE tmux server
# (`-L fw-agents`), so a bare `tmux kill-server` from any project's pane killed every
# project's agent on the host, and the wrap's `set-option -g` changed every project's
# globals. Each project now gets its own server, `fw-agents-<16 hex of the fw-project tag>`.
#
# The wrap legs drive the real claude-fw on a pty with a fake tmux that records its argv
# (as t4003/t4426 do); no real tmux server is started. The doctor legs use a fake tmux and
# socket files in a private TMUX_TMPDIR.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CFW="${T4781_CFW:-$FRAMEWORK_ROOT/bin/claude-fw}"
    T="$(mktemp -d)"
    mkdir -p "$T/bin" "$T/p1/sub" "$T/p2"
    printf 'project_name: p1\n' > "$T/p1/.framework.yaml"
    printf 'project_name: p2\n' > "$T/p2/.framework.yaml"
    printf '#!/bin/bash\nprintf "%%s\\n" "$@" > "$T4781_ARGV"\n' > "$T/bin/tmux"
    chmod +x "$T/bin/tmux"
}

teardown() { rm -rf "$T"; }

# _wrap <dir> <argv file> — run claude-fw from <dir> on a pty; the fake tmux records its argv.
_wrap() {
    command -v script >/dev/null || skip "script(1) unavailable (needed for a pty)"
    env -u TMUX -u FW_CLAUDE_FW_IN_TMUX -u FW_DISPATCHED_WORKER -u TL_CLAUDE_ENABLED \
        -u PROJECT_ROOT -u FRAMEWORK_ROOT FW_AGENT_SCOPE=0 T4781_ARGV="$2" \
        PATH="$T/bin:$PATH" script -qec "cd '$1' && timeout 10 bash '$CFW' -c" /dev/null >/dev/null 2>&1 || true
    [ -s "$2" ]
}

_id() { printf '%s' "$(cd "$1" && pwd -P)" | sha256sum | cut -c1-16; }

@test "T-4781: two project roots get two tmux servers, each fw-agents-<project id>" {
    _wrap "$T/p1" "$T/a1"
    _wrap "$T/p2" "$T/a2"
    [ "$(sed -n 1p "$T/a1")" = "-L" ]
    [ "$(sed -n 2p "$T/a1")" = "fw-agents-$(_id "$T/p1")" ]
    [ "$(sed -n 2p "$T/a2")" = "fw-agents-$(_id "$T/p2")" ]
    [ "$(sed -n 2p "$T/a1")" != "$(sed -n 2p "$T/a2")" ]
}

@test "T-4781: the same project root always gets the same server (from a subdir too)" {
    _wrap "$T/p1" "$T/a1"
    _wrap "$T/p1/sub" "$T/a3"
    [ "$(sed -n 2p "$T/a1")" = "$(sed -n 2p "$T/a3")" ]
}

@test "T-4781: every tmux call of the wrap, globals and redraw hooks included, names the project's own server" {
    _wrap "$T/p1" "$T/a1"
    local own="fw-agents-$(_id "$T/p1")"
    # set-option -g / -s are present, and the chain runs on one server: the project's own.
    grep -qx -- "-g" "$T/a1"
    grep -qx -- "-s" "$T/a1"
    [ "$(grep -A1 -x -- '-L' "$T/a1" | grep -vx -- '-L' | grep -v '^--$' | sort -u)" = "$own" ]
    ! grep -qx "fw-agents" "$T/a1" || false
    # The three redraw hooks run tmux on the same server.
    [ "$(grep -c -- "-L $own send-keys -t #{pane_id} C-l" "$T/a1")" -eq 3 ]
    ! grep -q -- "-L fw-agents send-keys" "$T/a1" || false
}

@test "T-4781: discovery keeps the fw-<dir>-<pid> session name" {
    _wrap "$T/p1" "$T/a1"
    grep -qE '^fw-p1-[0-9]+$' "$T/a1"
}

@test "T-4781: the shell and python derive the same socket name" {
    local py
    py=$(cd "$FRAMEWORK_ROOT" && PROJECT_ROOT="$T/p1" python3 -c \
        'from lib.sidecar import inject; print(inject.tmux_socket())')
    [ "$py" = "fw-agents-$(_id "$T/p1")" ]
    eval "$(awk '/^_fw_project_tag\(\) \{/,/^}/' "$CFW")"
    eval "$(awk '/^_cfw_tmux_socket\(\) \{/,/^}/' "$CFW")"
    [ "$(cd "$T/p1/sub" && PROJECT_ROOT='' _cfw_tmux_socket)" = "$py" ]
}

# ── doctor ──────────────────────────────────────────────────────────────────────────

# _sock <path> — a real unix socket file (doctor only looks at sockets).
_sock() { python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' "$1"; }

_doctor() {
    export TMUX_TMPDIR="$T/tt"
    local d="$TMUX_TMPDIR/tmux-$(id -u)"
    mkdir -p "$d"
    _sock "$d/fw-agents"
    _sock "$d/fw-agents-0123456789abcdef"
    # Fake tmux: list-sessions answers by socket (-S <path>).
    cat > "$T/bin/tmux" <<EOF
#!/bin/bash
case "\$2" in
    */fw-agents) printf '%s\n' $1 ;;
    */fw-agents-0123456789abcdef) printf '%s\n' fw-p1-11 fw-p1-12 ;;
esac
EOF
    chmod +x "$T/bin/tmux"
    YELLOW= GREEN= NC=
    warnings=0
    source "$FRAMEWORK_ROOT/lib/doctor-tmux.sh"
    PATH="$T/bin:$PATH" doctor_check_tmux_sharing > "$T/doctor.out"
}

@test "T-4781: doctor WARNs when one tmux server carries claude-fw sessions of two projects" {
    _doctor "fw-p1-11 fw-055-cockpit-22 other"
    grep -q "WARN.*tmux server 'fw-agents' carries claude-fw sessions of 2 projects" "$T/doctor.out"
    ! grep -q "fw-agents-0123456789abcdef" "$T/doctor.out" || false
    [ "$warnings" -eq 1 ]
}

@test "T-4781/control: doctor says OK when every server carries one project" {
    _doctor "fw-p1-11 fw-p1-13"
    grep -q "OK.*none shared between projects" "$T/doctor.out"
    [ "$warnings" -eq 0 ]
}

@test "T-4781: doctor is wired to the check" {
    grep -q 'doctor_check_tmux_sharing' "$FRAMEWORK_ROOT/bin/fw"
}
