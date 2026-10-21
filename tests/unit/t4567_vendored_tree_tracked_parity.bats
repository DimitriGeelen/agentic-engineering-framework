#!/usr/bin/env bats
# T-4567 — every file the framework repo TRACKS under .agentic-framework/ must
# be something do_vendor actually ships.
#
# The defect: .agentic-framework/install.sh was committed into the self-vendored
# tree once (T-880) and never refreshed, because install.sh is in no vendor
# class: do_vendor's includes[] does not list it, and `fw vendor self` has no
# helper for it. Six more files (tests/integration/*.bats and their .fabric
# cards, T-744) sat in the same blind spot. Every drift gate (`fw vendor self
# --check`, audit's self-vendor check) compares the classes it knows, source to
# copy, so a tracked file outside every class is invisible to all of them, and
# it goes stale with nothing ever saying so.
#
# This test asks the reverse question. The ship set is read from do_vendor's own
# `local includes=(` array, so adding an include widens it without editing this
# file. The files do_vendor writes outside that array are listed explicitly
# below. If one is added there, add it here too.

ROOT() { cd "$BATS_TEST_DIRNAME/../.." && pwd; }

# do_vendor's includes[] entries, one per line, comments stripped.
_includes() {
    awk '/^do_vendor\(\)/{f=1}
         f && /local includes=\(/{g=1; next}
         g && /^[[:space:]]*\)/{exit}
         g {sub(/#.*/, ""); gsub(/[[:space:]]/, ""); if ($0 != "") print}' "$(ROOT)/bin/fw"
}

# Files and trees do_vendor writes outside includes[] (bin/fw do_vendor):
# FRAMEWORK.md (completeness sentinel, written last), VERSION, the generated
# .gitignore / .fw-not-a-project / .upstream, and the pinned designer build.
EXTRA_FILES="FRAMEWORK.md VERSION .gitignore .fw-not-a-project .upstream"
EXTRA_TREES="vendor/designer"

@test "control: the includes[] parser finds do_vendor's ship set" {
    run _includes
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx bin
    echo "$output" | grep -qx lib
    echo "$output" | grep -qx agents
    # install.sh is deliberately not shipped to consumers.
    ! echo "$output" | grep -qx install.sh || false
}

@test "every tracked .agentic-framework/ path is in do_vendor's ship set" {
    local root; root="$(ROOT)"
    git -C "$root" rev-parse --git-dir >/dev/null 2>&1
    local -a ship=()
    while IFS= read -r i; do ship+=("$i"); done < <(_includes)
    [ "${#ship[@]}" -gt 5 ]

    local orphans="" p rel ok s
    while IFS= read -r p; do
        rel="${p#.agentic-framework/}"
        ok=0
        for s in "${ship[@]}" $EXTRA_TREES; do
            if [ "$rel" = "$s" ] || [ "${rel#"$s"/}" != "$rel" ]; then ok=1; break; fi
        done
        for s in $EXTRA_FILES; do
            [ "$rel" = "$s" ] && ok=1
        done
        [ "$ok" -eq 1 ] || orphans="${orphans}${p}"$'\n'
    done < <(git -C "$root" ls-files .agentic-framework)

    if [ -n "$orphans" ]; then
        echo "Tracked under .agentic-framework/ but shipped by no vendor class (goes stale silently):"
        printf '%s' "$orphans"
        echo "Fix: git rm the copy, or add the path to do_vendor's includes[] AND a fw vendor self class."
        return 1
    fi
}

@test "install.sh in particular is not tracked in the vendored tree" {
    run git -C "$(ROOT)" ls-files .agentic-framework/install.sh
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
