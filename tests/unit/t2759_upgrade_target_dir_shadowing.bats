#!/usr/bin/env bats
# T-2759: `fw upgrade` must never write a consumer's files somewhere else and
# then report success.
#
# THE DEFECT
#
# do_upgrade binds target_dir to the consumer at lib/upgrade.sh:566. The shim
# migration block at :1305 declared `local target_dir` a SECOND time, inside the
# same function. Bash does not create a new scope for that — it rebinds the
# existing one. From that line on, target_dir was
# dirname(readlink -f ~/.local/bin/fw).
#
# Steps 5-10 then wrote .claude/settings.json, .mcp.json, resume.md, scripts/,
# the .context subdirs, the .framework.yaml version pin and the enforcement
# baseline into THAT directory. The run printed "=== Upgrade Complete ===" and
# exited 0.
#
# WHY IT SURVIVED
#
# It is a false green, not a crash. A consumer in this state gets no hook
# updates and no governance refresh, and its pin never advances — so it reads as
# permanently "behind" no matter how many times it is upgraded, and every one of
# those upgrades reports success. Nothing ever prompts anyone to look. (Same
# failure direction as L-534.)
#
# TRIGGER CONDITION
#   ~/.local/bin/fw is a symlink, its target path ends in /bin/fw, and there is
#   no FRAMEWORK.md beside the target's parent (that check is what made the
#   refusal branch fire instead — and the refusal ALSO aborted the whole upgrade).
#
# These tests drive the real `bin/fw upgrade` with a controlled $HOME so the
# branch is genuinely taken. Asserting on the source text alone would not have
# caught it: the line looked perfectly ordinary.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FWROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

    FAKE_HOME="$TEST_TEMP_DIR/home"
    DECOY="$TEST_TEMP_DIR/decoy"
    CONSUMER="$TEST_TEMP_DIR/consumer"

    mkdir -p "$FAKE_HOME/.local/bin" "$DECOY/bin" "$CONSUMER"

    # A decoy that satisfies the shim-migration branch: symlink target ends in
    # /bin/fw, and there is deliberately NO FRAMEWORK.md at $DECOY/.. so the
    # protective refusal does not fire.
    touch "$DECOY/bin/fw"
    chmod +x "$DECOY/bin/fw"
    ln -s "$DECOY/bin/fw" "$FAKE_HOME/.local/bin/fw"

    printf 'framework_root: %s\nversion: 1.0.0\n' "$FWROOT" > "$CONSUMER/.framework.yaml"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

run_upgrade() {
    # --no-self-vendor: this test is about WHERE files land, and self-vendor
    # mutates the framework's own tree rather than the consumer's.
    HOME="$FAKE_HOME" run "$FWROOT/bin/fw" upgrade "$CONSUMER" --no-self-vendor
}

@test "T-2759: consumer receives .claude/settings.json, not the shim's link dir" {
    run_upgrade
    [ -f "$CONSUMER/.claude/settings.json" ]
    [ ! -f "$DECOY/bin/.claude/settings.json" ]
}

@test "T-2759: consumer receives .mcp.json, not the shim's link dir" {
    run_upgrade
    [ -f "$CONSUMER/.mcp.json" ]
    [ ! -f "$DECOY/bin/.mcp.json" ]
}

@test "T-2759: consumer receives resume.md, not the shim's link dir" {
    run_upgrade
    [ -f "$CONSUMER/.claude/commands/resume.md" ]
    [ ! -f "$DECOY/bin/.claude/commands/resume.md" ]
}

@test "T-2759: the consumer's version pin actually advances" {
    # The operator-visible symptom: a consumer that upgrades successfully every
    # time and stays pinned at the same version forever.
    run_upgrade
    run grep "^version:" "$CONSUMER/.framework.yaml"
    [ "$status" -eq 0 ]
    [[ "$output" != *"1.0.0"* ]]
}

@test "T-2759: nothing at all is written into the shim's link directory" {
    # Broader than the three named files — catches a step added later that
    # writes somewhere new under the rebound path.
    run_upgrade
    # The decoy's own fw binary is created in setup and is expected to survive;
    # anything else appearing here came from a step writing through the rebound
    # path. Assert the directory holds exactly that one entry.
    run find "$DECOY/bin" -mindepth 1
    [ "$output" = "$DECOY/bin/fw" ]
}

@test "T-2759: target_dir is bound exactly once in do_upgrade" {
    # The class is the re-declaration, not this one line. Bash allows a second
    # `local` in the same function and silently rebinds, so this is the only
    # cheap structural guard against the next instance.
    run python3 - "$FWROOT/lib/upgrade.sh" <<'PY'
import re, sys
src = open(sys.argv[1]).read().split('\n')
start = None
end = len(src)
for i, l in enumerate(src, 1):
    if l.startswith('do_upgrade() {'):
        start = i
    elif start and i > start and re.match(r'^[A-Za-z_][A-Za-z0-9_]*\(\) \{', l):
        end = i - 1
        break
hits = [i + 1 for i in range(start, end) if re.search(r'\blocal\s+target_dir\b', src[i])]
print(hits)
sys.exit(0 if len(hits) == 1 else 1)
PY
    [ "$status" -eq 0 ]
}
