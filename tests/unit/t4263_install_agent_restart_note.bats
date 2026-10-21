#!/usr/bin/env bats
# T-4263 (greenfield run aef-install-20261017T144241Z, F-23): an agent that ran
# install.sh from inside a live Claude Code session got "start your AI agent"
# and nothing telling it that its OWN session has none of the hooks it just
# installed — Claude Code reads .claude/settings.json at session start only.
# The success banner now says so when CLAUDECODE is set and a project was
# installed.
#
# Confirmed RED against the pre-T-4263 install.sh: print_completion_banner did
# not exist (the banner was inline in main), so every test fails.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT/install.sh"

# Extract print_completion_banner into a shim and call it (install_scan.bats pattern).
# T-4263 follow-up: the banner also reads the global PROVIDER (T-4240). The shim
# takes install.sh's own default line for it, so an unset global can't make the
# function die under set -u again; pass a third arg to override the provider.
run_banner() {
    local target="$1" claudecode="$2" provider="${3:-}"
    env -u CLAUDECODE -u PROVIDER ${claudecode:+CLAUDECODE="$claudecode"} \
        ${provider:+PROVIDER="$provider"} bash -c "
        set -euo pipefail
        TARGET_DIR='$target'
        $(grep -m1 '^PROVIDER=' "$INSTALL")
        BOLD=''; NC=''; GREEN=''; YELLOW=''; RED=''
        info() { echo \"[+] \$*\"; }
        warn() { echo \"[!] \$*\"; }
        $(sed -n '/^print_completion_banner()/,/^}$/p' "$INSTALL")
        print_completion_banner
    "
}

@test "T-4263: banner tells a running Claude Code session to restart in the target" {
    run run_banner /srv/proj 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installation complete!"* ]]
    [[ "$output" == *"Restart the agent there"* ]]
    [[ "$output" == *"/srv/proj/.claude/settings.json"* ]]
    [[ "$output" == *"cd /srv/proj && claude-fw"* ]]
}

@test "T-4263: no restart note outside an agent session" {
    run run_banner /srv/proj ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installation complete!"* ]]
    [[ "$output" == *"Project ready: /srv/proj"* ]]
    [[ "$output" != *"Restart the agent"* ]]
    [[ "$output" != *"CLAUDECODE is set"* ]]
}

@test "T-4263: no restart note when no project was installed (PATH tooling only)" {
    run run_banner "" 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw router + claude-fw are installed"* ]]
    [[ "$output" != *"Restart the agent"* ]]
    [[ "$output" != *"CLAUDECODE is set"* ]]
}

@test "T-4263 follow-up: PROVIDER reaches the banner (cursor gets no claude-fw restart line)" {
    grep -q '^PROVIDER="${PROVIDER:-' "$INSTALL"
    run run_banner /srv/proj "" cursor
    [ "$status" -eq 0 ]
    [[ "$output" == *"Start your AI agent (e.g. Cursor)"* ]]
    [[ "$output" != *"Restart Claude Code in"* ]]
    run run_banner /srv/proj ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"Restart Claude Code in /srv/proj with claude-fw"* ]]
}
