#!/bin/bash
# lib/verification-port.sh — hard-coded Watchtower port detection (T-2732)
#
# Single definition of the predicate. Sourced by:
#   - agents/task-create/update-task.sh  (the P-011 close gate)
#   - tests/unit/verification_port_hardcode.bats
#
# It lives here rather than inline in the gate because the regression suite has
# to run the REAL predicate over the real corpus. A test that re-types the
# producer's expression into a local helper can only ever check the sites its
# author already knew about (L-533, from the T-2729/T-2730/T-2731 escape family).
#
# Usage: source "$FRAMEWORK_ROOT/lib/verification-port.sh"
#        find_port_literals "$text"   # prints offending lines, one per line

[[ -n "${_FW_VERIFICATION_PORT_LOADED:-}" ]] && return 0
_FW_VERIFICATION_PORT_LOADED=1

# Print every line of $1 that reaches for a literal port-3000 URL without
# resolving the port on the same line. Prints nothing when clean. Always exits 0
# (pipefail-safe, L-302) — callers decide what a non-empty result means.
#
# The discriminator is NOT "mentions 3000". CLAUDE.md §Watchtower Port explicitly
# sanctions the defensive fallback
#     WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000")
# because it asks where the port actually is first and only then falls back. What
# is banned is reaching for 3000 without asking. So a line is an offender when it
# contains a port-3000 URL literal AND no port-resolution idiom.
#
# Fixed on 3000 by design. Resolving "the port that happens to be live" and
# flagging that instead would make the verdict depend on host state at run time —
# the same defect class the gate exists to catch.
find_port_literals() {
    printf '%s\n' "$1" \
        | grep -E 'https?://(localhost|127\.0\.0\.1|0\.0\.0\.0):3000' \
        | grep -vE 'fw[[:space:]]+watchtower[[:space:]]+(url|port)|watchtower\.(url|port)|fw[[:space:]]+config[[:space:]]+get[[:space:]]+PORT|\$\{?(WT_URL|WURL|WT_PORT)' \
        || true
}

# T-2991 — print every line of $1 that bash cannot parse as a command.
#
# WHY THIS EXISTS. P-011 is line-oriented: the gate reads one line and evals it
# (update-task.sh:1149,1169; verify_queue.py:127). A verification command written
# across several lines is therefore not one command — and the lines below the
# first are, by construction, NOT shell. They get eval'd anyway.
#
# That is not theoretical. It put 56MB of ImageMagick PostScript into this repo's
# root across four incidents over three months (T-2990). The block
#
#     python3 -c "
#     import yaml,sys
#     d = yaml.safe_load(open('policy/value-drivers.yaml'))
#     "
#
# runs `import yaml,sys` as a shell command, and `import` is a screenshot tool
# whose last argument is its output filename. cwd is PROJECT_ROOT.
#
# WHY THE FIRST LINE IS THE RIGHT PLACE TO CATCH IT. `import yaml,sys` is
# perfectly valid bash — no syntax check will ever object to it. What IS
# catchable is line 1: `python3 -c "` has an unterminated quote, and every
# instance of this class starts that way, because that is what wrapping a
# quoted command across lines does. Catching the opener means the body is never
# reached. Trying instead to recognise "lines that look like Python" would be a
# detector written from the instances that already announced themselves (L-543),
# and would still have to let `import yaml,sys` through.
#
# Prints offending lines, one per line; empty when clean. Always exits 0
# (pipefail-safe, L-302) — callers decide what a non-empty result means.
find_unparseable_verification_lines() {
    local text="$1" line
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -z "$line" ] && continue
        # `bash -n` parses without executing. This is the whole check: a line the
        # parser rejects is a line the gate must not hand to `eval`.
        bash -n -c "$line" 2>/dev/null || printf '%s\n' "$line"
    done <<< "$text"
    return 0
}

# Refuse a Verification block that contains an unparseable line, rather than
# eval'ing it. Returns 0 when the block is safe to run, 1 when it must not be.
# Diagnostic goes to stderr; the caller owns the exit path.
#
# Bypass: FW_ALLOW_UNPARSEABLE_VERIFICATION=1 (logged Tier-2 by the caller). A
# legitimate block could in principle carry a line this parser rejects, and the
# operator's judgement outranks the gate.
check_verification_parseable() {
    local text="$1" bad
    bad=$(find_unparseable_verification_lines "$text")
    [ -z "$bad" ] && return 0

    if [ "${FW_ALLOW_UNPARSEABLE_VERIFICATION:-0}" = "1" ]; then
        echo "  WARN: verification block has unparseable line(s) — running anyway" >&2
        echo "        (FW_ALLOW_UNPARSEABLE_VERIFICATION=1)" >&2
        return 0
    fi

    {
        echo ""
        echo "BLOCKED: the ## Verification block contains line(s) bash cannot parse."
        echo ""
        echo "$bad" | sed 's/^/    /'
        echo ""
        echo "  The gate runs ONE LINE AT A TIME. It does not join continuation"
        echo "  lines, so a command written across several lines is not one"
        echo "  command — line 1 is an unterminated quote, and the lines below it"
        echo "  are executed as SHELL even though they are not shell."
        echo ""
        echo "  That is how 56MB of ImageMagick PostScript got written into this"
        echo "  repo's root: a python body's 'import yaml,sys' ran as bash, and"
        echo "  'import' is a screenshot tool (T-2990)."
        echo ""
        echo "  Rewrite the command so each line stands alone. Either collapse it:"
        echo "      python3 -c \"import yaml,sys; d=yaml.safe_load(open('f.yaml')); sys.exit(0 if d else 1)\""
        echo "  or put the body in a file and call that:"
        echo "      python3 tests/check_f.py"
        echo ""
        echo "  Bypass (logged Tier-2): FW_ALLOW_UNPARSEABLE_VERIFICATION=1"
        echo ""
    } >&2
    return 1
}

# Extract the ## Verification block of a task file, stripped of comments, blank
# lines and fences — the same shape update-task.sh executes.
#
# T-2765: the HTML-comment strip below is not decoration. Task files written
# before the `#`-comment template used `<!-- ... -->` blocks in this section, and
# without the strip every line of that prose came back as a command. The gate
# (update-task.sh:1093) and audit CTL-013 (audit.sh:3255) both strip it; this
# helper claimed parity with the gate in its own comment and did not have it, so
# every caller — the port-literal scan, the unjudged-test-run scan, and
# `fw verify-queue` — was scanning template prose as if it were shell. Found by
# running the whole review queue through it: T-558 reported "5/5 commands
# failing" for a section that is empty.
#
# T-2921: this is now THE extractor — update-task.sh's P-011 gate calls it
# instead of keeping its own copy. The comment above claimed parity with the
# executor twice and had to be corrected once already; parity asserted in prose
# between two copies is the T-2949 class (one change, three artefacts, 57 days
# red). Shared by construction is the only version of that claim that stays true.
#
# The strip is STRUCTURAL, not textual, and that distinction is the whole bug.
# Every line surviving this function is handed to `eval`. A `<!--` opening a
# line is prose the author wrote for a reader — discard it. The same delimiter
# INSIDE a line is argument text belonging to a command — `sed '/<!--/,/-->/d'`,
# an awk program matching a footer marker, a printf building a fixture — and
# rewriting it corrupts the command. The old whole-block
# `re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)` could not tell those apart
# and did both:
#   * mangled  — `sed '/<!--/,/-->/d' f` became `sed '/d' f`, which errors. Loud.
#   * deleted  — `.*?` spans newlines under DOTALL, so a mid-line `<!--` pairs
#                with the NEXT `-->` anywhere below, including the close of a
#                real comment block further down. Every command between them
#                vanishes before `wc -l` counts them, and the gate then prints
#                "N/N passed" over a population it silently shrank. That is a
#                false green, and a green line asserting nothing is
#                indistinguishable from one asserting everything (cf. the
#                port-3000 class, 371 instances).
# Measured over 2939 task files at fix time: 3 differ, all three repairs, no
# command-count change. See T-2921 for the enumeration.
#
# The rule itself lives in lib/comment_strip.py and is NOT restated here.
# T-2954 moved it there so this function and agents/context/check-human-ac-tick.py
# share one implementation. Restating it in a comment beside a second copy is what
# this file used to do about update-task.sh's copy — and that comment recorded
# that the parity claim had already been found false once and been repaired by
# editing the copy. Prose asserting parity between two implementations is not
# parity (T-2949); a shared import is.
#
# Read lib/comment_strip.py for the rule, the DOTALL failure modes, and the
# three-disposition direction rule (discarded / counted / executed).
extract_verification_block() {
    local file="$1"
    sed -n '/^## Verification/,/^## /p' "$file" 2>/dev/null \
        | sed '$d' | tail -n +2 \
        | python3 "${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/comment_strip.py" 2>/dev/null \
        | grep -vE '^\s*$|^\s*#|^\s*```' || true
}
