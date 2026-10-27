#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-4828: TermLink field test (be.39, msg 829aeb6d) — "Arc focus arc-011 set
# 2026-09-22, 35 days ago (limit 14)" fired while arc-011 was TermLink's live arc
# with commits in the window. T-4774's AGE looked at focused_at alone. AGE now
# fires only for an arc that is old AND quiet: when the focused arc holds at
# least the DRIFT share (MIN_FRACTION) of the window's task commits, the old
# timestamp is reported on the OK line instead of as a warning.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CHECK="$FRAMEWORK_ROOT/lib/arc_focus_health.py"

setup() {
    P="$(mktemp -d)"
    mkdir -p "$P/.context/working" "$P/.context/arcs" "$P/.tasks/active"
    git -C "$P" init -q
    git -C "$P" config user.email t@t
    git -C "$P" config user.name t
    printf 'id: arc-900\nslug: focus-arc\nname: "Focus arc"\nstatus: in-progress\n' > "$P/.context/arcs/focus-arc.yaml"
    printf -- '---\nid: T-1\narc_id: focus-arc\n---\n' > "$P/.tasks/active/T-1-a.md"
    for n in 4 5 6 7 8 9 10 11 12 13 14; do
        printf -- '---\nid: T-%s\n---\n' "$n" > "$P/.tasks/active/T-$n-x.md"
    done
    printf '# Arc focus (T-1661).\ncurrent_arc: focus-arc\nfocused_at: 2026-01-02T00:00:00Z\n' \
        > "$P/.context/working/arc-focus.yaml"
}

teardown() {
    cd /
    rm -rf "$P"
}

commit() { git -C "$P" commit -q --allow-empty -m "$1"; }

run_check() { run python3 "$CHECK" --project-root "$P" --days 14; }

@test "old focus on an arc still committing: no AGE, OK line names age and activity" {
    commit "T-1: arc work"
    commit "T-4: outside"
    run_check
    [ "$status" -eq 0 ]
    ! grep -qE '^(AGE|DRIFT)\|' <<<"$output" || false
    grep -q "^OK|Arc focus 'focus-arc' active: 1 of 2 task(s) committed in the last 14 days are in it (focus set 2026-01-02, [0-9]* days ago)|" <<<"$output"
}

@test "old focus on a quiet arc (no commits at all): AGE still fires" {
    run_check
    grep -q "^AGE|Arc focus 'focus-arc' set 2026-01-02" <<<"$output"
}

@test "old focus, recent work all outside: AGE and DRIFT both fire" {
    commit "T-4: outside"
    run_check
    grep -q '^AGE|' <<<"$output"
    grep -q '^DRIFT|' <<<"$output"
}

@test "old focus, arc share below the DRIFT threshold: AGE still fires" {
    commit "T-1: arc work"
    for n in 4 5 6 7 8 9 10 11 12 13 14; do commit "T-$n: outside"; done
    run_check
    grep -q '^AGE|' <<<"$output"
    grep -q '^DRIFT|Arc focus .focus-arc.: 1 of 12 ' <<<"$output"
}

@test "handover: active old arc produces no stale WARNING (end to end through the caller's filter)" {
    commit "T-1: arc work"
    out=$(python3 "$CHECK" --project-root "$P" --days 14 | grep -E '^(AGE|DRIFT)\|' || true)
    [ -z "$out" ]
}
