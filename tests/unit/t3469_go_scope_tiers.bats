#!/usr/bin/env bats
#
# T-3469 — the GO-scope scan classifies its findings into
# candidate / in-flight / linked-late, and the WARN leads with the tier that
# actually means "nobody built this".
#
# Origin OBS-535: the scan emitted one undifferentiated count. The operator read
# "185 GO-scope-not-propagated" in the push gate as 185 abandoned decisions. The
# measured candidate set was 25. The qualifier existed only in the report file,
# which nobody opens.
#
# These tests run the SHIPPED python block, extracted from agents/audit/audit.sh
# between its own delimiters — not a reimplementation. A reimplementation would
# pass while the real scan regressed, which is the failure mode this suite is
# supposed to catch.

setup() {
    ROOT="${BATS_TEST_DIRNAME}/../.."
    AUDIT="$ROOT/agents/audit/audit.sh"
    FIXTURES="$ROOT/tests/fixtures/t3469"
    WORK="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$WORK/.tasks" "$BATS_TEST_TMPDIR/report"
    cp -r "$FIXTURES/completed" "$WORK/.tasks/completed"
    cp -r "$FIXTURES/active" "$WORK/.tasks/active"
    REPORT="$BATS_TEST_TMPDIR/report/LATEST.md"
    SCAN="$BATS_TEST_TMPDIR/scan.py"
    extract_scan
}

# Pull the python source out of audit.sh and re-bind the two shell values it
# interpolates. Anchored on the assignment line and the closing paren so the
# extraction breaks loudly if the block is renamed, rather than silently
# producing an empty script that "passes".
extract_scan() {
    awk '/^go_scope_summary=\$\(python3 -c "$/{f=1;next} /^" 2>\/dev\/null\)$/{f=0} f' \
        "$AUDIT" > "$SCAN.raw"
    [ -s "$SCAN.raw" ] || { echo "extraction produced nothing — did the block move?" >&2; return 1; }
    # audit.sh runs this inside a double-quoted string, so \$ is an escaped
    # dollar in the file. Unescape, then bind the two interpolated values.
    sed -e 's/\\\$/$/g' \
        -e "s|project_root = '\$PROJECT_ROOT'|project_root = '$WORK'|" \
        -e "s|report_path = '\$GO_SCOPE_REPORT_PATH'|report_path = '$REPORT'|" \
        "$SCAN.raw" > "$SCAN"
}

run_scan() { run python3 "$SCAN"; }

# summary fields: inceptions|go|findings|cand|in-flight|linked-late|sample
field() { echo "$1" | awk -F'|' -v n="$2" '{print $n}'; }

@test "extraction yields a runnable scan (guards the other tests)" {
    run_scan
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "the four qualifying inceptions are findings; the other two are not" {
    run_scan
    # T-9004 has related_tasks, T-9005 is NO-GO — neither may be flagged.
    [ "$(field "$output" 3)" -eq 4 ]
    [ "$(field "$output" 2)" -eq 5 ]   # GO-recorded inceptions (excludes NO-GO)
    [ "$(field "$output" 1)" -eq 6 ]   # completed inceptions examined
}

@test "control leg: the three tiers are distinguished, not all one label" {
    run_scan
    cand=$(field "$output" 4); flight=$(field "$output" 5); linked=$(field "$output" 6)
    [ "$cand" -eq 2 ]     # T-9003 (no follower) + T-9006 (follower predates it)
    [ "$flight" -eq 1 ]   # T-9002 — follower T-9102 still in active/
    [ "$linked" -eq 1 ]   # T-9001 — follower T-9101 completed
    # The control that matters: no tier swallowed the others.
    [ $((cand + flight + linked)) -eq "$(field "$output" 3)" ]
    [ "$cand" -ne "$(field "$output" 3)" ]
}

@test "a follower filed BEFORE the inception does not count as propagation" {
    run_scan
    grep -q '^- T-9006' "$REPORT"
    # T-9006 is mentioned by T-9106, but T-9106 was created 2025-12-01 and the
    # inception 2026-01-01. Work cannot implement a decision that did not exist.
    awk '/^## candidate /{f=1;next} /^## /{f=0} f' "$REPORT" | grep -q 'T-9006'
}

@test "classification never silences a finding" {
    run_scan
    # Every tiered item is still a finding: the tiers partition, they do not filter.
    total=$(field "$output" 3)
    listed=$(grep -c '^- T-' "$REPORT")
    [ "$listed" -eq "$total" ]
}

@test "the sample names candidates, and its overflow counts candidates only" {
    run_scan
    sample=$(field "$output" 7)
    echo "$sample" | grep -qE 'T-900(3|6)'
    # Must not advertise an overflow measured against all findings.
    if echo "$sample" | grep -q '+'; then
        echo "$sample" | grep -q 'more candidate'
    fi
}

@test "report carries a section per tier, each naming its followers" {
    run_scan
    grep -q '^## candidate (' "$REPORT"
    grep -q '^## in-flight (' "$REPORT"
    grep -q '^## linked-late (' "$REPORT"
    # in-flight followers are starred so the reader can see WHY it is in-flight.
    awk '/^## in-flight /{f=1;next} /^## /{f=0} f' "$REPORT" | grep -q 'T-9102\*'
    awk '/^## linked-late /{f=1;next} /^## /{f=0} f' "$REPORT" | grep -q 'T-9101\]'
}

@test "report still states the qualifier the WARN used to omit" {
    run_scan
    grep -q 'candidates for triage, not confirmed abandoned decisions' "$REPORT"
    grep -q 'NOBODY BUILT THIS' "$REPORT"
}

@test "an empty corpus reports zero findings rather than failing" {
    rm -rf "$WORK/.tasks/completed" "$WORK/.tasks/active"
    mkdir -p "$WORK/.tasks/completed" "$WORK/.tasks/active"
    run_scan
    [ "$status" -eq 0 ]
    [ "$(field "$output" 3)" -eq 0 ]
}

@test "audit.sh still parses, and still binds all seven summary fields" {
    run bash -n "$AUDIT"
    [ "$status" -eq 0 ]
    # The shell read must consume every field the python prints, or a count
    # lands in the wrong variable and the WARN misreports silently.
    grep -q "read -r _gs_inceptions _gs_go _gs_count _gs_cand _gs_flight _gs_linked _gs_sample" "$AUDIT"
}

@test "warn_unenumerable still guards an unevaluated scan (T-3099 must not regress)" {
    # A scan that did not run must not read as a scan that found nothing.
    #
    # This rail was observed FIRING during T-3469's own build: an unescaped
    # python docstring closed the shell string, the pre-scan emitted nothing,
    # and audit printed "GO-scope-not-propagated scan — NOT EVALUATED" instead
    # of a clean zero. That is the behaviour under test; this grep only pins
    # that the branch is still wired.
    grep -A8 'if \[ -z "\$go_scope_summary" \]; then' "$AUDIT" | grep -q 'warn_unenumerable'
}
