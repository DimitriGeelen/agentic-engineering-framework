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
    SEED="T-003"
    SEEDEP="T-002"
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

@test "T-2999: a body MENTION of the task does not satisfy the assertion" {
    # THE CONTROL THAT WAS MISSING. Every earlier behavioural test built a repo
    # where the seed commit either existed or nothing referenced the task at
    # all. The case in between -- task mentioned, never committed -- is the only
    # one that separates "a commit whose SUBJECT is this task" from "the string
    # appears somewhere in history", and it is exactly where the shipped form
    # returned a false green.
    cd "$SB"
    git init -q . && git config user.email t@t && git config user.name t
    # UNQUOTED heredoc: $SEED must expand, or the body never contains the id
    # and this control exercises nothing. (It did exactly that once — the id was
    # replaced with prose to dodge the focus-drift gate, and the test then passed
    # against the known-broken line.)
    git commit -q --allow-empty -F - <<MSG
TX-016: close gate

also finishes work related to $SEED and TX-015
MSG

    local line
    line=$(_verif "$GF" | tail -1)
    run bash -c "set -eo pipefail; cd '$SB'; $line"
    [ "$status" -ne 0 ] || {
        echo "body mention satisfied the assertion -- false green" >&2; return 1; }
}

@test "T-2999: the assertion checks the subject it MATCHED, not any subject" {
    # Second half of the same defect: --grep selects the commit, --format prints
    # THAT commit's subject. A body match therefore surfaces an unrelated
    # subject, and a bare -n test cannot notice. Here the real commit exists AND
    # an earlier one mentions the task, so a correct assertion must pass while
    # selecting the right commit.
    cd "$SB"
    git init -q . && git config user.email t@t && git config user.name t
    git commit -q --allow-empty -F - <<MSG
TX-020: unrelated work

mentions $SEED in passing
MSG
    git commit -q --allow-empty -m "$SEED: Initial project structure"
    git commit -q --allow-empty -m "TX-021: later work"

    local line
    line=$(_verif "$GF" | tail -1)
    run bash -c "set -eo pipefail; cd '$SB'; $line"
    [ "$status" -eq 0 ]

    run bash -c "cd '$SB'; git log --grep=\"^$SEED:\" -1 --format=%s"
    [ "$output" = "$SEED: Initial project structure" ] || {
        echo "selected the wrong commit: $output" >&2; return 1; }
}

@test "T-2999: both seeds anchor the pattern and compare the subject" {
    # Not capture-then-grep. That repair still SIGPIPEs once the capture exceeds
    # the 65536-byte pipe buffer, and P-011 caught it doing exactly that against
    # this repo's 608KB log. git log --grep filters inside git: no pipe exists.
    _verif "$GF" | grep -q "git log --grep='\^$SEED:' -1"
    _verif "$EP" | grep -q "git log --grep='\^$SEEDEP:' -1"
    _verif "$GF" | grep -q '\${s%%:\*}'
    _verif "$EP" | grep -q '\${s%%:\*}'
}

@test "T-2996: neither seed executes ANY pipe in its assertion" {
    # The strongest form of the L-387 guard: no pipeline, nothing to SIGPIPE,
    # at any history length. Weaker shape-checks kept passing while the line
    # was still broken.
    local f
    for f in "$GF" "$EP"; do
        run bash -c "$(declare -f _verif); _verif '$f' | grep -c '|'"
        [ "$output" = "0" ] || { echo "assertion in $f still contains a pipe" >&2; return 1; }
    done
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
    # writing. Note the capture-then-grep form does NOT escape this -- it only
    # moves the threshold to the 65536-byte pipe buffer, which is where this
    # task's first repair died (rc=141 against a 608KB log). Only the pipe-free
    # form is safe at any length.
    cd "$SB"
    git init -q . && git config user.email t@t && git config user.name t
    git commit -q --allow-empty -m "T-003: Initial project structure"
    # 1200 commits with long subjects: the log must exceed the 65536-byte pipe
    # buffer, or this test cannot see the failure it exists for. The 400-commit
    # version passed against the broken capture-then-grep form.
    for i in $(seq 1 1200); do
        git commit -q --allow-empty -m "filler commit $i — padding to push the log past the pipe buffer"
    done
    [ "$(git log --format=%s | wc -c)" -gt 65536 ]

    local line
    line=$(_verif "$GF" | tail -1)
    run bash -c "set -eo pipefail; cd '$SB'; $line"
    [ "$status" -eq 0 ] || { echo "rc=$status (141 = SIGPIPE)" >&2; return 1; }
}
