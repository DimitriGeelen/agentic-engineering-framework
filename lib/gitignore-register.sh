#!/usr/bin/env bash
# T-2994 (build slice of T-2992) — .gitignore rules that defer without a register.
#
# THE ASYMMETRY THIS EXISTS FOR. Every suppression mechanism the framework uses
# announces itself when it fires, except one:
#
#   skip "reason"      prints its reason on every suite run
#   allowlist entry    echoed by whichever scanner consults it
#   .gitignore rule    emits nothing, ever
#
# A gitignore rule is the only one that removes a signal silently AND
# permanently. There is no run, no report, and no moment at which it says "I am
# suppressing something".
#
# That is not a general worry, it is a measured incident. T-2990: two rules
# ignored 50MB of junk in the repo root, annotated "root-cause task pending" for
# a task that was never filed. The rules deleted the git-status surface that
# would have raised it again. Three months.
#
# WHY THE SITE IS THE ANCHOR AND THE PROSE IS ONLY THE QUALIFIER. T-2992's
# census measured the obvious alternative — scan for deferral prose wherever it
# appears — at 184 hits across lib/ and agents/, almost all ordinary
# explanation. A prose-keyed rail is ~94% noise. Keyed on .gitignore, the same
# vocabulary is a strong signal, because a comment beside a suppression is
# making a claim about work that is still open.
#
# WHY PER-BLOCK AND NOT PER-LINE. Ignore-file comments are written as
# paragraphs: a block names its task on line 1 and elaborates for another six.
# Per-line matching flags the elaboration and trains readers to ignore the rail.
# The unit of authorship is the contiguous comment block, so that is the unit of
# judgement.

# Vocabulary that makes a comment a claim about unfinished work. Deliberately
# narrow: "workaround" and "known issue" were considered and left out, because
# both routinely describe a settled, permanent state.
FW_GITIGNORE_DEFER_RE='pending|TODO|FIXME|for now|until |revisit|root.cause|temporar|not yet|someday|follow.?up|come back'

# Register references that count as "filed somewhere something reads".
FW_GITIGNORE_IDREF_RE='T-[0-9]+|G-[0-9]+|OBS-[0-9]+|L-[0-9]+|C-[0-9]+|P-[0-9]+'

# fw_gitignore_unregistered_defers <project_root>
#
# Prints one `<line_no>\t<comment_text>` per offending block (anchored at the
# block's first line). Returns 1 when at least one was found, 0 when clean — so
# callers branch on exit code without parsing.
#
# A block offends when it contains deferral vocabulary and no register id
# anywhere in the block.
fw_gitignore_unregistered_defers() {
    local root="${1:-${PROJECT_ROOT:-$PWD}}"
    local gi="$root/.gitignore"

    [ -f "$gi" ] || return 0

    awk -v defer="$FW_GITIGNORE_DEFER_RE" -v idref="$FW_GITIGNORE_IDREF_RE" '
        function flush() {
            # A block is reported only if it both defers and names nothing.
            if (n > 0 && has_defer && !has_id)
                printf "%d\t%s\n", start, first
            n = 0; has_defer = 0; has_id = 0; first = ""
        }
        {
            if ($0 ~ /^[[:space:]]*#/) {
                if (n == 0) { start = NR; first = $0 }
                n++
                # tolower() on both sides: the vocabulary is case-insensitive
                # ("Pending", "TODO"), the id pattern is not (T-123, not t-123).
                if (tolower($0) ~ tolower(defer)) has_defer = 1
                if ($0 ~ idref) has_id = 1
            } else {
                flush()
            }
        }
        END { flush() }
    ' "$gi" > /tmp/.fw-gitignore-defers.$$ 2>/dev/null

    local rc=0
    if [ -s /tmp/.fw-gitignore-defers.$$ ]; then
        cat /tmp/.fw-gitignore-defers.$$
        rc=1
    fi
    rm -f /tmp/.fw-gitignore-defers.$$
    return $rc
}
