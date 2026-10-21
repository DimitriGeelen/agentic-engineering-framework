#!/usr/bin/env bats
#
# T-4536 — T-4512 made the curl/wget check refuse any word that begins with a
# quoted expansion ("$X" could expand to -o FILE). That is right when X comes
# from the environment, and it turned T-3644's `WURL=x; curl -sf "$WURL/"` red.
# The fix honours an expansion only of a name THIS line assigned a literal that
# cannot begin an option, carried only across && / ; into further literal
# assignments or the curl/wget clause itself. Everything else stays refused.
#
# `! cmd` at statement position is INERT in bats (L-628) — this file uses
# `if cmd; then false; fi` for NOT-SAFE assertions.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

_safe()   { is_bash_safe_command "$1" || { echo "UNSAFE: $1"; false; }; }
_unsafe() { if is_bash_safe_command "$1"; then echo "SAFE: $1"; false; fi; }

# ── admitted: the line itself fixed the value ────────────────────────────────

@test "T-4536: 'WURL=x; curl -sf \"\$WURL/\"' is SAFE"   { _safe 'WURL=x; curl -sf "$WURL/"'; }
@test "T-4536: && chain, URL literal, is SAFE"            { _safe 'U=http://h:1 && curl -sf "$U/x"'; }
@test "T-4536: braced \${W} expansion is SAFE"            { _safe 'W=x; curl "${W}/a"'; }
@test "T-4536: two literal assignments then curl is SAFE" { _safe 'H=h; P=1; curl -sf "$H:$P/x"'; }

# ── refused: the value is unknown or may begin an option ─────────────────────

@test "T-4536 neg: env-supplied '\$WURL' alone is NOT-SAFE"     { _unsafe 'curl -sf "$WURL/"'; }
@test "T-4536 neg: literal starting with - is NOT-SAFE"         { _unsafe 'WURL=-ofile; curl -sf "$WURL/"'; }
@test "T-4536 neg: empty literal is NOT-SAFE"                   { _unsafe 'W=; curl "$W-ofile"'; }
@test "T-4536 neg: backslash-escaped dash is NOT-SAFE"          { _unsafe 'W=\-o; curl "$W/"'; }
@test "T-4536 neg: reassigned to an option is NOT-SAFE"         { _unsafe 'W=x; W=-o; curl "$W"'; }
@test "T-4536 neg: read between assignment and curl is NOT-SAFE" { _unsafe 'W=x; read W; curl "$W/"'; }
@test "T-4536 neg: export between is NOT-SAFE"                  { _unsafe 'W=x; export W=-o; curl "$W/"'; }
@test "T-4536 neg: loop variable shadows it, NOT-SAFE"          { _unsafe 'W=x; for W in -o; do curl "$W/"; done'; }
@test "T-4536 neg: || does not carry the assignment"            { _unsafe 'W=x || curl "$W/"'; }
@test "T-4536 neg: longer name \$Wy is not \$W"                 { _unsafe 'W=x; curl "$Wy"'; }
@test "T-4536 neg: unassigned other name is NOT-SAFE"           { _unsafe 'W=x; curl "$V"'; }
@test "T-4536 neg: -o FILE still a write with a known var"      { _unsafe 'U=http://h; curl -o f "$U"'; }
