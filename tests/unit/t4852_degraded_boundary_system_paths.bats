#!/usr/bin/env bats
#
# T-4852: with python3 broken, check-project-boundary.sh falls back to the bash-only
# scan in lib/hook-degraded.sh (T-4652). That scan named only /opt /home /root /srv
# /mnt, so a write into /etc, /usr, /var or /boot was allowed (ring20-dashboard be.46,
# msg 2c503ddf finding 1). The degraded scan must refuse WRITES under those system
# roots; reads stay allowed, project writes stay allowed, healthy python is unchanged.
#
# `! cmd` at statement position is inert in bats (T-4398): use `|| false`.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    PROJ="$(realpath "$(mktemp -d)")"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active"
    export PROJECT_ROOT="$PROJ"

    # A python3 that cannot run at all; first on PATH inside the test only.
    BADPY="$(mktemp -d)"
    printf '#!/bin/sh\necho "python3: broken" >&2\nexit 1\n' > "$BADPY/python3"
    chmod +x "$BADPY/python3"
}

teardown() {
    rm -rf "$PROJ" "$BADPY"
}

bash_payload() {
    printf '{"tool_name":"Bash","tool_use_id":"toolu_t4852","cwd":"%s","tool_input":{"command":"%s"}}' "$PROJ" "$1"
}

tool_payload() {
    # $1 tool name, $2 file path
    printf '{"tool_name":"%s","tool_input":{"file_path":"%s","content":"x"}}' "$1" "$2"
}

degraded() {
    run env PATH="$BADPY:$PATH" bash "$ROOT/agents/context/check-project-boundary.sh" <<< "$1"
}

healthy() {
    run bash "$ROOT/agents/context/check-project-boundary.sh" <<< "$1"
}

# --- the reported case ---------------------------------------------------------------

@test "T-4852: degraded + redirect into /etc/systemd/system is BLOCKED" {
    degraded "$(bash_payload "echo hi > /etc/systemd/system/evil.service")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK DEGRADED"* ]]
}

@test "T-4852: degraded + append redirect into /etc is BLOCKED" {
    degraded "$(bash_payload "echo x >> /etc/hosts")"
    [ "$status" -eq 2 ]
}

@test "T-4852: degraded + tee into /usr/local/bin is BLOCKED" {
    degraded "$(bash_payload "echo x | tee -a /usr/local/bin/fw")"
    [ "$status" -eq 2 ]
}

@test "T-4852: degraded + cp into /var/spool/cron is BLOCKED" {
    degraded "$(bash_payload "cp evil /var/spool/cron/root")"
    [ "$status" -eq 2 ]
}

@test "T-4852: degraded + dd of=/boot is BLOCKED" {
    degraded "$(bash_payload "dd if=x of=/boot/grub/grub.cfg")"
    [ "$status" -eq 2 ]
}

@test "T-4852: degraded + sed -i on /etc is BLOCKED" {
    degraded "$(bash_payload "sed -i s/a/b/ /etc/ssh/sshd_config")"
    [ "$status" -eq 2 ]
}

@test "T-4852: degraded + cd /etc then write is BLOCKED" {
    degraded "$(bash_payload "cd /etc && echo x > cron.d/evil")"
    [ "$status" -eq 2 ]
}

@test "T-4852: degraded + Write tool to /etc is BLOCKED" {
    degraded "$(tool_payload Write /etc/cron.d/evil)"
    [ "$status" -eq 2 ]
}

@test "T-4852: degraded + Edit tool to /usr is BLOCKED" {
    degraded "$(tool_payload Edit /usr/lib/systemd/system/x.service)"
    [ "$status" -eq 2 ]
}

# --- what must still pass ------------------------------------------------------------

@test "T-4852: degraded + write inside the project still passes" {
    degraded "$(bash_payload "echo hi > $PROJ/out.txt")"
    [ "$status" -eq 0 ]
}

@test "T-4852: degraded + Write tool inside the project still passes" {
    degraded "$(tool_payload Write "$PROJ/notes.md")"
    [ "$status" -eq 0 ]
}

@test "T-4852: degraded + read of /etc still passes" {
    degraded "$(bash_payload "cat /etc/os-release")"
    [ "$status" -eq 0 ]
}

@test "T-4852: degraded + Read tool on /usr still passes" {
    degraded "$(tool_payload Read /usr/share/doc/x)"
    [ "$status" -eq 0 ]
}

@test "T-4852: degraded + /usr/bin/env and 2>/dev/null still pass" {
    degraded "$(bash_payload "/usr/bin/env ls 2>/dev/null")"
    [ "$status" -eq 0 ]
}

# --- healthy python unchanged ---------------------------------------------------------

@test "T-4852: healthy python + read of /etc passes (unchanged)" {
    healthy "$(bash_payload "cat /etc/os-release")"
    [ "$status" -eq 0 ]
}

@test "T-4852: healthy python output carries no degraded banner" {
    healthy "$(bash_payload "echo hi > $PROJ/out.txt")"
    [ "$status" -eq 0 ]
    [[ "$output" != *"DEGRADED"* ]] || false
}
