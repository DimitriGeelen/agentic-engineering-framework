#!/usr/bin/env bats
# Invariant: gate scripts must not emit bare 'fw' COMMANDS — use bin/fw, or the
# _emit_user_command/_fw_cmd helpers that resolve the right path per project.
# Origin: T-1146 GO / T-1203 — bare commands are not copy-pasteable and violate PL-007.
#
# T-2700 rewrote the detector, which had been red and unrun (T-2697). It flagged
# six lines; two were real and four were not, in two distinct ways:
#
#   1. `\bfw\b` matches inside `bin/fw`, because `/` is a word boundary. The
#      guard flagged the exact form it wants. A guard that fires on its own fix
#      cannot be acted on — the only way to satisfy it was to stop mentioning fw.
#
#   2. It could not tell a COMMAND from PROSE ABOUT a command. Lines like
#      "Works for: fw task update, fw context add-*." are sentences naming verbs,
#      not things to paste. Rewriting them to say `bin/fw task update` mid-sentence
#      would degrade the message to satisfy a scanner. L-519 from the other side:
#      previously a text match let prose satisfy an assertion; here it let prose
#      violate one.
#
# So the rule is positional, not lexical: within the emitted string, after leading
# whitespace, an optional list marker (`1.`, `-`, `*`) and any ENV=value prefixes,
# does the COMMAND POSITION start with `fw `? That is a pasteable command. `fw`
# anywhere else in the sentence is prose and is left alone.
_bare_fw_count() {
    local file="$1"
    [ -f "$file" ] || { echo "MISSING"; return; }
    # Only EMITTED strings. Scanning every quoted string in the file flags
    # `case "fw hook "*|"bin/fw hook "*)` — a dispatch pattern that matches an
    # incoming command line, not a message telling anyone to run something.
    # Third variant of the same confusion in this one detector: it must not
    # merely find the text `fw`, it must find it where a human is being told to
    # type it.
    grep -hE '(echo|printf)' "$file" \
        | grep -vE '^[[:space:]]*#' \
        | grep -oE '"[^"]*"' \
        | sed -E 's/^"//; s/"$//' \
        | sed -E 's/^[[:space:]]*//' \
        | sed -E 's/^([0-9]+\.|[-*])[[:space:]]+//' \
        | sed -E 's/^([A-Z_][A-Z0-9_]*=[^[:space:]]*[[:space:]]+)+//' \
        | grep -cE '^fw[[:space:]]' || true
}

@test "detector distinguishes a command from prose about a command" {
    # Self-test, because this guard's whole value is the distinction it draws.
    local tmp="$BATS_TEST_TMPDIR/probe.sh"
    printf '%s\n' \
        'echo "  1. Run this: fw task update T-1 --status x"' \
        'echo "  fw context focus T-1"' \
        'echo "  FW_X=1 fw task update T-1"' \
        'echo "  bin/fw task update T-1"' \
        'echo "  Works for: fw task update, fw context add-*."' \
        'echo "  Append --switch-focus to a fw command (logged Tier 2)."' \
        > "$tmp"
    # bare command position: lines 2 and 3 (line 1 has prose before the command,
    # which is a weaker form we deliberately do not chase)
    [ "$(_bare_fw_count "$tmp")" -eq 2 ]
}
@test "update-task.sh has no bare fw in echo statements" {
    [ "$(_bare_fw_count agents/task-create/update-task.sh)" -eq 0 ]
}

@test "check-tier0.sh uses _watchtower_url for approval URL" {
    grep -q '_watchtower_url' agents/context/check-tier0.sh
}

@test "check-tier0.sh uses _emit_user_command for CLI fallback" {
    grep -q '_emit_user_command' agents/context/check-tier0.sh
}

@test "hooks.sh commit-msg hook sources paths.sh" {
    grep -q 'source.*paths.sh' agents/git/lib/hooks.sh
}

@test "hooks.sh inception gate uses _emit_user_command" {
    # The inception gate block message should use _emit_user_command, not bare fw
    grep -A2 'Record a decision' agents/git/lib/hooks.sh | grep -q '_emit_user_command'
}

@test "hooks.sh install output uses _emit_user_command" {
    grep 'Bypass:.*tier0' agents/git/lib/hooks.sh | grep -q '_emit_user_command'
}

@test "handover.sh terminal output uses _emit_user_command" {
    # Terminal echo lines with fw should use _emit_user_command (not markdown content)
    bare=$(grep 'echo.*".*Run:.*\bfw\b' agents/handover/handover.sh \
        | grep -v '_fw_cmd\|_emit_user_command' \
        | wc -l)
    [ "$bare" -eq 0 ]
}

@test "check-active-task.sh has no bare fw in block messages" {
    [ "$(_bare_fw_count agents/context/check-active-task.sh)" -eq 0 ]
}

@test "checkpoint.sh has no bare fw in guidance messages" {
    [ "$(_bare_fw_count agents/context/checkpoint.sh)" -eq 0 ]
}

@test "budget-gate.sh has no bare fw in block messages" {
    [ "$(_bare_fw_count agents/context/budget-gate.sh)" -eq 0 ]
}

@test "check-agent-dispatch.sh has no bare fw in block messages" {
    [ "$(_bare_fw_count agents/context/check-agent-dispatch.sh)" -eq 0 ]
}

@test "check-project-boundary.sh has no bare fw in block messages" {
    [ "$(_bare_fw_count agents/context/check-project-boundary.sh)" -eq 0 ]
}

@test "init.sh has no bare fw in welcome messages" {
    [ "$(_bare_fw_count agents/context/lib/init.sh)" -eq 0 ]
}
