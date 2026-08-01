#!/usr/bin/env bash
# T-2713 — one truthful answer to "is this consumer ahead or behind?".
#
# THE DEFECT THIS REPLACES
#
# Three sites open-coded the same comparison:
#
#     [ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" = "$a" ] && ahead || behind
#
#   bin/fw:2015          doctor's consumer-fleet ahead/behind badge
#   lib/upgrade.sh:849   pre-step-1 runtime downgrade guard  (T-1912)
#   lib/upgrade.sh:1742  pin-rewrite downgrade guard         (T-1839)
#
# `sort -V` orders version STRINGS. VERSION here is a tag counter that RESETS —
# this repo's tags run v1.6.763, v1.6.762, v1.6.761, then v1.6.10, v1.6.9, and
# VERSION itself has gone 1.6.354 -> 1.6.121 -> 1.6.176. A counter that resets
# does not order, so every one of those three "ahead" verdicts is a guess wearing
# the costume of a comparison.
#
# The guards themselves are RIGHT (do not silently downgrade a consumer). They
# were simply handed an ordering that does not exist. Consequence in the field:
# a consumer pinned 1.6.264 reads "ahead" of a framework at 1.6.163, `fw upgrade`
# refuses to protect it, and it sits frozen for weeks — receiving no governance
# or security fixes — while wearing a bigger number.
#
# WHAT ORDERS INSTEAD
#
# Git ancestry, which cannot reset:
#   consumer commit is an ancestor of framework HEAD  -> genuinely BEHIND
#   framework HEAD is an ancestor of consumer commit  -> genuinely AHEAD
#   neither                                            -> DIVERGED
#
# For that we need the consumer's commit. Today the pin records only the counter,
# so `fw upgrade` now also records `version_sha:` (T-2713). Legacy pins have no
# sha; the version tag is tried next, and 31 tags exist for a counter in the
# hundreds, so most legacy pins resolve to neither. That case is UNDECIDABLE and
# is reported as such. It is NOT rendered as "ahead" — asserting a direction we
# cannot compute is what froze the consumer in the first place.
#
# This is T-2290's medicine (replace an untrustworthy proxy — there, file mtime —
# with the real object) applied to the same shape one layer up.
#
# Usage:
#   fw_version_relation <consumer_version> <framework_version> [consumer_sha] [framework_root]
#     sets:   FW_VERSION_RELATION         same | behind | ahead | diverged | undecidable
#     sets:   FW_VERSION_RELATION_REASON  one human-readable line
#     echoes: the relation (convenience only)
#
# CALL IT BARE, NOT IN `$(...)`. Command substitution forks a subshell, so the
# globals never reach the caller and every block message renders with an empty
# reason — a message that reports confidently about nothing. Correct:
#     fw_version_relation "$cv" "$fv" "$sha" "$root"
#     case "$FW_VERSION_RELATION" in ...

# Default for the undecidable case: 1 = proceed with a loud warning, 0 = refuse.
# Rationale in T-2713 §Decisions; this is the operator-reviewable knob.
: "${FW_UNDECIDABLE_VERSION_PROCEED:=1}"

fw_version_relation() {
    local cversion="$1"
    local fversion="$2"
    local csha="${3:-}"
    local froot="${4:-${FRAMEWORK_ROOT:-.}}"

    FW_VERSION_RELATION=""
    FW_VERSION_RELATION_REASON=""

    _vr_set() {   # _vr_set <relation> <reason>
        FW_VERSION_RELATION="$1"
        FW_VERSION_RELATION_REASON="$2"
        echo "$1"
    }

    if [ -z "$cversion" ]; then
        _vr_set undecidable "consumer records no version"
        return 0
    fi

    if [ "$cversion" = "$fversion" ]; then
        _vr_set same "pinned version matches framework"
        return 0
    fi

    # Resolve a commit for the consumer: recorded sha first, then the version tag.
    local cref="" cref_kind=""
    if [ -n "$csha" ] && git -C "$froot" rev-parse -q --verify "${csha}^{commit}" >/dev/null 2>&1; then
        cref="$csha"
        cref_kind="recorded sha"
    elif git -C "$froot" rev-parse -q --verify "v${cversion}^{commit}" >/dev/null 2>&1; then
        cref="v${cversion}"
        cref_kind="tag v${cversion}"
    fi

    if [ -z "$cref" ]; then
        # No commit to compare. Deliberately NOT falling back to string order —
        # that fallback is the entire defect. Say so instead.
        _vr_set undecidable "no version_sha recorded and no tag v${cversion} in framework repo; VERSION is a resetting counter so string order cannot decide"
        return 0
    fi

    local head_sha
    head_sha=$(git -C "$froot" rev-parse HEAD 2>/dev/null || true)
    if [ -z "$head_sha" ]; then
        _vr_set undecidable "framework HEAD unreadable (not a git checkout?)"
        return 0
    fi

    local cres
    cres=$(git -C "$froot" rev-parse "${cref}^{commit}" 2>/dev/null || true)
    if [ "$cres" = "$head_sha" ]; then
        _vr_set same "consumer ${cref_kind} is framework HEAD"
        return 0
    fi

    if git -C "$froot" merge-base --is-ancestor "$cref" HEAD 2>/dev/null; then
        _vr_set behind "consumer ${cref_kind} is an ancestor of framework HEAD — framework contains the consumer's code"
        return 0
    fi

    if git -C "$froot" merge-base --is-ancestor HEAD "$cref" 2>/dev/null; then
        _vr_set ahead "framework HEAD is an ancestor of consumer ${cref_kind} — consumer genuinely holds newer code"
        return 0
    fi

    _vr_set diverged "consumer ${cref_kind} and framework HEAD have diverged (neither contains the other)"
    return 0
}

# Write the framework's HEAD commit into a consumer's .framework.yaml.
#
# Lives here, beside the reader, on purpose (L-399): the pin format is a
# producer/consumer contract, and the two halves shipping in different files is
# how contracts drift. If you change the field name, both sides are in view.
#
# Best-effort: a framework checkout without git leaves the field absent, and the
# relation then reports `undecidable` honestly instead of guessing.
fw_record_version_sha() {
    local yf="$1"
    local froot="${2:-${FRAMEWORK_ROOT:-.}}"
    local sha
    sha=$(git -C "$froot" rev-parse HEAD 2>/dev/null || true)
    [ -n "$sha" ] || return 0
    [ -f "$yf" ] || return 0
    if grep -q "^version_sha:" "$yf" 2>/dev/null; then
        # portable in-place edit (BSD/GNU sed differ on -i)
        local tmp="${yf}.vrtmp"
        sed "s/^version_sha:.*/version_sha: $sha/" "$yf" > "$tmp" && mv "$tmp" "$yf"
    else
        echo "version_sha: $sha" >> "$yf"
    fi
}

# Should a guard refuse to proceed for this relation?
# ahead/diverged  -> always refuse (a real downgrade risk)
# undecidable     -> operator-configurable, default proceed-with-warning
fw_version_relation_should_refuse() {
    case "$1" in
        ahead|diverged) return 0 ;;
        undecidable)
            if [ "${FW_UNDECIDABLE_VERSION_PROCEED:-1}" = "1" ]; then return 1; else return 0; fi
            ;;
        *) return 1 ;;
    esac
}
