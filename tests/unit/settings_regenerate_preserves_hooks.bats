#!/usr/bin/env bats
# T-2710: a forced .claude/settings.json regenerate must not silently delete hooks
# that `fw hook-enable` added after init.
#
# generate_claude_code_config (lib/init.sh) writes settings.json from a fixed heredoc
# template. With force=true it overwrote unconditionally — so the 6 hooks this repo
# added post-init (check-active-completed-dup, check-arc-id, check-heredoc-cmd-sub,
# check-inception-decisions, check-inception-schema, check-settings-edit) were wiped
# by any `fw upgrade` that took the regenerate branch. Six governance gates off, no
# message. T-2709's A2 made that branch reachable on every consumer, which is what
# turned a dormant trap into a live one.
#
# Two invariants, and BOTH matter:
#   1. hooks the template does not define are carried forward
#   2. hooks the template DOES define are re-emitted from the template
# (2) is not a detail — it is what lets a path fix (T-2709's ${CLAUDE_PROJECT_DIR}
# rewrite) still reach consumers on upgrade. A merge that preferred the on-disk copy
# would freeze every consumer at whatever it was initialised with. Test 4 pins it.
#
# Test 5 is a NEGATIVE CONTROL: it asserts the fixture actually loses hooks when the
# merge is bypassed. Without it, deleting the merge would leave this file green — the
# exact way the defect shipped the first time (a check that reports success about the
# wrong object).

load ../test_helper

MERGE="$BATS_TEST_DIRNAME/../../lib/settings_merge.py"

# Hooks present on disk but absent from the generator template.
NON_TEMPLATE="check-active-completed-dup check-arc-id check-heredoc-cmd-sub check-inception-decisions check-inception-schema check-settings-edit"

setup() {
    TMP="$(mktemp -d)"
    # "previous" = a project that ran `fw hook-enable`: template hooks + the 6 extras,
    # plus a foreign hook and a non-hooks top-level key.
    cat > "$TMP/prev.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Write|Edit|Bash", "hooks": [{"type": "command", "command": "/old/host/bin/fw hook check-active-task"}]},
      {"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/bin/fw hook check-arc-id"}]},
      {"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/bin/fw hook check-inception-decisions"}]},
      {"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/bin/fw hook check-inception-schema"}]},
      {"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/bin/fw hook check-active-completed-dup"}]},
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/bin/fw hook check-heredoc-cmd-sub"}]},
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "/usr/local/bin/vnx-guard check"}]}
    ],
    "PostToolUse": [
      {"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/bin/fw hook check-settings-edit"}]}
    ]
  },
  "permissions": {"allow": ["Bash(ls:*)"]}
}
JSON
    # "new" = what the template emits: check-active-task only, portable path.
    cat > "$TMP/new.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Write|Edit|Bash", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/bin/fw hook check-active-task"}]}
    ]
  }
}
JSON
}

teardown() {
    rm -rf "$TMP"
}

# Names of every framework hook in a settings file, one per line.
hook_names() {
    python3 -c "
import json, re, sys
d = json.load(open(sys.argv[1]))
for ev, entries in (d.get('hooks') or {}).items():
    for e in entries or []:
        for h in e.get('hooks') or []:
            m = re.search(r'\bfw\s+hook\s+([A-Za-z0-9_-]+)', h.get('command', ''))
            if m:
                print(m.group(1))
" "$1"
}

@test "T-2710: all six non-template hooks survive a forced regenerate" {
    run python3 "$MERGE" "$TMP/new.json" "$TMP/prev.json"
    [ "$status" -eq 0 ]

    names="$(hook_names "$TMP/new.json")"
    for h in $NON_TEMPLATE; do
        echo "$names" | grep -qx "$h" || {
            echo "MISSING after regenerate: $h"
            echo "present: $names"
            false
        }
    done
}

@test "T-2710: carry-forward is reported, not silent" {
    run python3 "$MERGE" "$TMP/new.json" "$TMP/prev.json"
    [ "$status" -eq 0 ]
    # One CARRIED line per preserved hook — the operator must be able to see it.
    count=$(echo "$output" | grep -c 'CARRIED' || true)
    [ "$count" -ge 6 ]
    echo "$output" | grep -q 'CARRIED.*check-arc-id'
}

@test "T-2710: foreign non-framework hooks are still dropped (T-677 preserved)" {
    run python3 "$MERGE" "$TMP/new.json" "$TMP/prev.json"
    [ "$status" -eq 0 ]
    # T-677 deliberately replaces third-party hooks; this fix must not reverse it.
    run grep -c 'vnx-guard' "$TMP/new.json"
    [ "$output" = "0" ]
}

@test "T-2710: template wins for hooks it defines (T-2709 path fix keeps propagating)" {
    run python3 "$MERGE" "$TMP/new.json" "$TMP/prev.json"
    [ "$status" -eq 0 ]

    # prev had check-active-task pinned to /old/host/bin/fw. The template's portable
    # form must replace it, and must not be duplicated alongside it.
    run grep -c '/old/host/bin/fw' "$TMP/new.json"
    [ "$output" = "0" ]

    occurrences=$(hook_names "$TMP/new.json" | grep -cx 'check-active-task')
    [ "$occurrences" -eq 1 ]
}

@test "T-2710: non-hooks top-level keys are preserved" {
    run python3 "$MERGE" "$TMP/new.json" "$TMP/prev.json"
    [ "$status" -eq 0 ]
    run grep -c 'permissions' "$TMP/new.json"
    [ "$output" != "0" ]
}

@test "T-2710: NEGATIVE CONTROL — fixture genuinely loses hooks without the merge" {
    # If this ever passes without running the merge, the fixture stopped exercising
    # the defect and every test above became decorative.
    names="$(hook_names "$TMP/new.json")"
    for h in $NON_TEMPLATE; do
        if echo "$names" | grep -qx "$h"; then
            echo "fixture is not exercising the defect: $h present pre-merge"
            false
        fi
    done
    # ...and the stale path is present until the template overwrites it.
    run grep -c 'check-active-task' "$TMP/new.json"
    [ "$output" != "0" ]
}
