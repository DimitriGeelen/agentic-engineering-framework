#!/usr/bin/env bats
# T-2911 — the two hook-registration producer sites must not diverge again.
#
# `fw hook-enable` (bin/hook-enable.sh) is how a hook gets added to THIS repo's own
# .claude/settings.json over time — one call per hook, cumulative. `generate_claude_code_config`
# (lib/init.sh) is the fixed template every `fw init`/`fw upgrade` regenerate writes into a
# CONSUMER's settings.json. bin/hook-enable.sh:120 already said "both sites must change
# together (L-399 producer/consumer parity)" — prose only, so it was broken 7 times (8 counting
# check-rail-mcp-label, added via `fw hook-enable` by T-2908 one commit before this task's own
# measurement, reproducing the exact defect this file exists to catch).
#
# Key on hook NAME, not the raw command string or (event,matcher,command) tuple: the emitted
# command differs between framework-mode (`bin/fw`) and consumer-mode
# (`.agentic-framework/bin/fw`) by design (T-1504/T-2709), and T-2909 S1 measured name as the
# only key with zero false positives across 28 historical settings.json revisions.
#
# Test 6 is a NEGATIVE CONTROL: it removes one hook from a temp COPY of lib/init.sh and proves
# the comparator actually flags it missing. Without it, this suite could pass for the same
# reason the defect shipped — a check that reports parity about the wrong (self-identical)
# object.

load ../test_helper

INIT_SH="$FRAMEWORK_ROOT/lib/init.sh"
REAL_SETTINGS="$FRAMEWORK_ROOT/.claude/settings.json"

# ---------------------------------------------------------------------------
# Framework-only allowlist (T-2911 AC5).
#
# A hook name here is DELIBERATELY absent from generate_claude_code_config —
# it must never run in a consumer project. Every entry needs a one-line reason.
# This list is checked programmatically (see _in_allowlist below); it is not
# advisory. As of T-2911 it is empty: the investigation for this task found
# no hook currently registered in this repo that is inappropriate for a
# consumer (arcs, inception, onboarding tags, task dup-guard, heredoc lint,
# settings-edit nudge, and the TermLink MCP rail label all apply equally to
# consumer projects). Populate it, with a reason per line, the day a hook is
# added that is genuinely framework-repo-only — do not leave a real
# divergence unmirrored AND unlisted (that is the L-506 leg this class keeps
# hitting).
FRAMEWORK_ONLY_HOOKS=()
# Example shape once populated:
#   FRAMEWORK_ONLY_HOOKS=("self-vendor-sync:only meaningful inside the framework repo's own vendoring loop")

_in_allowlist() {
    local needle="$1" entry
    for entry in "${FRAMEWORK_ONLY_HOOKS[@]:-}"; do
        [ "${entry%%:*}" = "$needle" ] && return 0
    done
    return 1
}

# Hook names registered in a real settings.json file, one per line, deduped+sorted.
_settings_hook_names() {
    python3 -c "
import json, re, sys
d = json.load(open(sys.argv[1]))
names = set()
for ev, entries in (d.get('hooks') or {}).items():
    for e in entries or []:
        for h in e.get('hooks') or []:
            m = re.search(r'\bfw\s+hook\s+([A-Za-z0-9_-]+)', h.get('command', ''))
            if m:
                names.add(m.group(1))
for n in sorted(names):
    print(n)
" "$1"
}

# Hook names emitted by generate_claude_code_config() in a given lib/init.sh-shaped
# file. All '\$fw_prefix hook <name>' occurrences in the whole file belong to this one
# function (verified: no other generator in lib/init.sh emits Claude Code hook JSON) —
# a flat grep is sufficient and avoids brace-matching through the heredoc's own JSON
# '}' lines, which a naive function-body extractor would trip on.
_template_hook_names() {
    grep -oE '\$fw_prefix hook [A-Za-z0-9_-]+' "$1" | awk '{print $NF}' | sort -u
}

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "T-2911: the template extractor is non-vacuous — finds at least one hook name" {
    # Anti-vacuity anchor: if the extractor silently matched nothing, every
    # comparison below would pass by finding both sides empty.
    local names
    names="$(_template_hook_names "$INIT_SH")"
    [ -n "$names" ]
    echo "$names" | grep -qx "check-active-task"
}

@test "T-2911: check-onboarding-gate is in the template, asserted by name" {
    # AC2 — arc-017's whole mechanic. Must not ride on a set-comparison a
    # future refactor could weaken; assert the literal name.
    _template_hook_names "$INIT_SH" | grep -qx "check-onboarding-gate"
}

@test "T-2911: template hook set has no unmirrored, unlisted divergence from this repo's own settings.json" {
    # This repo's own .claude/settings.json is the real, cumulative output of every
    # 'fw hook-enable' call ever made here — the de facto record of "hooks a
    # consumer should also get" (subject to the allowlist above).
    local real tmpl missing
    real="$(_settings_hook_names "$REAL_SETTINGS")"
    tmpl="$(_template_hook_names "$INIT_SH")"

    missing=""
    while IFS= read -r name; do
        [ -z "$name" ] && continue
        if ! echo "$tmpl" | grep -qx "$name"; then
            _in_allowlist "$name" || missing="$missing $name"
        fi
    done <<< "$real"

    if [ -n "$missing" ]; then
        echo "hooks in $REAL_SETTINGS but absent from generate_claude_code_config and not allowlisted:$missing"
        false
    fi
}

@test "T-2911: fresh 'fw init' consumer registers check-onboarding-gate by name" {
    run "$FRAMEWORK_ROOT/bin/fw" init "$TEST_TEMP_DIR" --provider claude
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/.claude/settings.json" ]
    _settings_hook_names "$TEST_TEMP_DIR/.claude/settings.json" | grep -qx "check-onboarding-gate"
}

@test "T-2911: fresh 'fw init' consumer's hook set matches this repo's, modulo the allowlist" {
    run "$FRAMEWORK_ROOT/bin/fw" init "$TEST_TEMP_DIR" --provider claude
    [ "$status" -eq 0 ]

    local real consumer missing
    real="$(_settings_hook_names "$REAL_SETTINGS")"
    consumer="$(_settings_hook_names "$TEST_TEMP_DIR/.claude/settings.json")"

    missing=""
    while IFS= read -r name; do
        [ -z "$name" ] && continue
        if ! echo "$consumer" | grep -qx "$name"; then
            _in_allowlist "$name" || missing="$missing $name"
        fi
    done <<< "$real"

    if [ -n "$missing" ]; then
        echo "hooks this repo has but a fresh consumer does not, and not allowlisted:$missing"
        false
    fi
}

@test "T-2911: NEGATIVE CONTROL — the parity comparator catches a real removal from the template" {
    # Proves test 3/5 are non-vacuous: mutate a temp COPY of lib/init.sh (never the
    # real file) removing exactly the check-onboarding-gate line, and confirm the
    # same comparator logic used above flags it as missing. If this test ever
    # passes without the 'false' branch firing, the comparator stopped comparing.
    local mutated="$TEST_TEMP_DIR/init.sh"
    sed '/hook check-onboarding-gate/d' "$INIT_SH" > "$mutated"

    # Sanity: the mutation actually removed the name (fixture didn't drift).
    if _template_hook_names "$mutated" | grep -qx "check-onboarding-gate"; then
        echo "fixture is not exercising the removal — check-onboarding-gate still present post-sed"
        false
    fi

    local real tmpl missing
    real="$(_settings_hook_names "$REAL_SETTINGS")"
    tmpl="$(_template_hook_names "$mutated")"

    missing=""
    while IFS= read -r name; do
        [ -z "$name" ] && continue
        if ! echo "$tmpl" | grep -qx "$name"; then
            _in_allowlist "$name" || missing="$missing $name"
        fi
    done <<< "$real"

    echo "$missing" | grep -qw "check-onboarding-gate"
}
