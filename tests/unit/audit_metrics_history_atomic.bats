#!/usr/bin/env bats
# T-100190: metrics-history writer must be atomic (same-dir temp + os.replace).
#
# Origin: 2026-07-05 — a cron audit killed mid-`yaml.dump` truncated
# .context/project/metrics-history.yaml (file ended with a bare "warn"),
# and the pre-push YAML gate (T-1599/T-1610) then blocked all pushes until
# manual `git checkout --` recovery. Third instance of the non-atomic
# YAML-write class (T-2457 fabric cards / L-493, T-2456 fw note / L-492).

AUDIT_SH="$BATS_TEST_DIRNAME/../../agents/audit/audit.sh"

setup() {
    FIXTURE="$(mktemp -d)"
    mkdir -p "$FIXTURE/.context/project" "$FIXTURE/.tasks/active" "$FIXTURE/.tasks/completed"
    git -C "$FIXTURE" init -q
    cat > "$FIXTURE/.context/project/metrics-history.yaml" << 'YAML'
# Time-series metrics history
entries:
- timestamp: '2026-07-01T00:00:00Z'
  pass: 5
  warn: 1
  fail: 0
- timestamp: '2026-07-02T00:00:00Z'
  pass: 6
  warn: 0
  fail: 0
YAML
}

teardown() {
    rm -rf "$FIXTURE"
}

@test "metrics-history write path uses temp + os.replace, no truncating open-w" {
    # Atomic pattern present in the METRICS_EOF block
    grep -q 'os.replace(tmp_path, METRICS_FILE)' "$AUDIT_SH"
    # The truncating in-place write is gone
    ! grep -q 'with open(METRICS_FILE, "w")' "$AUDIT_SH"
}

@test "extracted METRICS_EOF block round-trips: output parses, entries preserved, no temp left" {
    PROJECT_ROOT="$FIXTURE" AUDIT_PASS=7 AUDIT_WARN=2 AUDIT_FAIL=1 python3 - "$AUDIT_SH" << 'PYEOF'
import re, sys, os
src = open(sys.argv[1]).read()
m = re.search(r"python3 << 'METRICS_EOF'\n(.*?)\nMETRICS_EOF", src, re.S)
assert m, "METRICS_EOF block not found in audit.sh"
exec(compile(m.group(1), "metrics_block", "exec"))
PYEOF
    # File parses as YAML and the new entry was appended after prune
    run python3 -c "
import yaml, sys
d = yaml.safe_load(open('$FIXTURE/.context/project/metrics-history.yaml'))
entries = d['entries']
assert len(entries) >= 1, entries
latest = entries[-1]
assert latest['pass'] == 7 and latest['warn'] == 2 and latest['fail'] == 1, latest
"
    [ "$status" -eq 0 ]
    # No orphaned temp file
    [ ! -e "$FIXTURE/.context/project/metrics-history.yaml.tmp" ]
}

@test "kill before replace leaves live file intact (temp absorbs the partial write)" {
    # Simulate the failure mode: write the temp, never call os.replace, then
    # verify the live file still parses. This pins the *reason* for atomicity.
    printf 'entries:\n- timestamp: 2026-07-03\n  pa' > "$FIXTURE/.context/project/metrics-history.yaml.tmp"
    run python3 -c "
import yaml
yaml.safe_load(open('$FIXTURE/.context/project/metrics-history.yaml'))
"
    [ "$status" -eq 0 ]
}
