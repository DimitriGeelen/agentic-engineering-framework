#!/usr/bin/env bats
# T-3621 (OBS-587): the pre-push unit-suite gate is a RATCHET.
#
# Since T-3602 the nightly run completes and records ~114 reds that pre-date
# the gate. A gate that FAILs on all of them blocks every push until the whole
# backlog is fixed; a gate that ignores them lets the backlog read as green.
# The ratchet does neither:
#
#   pre-push scope (`audit.sh --section structure`, exactly what the pre-push
#   hook runs):
#     red NOT in the baseline            → FAIL (new breakage)
#     baselined red past its expiry      → FAIL
#     only unexpired baselined reds      → WARN with the count
#     no/unreadable baseline             → FAIL on every red (fail closed)
#   any other scope (full `fw audit`, the */30 cron's multi-section run):
#     every red FAILs, baselined or not  → the backlog never reads green
#
#   The baseline only shrinks without the operator: `regenerate` drops entries
#   the latest report shows green, never adds; `add` refuses without
#   --i-am-human; `init` refuses when a baseline already exists.
#
# Hermetic: fixture reports + fixture baselines under $BATS_TEST_TMPDIR. The
# audit check is EXTRACTED from the shipped agents/audit/audit.sh.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TOOL="$REPO_ROOT/agents/audit/unit_suite_baseline.py"
    WORK="$BATS_TEST_TMPDIR/t3621"
    mkdir -p "$WORK"
    FUTURE=$(date -u -d '+10 days' +%F)
    PAST=$(date -u -d '-1 days' +%F)
}

# _run_check <report> <baseline> <sections>
_run_check() {
    run env FW_UNIT_SUITE_REPORT="$1" FW_UNIT_SUITE_BASELINE="$2" SECTIONS="$3" \
        REPO_ROOT="$REPO_ROOT" bash -c '
        pass() { echo "PASS|$1"; }
        info() { echo "INFO|$1"; }
        warn() { echo "WARN|$1"; echo "WARNEV|$2"; echo "WARNMIT|$3"; }
        fail() { echo "FAIL|$1"; echo "EVIDENCE|$2"; echo "MITIGATION|$3"; }
        eval "$(sed -n "/^pass_over() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^warn_unenumerable() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^_audit_is_prepush_scope() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^check_unit_suite_report() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        CONTEXT_DIR="/nonexistent-t3621"
        check_unit_suite_report
    '
}

# _report <path> <bats-failed-yaml-list> [finished] [files_timed_out-yaml-list]
_report() {
    local path="$1" failed="$2" fin="${3:-$(date -u +%FT%TZ)}" ftimed="${4:-[]}"
    local n=0
    [ "$failed" != "[]" ] && n=$(echo "$failed" | tr ',' '\n' | wc -l | tr -d ' ')
    cat > "$path" <<EOF
schema: unit-suite-report-v2
task: T-3621
started: '$fin'
finished: '$fin'
timeout_seconds: 7200
timed_out: false
runner_exit: 1
legs:
  bats:
    files: 10
    files_completed: 10
    files_timed_out: $ftimed
    files_not_run: 0
    tests: 100
    failed_count: $n
    skipped: 0
    exit: 1
    failed: $failed
    error: null
  pytest:
    files: 2
    files_completed: 2
    files_timed_out: []
    files_not_run: 0
    tests: 20
    failed_count: 0
    skipped: 0
    exit: 0
    failed: []
    error: null
EOF
}

# _baseline <path> <expires> <name>...
_baseline() {
    local path="$1" exp="$2"; shift 2
    {
        echo "schema: unit-suite-baseline-v1"
        echo "task: T-3621"
        echo "entries:"
        for n in "$@"; do
            echo "  - leg: bats"
            echo "    name: '$n'"
            echo "    file: ${n%%:*}"
            echo "    owner: T-9999"
            echo "    added: '2026-10-01'"
            echo "    expires: '$exp'"
        done
    } > "$path"
}

PREPUSH=structure

# `! cmd` mid-test is a dead negation in bats (errexit ignores it, T-3598/T-3610):
# negate inside a function so the function's status is a plain command status.
_refute_out() { ! echo "$output" | grep -q "$1"; }
_refute_evidence() { ! echo "$output" | grep '^EVIDENCE|' | grep -q "$1"; }

# ── grading: pre-push scope ─────────────────────────────────────────────────

@test "T-3621: pre-push — a red NOT in the baseline FAILs, naming only the new one" {
    _report "$WORK/r.yaml" '["old.bats: known red", "new.bats: fresh breakage"]'
    _baseline "$WORK/b.yaml" "$FUTURE" "old.bats: known red"
    _run_check "$WORK/r.yaml" "$WORK/b.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit).*1 NEW red'
    echo "$output" | grep '^EVIDENCE|' | grep -q 'new.bats: fresh breakage'
    _refute_evidence 'old.bats: known red'
}

@test "T-3621: pre-push — only baselined reds WARN with the count, no FAIL" {
    _report "$WORK/r.yaml" '["old.bats: known red", "old.bats: second known red"]'
    _baseline "$WORK/b.yaml" "$FUTURE" "old.bats: known red" "old.bats: second known red"
    _run_check "$WORK/r.yaml" "$WORK/b.yaml" "$PREPUSH"
    echo "$output"
    _refute_out '^FAIL|'
    echo "$output" | grep -q '^WARN|Unit suite (tests/unit): 2 BASELINED red'
}

@test "T-3621: pre-push — a baselined red past its expiry FAILs" {
    _report "$WORK/r.yaml" '["old.bats: known red"]'
    _baseline "$WORK/b.yaml" "$PAST" "old.bats: known red"
    _run_check "$WORK/r.yaml" "$WORK/b.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit).*1 EXPIRED'
    echo "$output" | grep '^EVIDENCE|' | grep -q 'old.bats: known red'
}

@test "T-3621: pre-push — no baseline file fails closed: every red FAILs" {
    _report "$WORK/r.yaml" '["old.bats: known red"]'
    _run_check "$WORK/r.yaml" "$WORK/absent.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit)'
}

@test "T-3621: pre-push — unparsable baseline fails closed: every red FAILs" {
    _report "$WORK/r.yaml" '["old.bats: known red"]'
    printf 'entries: [unclosed\n' > "$WORK/b.yaml"
    _run_check "$WORK/r.yaml" "$WORK/b.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit)'
}

@test "T-3621: pre-push — baselined-only but STALE report still WARNs stale (unchanged rule)" {
    _report "$WORK/r.yaml" '["old.bats: known red"]' "2026-01-01T00:00:00Z"
    _baseline "$WORK/b.yaml" "$FUTURE" "old.bats: known red"
    _run_check "$WORK/r.yaml" "$WORK/b.yaml" "$PREPUSH"
    echo "$output"
    _refute_out '^FAIL|'
    echo "$output" | grep -q '^WARN|Unit suite (tests/unit) report STALE'
}

@test "T-3621: pre-push — baselined-only but INCOMPLETE run names the unfinished files (unchanged rule)" {
    _report "$WORK/r.yaml" '["old.bats: known red"]' "" '["slow.bats"]'
    _baseline "$WORK/b.yaml" "$FUTURE" "old.bats: known red"
    _run_check "$WORK/r.yaml" "$WORK/b.yaml" "$PREPUSH"
    echo "$output"
    _refute_out '^FAIL|'
    echo "$output" | grep -q 'slow.bats'
}

# ── grading: every other scope keeps FAILing on every red ───────────────────

@test "T-3621: full audit (no --section) FAILs on baselined reds — backlog never reads green" {
    _report "$WORK/r.yaml" '["old.bats: known red"]'
    _baseline "$WORK/b.yaml" "$FUTURE" "old.bats: known red"
    _run_check "$WORK/r.yaml" "$WORK/b.yaml" ""
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit): 1 of 120 unit test(s) RED'
    echo "$output" | grep '^EVIDENCE|' | grep -q '1 baselined'
}

@test "T-3621: the */30 cron multi-section run FAILs on baselined reds" {
    _report "$WORK/r.yaml" '["old.bats: known red"]'
    _baseline "$WORK/b.yaml" "$FUTURE" "old.bats: known red"
    _run_check "$WORK/r.yaml" "$WORK/b.yaml" "structure,compliance,quality,discovery"
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit): 1 of 120 unit test(s) RED'
}

@test "T-3621: the pre-push hook still runs exactly '--section structure' (the scope the ratchet keys on)" {
    grep -q '"$AUDIT_SCRIPT" --section structure' "$REPO_ROOT/agents/git/lib/hooks.sh"
}

# ── the baseline only shrinks without the operator ──────────────────────────

@test "T-3621: an agent adding an entry is refused without --i-am-human" {
    _baseline "$WORK/b.yaml" "$FUTURE" "old.bats: known red"
    cp "$WORK/b.yaml" "$WORK/b.before"
    run python3 "$TOOL" add --baseline "$WORK/b.yaml" --leg bats --name "new.bats: sneaked in"
    echo "$output"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'i-am-human'
    cmp -s "$WORK/b.yaml" "$WORK/b.before"
}

@test "T-3621: the operator can add an entry with --i-am-human (default expiry 14 days)" {
    _baseline "$WORK/b.yaml" "$FUTURE" "old.bats: known red"
    run python3 "$TOOL" add --i-am-human --baseline "$WORK/b.yaml" --leg bats \
        --name "new.bats: accepted" --owner T-1234
    echo "$output"
    [ "$status" -eq 0 ]
    exp=$(date -u -d '+14 days' +%F)
    python3 - "$WORK/b.yaml" "$exp" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
e = [x for x in d["entries"] if x["name"] == "new.bats: accepted"]
assert len(e) == 1 and e[0]["owner"] == "T-1234" and str(e[0]["expires"]) == sys.argv[2], e
PY
}

@test "T-3621: regenerate drops entries that turned green, keeps reds and unrun files, never adds" {
    _report "$WORK/r.yaml" '["still.bats: red", "brandnew.bats: red"]' "" '["slow.bats"]'
    _baseline "$WORK/b.yaml" "$FUTURE" "still.bats: red" "fixed.bats: now green" "slow.bats: unknown"
    run python3 "$TOOL" regenerate --baseline "$WORK/b.yaml" --report "$WORK/r.yaml"
    echo "$output"
    [ "$status" -eq 0 ]
    python3 - "$WORK/b.yaml" <<'PY'
import sys, yaml
names = {x["name"] for x in yaml.safe_load(open(sys.argv[1]))["entries"]}
assert names == {"still.bats: red", "slow.bats: unknown"}, names
PY
}

@test "T-3621: regenerate keeps every entry when the report is unreadable" {
    printf 'legs: [broken\n' > "$WORK/r.yaml"
    _baseline "$WORK/b.yaml" "$FUTURE" "a.bats: x" "b.bats: y"
    cp "$WORK/b.yaml" "$WORK/b.before"
    run python3 "$TOOL" regenerate --baseline "$WORK/b.yaml" --report "$WORK/r.yaml"
    echo "$output"
    [ "$status" -ne 0 ]
    cmp -s "$WORK/b.yaml" "$WORK/b.before"
}

@test "T-3621: init refuses when a baseline already exists (no grow-by-reinit)" {
    _report "$WORK/r.yaml" '["a.bats: x", "b.bats: y"]'
    _baseline "$WORK/b.yaml" "$FUTURE" "a.bats: x"
    cp "$WORK/b.yaml" "$WORK/b.before"
    run python3 "$TOOL" init --baseline "$WORK/b.yaml" --report "$WORK/r.yaml"
    echo "$output"
    [ "$status" -ne 0 ]
    cmp -s "$WORK/b.yaml" "$WORK/b.before"
}

@test "T-3621: init maps reds to triage owners or 'untriaged', expiry 14 days" {
    _report "$WORK/r.yaml" '["owned.bats: x", "unowned.bats: y"]'
    mkdir -p "$WORK/reports"
    cat > "$WORK/reports/T-7777-triage.md" <<'EOF'
| File | Failing tests | Breaking commit | Verdict | Action |
|---|---|---|---|---|
| owned | 1 | abc | REGRESSION | **T-8888** |
EOF
    run python3 "$TOOL" init --baseline "$WORK/b.yaml" --report "$WORK/r.yaml" \
        --triage-dir "$WORK/reports"
    echo "$output"
    [ "$status" -eq 0 ]
    exp=$(date -u -d '+14 days' +%F)
    python3 - "$WORK/b.yaml" "$exp" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
own = {x["name"]: x["owner"] for x in d["entries"]}
assert own == {"owned.bats: x": "T-8888", "unowned.bats: y": "untriaged"}, own
assert all(str(x["expires"]) == sys.argv[2] for x in d["entries"])
PY
}

# ── the committed baseline is well-formed (invariant, not a live count) ─────

@test "T-3621: committed baseline parses; every entry has leg, name, owner, expires" {
    python3 - "$REPO_ROOT/.context/audits/unit-suite/baseline.yaml" <<'PY'
import sys, re, yaml, datetime
d = yaml.safe_load(open(sys.argv[1]))
assert d["schema"] == "unit-suite-baseline-v1"
assert d["entries"], "empty baseline"
for e in d["entries"]:
    assert e["leg"] in ("bats", "pytest"), e
    assert e["name"], e
    assert e["owner"] == "untriaged" or re.fullmatch(r"T-\d+", e["owner"]), e
    datetime.date.fromisoformat(str(e["expires"]))
PY
}
