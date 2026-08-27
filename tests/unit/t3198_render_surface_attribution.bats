#!/usr/bin/env bats
# T-3198 (supersedes T-2840) — render-surface attribution must read the commit
# SUBJECT, not the whole message.
#
# The subject is where this repo records AUTHORSHIP ("T-3186: fix the thing").
# The body is where it records CROSS-REFERENCES ("unblocks T-3186", "origin:
# T-2837"). _render_surface_git_touched_paths used --grep over the whole
# message, so a commit that merely mentioned another task donated its entire
# footprint to it.
#
# Measured live before the fix: T-3186, T-3194 and T-2837 were each credited
# with web/blueprints/config.py by donor commits they did not author, and all
# three closes spent a --skip-render-review Tier-2 bypass on a false positive.
#
# THE CONTROL LEG IS THE POINT. "Narrows correctly" and "turned the rail off"
# emit an identical diff and an identical green suite. Only the paired
# assertion — the true owner STILL fires — separates them. Tests 3, 4 and 6
# exist for that reason and must not be deleted as redundant.

load ../test_helper

setup() {
    # test_helper's teardown expects TEST_TEMP_DIR; this setup() overrides its
    # setup(), so establish it here or every test fails in teardown.
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    REPO="$TEST_TEMP_DIR/attrib-repo"
    mkdir -p "$REPO"
    cd "$REPO" || return 1
    git init -q .
    git config user.email t3198@test
    git config user.name t3198
    git config commit.gpgsign false

    # --- commit A: T-9001 authors a NON-render file -------------------------
    mkdir -p lib web/templates web/blueprints
    echo "one" > lib/alpha.sh
    git add -A
    git commit -qm "T-9001: touch only a non-render file"

    # --- commit B: T-9002 authors a RENDER file and MENTIONS T-9001 ---------
    # This is the donor shape. The body cross-reference is the ordinary,
    # desirable habit of recording what a commit unblocks.
    echo "two" > web/templates/donor.html
    git add -A
    git commit -qm "T-9002: touch a render surface" -m "Unblocks T-9001, which was waiting on this."

    # --- commit C: T-9003 genuinely authors a render file -------------------
    echo "three" > web/blueprints/genuine.py
    git add -A
    git commit -qm "T-9003: genuinely edit a blueprint"

    # --- commit D: T-9004 appears ONLY in a body, never in a subject --------
    # Exercises the retained whole-message fallback.
    echo "four" > web/templates/fallback.html
    git add -A
    git commit -qm "chore: no task prefix on this subject" -m "Relates to T-9004."

    # --- commit E: prefix-collision guard -----------------------------------
    # T-900 must not inherit T-9001's footprint by substring.
    echo "five" > web/templates/collide.html
    git add -A
    git commit -qm "T-9005: unrelated render edit"

    source "$FRAMEWORK_ROOT/lib/render_surface.sh"
}

touched() { _render_surface_git_touched_paths "$1"; }

# ---- The defect ---------------------------------------------------------

@test "T-3198: a body cross-reference does NOT donate the donor's render file" {
    run touched T-9001
    [ "$status" -eq 0 ]
    # T-9001 authored lib/alpha.sh only.
    echo "$output" | grep -q "lib/alpha.sh"
    # web/templates/donor.html belongs to T-9002, which merely mentioned T-9001.
    ! echo "$output" | grep -q "web/templates/donor.html"
}

@test "T-3198: the mis-attributed task no longer trips the render-surface gate" {
    cat > "$TEST_TEMP_DIR/T-9001-x.md" <<'EOF'
---
id: T-9001
---
# body
EOF
    run task_touches_render_surface "$TEST_TEMP_DIR/T-9001-x.md"
    # 1 == does not touch a render surface
    [ "$status" -eq 1 ]
}

# ---- Control legs: narrowing must not turn the rail OFF ------------------

@test "T-3198/control: the donor itself still owns its render file" {
    run touched T-9002
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "web/templates/donor.html"
}

@test "T-3198/control: a genuine subject-attributed render edit still fires the gate" {
    cat > "$TEST_TEMP_DIR/T-9003-x.md" <<'EOF'
---
id: T-9003
---
# body
EOF
    run task_touches_render_surface "$TEST_TEMP_DIR/T-9003-x.md"
    # 0 == touches a render surface; the gate must still catch this
    [ "$status" -eq 0 ]
}

@test "T-3198/control: render_surface_files_in still names the genuine file" {
    cat > "$TEST_TEMP_DIR/T-9003-y.md" <<'EOF'
---
id: T-9003
---
# body
EOF
    run render_surface_files_in "$TEST_TEMP_DIR/T-9003-y.md"
    echo "$output" | grep -q "web/blueprints/genuine.py"
}

# ---- The retained fallback ----------------------------------------------

@test "T-3198/fallback: body-only reference still resolves when no subject claims the task" {
    # Nothing carries "T-9004:" in a subject, so the broad whole-message grep
    # is reached and behaves exactly as it did before this change. This is what
    # makes the fix strictly false-positive-reducing rather than a trade.
    run touched T-9004
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "web/templates/fallback.html"
}

# ---- Prefix collision ----------------------------------------------------

@test "T-3198: a shorter task id does not substring-match a longer one" {
    # T-900 is a prefix of T-9001..T-9005. It authored nothing.
    run touched T-900
    [ "$status" -eq 0 ]
    # [[ != ]] rather than `! ... | grep`: a !-negated command is exempt from
    # errexit, so in any position but the last it asserts nothing. Caught by
    # tools/bats-dead-negation-lint.py — mutation testing could not see it,
    # because the live second assertion reddened for the same mutations.
    [[ "$output" != *"lib/alpha.sh"* ]]
    [[ "$output" != *"web/templates/collide.html"* ]]
}

# ---- Source-level ---------------------------------------------------------

@test "T-3198: helper is syntactically valid and both consumers share it" {
    bash -n "$FRAMEWORK_ROOT/lib/render_surface.sh"
    # task_touches_render_surface + render_surface_files_in + the definition
    run grep -c "_render_surface_git_touched_paths" "$FRAMEWORK_ROOT/lib/render_surface.sh"
    [ "$output" -ge 3 ]
}
