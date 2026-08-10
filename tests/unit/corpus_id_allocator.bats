#!/usr/bin/env bats
# T-2902 — the L-/PL- allocator must not reissue a live id when the corpus changes shape.
#
# WHAT MAKES THIS SUITE NON-VACUOUS, read this before adding legs:
#
# The bug being pinned is NOT "the regex was wrong". It is that a scan matching zero
# rows is indistinguishable from an empty corpus, so the allocator returns its seed
# with confidence. Any test that only asserts "the new code gets the right answer on
# the shapes we know about" would have passed against BOTH broken versions of this
# allocator on the shapes they knew about. That is exactly how T-1369's fix shipped
# and how the same defect then recurred at three more sites (G-079).
#
# So the load-bearing leg is `pre-fix allocator is RED on the same fixture` — it runs
# the OLD pattern against the SAME corpus and asserts it finds nothing, proving the
# fixture actually exercises the defect. If that leg ever goes green, this whole file
# is measuring nothing and the other legs are decoration.
#
# The legs deliberately use a THIRD serialisation (quoted ids) that neither historical
# pattern handled — not the two we already know about — because the claim under test
# is "shape-independent", and a fixture drawn from the known shapes cannot test it.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/lib/corpus-id.sh"
    TMP="$(mktemp -d)"
}

teardown() {
    [ -n "$TMP" ] && rm -rf "$TMP"
}

# The two historical patterns, verbatim, so the legs below are testing the real thing
# and not a paraphrase of it.
old_pattern_pre_t1369() {   # agents/context/lib/learning.sh @ 908376daa
    grep -E "^- id: L-" "$1" | sed "s/.*L-0*//" | sort -n | tail -1
}
old_pattern_post_t1369() {  # agents/context/lib/learning.sh before T-2902
    grep -E "^[- ]+id: L-" "$1" | sed "s/.*L-0*//" | sort -n | tail -1
}

# --- fixtures: the same corpus, three ways ---

fixture_legacy() {          # pre-2026-04-13 shape
    cat > "$1" <<'YAML'
learnings:
- id: L-500
  learning: "a"
YAML
}

fixture_sorted_keys() {     # the shape T-1232's yaml.dump produced — caused the 24 dups
    cat > "$1" <<'YAML'
learnings:
- context: Added via context agent
  id: L-500
  learning: a
YAML
}

fixture_quoted() {          # a THIRD shape neither historical pattern handles
    cat > "$1" <<'YAML'
learnings:
- id: "L-500"
  learning: "a"
YAML
}

@test "LOAD-BEARING: the pre-fix allocator is RED on the quoted fixture" {
    # If this ever passes, every other leg in this file is vacuous.
    fixture_quoted "$TMP/l.yaml"

    run old_pattern_post_t1369 "$TMP/l.yaml"
    [ -z "$output" ]   # matched nothing -> next_id stays 1 -> would reissue L-001

    run old_pattern_pre_t1369 "$TMP/l.yaml"
    [ -z "$output" ]
}

@test "LOAD-BEARING: the pre-T-1369 allocator is RED on the sort_keys fixture" {
    # This is the exact historical failure: 234 entries, zero matches, mints L-001.
    fixture_sorted_keys "$TMP/l.yaml"
    run old_pattern_pre_t1369 "$TMP/l.yaml"
    [ -z "$output" ]
}

@test "corpus_max_id reads the quoted shape the old patterns missed" {
    fixture_quoted "$TMP/l.yaml"
    run corpus_max_id "$TMP/l.yaml" L
    [ "$status" -eq 0 ]
    [ "$output" = "500" ]
}

@test "corpus_max_id reads the sort_keys shape (the T-2902 corpus)" {
    fixture_sorted_keys "$TMP/l.yaml"
    run corpus_max_id "$TMP/l.yaml" L
    [ "$status" -eq 0 ]
    [ "$output" = "500" ]
}

@test "corpus_max_id reads the legacy shape (no regression on what worked)" {
    fixture_legacy "$TMP/l.yaml"
    run corpus_max_id "$TMP/l.yaml" L
    [ "$status" -eq 0 ]
    [ "$output" = "500" ]
}

@test "a genuinely empty corpus still starts at 1 — the refusal must not false-positive" {
    printf 'learnings:\n' > "$TMP/l.yaml"
    run corpus_max_id "$TMP/l.yaml" L
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a missing file starts at 1" {
    run corpus_max_id "$TMP/nope.yaml" L
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "cross-prefix is legitimate, not an error: PL- asked of an L--only corpus" {
    # A consumer project allocating PL- against a corpus holding only L- must start
    # at 1, not refuse. Getting this wrong would block every consumer.
    fixture_quoted "$TMP/l.yaml"
    run corpus_max_id "$TMP/l.yaml" PL
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "PL- ids are read when present, and L- does not match inside PL-" {
    cat > "$TMP/l.yaml" <<'YAML'
learnings:
- id: PL-042
  learning: "a"
YAML
    run corpus_max_id "$TMP/l.yaml" PL
    [ "$status" -eq 0 ]
    [ "$output" = "42" ]

    run corpus_max_id "$TMP/l.yaml" L
    [ "$status" -eq 0 ]
    [ -z "$output" ]   # must NOT read "L-042" out of "PL-042"
}

@test "zero-padding is stripped, not treated as octal" {
    cat > "$TMP/l.yaml" <<'YAML'
learnings:
- id: L-008
  learning: "a"
YAML
    run corpus_max_id "$TMP/l.yaml" L
    [ "$status" -eq 0 ]
    [ "$output" = "8" ]   # 008 must not arrive as octal or as "008"
}

@test "max is numeric, not lexical" {
    cat > "$TMP/l.yaml" <<'YAML'
learnings:
- id: L-009
  learning: "a"
- id: L-100
  learning: "b"
YAML
    run corpus_max_id "$TMP/l.yaml" L
    [ "$status" -eq 0 ]
    [ "$output" = "100" ]   # lexical sort would answer 009
}

@test "NON-VACUITY: resolves against the real repo corpus" {
    # Every leg above builds its own fixture. If corpus_max_id were subtly broken on
    # a real 608-entry file (duplicate ids, PL- and L- interleaved, prose quoting ids)
    # the fixtures would not show it.
    real="$FRAMEWORK_ROOT/.context/project/learnings.yaml"
    [ -f "$real" ] || skip "no live corpus in this checkout"
    run corpus_max_id "$real" L
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [ "$output" -ge 570 ]   # the corpus had max L-570 when this was written
}

@test "the live corpus's duplicate ids do not confuse max" {
    # 24 ids appear twice in the real file. max must be unaffected by that.
    real="$FRAMEWORK_ROOT/.context/project/learnings.yaml"
    [ -f "$real" ] || skip "no live corpus in this checkout"
    expected=$(python3 -c "
import yaml,re
ls=yaml.safe_load(open('$real'))['learnings']
n=[int(m.group(1)) for m in (re.match(r'L-0*(\d+)\$',str(e.get('id',''))) for e in ls) if m]
print(max(n))")
    run corpus_max_id "$real" L
    [ "$output" = "$expected" ]
}

@test "a corpus that RAISES on parse falls back loudly, never silently" {
    printf 'a: b: c\n' > "$TMP/l.yaml"     # ScannerError — verified, not assumed
    run corpus_max_id "$TMP/l.yaml" L
    # Whatever it decides, it must have said so on stderr — a silent answer here is
    # the L-570 defect (a failed read indistinguishable from a real negative).
    echo "$output" | grep -q "corpus-id: WARNING"
}

@test "a corpus clobbered to a bare scalar is REFUSED, not read as empty" {
    # This leg was written expecting `:::junk` to raise. It does not — PyYAML loads it
    # as the string ':::not yaml at all', so the naive path answers "no ids, start at
    # 1" with no error anywhere. That is the T-2902 defect reached by a different
    # route, and it was invisible until this leg failed for the "wrong" reason.
    printf ':::not yaml at all\n' > "$TMP/l.yaml"
    run corpus_max_id "$TMP/l.yaml" L
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "not as a mapping or list"
}

@test "flow-style ids are read — a fourth shape, free" {
    printf 'learnings:\n  - {id: L-500, learning: a}\n' > "$TMP/l.yaml"
    run corpus_max_id "$TMP/l.yaml" L
    [ "$status" -eq 0 ]
    [ "$output" = "500" ]

    # and the pre-fix pattern is RED on it, so this is a real shape, not a freebie
    run old_pattern_post_t1369 "$TMP/l.yaml"
    [ -z "$output" ]
}
