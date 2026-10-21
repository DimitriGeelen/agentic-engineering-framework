#!/usr/bin/env bats
# T-4570: bats <1.11 (Ubuntu 24.04 ships 1.10) gathers test names from a .bats
# file's SOURCE TEXT, heredoc bodies included. A heredoc fixture carrying a real
# `@test "..."` line is therefore counted as a test of the enclosing file, and two
# such fixtures with one name abort the whole run ("Duplicate test name(s)") before
# any test executes — `bats tests/unit/` and `fw test unit` both died on
# t4058_unit_suite_keeps_failures.bats in the clean-room cloud run.
#
# Keep fixture tests in files (tests/unit/fixtures/<task>/*.bats.fixture) and copy
# them into place. This lint fails on any tests/unit/*.bats where bats <1.11's
# source-text count of @test lines differs from the real test count (`bats --count`).
# A cheap heredoc scan picks the candidate files first; `bats --count` decides.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# The line regex bats <1.11 (bats-preprocess) uses to recognise a test.
OLD_BATS_TEST_RE='^[[:blank:]]*@test[[:blank:]]+(.*[^[:blank:]])[[:blank:]]+\{'

# Prints files with an @test line after a heredoc opener and before its delimiter.
# Generous on purpose (a `<<` inside a string also opens): it only picks candidates.
_candidates() {
    python3 -I - "$@" <<'PY'
import re, sys
opener = re.compile(r"<<(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")
test_line = re.compile(r"^[ \t]*@test[ \t]")
for path in sys.argv[1:]:
    pending = []
    for line in open(path, encoding="utf-8", errors="replace").read().split("\n"):
        if pending:
            strip_tabs, delim = pending[0]
            if (line.lstrip("\t") if strip_tabs else line) == delim:
                pending.pop(0)
            elif test_line.match(line):
                print(path)
                break
            continue
        if not line.lstrip().startswith("#"):
            pending = [(m.group(1) == "-", m.group(3)) for m in opener.finditer(line)]
PY
}

# Exit 1 and name each file whose old-bats source count differs from bats --count.
_check() {
    local f src real bad=0
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        src=$(grep -cE "$OLD_BATS_TEST_RE" "$f")
        real=$(bats --count "$f" 2>/dev/null)
        if [ "$src" != "$real" ]; then
            echo "$f: bats <1.11 sees $src @test lines, bats --count sees $real"
            bad=1
        fi
    done < <(_candidates "$@")
    return "$bad"
}

@test "no tests/unit/*.bats has @test lines that bats <1.11 counts but bats does not run" {
    run _check "$REPO_ROOT"/tests/unit/*.bats
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "control: a heredoc @test fixture is flagged; the file-copy form passes" {
    # On bats <1.11 `bats --count` scans source text too, so both counts agree and the
    # lint cannot bite there; on such a host the defect shows as a load abort instead.
    printf '%s\n' "1.11.0" "$(bats --version | awk '{print $2}')" | sort -VC \
        || skip "bats $(bats --version | awk '{print $2}') < 1.11 counts heredoc @test lines itself"
    bad="$BATS_TEST_TMPDIR/bad.bats"
    good="$BATS_TEST_TMPDIR/good.bats"
    printf '%s\n' 'f() {' "    cat > x.bats <<'EOF'" '@test "fixture" { true; }' 'EOF' '}' \
        '@test "real" { f; }' > "$bad"
    printf '%s\n' 'f() { cp fixtures/x.bats.fixture x.bats; }' '@test "real" { f; }' > "$good"
    run _check "$bad"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bad.bats: bats <1.11 sees 2 @test lines, bats --count sees 1"* ]]
    run _check "$good"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
