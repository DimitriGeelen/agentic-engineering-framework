#!/usr/bin/env bats
# T-4792 (OBS-185): a command inside $(…) or backticks is judged as a command. Before,
# `echo $(bash deploy.sh)` read as read-only because only the outer `echo` was judged.
# The framework's own idioms (`curl -sf "$(bin/fw watchtower url)/page"`,
# `cd $(git rev-parse --show-toplevel)`) must stay read-only.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export PROJECT_ROOT="$REPO" _FW_PAYLOAD_CWD="$REPO"
    cd "$REPO"
    source "$REPO/agents/context/lib/safe-commands.sh"
}

@test "gated: echo \$(bash deploy.sh)"            { run is_bash_safe_command 'echo $(bash deploy.sh)'; [ "$status" -eq 1 ]; }
@test "gated: echo \$(git commit …)"              { run is_bash_safe_command "echo \$(git commit -m 'B: x')"; [ "$status" -eq 1 ]; }
@test "gated: backtick substitution"              { run is_bash_safe_command 'echo `bash deploy.sh`'; [ "$status" -eq 1 ]; }
@test "gated: ls \$(python3 mutate.py)"           { run is_bash_safe_command 'ls $(python3 mutate.py)'; [ "$status" -eq 1 ]; }
@test "gated: substitution inside double quotes"  { run is_bash_safe_command 'echo "$(touch /tmp/t4792-x)"'; [ "$status" -eq 1 ]; }
@test "gated: nested substitution"                { run is_bash_safe_command 'echo $(echo $(bash deploy.sh))'; [ "$status" -eq 1 ]; }
@test "gated: substitution nested in arithmetic"  { run is_bash_safe_command 'echo $(( $(bash x) + 1 ))'; [ "$status" -eq 1 ]; }
@test "gated: unbalanced \$( fails closed"        { run is_bash_safe_command 'echo $(ls'; [ "$status" -eq 1 ]; }

@test "safe: curl -sf \"\$(bin/fw watchtower url)/page\"" { run is_bash_safe_command 'curl -sf "$(bin/fw watchtower url)/page"'; [ "$status" -eq 0 ]; }
@test "safe: cd \$(git rev-parse --show-toplevel)"         { run is_bash_safe_command 'cd $(git rev-parse --show-toplevel)'; [ "$status" -eq 0 ]; }
@test "safe: echo \"built \$(date -u +%F)\""               { run is_bash_safe_command 'echo "built $(date -u +%F)"'; [ "$status" -eq 0 ]; }
@test "safe: single-quoted \$( ) is literal text"          { run is_bash_safe_command "echo 'literal \$(bash deploy.sh) here'"; [ "$status" -eq 0 ]; }
@test "safe: escaped \\\$( is literal text"                { run is_bash_safe_command 'echo \$(bash deploy.sh)'; [ "$status" -eq 0 ]; }
@test "safe: arithmetic \$((1 + 2))"                       { run is_bash_safe_command 'echo $((1 + 2))'; [ "$status" -eq 0 ]; }
@test "safe: X=\$(git rev-parse --short HEAD)"             { run is_bash_safe_command 'X=$(git rev-parse --short HEAD)'; [ "$status" -eq 0 ]; }
@test "safe: pwd on its own"                               { run is_bash_safe_command 'pwd'; [ "$status" -eq 0 ]; }
