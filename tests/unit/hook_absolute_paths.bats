#!/usr/bin/env bats
# T-1364 (G-053-A) / T-1504: hook commands in .claude/settings.json must resolve
# INDEPENDENTLY OF CWD. Claude Code's hook runner (POSIX sh -c) does not chdir to the
# project root, so a bare-relative command like "bin/fw hook X" only resolves when the
# parent shell happens to be at project root — rarely true after any cd/subshell/
# pipeline. Downstream 003-NTB-ATC-Plugin observed 680 silent failures in one session.
# That regression is what this file guards, and it still does.
#
# T-2709 (from the T-2704 RCA) — WHY THE ASSERTION CHANGED, and why this file was
# rewritten rather than deleted:
#
#   The original remediation framed the choice as *relative vs absolute* and pinned the
#   winner as a test invariant here: every command must `startswith('/')`. But the
#   absolute path it emitted was the GENERATING HOST's checkout path, baked in forever.
#   Clone the repo anywhere else and all 25 hooks fail to resolve — governance silently
#   OFF, failing toward no-enforcement.
#
#   The excluded third option is ${CLAUDE_PROJECT_DIR}/bin/fw: Claude Code expands it to
#   the project root before the hook runs, so it is ABSOLUTE AFTER EXPANSION (T-1364's
#   actual constraint, kept in full) and host-portable. `startswith('/')` is false for
#   that string, so the old assertion actively enforced against the correct fix — which
#   is precisely why deleting this file would be the wrong move: the CWD-drift guard is
#   real and load-bearing. Only the proxy it measured was wrong.
#
#   New invariant: placeholder-or-absolute, never bare-relative.
#   Both forms are absolute at exec time; a bare-relative command is not.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Assert every hook command resolves absolutely at exec time — either via the
# ${CLAUDE_PROJECT_DIR} placeholder (expanded by Claude Code to an absolute project
# root) or as a literal absolute path. A bare-relative command is the regression.
assert_hooks_resolve_absolutely() {
    local settings_file="$1"
    python3 -c "
import json, re, sys
with open('$settings_file') as f:
    data = json.load(f)

PLACEHOLDER = re.compile(r'^\"?\\\$\{?CLAUDE_PROJECT_DIR\}?')

bad = []
total = 0
for event, entries in data.get('hooks', {}).items():
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            if not cmd:
                continue
            total += 1
            bin_path = cmd.split()[0]
            if PLACEHOLDER.match(bin_path):
                continue          # absolute after Claude Code expansion
            if bin_path.startswith('/'):
                continue          # literal absolute — resolves, though host-bound
            bad.append(f'{event}: {cmd}')
if bad:
    print('BARE-RELATIVE HOOK COMMANDS FOUND (break under CWD drift — T-1364/T-1504):')
    for b in bad:
        print(f'  {b}')
    sys.exit(1)
print(f'OK — {total} hooks, all absolute at exec time')
"
}

# Assert the generator emits the portable placeholder form (T-2709 / A1).
assert_hooks_use_placeholder() {
    local settings_file="$1"
    local expected_suffix="$2"   # e.g. /bin/fw  or  /.agentic-framework/bin/fw
    python3 -c "
import json, sys
with open('$settings_file') as f:
    data = json.load(f)
want = '\${CLAUDE_PROJECT_DIR}$expected_suffix hook '
bad, total = [], 0
for event, entries in data.get('hooks', {}).items():
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            if not cmd:
                continue
            total += 1
            if not cmd.startswith(want):
                bad.append(f'{event}: {cmd}')
if bad or total == 0:
    print(f'EXPECTED every command to start with: {want!r}')
    for b in bad:
        print(f'  got: {b}')
    sys.exit(1)
print(f'OK — {total} hooks, all on the portable placeholder')
"
}

@test "hook paths: framework's own settings.json has no bare-relative hook commands" {
    run assert_hooks_resolve_absolutely "$FRAMEWORK_ROOT/.claude/settings.json"
    [ "$status" -eq 0 ]
}

@test "hook paths: generate_claude_code_config for framework-mode emits the portable placeholder" {
    # Build a minimal framework fixture (root bin/fw + FRAMEWORK.md => framework mode)
    local fake_fw="$TEST_TEMP_DIR/fw-repo"
    mkdir -p "$fake_fw/bin" "$fake_fw/agents"
    touch "$fake_fw/FRAMEWORK.md"
    cp "$FRAMEWORK_ROOT/bin/fw" "$fake_fw/bin/fw"

    bash -c "source '$FRAMEWORK_ROOT/lib/init.sh' && generate_claude_code_config '$fake_fw'" >/dev/null

    run assert_hooks_resolve_absolutely "$fake_fw/.claude/settings.json"
    [ "$status" -eq 0 ]

    run assert_hooks_use_placeholder "$fake_fw/.claude/settings.json" "/bin/fw"
    [ "$status" -eq 0 ]

    # The generating host's checkout path must NOT appear anywhere in the output —
    # that leak IS the T-2704 defect.
    run grep -cF "$fake_fw" "$fake_fw/.claude/settings.json"
    [ "$output" -eq 0 ]
}

@test "hook paths: generate_claude_code_config for consumer-mode emits the portable vendored placeholder" {
    local consumer="$TEST_TEMP_DIR/consumer"
    mkdir -p "$consumer/.agentic-framework/bin" "$consumer/.agentic-framework/agents"
    touch "$consumer/.agentic-framework/FRAMEWORK.md"
    cp "$FRAMEWORK_ROOT/bin/fw" "$consumer/.agentic-framework/bin/fw"
    # Note: no $consumer/bin/fw — so consumer mode is selected

    bash -c "source '$FRAMEWORK_ROOT/lib/init.sh' && generate_claude_code_config '$consumer'" >/dev/null

    run assert_hooks_resolve_absolutely "$consumer/.claude/settings.json"
    [ "$status" -eq 0 ]

    run assert_hooks_use_placeholder "$consumer/.claude/settings.json" "/.agentic-framework/bin/fw"
    [ "$status" -eq 0 ]

    run grep -cF "$consumer" "$consumer/.claude/settings.json"
    [ "$output" -eq 0 ]
}

@test "hook paths: no bare-relative bin/fw remains in generated settings.json" {
    # The original T-1364 regression shape, pinned directly. Unchanged from the
    # pre-T-2709 version of this test — the placeholder does not reintroduce it.
    local fake="$TEST_TEMP_DIR/p"
    mkdir -p "$fake/.agentic-framework/bin" "$fake/.agentic-framework/agents"
    touch "$fake/.agentic-framework/FRAMEWORK.md"
    cp "$FRAMEWORK_ROOT/bin/fw" "$fake/.agentic-framework/bin/fw"

    bash -c "source '$FRAMEWORK_ROOT/lib/init.sh' && generate_claude_code_config '$fake'" >/dev/null

    ! grep -qE '"command": *"bin/fw hook' "$fake/.claude/settings.json"
    ! grep -qE '"command": *"\.agentic-framework/bin/fw hook' "$fake/.claude/settings.json"
}

@test "hook paths: the rewritten assertion still REJECTS a bare-relative command" {
    # Negative control. A guard you have not watched fail is a guard you are guessing
    # about — this fixture is the exact shape T-1364/T-1504 remediated.
    local fixture="$TEST_TEMP_DIR/relative/.claude"
    mkdir -p "$fixture"
    cat > "$fixture/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": ".agentic-framework/bin/fw hook check-active-task" }
        ]
      }
    ]
  }
}
JSON
    run assert_hooks_resolve_absolutely "$fixture/settings.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"BARE-RELATIVE"* ]]
}
