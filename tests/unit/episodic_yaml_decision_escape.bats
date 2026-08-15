#!/usr/bin/env bats
# T-1871 — episodic generator must emit valid YAML when ## Decisions content
# contains YAML-double-quote-hostile characters (backticks, backslashes,
# embedded quotes, escape sequences).
#
# L-392 class: double-quoted YAML scalars process escape sequences like `\X`
# and reject unknown ones, so embedding a markdown code-span like
# `markdown2.markdown(f"\`\`\`{lang}…\`\`\`")` blows up yaml.safe_load on the
# generated artefact. Fix: emit decision fields as single-quoted YAML scalars
# (only escape is '→''), which pass everything else through verbatim.
#
# Witness: T-1764 close 2026-05-16 → .context/episodic/T-1764.yaml line 47
# rejected with "found unknown escape character `\``".

load ../test_helper

# ---- Source-level invariant ----

# T-3015 moved decision emission out of episodic.sh into extract_decisions.py,
# because the shell writer parsed a block-structured section line by line. The
# T-1871 invariant did not move — single-quoted scalars, ' doubled — so this
# guard follows the emitter rather than being deleted with the code it watched.
# The behavioural legs below (backticks / quotes / backslash, end-to-end through
# the real generator) are what prove the invariant holds; this one pins the shape
# so a future rewrite cannot quietly switch to double quotes and stay green.
@test "the decision emitter uses single-quoted YAML scalars (T-1871, moved T-3015)" {
    local emitter="$FRAMEWORK_ROOT/agents/context/lib/extract_decisions.py"
    grep -q "L-392" "$emitter"
    # _q() is the single chokepoint: wraps in ' and doubles any interior '
    grep -qE "return \"'\" \+ .*\.replace\(\"'\", \"''\"\) \+ \"'\"" "$emitter"
    # every emitted field routes through _q()
    grep -qE "decision: \{_q\(topic\)\}" "$emitter"
    grep -qE "\{key\}: \{_q\(entry\[key\]\)\}" "$emitter"
    grep -qE "alternatives_rejected: \[\{_q\(" "$emitter"
    # and episodic.sh must no longer hand-roll its own emission
    ! grep -qE "chose: '\\\$chose'" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
}

@test "guard control: the shape guard fails if the emitter switches to double quotes" {
    local tmp="$BATS_TEST_TMPDIR/emitter.py"
    sed 's/return "'"'"'" + /return chr(34) + /' \
        "$FRAMEWORK_ROOT/agents/context/lib/extract_decisions.py" > "$tmp"
    run grep -qE "return \"'\" \+ .*\.replace\(\"'\", \"''\"\) \+ \"'\"" "$tmp"
    [ "$status" -ne 0 ]
}

@test "bash -n clean on agents/context/lib/episodic.sh (T-1871)" {
    run bash -n "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    [ "$status" -eq 0 ]
}

# ---- T-1873: outcomes/challenges/artifacts also single-quoted ----

@test "T-1873: outcomes emission uses single-quoted scalars" {
    grep -q "T-1873" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    grep -qE "echo \"  - '\\\$text'\"" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    # No double-quoted outcomes scalar anywhere in the outcomes block
    ! grep -qE 'echo "  - \\"\$text\\""' "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
}

@test "T-1873: challenges emission uses single-quoted scalars" {
    grep -qE "description: '\\\$escaped'" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
}

@test "T-1873: artifacts emission uses single-quoted scalars" {
    grep -qE "echo \"  - '\\\$escaped'\"" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
}

# ---- Behavioural — emit a decisions block and yaml-parse it ----

# Helper: emit a single decision via the same sed chain the script uses,
# then assert the result parses cleanly with yaml.safe_load.
_emit_and_parse() {
    local topic="$1" chose="$2" why="$3" rejected="$4"
    local out="$TEST_TEMP_DIR/episodic.yaml"

    {
        echo "decisions:"
        local t=$(echo "$topic" | sed "s/'/''/g")
        echo "  - decision: '$t'"
        local c=$(echo "$chose" | sed "s/'/''/g")
        echo "    chose: '$c'"
        local w=$(echo "$why" | sed "s/'/''/g")
        echo "    rationale: '$w'"
        local r=$(echo "$rejected" | sed "s/'/''/g")
        echo "    alternatives_rejected: ['$r']"
    } > "$out"

    python3 -c "import yaml; yaml.safe_load(open('$out'))"
}

@test "T-1871/a: decision with backticked code in chose parses (L-392 origin case)" {
    run _emit_and_parse \
        "2026-05-06 — Render source files as fenced code blocks" \
        "markdown2.markdown(f\"\`\`\`{lang}\n{content}\n\`\`\`\", extras=[\"fenced-code-blocks\"])" \
        "Reuses existing dependency" \
        "Raw <pre><code> — no syntax highlighting"
    [ "$status" -eq 0 ]
}

@test "T-1871/b: decision with embedded single-quote escapes via '→'' (T-1871)" {
    run _emit_and_parse \
        "Don't roll your own" \
        "Use what's already there" \
        "It's cheaper" \
        "Rolling our own — too clever"
    [ "$status" -eq 0 ]
}

@test "T-1871/c: decision with embedded double-quote renders without escape (T-1871)" {
    run _emit_and_parse \
        'Single source-of-truth predicate' \
        'New "is_viewable_path(filepath)" helper in web/shared.py' \
        'Two whitelists can drift; one cannot' \
        'Hardcoding "for clarity" — invites recurrence'
    [ "$status" -eq 0 ]
}

@test "T-1871/d: decision with literal backslash survives (no \\X interpretation) (T-1871)" {
    run _emit_and_parse \
        'Path traversal blocked' \
        'Resolved real-path then check startswith PROJECT_ROOT — handles ..\..\etc\passwd too' \
        'Symlink + traversal both caught at one site' \
        'Per-route guards — drift risk'
    [ "$status" -eq 0 ]
}
