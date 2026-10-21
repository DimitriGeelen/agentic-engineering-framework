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
run_banner() {
    local target="$1" claudecode="$2"
    env -u CLAUDECODE ${claudecode:+CLAUDECODE="$claudecode"} bash -c "
        set -euo pipefail
        TARGET_DIR='$target'
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
