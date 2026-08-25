#!/usr/bin/env bats
# T-100196 (Leg 2 of T-100195/T-100194): `fw go-live` safe reconcile guard.
#
# The chosen mechanism (T-100196 Decisions: session-on-master, mechanism (c))
# is defended in depth by this guard (mechanism (b)): it consumes the same
# ahead/behind classification T-100195 introduced and routes to the SAFE
# action instead of leaving a bare `git merge origin/master` as the only
# option — the exact command that exploded into 100+ conflicts in T-100194.
#
# Three states asserted at the CLI surface (`bin/fw go-live`), each via a
# bare ORIGIN + CLONE fixture with a low FW_BRANCH_BEHIND_WARN threshold:
#   1. diverged-fork (ahead>t AND behind>t)  → REFUSED, no merge attempted
#   2. ff-clean      (ahead=0, behind>0)     → fast-forwarded
#   3. behind-threshold / nudge (0<ahead<=t, behind>t) → advisory, no merge

setup() {
    WT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FW="$WT/bin/fw"
    FIX="$BATS_TEST_TMPDIR/fix"
    ORIGIN="$FIX/origin.git"
    CLONE="$FIX/clone"
    mkdir -p "$FIX"
    git init --bare -q -b master "$ORIGIN"
    git clone -q "$ORIGIN" "$CLONE" 2>/dev/null
    cd "$CLONE"
    git config user.email t@t && git config user.name t
    git checkout -q -b master
    echo one > f.txt && git add f.txt && git commit -qm c1
    echo two >> f.txt && git commit -qam c2
    git push -q origin master

    mkdir -p "$CLONE/.tasks"
    export PROJECT_ROOT="$CLONE"
    export FRAMEWORK_ROOT="$WT"
    export FW_BRANCH_BEHIND_WARN=2
}

@test "go-live: diverged-fork (ahead>t AND behind>t) → REFUSED, no merge attempted" {
    for i in 1 2 3; do echo "c$i" >> c.txt && git -C "$CLONE" add c.txt && git -C "$CLONE" commit -qm "c$i"; done
    HEAD_BEFORE=$(git -C "$CLONE" rev-parse HEAD)
    # advance origin/master via a second clone so origin/master moves independently
    SECOND="$FIX/second"
    git clone -q "$ORIGIN" "$SECOND" 2>/dev/null
    git -C "$SECOND" config user.email t@t && git -C "$SECOND" config user.name t
    for i in 1 2 3; do echo "m$i" >> "$SECOND/f.txt" && git -C "$SECOND" commit -qam "m$i"; done
    git -C "$SECOND" push -q origin master

    run "$FW" go-live
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "REFUSED"
    echo "$output" | grep -qi "diverged-fork"
    if echo "$output" | grep -qi "fast-forward"; then false; fi
    # never attempted a merge: HEAD unchanged, no MERGE_HEAD left behind
    [ "$(git -C "$CLONE" rev-parse HEAD)" = "$HEAD_BEFORE" ]
    [ ! -f "$CLONE/.git/MERGE_HEAD" ]
}

@test "go-live: ff-clean (ahead=0, behind>0) → fast-forwarded" {
    SECOND="$FIX/second"
    git clone -q "$ORIGIN" "$SECOND" 2>/dev/null
    git -C "$SECOND" config user.email t@t && git -C "$SECOND" config user.name t
    for i in 1 2 3; do echo "m$i" >> "$SECOND/f.txt" && git -C "$SECOND" commit -qam "m$i"; done
    git -C "$SECOND" push -q origin master

    run "$FW" go-live
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "ff-clean"
    echo "$output" | grep -qi "fast-forward"
    # HEAD now matches the advanced origin/master
    git -C "$CLONE" fetch -q origin
    [ "$(git -C "$CLONE" rev-parse HEAD)" = "$(git -C "$CLONE" rev-parse origin/master)" ]
}

@test "go-live: behind-threshold / nudge (0<ahead<=t, behind>t) → advisory, no merge attempted" {
    echo lf > lf.txt && git -C "$CLONE" add lf.txt && git -C "$CLONE" commit -qm lf
    HEAD_BEFORE=$(git -C "$CLONE" rev-parse HEAD)
    SECOND="$FIX/second"
    git clone -q "$ORIGIN" "$SECOND" 2>/dev/null
    git -C "$SECOND" config user.email t@t && git -C "$SECOND" config user.name t
    for i in 1 2 3; do echo "m$i" >> "$SECOND/f.txt" && git -C "$SECOND" commit -qam "m$i"; done
    git -C "$SECOND" push -q origin master

    run "$FW" go-live
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "behind-threshold"
    echo "$output" | grep -qi "fw integrate run"
    if echo "$output" | grep -qi "REFUSED"; then false; fi
    # advisory only — never attempts a merge
    [ "$(git -C "$CLONE" rev-parse HEAD)" = "$HEAD_BEFORE" ]
    [ ! -f "$CLONE/.git/MERGE_HEAD" ]
}

@test "go-live: up to date → no-op, exit 0" {
    run "$FW" go-live
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "up to date"
}
