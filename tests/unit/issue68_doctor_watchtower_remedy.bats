#!/usr/bin/env bats
# #68: `fw doctor` printed `bin/watchtower.sh ...` as the remedy for a stale or
# unreachable Watchtower triple. In a vendored project that path does not exist
# (the script lives under .agentic-framework/bin/), so the remedy failed with
# "No such file or directory". Both remedies now go through _emit_user_command
# (lib/fw-command.sh, T-5302/T-5304), which prints `cd <project> && bin/fw ...`
# in the framework repo and `cd <project> && .agentic-framework/bin/fw ...` in a
# vendored project, like the neighbouring log-fd branch already does.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FW="$REPO_ROOT/bin/fw"
}

# Body of do_doctor only, so that the `fw watchtower` router further down
# (which legitimately execs "$FRAMEWORK_ROOT/bin/watchtower.sh") is not read.
_doctor_body() {
    awk '/^do_doctor\(\)/ {in_fn=1} in_fn {print} in_fn && /^}/ {exit}' "$FW"
}

@test "#68: do_doctor exists (anchor for the checks below)" {
    run _doctor_body
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "#68: no doctor remedy points at bin/watchtower.sh" {
    run bash -c "awk '/^do_doctor\\(\\)/ {f=1} f {print} f && /^}/ {exit}' '$FW' | grep -n 'Run: bin/watchtower.sh'"
    [ "$status" -eq 1 ]
}

@test "#68: stale-triple and endpoint-down remedies go through _emit_user_command" {
    body=$(_doctor_body)
    echo "$body" | grep -A1 'Stale Watchtower triple' | grep -qF 'Run: $(_emit_user_command "watchtower restart")'
    echo "$body" | grep -A1 'identity mismatch or endpoint down' | grep -qF 'Run: $(_emit_user_command "watchtower restart")'
}
