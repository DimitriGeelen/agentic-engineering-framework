#!/bin/bash
# lib/section-extract.sh — anchored section extraction for the task-file
# sections that gate build/inception completion, other than ## Verification
# (T-3148).
#
# lib/verification-port.sh:extract_verification_block (T-3134) fixed three
# defects in the old `sed -n '/^## X/,/^## /p' | sed '$d'` shape for the
# Verification section only:
#   D1 — `sed '$d'` discards sed's re-printed terminator line. When the
#        section is the FILE'S LAST section there is no terminator to
#        discard, so it deletes real content instead (832's report).
#   D2 — the start pattern is an unanchored PREFIX match, so a heading that
#        merely BEGINS with the section name (or a duplicate exact heading)
#        opens a second range. sed ranges repeat; over-inclusion follows.
#   D3 — the dangerous direction of D2: a prefix-matching heading BEFORE the
#        real one is consumed as the FIRST range's own terminator, so the
#        real heading never opens a range at all and the gate reads empty —
#        silent skip, not silent over-inclusion.
#
# T-3148 found five more sed-range sites carrying the identical three
# defects, four of them gate-bearing (P-010 AC gate ×2, G-020 build-readiness,
# the inception-decide AC preflight) and two cosmetic (a Recommendation-body
# drift hint in each of the two AC gates).
#
# Copying extract_verification_block's awk VERBATIM is not correct for every
# section, and doing so is itself the bug T-3144 hit within the hour on this
# same task's session: that function is FIRST-WINS (take the FIRST matching
# heading, ignore any later one). First-wins is right for Verification — a
# later block supersedes the first, so keeping the first is correct precisely
# because a task is never mid-revision on its own Verification section. It is
# WRONG for Recommendation: the shipped template ships a `## Recommendation`
# STUB, and the agent's real content is appended AFTER it. First-wins reads
# the stub and reports "empty" against 40 lines of real recommendation on
# screen (T-3144, this same task's own observed instance, logged in the task
# body under "Observed instance").
#
# So each section below states its own per-site decision explicitly, per AC1:
#
#   extract_ac_section            — FIRST-WINS. '## Acceptance Criteria' is
#                                    written once, near the top of the file,
#                                    by convention. Corpus measurement (T-3148
#                                    description) found duplicate headings only
#                                    as exact copies with no distinguishing
#                                    content, so the earliest instance is a
#                                    safe, deterministic choice and matches the
#                                    section's own natural single-occurrence
#                                    shape.
#   extract_recommendation_block  — LAST-WINS. The section is filled in AFTER
#                                    the template ships it as an empty stub, so
#                                    the section instance that matters is
#                                    whichever heading occurs LAST in the file.
#
# Usage: source "$FRAMEWORK_ROOT/lib/section-extract.sh"

[[ -n "${_FW_SECTION_EXTRACT_LOADED:-}" ]] && return 0
_FW_SECTION_EXTRACT_LOADED=1

# FIRST-WINS, anchored. Structurally identical to
# lib/verification-port.sh:extract_verification_block (T-3134) — only the
# heading text differs. `next` on the heading line means the heading itself
# is never printed; `inblk && /^## /` closes the range on ANY subsequent
# level-2 heading (not just a same-named one) without re-printing it, so
# nothing needs a trailing `sed '$d'` to discard — D1 cannot occur because
# there is no terminator line to discard in the first place.
#
# The previous form was `sed -n '/^## Acceptance Criteria/,/^## /p' | sed '$d'`.
extract_ac_section() {
    local file="$1"
    awk '
        /^## Acceptance Criteria[[:space:]]*$/ { if (!seen) { seen=1; inblk=1 }; next }
        inblk && /^## / { inblk=0 }
        inblk { print }
    ' "$file" 2>/dev/null
}

# LAST-WINS, anchored. Deliberately the opposite policy of extract_ac_section
# — see file header for why. Every anchored heading match resets `buf`,
# discarding whatever range came before it, so the range that survives to
# `END` is the one opened by the LAST heading in the file. A file with no
# matching heading at all prints nothing (`seen` stays unset).
#
# The previous form was `sed -n '/^## Recommendation/,/^## /p' | sed '$d'`.
extract_recommendation_block() {
    local file="$1"
    awk '
        /^## Recommendation[[:space:]]*$/ { seen=1; inblk=1; buf=""; next }
        inblk && /^## / { inblk=0 }
        inblk { buf = buf $0 "\n" }
        END { if (seen) printf "%s", buf }
    ' "$file" 2>/dev/null
}
