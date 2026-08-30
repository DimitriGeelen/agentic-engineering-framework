#!/usr/bin/env bats
#
# T-3222 — `curl` and `wget` sat on the Bash safe-list unconditionally, so
# `curl -o FILE` and `wget -O FILE` were admitted WITH NO ACTIVE TASK.
#
# That contradicted the admission rule the list states for itself — "only verbs
# that cannot write a file WITHOUT a shell redirect", the basis on which it
# excludes `awk` and `uniq`. Both write a file with no redirect, so
# has_bash_write_pattern (which looks for redirects) never saw them.
#
# Reported as a side finding by peer 832-Workflow-designer on their T-638, while
# they were fixing the sibling defect this repo closed as T-3221. Confirmed here
# against the live hook before anything was changed.
#
# WHERE THE CHECK LIVES, and why that is the interesting part. The obvious home
# is has_bash_write_pattern, so that a fetch-write reads as a write to every
# caller. It is NOT there. That function scans the whole raw command string, and
# already classifies `git commit -m "we no longer rm -rf the output dir"` as a
# WRITE — a mention in a commit message treated as an action (measured;
# OBS-356; predates all of this). Putting curl there would have added another
# instance of the exact class T-3221/T-3223 exist to remove. The check is
# clause-scoped instead, on quote-stripped text with the base already extracted,
# so only a real invocation can match. The mention leg below pins that.
#
# `! cmd` at statement position is INERT in bats (L-628, T-3199) — this file
# uses `if cmd; then false; fi` and explicit compares.
#
# Task IDs in probe strings are spelled TT-9 deliberately: a real-looking
# T-NNNN here is read as an action target by the focus-drift gate when this
# file is edited (which is that same class again, and it fired twice during
# T-3221/T-3223).

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

@test "every fetch-to-file spelling reads as a write" {
    local c missed=0
    local -a writes=(
        'curl -o /tmp/x https://e/'
        'curl --output /tmp/x https://e/'
        'curl --output=/tmp/x https://e/'
        'curl -O https://e/f'
        'curl -sO https://e/f'
        'curl -so /tmp/x https://e/'
        'curl --remote-name https://e/f'
        'curl --output-dir /tmp https://e/f'
        'wget -O /tmp/x https://e/'
        'wget -O/tmp/x https://e/'
        'wget --output-document /tmp/x https://e/'
        'wget -o /tmp/log https://e/'
    )
    for c in "${writes[@]}"; do
        if ! _fw_fetch_writes_file "$c"; then
            echo "MISSED (would be admitted with no task): $c" >&2
            missed=$((missed+1))
        fi
    done
    [ "$missed" -eq 0 ]
}

@test "read-only and write-to-stdout forms are NOT writes" {
    # The destination is the hazard, not the flag. A false positive here does
    # not merely annoy: `curl -sf "$(bin/fw watchtower url)/page"` is the
    # framework's OWN documented P-011 verification idiom, and gating it would
    # break verification in exactly the no-task state where it is needed.
    local c false_pos=0
    local -a safe=(
        'curl -sf https://e/'
        'curl -I https://e/'
        'curl -s -L https://e/'
        'curl -o - https://e/'
        'curl -o- https://e/'
        'curl --output=- https://e/'
        'wget -O - https://e/'
        'wget -O- https://e/'
        'wget --spider https://e/'
        'curl -sf "$(bin/fw watchtower url)/page"'
    )
    for c in "${safe[@]}"; do
        if _fw_fetch_writes_file "$c"; then
            echo "FALSE POSITIVE (would gate a read): $c" >&2
            false_pos=$((false_pos+1))
        fi
    done
    [ "$false_pos" -eq 0 ]
}

@test "an unparseable clause is treated as a write, not waved through" {
    _fw_fetch_writes_file 'curl -o "unclosed'
}

# ── through the live hook, focus null ────────────────────────────────────────

@test "curl -o FILE is blocked with no active task" {
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'curl -o /tmp/zzz https://e/')" = blocked ]
}

@test "wget -O FILE is blocked with no active task" {
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'wget -O /tmp/zzz https://e/')" = blocked ]
}

@test "curl -sf URL is still admitted with no active task" {
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'curl -sf https://e/')" = ADMITTED ]
}

@test "the framework's own verification idiom is still admitted" {
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'curl -sf "$(bin/fw watchtower url)/page"')" = ADMITTED ]
}

@test "a commit chained to a fetch-write no longer rides through (T-3221 join)" {
    # This is the case T-3221 measured and deliberately left open, because its
    # predicate defers clause admissibility to this allowlist. Closing the hole
    # HERE closes it there too, with no change to the commit predicate — which
    # is the composition property T-3221 was built for.
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'git commit -m "TT-9: x" && curl -o /tmp/zzz https://e/')" = blocked ]
}

@test "a commit whose MESSAGE mentions curl -o is still admitted" {
    # The whole reason the check is clause-scoped. If it lived in
    # has_bash_write_pattern (whole raw string), this would be blocked — a
    # mention treated as an action, which is the class this cluster removes.
    [ "$(_verdict "$(_mkroot)" "$HOOK" 'git commit -m "TT-9: doc: use curl -o FILE to save it"')" = ADMITTED ]
}

# ── MUTATION CONTROL ─────────────────────────────────────────────────────────

@test "restoring the unconditional curl|wget arm re-opens the hole" {
    # Derived from live source, so reverting the fix reddens this rather than
    # leaving a frozen copy that agrees with itself forever.
    local m="$BATS_TEST_TMPDIR/root-mutant"
    cp -r "$(_mkroot)" "$m"
    local lib="$m/agents/context/lib/safe-commands.sh"
    local n
    n="$(grep -c '_fw_fetch_writes_file "\$cmd" && return 1' "$lib")"
    [ "$n" -eq 1 ]
    sed -i 's|_fw_fetch_writes_file "\$cmd" \&\& return 1||' "$lib"
    bash -n "$lib"

    [ "$(_verdict "$m" "$m/agents/context/check-active-task.sh" 'curl -o /tmp/zzz https://e/')" = ADMITTED ]
    # control: the mutant is otherwise functional, so the leg above is measuring
    # the removed line and not a broken mutant
    [ "$(_verdict "$m" "$m/agents/context/check-active-task.sh" 'curl -sf https://e/')" = ADMITTED ]
    [ "$(_verdict "$m" "$m/agents/context/check-active-task.sh" 'rm -rf /tmp/zzz')" = blocked ]
}

# ── NO WIDENING ──────────────────────────────────────────────────────────────

@test "the fix admits nothing the pre-fix hook blocked" {
    local m="$BATS_TEST_TMPDIR/root-mutant2"
    cp -r "$(_mkroot)" "$m"
    sed -i 's|_fw_fetch_writes_file "\$cmd" \&\& return 1||' \
        "$m/agents/context/lib/safe-commands.sh"
    local mh="$m/agents/context/check-active-task.sh"
    local root; root="$(_mkroot)"
    local c widened=0
    local -a corpus=(
        'ls -la'
        'git status'
        'curl -sf https://e/'
        'curl -o /tmp/x https://e/'
        'wget -O /tmp/x https://e/'
        'wget --spider https://e/'
        'rm -rf /tmp/zzz'
        'echo hi > /tmp/zzz'
        'git commit -m "TT-9: x"'
        'git add -A && git commit -m "TT-9: x"'
        'bin/fw doctor'
        'curl -sf "$(bin/fw watchtower url)/page"'
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

@test "the admission rule the list states for itself is quoted at the fix" {
    grep -q 'cannot write a file WITHOUT a shell redirect' "$LIB"
}
