#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-4774: arc-focus.yaml (T-1661) stayed pinned to one arc for 38 days while
# every recent task was outside it, and nothing said so. lib/arc_focus_health.py
# is the one predicate behind the handover's ## Current Arc warning and the
# fw doctor check: AGE (focused_at too old) and DRIFT (recent work not in the arc).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CHECK="$FRAMEWORK_ROOT/lib/arc_focus_health.py"

setup() {
    P="$(mktemp -d)"
    mkdir -p "$P/.context/working" "$P/.context/arcs" "$P/.tasks/active" "$P/.tasks/completed"
    git -C "$P" init -q
    git -C "$P" config user.email t@t
    git -C "$P" config user.name t
    printf 'id: arc-900\nslug: focus-arc\nname: "Focus arc"\nstatus: in-progress\n' > "$P/.context/arcs/focus-arc.yaml"
    # T-1 by canonical arc_id, T-2 by numeric id, T-3 by legacy tag; T-4/T-5 outside.
    printf -- '---\nid: T-1\narc_id: focus-arc\n---\n' > "$P/.tasks/completed/T-1-a.md"
    printf -- '---\nid: T-2\narc_id: arc-900\n---\n' > "$P/.tasks/completed/T-2-b.md"
    printf -- '---\nid: T-3\ntags: [arc:focus-arc]\n---\n' > "$P/.tasks/active/T-3-c.md"
    printf -- '---\nid: T-4\n---\n' > "$P/.tasks/active/T-4-d.md"
    printf -- '---\nid: T-5\n---\n' > "$P/.tasks/active/T-5-e.md"
}

teardown() {
    cd /
    rm -rf "$P"
}

focus() {  # focus <arc|null> <focused_at|null>
    printf '# Arc focus (T-1661).\ncurrent_arc: %s\nfocused_at: %s\n' "$1" "$2" > "$P/.context/working/arc-focus.yaml"
}

commit() {
    git -C "$P" commit -q --allow-empty -m "$1"
}

now_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

run_check() {
    run python3 "$CHECK" --project-root "$P" --days 14
}

@test "no focus file: OK, silent" {
    rm -f "$P/.context/working/arc-focus.yaml"
    run_check
    [ "$status" -eq 0 ]
    [ "$output" = "OK|Arc focus: none set|" ]
}

@test "focus cleared (null): OK" {
    focus null null
    commit "T-4: outside work"
    run_check
    [ "$status" -eq 0 ]
    [[ "$output" == OK\|* ]]
}

@test "fresh focus with recent work in the arc: OK" {
    focus focus-arc "$(now_ts)"
    commit "T-1: arc work"
    commit "T-2: arc work via numeric id"
    commit "T-3: arc work via legacy tag"
    commit "T-4: one outside"
    run_check
    [ "$status" -eq 0 ]
    [[ "$output" == "OK|Arc focus 'focus-arc' current"* ]]
    ! grep -qE '^(AGE|DRIFT)' <<<"$output" || false
}

@test "old focus: AGE names arc, date and age in days" {
    focus focus-arc 2026-01-02T00:00:00Z
    commit "T-1: arc work"
    run_check
    [ "$status" -eq 0 ]
    grep -q "^AGE|Arc focus 'focus-arc' set 2026-01-02, [0-9]* days ago (limit 14)|.*fw arc focus focus-arc.*fw arc focus --clear" <<<"$output"
    ! grep -q '^DRIFT' <<<"$output" || false
}

@test "missing focused_at with an arc set: AGE" {
    focus focus-arc null
    commit "T-1: arc work"
    run_check
    grep -q "^AGE|Arc focus 'focus-arc' has no readable focused_at" <<<"$output"
}

@test "recent work all outside the arc: DRIFT with in/out counts" {
    focus focus-arc "$(now_ts)"
    commit "T-4: outside"
    commit "T-5: outside"
    run_check
    [ "$status" -eq 0 ]
    grep -q "^DRIFT|Arc focus 'focus-arc': 0 of 2 task(s) committed in the last 14 days are in it, 2 outside" <<<"$output"
    ! grep -q '^AGE' <<<"$output" || false
}

@test "handover and WM- commits are not counted as work" {
    focus focus-arc "$(now_ts)"
    commit "T-1: arc work"
    commit "T-4: Session handover S-2026-1026-1544"
    commit "T-5: Checkpoint handover S-2026-1023-1233"
    commit "T-5: handover S-2026-1023-1954 enriched"
    commit "WM-003: session state before host shutdown"
    run_check
    [[ "$output" == OK\|* ]]
    # Without the exclusion, 1 of 3 (33%) would still be OK — so prove the
    # counted set directly: only the arc commit remains, nothing outside.
    run python3 -c "import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/lib'); import arc_focus_health as a; print(sorted(a.recent_task_ids(__import__('pathlib').Path('$P'), 14)))"
    [ "$output" = "['T-1']" ]
}

@test "handover-only recent commits outside the arc do not cause DRIFT" {
    focus focus-arc "$(now_ts)"
    commit "T-4: Session handover S-2026-1026-1544"
    run_check
    [[ "$output" == OK\|* ]]
}

@test "registry: ARC_FOCUS_STALE_DAYS is registered with default 14" {
    grep -q '"ARC_FOCUS_STALE_DAYS|14|' "$FRAMEWORK_ROOT/lib/config.sh"
}

@test "callers: handover T-1661 block and fw doctor use the shared check" {
    grep -q 'arc_focus_health.py' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
    grep -q 'WARNING:\*\* arc focus may be stale' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
    grep -q 'arc_focus_health.py' "$FRAMEWORK_ROOT/bin/fw"
}
