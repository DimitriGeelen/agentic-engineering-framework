#!/usr/bin/env bats
#
# T-3644 — a segment that is ONLY a literal assignment (`WURL=x; curl ...`)
# writes nothing and runs nothing, so the read-only classifier must admit it.
# Ported from 055-agentic-fleet-cockpit (framework:pickup offset 227, their
# task 316), re-derived against our code. T-3466 (F-15) already admits a
# TERMINAL `VAR=$(cmd)`; this is the literal-value remainder.
#
# Traps 055 documented, kept as negative corpus:
#   - `^NAME=(.*)$` also matches `X=1 rm -rf /` — refuse if anything follows
#   - `X=$(cat a && rm b)` must not ride a single-command check
#   - backticks are a command substitution too
# Plus ours: a bare `PATH=/tmp; cat x` changes what `cat` RESOLVES to for the
# rest of the line, so the T-3374 env-prefix denylist applies here as well.
#
# `! cmd` at statement position is INERT in bats (L-628) — this file uses
# `if cmd; then false; fi` for NOT-SAFE assertions.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

_safe()   { is_bash_safe_command "$1" || { echo "UNSAFE: $1"; false; }; }
_unsafe() { if is_bash_safe_command "$1"; then echo "SAFE: $1"; false; fi; }

# ── admitted ─────────────────────────────────────────────────────────────────

@test "T-3644: 'WURL=x; curl -sf \"\$WURL/\"' is SAFE" { _safe 'WURL=x; curl -sf "$WURL/"'; }
@test "T-3644: bare 'X=1' is SAFE"                  { _safe 'X=1'; }
@test "T-3644: double-quoted value is SAFE"         { _safe 'X="a b"; echo "$X"'; }
@test "T-3644: single-quoted value is SAFE"         { _safe "X='a b'; echo \"\$X\""; }
@test "T-3644: empty value is SAFE"                 { _safe 'X=; echo hi'; }
@test "T-3644: parameter expansion in value is SAFE" { _safe 'X=$HOME/y; ls "$X"'; }
@test "T-3644: && chain with literal assignment is SAFE" { _safe 'U=http://h:1 && curl -sf "$U/x"'; }
@test "T-3644 control: T-3466 terminal 'X=\$(cat f)' stays SAFE" { _safe 'X=$(cat f)'; }

# ── refused ──────────────────────────────────────────────────────────────────

@test "T-3644 neg: 'X=1 rm -rf /tmp/x' is NOT-SAFE"     { _unsafe 'X=1 rm -rf /tmp/x'; }
@test "T-3644 neg: 'X=1; rm -rf /tmp/x' is NOT-SAFE"    { _unsafe 'X=1; rm -rf /tmp/x'; }
@test "T-3644 neg: backtick value is NOT-SAFE"          { _unsafe 'X=`rm f`; echo hi'; }
@test "T-3644 neg: backtick inside quotes is NOT-SAFE"  { _unsafe 'X="`rm f`"; echo hi'; }
@test "T-3644 neg: \$( ) inside quotes, non-terminal, is NOT-SAFE" { _unsafe 'X="$(rm f)"; echo hi'; }
@test "T-3644 neg: 'X=\$(cat a && rm b)' is NOT-SAFE"   { _unsafe 'X=$(cat a && rm b)'; }
@test "T-3644 neg: 'X=\$(rm f)' is NOT-SAFE"            { _unsafe 'X=$(rm f)'; }
@test "T-3644 neg: 'PATH=/tmp; cat x' is NOT-SAFE"      { _unsafe 'PATH=/tmp; cat x'; }
@test "T-3644 neg: 'IFS=x; cat y' is NOT-SAFE"          { _unsafe 'IFS=x; cat y'; }
@test "T-3644 neg: 'LD_PRELOAD=/tmp/e.so; cat x' is NOT-SAFE" { _unsafe 'LD_PRELOAD=/tmp/e.so; cat x'; }
@test "T-3644 neg: arithmetic '\$((...))' value is NOT-SAFE" { _unsafe 'X=$((1+1)); echo hi'; }
@test "T-3644 neg: 'X=1 > f' is a write"                { has_bash_write_pattern 'X=1 > f'; }
