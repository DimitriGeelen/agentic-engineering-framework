#!/usr/bin/env bats
#
# T-3238 — `find` sat on the Bash safe-list unconditionally, so
# `find . -delete` and `find . -exec rm {} \;` were admitted WITH NO ACTIVE
# TASK. find is a search tool with a mutation grammar bolted on: `-delete`
# removes what it matches, `-exec`/`-execdir`/`-ok`/`-okdir` run an arbitrary
# command per match, and `-fprint`/`-fprintf`/`-fprint0`/`-fls` write files
# with no shell redirect — the exact admission rule the list states for itself.
#
# Same L-547 class as T-3237 (bare wget) and T-2834 before it: the verdict was
# keyed on the FIRST WORD, not the whole command. The check is clause-scoped on
# quote-stripped text (the T-3222 pattern), so a MENTION of a predicate inside
# a quoted argument does not gate — the mention legs below pin that.
#
# `! cmd` at statement position is INERT in bats (L-628, T-3199) — this file
# uses `if cmd; then false; fi` and explicit compares.
#
# Task IDs in probe strings are spelled TT-9 deliberately (see the T-3222
# suite's header for why).

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB="$ROOT/agents/context/lib/safe-commands.sh"
    HOOK="$ROOT/agents/context/check-active-task.sh"
    export ROOT LIB HOOK
    source "$LIB"
}

_mkroot() {
    local t="$BATS_TEST_TMPDIR/root"
    [ -d "$t" ] && { printf '%s' "$t"; return 0; }
    mkdir -p "$t/.context/working" "$t/.tasks/active" "$t/.tasks/completed"
    cp -r "$ROOT/agents" "$ROOT/lib" "$t/" 2>/dev/null
    printf 'current_task: null\n' > "$t/.context/working/focus.yaml"
    printf '%s' "$t"
}

_verdict() {
    local root="$1" hook="$2" cmd="$3" json
    json="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$cmd")"
    if printf '%s' "$json" | PROJECT_ROOT="$root" FRAMEWORK_ROOT="$root" \
        CLAUDE_PROJECT_DIR="$root" bash "$hook" >/dev/null 2>&1; then
        printf 'ADMITTED'
    else
        printf 'blocked'
    fi
}

# ── the predicate, both directions ───────────────────────────────────────────

@test "every action-predicate spelling reads as unsafe" {
    local c missed=0
    local -a actions=(
        'find . -delete'
        'find . -name "*.tmp" -delete'
        'find . -exec rm {} \;'
        'find /tmp -execdir sh -c x {} \;'
        'find . -ok rm {} \;'
        'find . -okdir rm {} \;'
        'find . -fprint /tmp/out'
        'find . -fprintf /tmp/out "%p"'
        'find . -fprint0 /tmp/out'
        'find . -fls /tmp/ls'
    )
    for c in "${actions[@]}"; do
        if is_bash_safe_command "$c"; then
            echo "MISSED (would be admitted with no task): $c" >&2
            missed=$((missed+1))
        fi
    done
    [ "$missed" -eq 0 ]
}

@test "pure-search forms are still safe" {
    # The dominant legitimate use. A false positive here gates the searches
    # agents run reflexively, in exactly the no-task state where the safe-list
    # is the only thing preventing a deadlock.
    local c false_pos=0
    local -a safe=(
        'find . -name "*.py"'
        'find . -type f -mtime -1 -print'
        'find . -name "*.tmp" -print0'
        'find /tmp -maxdepth 2 -type d'
        'find . -iname "*.md" -newer /tmp/ref'
    )
    for c in "${safe[@]}"; do
        if ! is_bash_safe_command "$c"; then
            echo "FALSE POSITIVE (would gate a search): $c" >&2
            false_pos=$((false_pos+1))
        fi
    done
    [ "$false_pos" -eq 0 ]
}

@test "a QUOTED predicate is a mention, not an action" {
    # The whole reason the check is clause-scoped on quote-stripped text
    # (L-547 in the other direction): `-delete` as a -name ARGUMENT matches
    # files literally named -delete; it deletes nothing.
    is_bash_safe_command 'find . -name "-delete"'
    is_bash_safe_command 'grep -r delete .'
}

@test "an unparseable clause is treated as an action, not waved through" {
    _fw_find_has_action_predicate 'find . -name "unclosed'
}

# ── through the live hook, focus null ────────────────────────────────────────

@test "find -delete is blocked with no active task" {
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'find . -delete')" = blocked ]
}

@test "find -exec is blocked with no active task" {
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'find /tmp -execdir touch {} \;')" = blocked ]
}

@test "find -name is still admitted with no active task" {
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'find . -name "*.py"')" = ADMITTED ]
}

@test "a commit chained to a find-action no longer rides through (T-3221 join)" {
    # Same composition property the T-3222 suite pins: the commit-checkpoint
    # predicate defers clause admissibility to this allowlist, so closing the
    # hole here closes it there with no change to the commit predicate.
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'git commit -m "TT-9: x" && find /tmp -name "*.bak" -delete')" = blocked ]
}

@test "a commit whose MESSAGE mentions find -delete is still admitted" {
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'git commit -m "TT-9: doc: find . -delete cleans stale tmpfiles"')" = ADMITTED ]
}

# ── MUTATION CONTROL ─────────────────────────────────────────────────────────

@test "restoring the unconditional find arm re-opens the hole" {
    # Derived from live source, so reverting the fix reddens this rather than
    # leaving a frozen copy that agrees with itself forever.
    local m="$BATS_TEST_TMPDIR/root-mutant"
    cp -r "$(_mkroot)" "$m"
    local lib="$m/agents/context/lib/safe-commands.sh"
    local n
    n="$(grep -c '_fw_find_has_action_predicate "\$cmd" && return 1' "$lib")"
    [ "$n" -eq 1 ]
    sed -i 's|_fw_find_has_action_predicate "\$cmd" \&\& return 1||' "$lib"
    bash -n "$lib"

    [ "$(_verdict "$m" "$m/agents/context/check-active-task.sh" 'find . -delete')" = ADMITTED ]
    # controls: the mutant is otherwise functional, so the leg above is
    # measuring the removed line and not a broken mutant
    [ "$(_verdict "$m" "$m/agents/context/check-active-task.sh" 'find . -name "*.py"')" = ADMITTED ]
    [ "$(_verdict "$m" "$m/agents/context/check-active-task.sh" 'rm -rf /tmp/zzz')" = blocked ]
}

# ── NO WIDENING ──────────────────────────────────────────────────────────────

@test "the fix admits nothing the pre-fix hook blocked" {
    local m="$BATS_TEST_TMPDIR/root-mutant2"
    cp -r "$(_mkroot)" "$m"
    sed -i 's|_fw_find_has_action_predicate "\$cmd" \&\& return 1||' \
        "$m/agents/context/lib/safe-commands.sh"
    local mh="$m/agents/context/check-active-task.sh"
    local root; root="$(_mkroot)"
    local c widened=0
    local -a corpus=(
        'ls -la'
        'git status'
        'find . -name "*.py"'
        'find . -delete'
        'find . -exec rm {} \;'
        'grep -r pattern .'
        'rm -rf /tmp/zzz'
        'echo hi > /tmp/zzz'
        'git commit -m "TT-9: x"'
        'git add -A && git commit -m "TT-9: x"'
        'bin/fw doctor'
    )
    for c in "${corpus[@]}"; do
        if [ "$(_verdict "$m" "$mh" "$c")" = blocked ] \
           && [ "$(_verdict "$root" "$HOOK" "$c")" = ADMITTED ]; then
            echo "WIDENED: $c" >&2
            widened=$((widened+1))
        fi
    done
    [ "$widened" -eq 0 ]
}
