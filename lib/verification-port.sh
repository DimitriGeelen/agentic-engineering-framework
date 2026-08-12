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
