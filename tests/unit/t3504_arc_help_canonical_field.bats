#!/usr/bin/env bats
# T-3504 — `fw arc help` must not call the DEPRECATED tag form canonical.
#
# Slice S4 of T-3501. Reported by the peer agent at agent-chat-arc @1090, whose
# point was that this makes the membership defect SELF-JUSTIFYING for a reader:
# an author who checks the help before writing is told the deprecated form is the
# right one. Pre-fix, `fw arc help` contradicted itself within 50 lines:
#
#   line 17: Source-of-truth is task-side arc_id: (T-1849).        <- correct
#   line 53: T-1851: prefer task-side arc_id: + 'fw arc tag'.      <- correct
#   line 67: Task tags: arc:<id> (canonical); from-T-XXXX ...      <- WRONG
#
# and the wrong line was the last word.
#
# Asserted on the RENDERED help output, not on a source line: the output is what
# misinforms the reader, and a source-line assertion would pass if the text moved.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/project"
    mkdir -p "$PROJECT_ROOT/.context/arcs" "$PROJECT_ROOT/.context/working"
    HELP_OUT="$BATS_TEST_TMPDIR/arc-help.txt"
    # Redirect-then-grep throughout (L-387): `cmd | grep -q` takes SIGPIPE and
    # exits 141 with the pattern present.
    "$FRAMEWORK_ROOT/bin/fw" arc help > "$HELP_OUT" 2>&1 || true
    export HELP_OUT
}

@test "t3504: fw arc help emits membership guidance at all" {
    # Guards the other assertions: a help command that printed nothing would make
    # every 'must not contain' check below pass vacuously.
    run grep -c "arc_id" "$HELP_OUT"
    [ "$status" -eq 0 ]
    [ "$output" -ge 2 ]
}

@test "t3504: the arc:<slug> TAG form is never described as canonical" {
    # THE CONTROL LEG. This exact string was present before the fix, so this
    # assertion fails against pre-fix code — which is what makes the rest mean
    # something.
    run grep -F 'arc:<id> (canonical)' "$HELP_OUT"
    [ "$status" -ne 0 ]
}

@test "t3504: no line pairs the tag namespace with the word canonical" {
    # Broader than the literal above: catches a reworded regression that still
    # calls the legacy form canonical.
    run grep -nE '^[^#]*arc:<?(id|slug)>?[^#]*canonical' "$HELP_OUT"
    [ "$status" -ne 0 ]
}

@test "t3504: arc_id: is named as the canonical field" {
    run grep -E 'arc_id.*canonical|canonical.*arc_id' "$HELP_OUT"
    [ "$status" -eq 0 ]
}

@test "t3504: the tag form is still named, and named as legacy" {
    # The fix must not delete the legacy form from the docs — it is still READ,
    # so an author debugging an un-migrated task needs to know it exists.
    run grep -E 'arc:<id> tag \(legacy' "$HELP_OUT"
    [ "$status" -eq 0 ]
}

@test "t3504: the pre-existing correct statements survive" {
    # The defect was a contradiction, not a shortage of guidance. Rewriting the
    # already-correct lines would drop the T-1849/T-1851 references a reader needs.
    run grep -F 'Source-of-truth is task-side arc_id: (T-1849).' "$HELP_OUT"
    [ "$status" -eq 0 ]
    run grep -F "T-1851: prefer task-side arc_id: + 'fw arc tag'." "$HELP_OUT"
    [ "$status" -eq 0 ]
}

@test "t3504: the source header no longer calls the tag namespace canonical" {
    # lib/arc.sh:34 is the first thing a reader of the SOURCE sees; it carried the
    # same claim as the help text and is corrected with it.
    run grep -nE '^#.*`arc:<slug>` tag namespace \(canonical' "$FRAMEWORK_ROOT/lib/arc.sh"
    [ "$status" -ne 0 ]
}
