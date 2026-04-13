#!/usr/bin/env bats
# Invariant: gate scripts must not emit bare 'fw' commands — use _emit_user_command/_fw_cmd
# Origin: T-1146 GO / T-1203 — bare commands are not copy-pasteable and violate PL-007

@test "update-task.sh has no bare fw in echo statements" {
    # Exclude comments, _fw_cmd/_emit_user_command usage, and FRAMEWORK_ROOT refs
    count=$(grep -c 'echo.*".*\bfw\b ' agents/task-create/update-task.sh \
        | head -1 || echo 0)
    bare=$(grep 'echo.*".*\bfw\b ' agents/task-create/update-task.sh \
        | grep -v '^\s*#' \
        | grep -v '_fw_cmd\|_emit_user_command\|FRAMEWORK_ROOT' \
        | wc -l)
    [ "$bare" -eq 0 ]
}

@test "check-tier0.sh uses _watchtower_url for approval URL" {
    grep -q '_watchtower_url' agents/context/check-tier0.sh
}

@test "check-tier0.sh uses _emit_user_command for CLI fallback" {
    grep -q '_emit_user_command' agents/context/check-tier0.sh
}
