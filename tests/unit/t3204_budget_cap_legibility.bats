#!/usr/bin/env bats
# T-3204: the budget gauge's denominator is a CONFIGURED CAP, and now says so.
#
# CONTEXT_WINDOW (default 300000) was never an estimate of the model's context
# window — its own comment called it "a safe default for quality + cost control".
# But five reader-facing messages reported the ratio as "% of context window",
# which reads as a hard limit approaching rather than as a policy dial sitting at
# its configured value. Those two readings license opposite actions.
#
# This task changed WORDING and added an OPT-IN model field. It deliberately did
# not change the cap's value or the 75/85/95 ladder — so the pins below assert
# non-behaviour as hard as they assert behaviour.
#
# ── on negations ──────────────────────────────────────────────────────────────
# `! cmd` at statement position is INERT in bats (POSIX exempts `set -e` for any
# command preceded by `!`, and bats reads only the last command's status). This
# file uses `if cmd; then false; fi`. Found the hard way in T-3199, where five
# such assertions had been inert for months; sibling lint tracked in T-3191.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CT="$REPO_ROOT/lib/context_tokens.py"
    FIX="$BATS_TEST_TMPDIR/t.jsonl"

    # Two usage entries from one model: compute_context_tokens_detail refuses to
    # scope on fewer than two ("fail-open, not fail-guess"), so one entry would
    # exercise the refusal path rather than the path under test.
    cat > "$FIX" <<'EOF'
{"timestamp":"2026-08-28T10:00:00Z","message":{"model":"claude-opus-5","usage":{"input_tokens":100,"cache_read_input_tokens":900}}}
{"timestamp":"2026-08-28T10:01:00Z","message":{"model":"claude-opus-5","usage":{"input_tokens":200,"cache_read_input_tokens":4800}}}
EOF
}

# ── the opt-in contract ───────────────────────────────────────────────────────

@test "CONTROL: default stdout is a bare integer — the contract both gauges parse" {
    # This is the control that makes the --with-model tests mean something, and
    # it is also the highest-stakes assertion in the file: checkpoint.sh and
    # budget-gate.sh both capture this straight into a shell integer, so an
    # unconditional extra field would corrupt CONTEXT_TOKENS in BOTH at once.
    run bash -c "python3 '$CT' '' < '$FIX'"
    [ "$status" -eq 0 ]
    [ "$output" = "5000" ]
    if printf '%s' "$output" | grep -q 'claude'; then false; fi
    if printf '%s' "$output" | grep -qP '\t'; then false; fi
}

@test "--with-model emits tokens TAB model" {
    run bash -c "python3 '$CT' '' --with-model < '$FIX'"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | cut -f1)" = "5000" ]
    [ "$(printf '%s' "$output" | cut -f2)" = "claude-opus-5" ]
}

@test "a flag alone is accepted as the only argument" {
    # Characterization, NOT discrimination — stated plainly because the first
    # version of this test claimed to catch a positional parse and did not.
    # A positional parse also passes this case: every flag begins with '-'
    # (0x2D), which sorts BELOW every ISO-8601 digit, so a flag mistaken for a
    # timestamp filters nothing and the answer comes out right by accident.
    # The test below is the one that discriminates.
    run bash -c "python3 '$CT' --with-model < '$FIX'"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | cut -f1)" = "5000" ]
    [ "$(printf '%s' "$output" | cut -f2)" = "claude-opus-5" ]
}

@test "a timestamp AFTER a flag is still honoured as the timestamp" {
    # This is the discriminating case. Positional parsing binds argv[1] —
    # "--with-model" — as the session start and silently ignores the real
    # timestamp, so nothing is filtered and the full 5000 comes back. Flag-aware
    # parsing binds the timestamp, drops the 10:00:00Z entry as pre-session,
    # leaves one in-scope entry, and the module's own "fail-open, not fail-guess"
    # floor returns 0. The two implementations differ here and nowhere else.
    run bash -c "python3 '$CT' --with-model '2026-08-28T10:00:30Z' < '$FIX'"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | cut -f1)" = "0" ]
}

@test "a token count we refused to trust reports no model either" {
    # Below two in-scope entries the module returns 0 rather than guess. The
    # model must go empty with it — reporting a confident model beside a refused
    # count would be the same false-green shape this task is about.
    #
    # ONE entry, not zero: an empty transcript returns from the `if not entries`
    # branch and never reaches the `len(in_scope) < 2` floor this pins. The first
    # version of this test used an empty file and was therefore inert against a
    # mutation of that floor — caught by mutation M4, not by review.
    head -1 "$FIX" > "$BATS_TEST_TMPDIR/one.jsonl"
    run bash -c "python3 '$CT' '' --with-model < '$BATS_TEST_TMPDIR/one.jsonl'"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | cut -f1)" = "0" ]
    [ -z "$(printf '%s' "$output" | cut -f2)" ]
}

@test "an empty transcript also yields no count and no model" {
    printf '' > "$BATS_TEST_TMPDIR/empty.jsonl"
    run bash -c "python3 '$CT' '' --with-model < '$BATS_TEST_TMPDIR/empty.jsonl'"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | cut -f1)" = "0" ]
    [ -z "$(printf '%s' "$output" | cut -f2)" ]
}

# ── the wording ───────────────────────────────────────────────────────────────

@test "no message in either gauge still calls the cap a context window" {
    for f in agents/context/checkpoint.sh agents/context/budget-gate.sh; do
        if grep -q '^[[:space:]]*echo.*of context window' "$REPO_ROOT/$f"; then
            echo "still misleading: $f" >&2
            false
        fi
    done
}

@test "every percentage message names the cap and its value" {
    # Paired with the test above: that one proves the old phrasing is gone, this
    # one proves something correct replaced it rather than the text being deleted.
    for f in agents/context/checkpoint.sh agents/context/budget-gate.sh; do
        run grep -c 'echo.*budget cap' "$REPO_ROOT/$f"
        [ "$status" -eq 0 ]
        [ "$output" -ge 3 ]
    done
    grep -q 'CONTEXT_WINDOW}-token budget cap' "$REPO_ROOT/agents/context/checkpoint.sh"
    grep -q 'CONTEXT_WINDOW}-token budget cap' "$REPO_ROOT/agents/context/budget-gate.sh"
}

@test "status names the model the cap is being applied to, and how to change it" {
    grep -q 'the cap is a configured dial, not this model' "$REPO_ROOT/agents/context/checkpoint.sh"
    grep -q 'config set CONTEXT_WINDOW' "$REPO_ROOT/agents/context/checkpoint.sh"
}

# ── the non-behaviour pins ────────────────────────────────────────────────────

@test "the cap's value is UNCHANGED at 300000 in both gauges" {
    # T-3204 is a legibility change. If this reddens, someone converted a
    # deliberate cost-control policy into a derived value — which is an operator
    # decision, explicitly surfaced rather than taken (see the task's Recommendation).
    run grep -c 'fw_config_int "CONTEXT_WINDOW" 300000' "$REPO_ROOT/agents/context/checkpoint.sh"
    [ "$output" = "1" ]
    run grep -c 'fw_config_int "CONTEXT_WINDOW" 300000' "$REPO_ROOT/agents/context/budget-gate.sh"
    [ "$output" = "1" ]
}

@test "the 75/85/95 ladder ratios are UNCHANGED in both gauges" {
    for f in agents/context/checkpoint.sh agents/context/budget-gate.sh; do
        grep -q 'TOKEN_WARN=$((CONTEXT_WINDOW \* 75 / 100))' "$REPO_ROOT/$f"
        grep -q 'TOKEN_URGENT=$((CONTEXT_WINDOW \* 85 / 100))' "$REPO_ROOT/$f"
        grep -q 'TOKEN_CRITICAL=$((CONTEXT_WINDOW \* 95 / 100))' "$REPO_ROOT/$f"
    done
}

@test "both gauges still parse" {
    bash -n "$REPO_ROOT/agents/context/checkpoint.sh"
    bash -n "$REPO_ROOT/agents/context/budget-gate.sh"
}
