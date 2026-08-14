#!/usr/bin/env bats
# T-2996 (G-006): the onboarding seeds asserted a property of HEAD.
#
# `git log -1 --format=%s | grep -q "T-003"` is true at the moment the seed task
# completes and false from the next commit onward. Every project built on AEF
# inherited a CTL-013 that fires forever and that no consumer action clears —
# and `fw update` overwrites any local fix.
#
# The load-bearing tests are the two behavioural ones at the bottom. They build
# throwaway repos and run the seed's actual assertion under P-011's real
# conditions (`set -eo pipefail`), rather than asserting on the text of the file.
# The text tests above them exist only to catch a regression to the old shape.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    GF="$FRAMEWORK_ROOT/lib/seeds/tasks/greenfield/T-003-first-governed-commit.md"
    EP="$FRAMEWORK_ROOT/lib/seeds/tasks/existing-project/T-002-first-governed-commit.md"
    [ -f "$GF" ] && [ -f "$EP" ] || skip "seed files not found"
    SB="$(mktemp -d)"
}

teardown() { rm -rf "$SB" 2>/dev/null; }

# Extract the executable (non-comment, non-blank) lines of a seed's Verification.
_verif() {
    awk '/^## Verification$/{f=1;next} f && /^## /{exit} f && !/^[[:space:]]*#/ && NF' "$1"
}

# --- shape: the old form must not come back ---

@test "T-2996: no seed EXECUTES an assertion on HEAD alone" {
    # Executable lines only. The seeds now carry a comment explaining why
    # `git log -1` is wrong, and a whole-file grep flags that explanation —
    # scanning prose about a pattern as if it were the pattern. (Exactly the
    # trap that turned a structural invariant red in T-2990.)
    local f hits=""
    for f in "$FRAMEWORK_ROOT"/lib/seeds/tasks/*/*.md; do
        [ -f "$f" ] || continue
        if _verif "$f" | grep -q 'git log -1'; then hits="$hits $f"; fi
    done
    [ -z "$hits" ] || { echo "executable 'git log -1' in:$hits" >&2; return 1; }
}

@test "T-2996: neither seed pipes git log straight into grep -q (L-387)" {
    local f
    for f in "$GF" "$EP"; do
        # The offending shape is git log's OWN stdout going into grep. Excluding
        # `;` and `)` from the gap is what distinguishes it from the capture
        # form, which legitimately pipes later on the same line:
        #   out=$(git log --format=%s); echo "$out" | grep -q "T-003"
        # A gap of `[^|]*` matches straight across that `;` and flags the fix.
        run bash -c "$(declare -f _verif); _verif '$f' | grep -cE 'git log[^;)|]*\| *grep'"
        [ "$output" = "0" ] || { echo "pipeline form still in $f" >&2; return 1; }
    done
}

@test "T-2996: both seeds use the capture-then-grep shape" {
    _verif "$GF" | grep -q 'out=$(git log --format=%s)'
    _verif "$EP" | grep -q 'out=$(git log --format=%s)'
}

# --- behaviour: the whole point ---

@test "T-2996: the assertion survives commits made after the seed task" {
    # This is the exact reproduction from the consumer report: complete the seed
    # commit, then make ANY later commit. The old form went red here forever.
    cd "$SB"
    git init -q . && git config user.email t@t && git config user.name t
    git commit -q --allow-empty -m "T-003: Initial project structure"
    git commit -q --allow-empty -m "some later unrelated work"
    git commit -q --allow-empty -m "and another"

    local line
    line=$(_verif "$GF" | tail -1)
    # Run it the way P-011 does — pipefail included (T-2743: an interactive
    # shell does not rehearse the gate).
    run bash -c "set -eo pipefail; cd '$SB'; $line"
    [ "$status" -eq 0 ] || { echo "assertion went red after later commits: $line" >&2; return 1; }
}

@test "T-2996: the assertion still fails when no commit references the task" {
    # Positive control. Without this, a line that always returns 0 would satisfy
    # the test above and look identical to a working check.
    cd "$SB"
    git init -q . && git config user.email t@t && git config user.name t
    git commit -q --allow-empty -m "nothing to do with the seed"

    local line
    line=$(_verif "$GF" | tail -1)
    run bash -c "set -eo pipefail; cd '$SB'; $line"
    [ "$status" -ne 0 ] || { echo "assertion passed with no matching commit — it is vacuous" >&2; return 1; }
}

@test "T-2996: the existing-project seed behaves the same" {
    cd "$SB"
    git init -q . && git config user.email t@t && git config user.name t
    git commit -q --allow-empty -m "T-002: adopt the framework"
    git commit -q --allow-empty -m "later work"

    local line
    line=$(_verif "$EP" | tail -1)
    run bash -c "set -eo pipefail; cd '$SB'; $line"
    [ "$status" -eq 0 ]
}

@test "T-2996: it holds on a long history (the SIGPIPE case)" {
    # L-387 fires when grep matches early and closes stdin while git is still
    # writing. With the match at the very bottom of a long log, the old pipeline
    # form is most exposed; the capture form cannot be.
    cd "$SB"
    git init -q . && git config user.email t@t && git config user.name t
    git commit -q --allow-empty -m "T-003: Initial project structure"
    for i in $(seq 1 400); do git commit -q --allow-empty -m "filler commit $i"; done

    local line
    line=$(_verif "$GF" | tail -1)
    run bash -c "set -eo pipefail; cd '$SB'; $line"
    [ "$status" -eq 0 ] || { echo "rc=$status (141 = SIGPIPE)" >&2; return 1; }
}
