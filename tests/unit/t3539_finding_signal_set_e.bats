#!/usr/bin/env bats
# T-3539: a finding-signal return code must not silently kill its caller.
#
# THE DEFECT, IN ONE LINE
#
#   out=$(inception_underdisposed_questions "$f")   # under `set -euo pipefail`
#
# That function returns 1 to mean "I FOUND under-disposed questions" — a finding,
# not an error. Under `set -e` the assignment propagates the 1 and the script dies
# THERE, before the warning the function exists to trigger can be printed.
#
# Measured blast radius: all three call sites had the unguarded form, so
# `fw task review`, `fw inception decide` AND `fw task update --status
# work-completed` were all silently broken for any inception with an undisposed
# question. `fw task review T-3532` exited 1 printing NOTHING, and Watchtower —
# handed a non-zero exit and two empty streams — could only say "Unknown error
# from fw inception decide". The operator spent a round trip on it.
#
# WHY THESE TESTS AND NOT A UNIT TEST OF THE FUNCTION
#
# The function is CORRECT in isolation and always was. `bats` running it directly
# would be green against the broken tree. The bug lives in the composition of the
# function's contract with the caller's shell options, so the tests reproduce that
# composition — including a control proving the unguarded form really does die,
# because a test that cannot fail against the pre-fix code measures nothing.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    FIX="$(mktemp -d)"
    cat > "$FIX/inception.md" <<'MD'
---
id: T-9999
workflow_type: inception
---
# T-9999
## Open Questions

- **IW-1: A question nobody disposed**
  confidence: 1
  disposition:
  rationale:

## Next Section
MD
}

teardown() { rm -rf "$FIX" 2>/dev/null; }

# ── the contract: it really does return non-zero on a FINDING ────────────────

@test "t3539: the function returns non-zero when it FINDS under-disposed questions" {
    run bash -c "
        export PROJECT_ROOT='$REPO_ROOT' FRAMEWORK_ROOT='$REPO_ROOT'
        source '$REPO_ROOT/lib/inception-readiness.sh'
        inception_underdisposed_questions '$FIX/inception.md' > /dev/null
    "
    [ "$status" -eq 1 ]
}

@test "t3539: ...and still prints the finding on stdout — the rc is redundant" {
    run bash -c "
        export PROJECT_ROOT='$REPO_ROOT' FRAMEWORK_ROOT='$REPO_ROOT'
        source '$REPO_ROOT/lib/inception-readiness.sh'
        inception_underdisposed_questions '$FIX/inception.md' || true
    "
    [[ "$output" == *"IW-1"* ]]
}

# ── the hazard, and the control that proves the hazard is real ───────────────

@test "t3539 CONTROL: the UNGUARDED assignment dies under set -euo pipefail" {
    run bash -c "
        set -euo pipefail
        export PROJECT_ROOT='$REPO_ROOT' FRAMEWORK_ROOT='$REPO_ROOT'
        source '$REPO_ROOT/lib/inception-readiness.sh'
        _u=\$(inception_underdisposed_questions '$FIX/inception.md')
        echo SURVIVED
    "
    [ "$status" -ne 0 ]
    [[ "$output" != *"SURVIVED"* ]]
}

@test "t3539: the GUARDED assignment survives and keeps the finding" {
    run bash -c "
        set -euo pipefail
        export PROJECT_ROOT='$REPO_ROOT' FRAMEWORK_ROOT='$REPO_ROOT'
        source '$REPO_ROOT/lib/inception-readiness.sh'
        _u=\$(inception_underdisposed_questions '$FIX/inception.md') || true
        [ -n \"\$_u\" ] && echo SURVIVED
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"SURVIVED"* ]]
}

# ── every real call site carries the guard ───────────────────────────────────
#
# Structural, because the behavioural test above cannot reach all three without
# standing up three full fixture projects. If a fourth call site is added without
# the guard, this goes red.

@test "t3539: every inception_underdisposed_questions call site is guarded" {
    run bash -c "
        cd '$REPO_ROOT'
        grep -rn 'inception_underdisposed_questions' lib/ agents/ \
          | grep -v '.agentic-framework' \
          | grep '=\$(' \
          | grep -v '|| true' \
          | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'
    "
    # grep exits 1 when it finds nothing, which is the passing case here.
    [ "$status" -ne 0 ] || {
        echo "UNGUARDED call site(s) found:"; echo "$output"; false
    }
}

@test "t3539: the caller contract is documented at the source" {
    run grep -c "CALLER CONTRACT" "$REPO_ROOT/lib/inception-readiness.sh"
    [ "$status" -eq 0 ]
}
