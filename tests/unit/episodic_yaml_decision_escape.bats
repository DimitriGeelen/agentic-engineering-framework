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

@test "episodic.sh emits decision fields as single-quoted YAML scalars (T-1871)" {
    grep -q "T-1871" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    # decision topic line: - decision: '$topic'
    grep -qE "decision: '\\\$topic'" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    # chose / rationale / alternatives_rejected all single-quoted
    grep -qE "chose: '\\\$chose'" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    grep -qE "rationale: '\\\$why'" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    grep -qE "alternatives_rejected: \[''?\\\$rej''?\]" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    # escape sed must be '→'' not "→\"
    grep -qE "sed \"s/'/''/g\"" "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
}

@test "bash -n clean on agents/context/lib/episodic.sh (T-1871)" {
    run bash -n "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    [ "$status" -eq 0 ]
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
