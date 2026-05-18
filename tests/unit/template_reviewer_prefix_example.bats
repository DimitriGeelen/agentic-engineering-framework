#!/usr/bin/env bats
# T-1895 (T-1878 A): template + CLAUDE.md surface [REVIEWER] as a peer of [REVIEW]
# at AC-author time, not just as a post-hoc conversion rule.
#
# T-1878 spike found a 412:7 [REVIEW]:[REVIEWER] adoption gap. The prefix existed
# (T-1811) but the author-time nudge didn't — agents reaching for the template
# only saw [REVIEW] as the example shape. This test pins both surfaces so the
# nudge survives future template edits.
#
# Pair: T-1896 (intervention B — structural catch via reviewer pattern
# `human-ac-mechanical-signal`) will fire when this author-time nudge is missed.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/.tasks/templates/default.md" ] || skip "template not found"
    [ -f "$FRAMEWORK_ROOT/CLAUDE.md" ] || skip "CLAUDE.md not found"
}

@test "default template Human block surfaces [REVIEWER] example alongside [REVIEW]" {
    template="$FRAMEWORK_ROOT/.tasks/templates/default.md"

    # Both prefix examples present
    grep -q "\[REVIEW\] example" "$template"
    grep -q "\[REVIEWER\] example" "$template"
}

@test "default template carries author-time decision rule for prefix routing" {
    template="$FRAMEWORK_ROOT/.tasks/templates/default.md"

    # The one-line decision rule cues the agent to default [REVIEWER] when
    # Expected is grep-able / file-exists / structural.
    grep -q "grep-able" "$template"
    grep -q "default to \[REVIEWER\]" "$template" \
        || grep -q "prefer \[REVIEWER\]" "$template"
}

@test "default template [REVIEWER] example shows the conversion path" {
    template="$FRAMEWORK_ROOT/.tasks/templates/default.md"

    # Example must mention `bin/fw reviewer` or `## Verification` so the
    # reader sees the structural target of the conversion.
    out=$(awk '/\[REVIEWER\] example/,/^     \[REVIEW\] example|^-->/' "$template")
    echo "$out" | grep -q "bin/fw reviewer" \
        || echo "$out" | grep -q "## Verification"
}

@test "CLAUDE.md AC Classification has author-time default rule citing T-1878" {
    claude_md="$FRAMEWORK_ROOT/CLAUDE.md"

    # The author-time default block must exist (added by T-1895) and must
    # cite T-1878 so the precedent chain is discoverable.
    out=$(grep -A2 "Author-time default" "$claude_md")
    echo "$out" | grep -q "T-1878"
    echo "$out" | grep -q "grep-able"
}

@test "CLAUDE.md Human AC Format Requirements lists [REVIEWER] as a peer prefix" {
    claude_md="$FRAMEWORK_ROOT/CLAUDE.md"

    # The format-requirements prefix bullet list (T-325 section) must
    # include [REVIEWER] alongside [RUBBER-STAMP] and [REVIEW]. Before
    # T-1895 the list omitted [REVIEWER], leaving a producer/consumer
    # split with §AC Classification Guidance.
    sec=$(awk '/Human AC Format Requirements/{flag=1; next} flag && /^### /{exit} flag' "$claude_md")
    echo "$sec" | grep -q "\`\[RUBBER-STAMP\]\`"
    echo "$sec" | grep -q "\`\[REVIEWER\]\`"
    echo "$sec" | grep -q "\`\[REVIEW\]\`"
}
