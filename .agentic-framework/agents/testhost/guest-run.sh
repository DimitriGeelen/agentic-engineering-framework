#!/usr/bin/env bash
# guest-run.sh INPUT-DIR OUTPUT-DIR — what the test VM's boot service runs (T-5009 phase 3).
#
# INPUT-DIR holds pr.bundle (made by the controller: refs/heads/base and refs/heads/head).
# This script and pr-checks.sh come from AEF's own released copy (the template / the
# controller's input disk), NEVER from the bundle. The bundle is cloned into a work dir
# (as the unprivileged user `testhost` when running as root and that user exists) and the
# only thing run from it is the checks themselves, via pr-checks.sh.
#
# stdout is the serial console: progress goes there. OUTPUT-DIR receives:
#   result.json  {version:1, status: passed|failed, phases:[{name, rc, seconds}], started, finished}
#   checks.log   the checks' output, capped at TESTHOST_GUEST_LOG_CAP bytes (default 1 MiB)
# The controller treats both as hostile data and decides the run's state itself.
set -euo pipefail

in_dir="${1:?usage: guest-run.sh INPUT-DIR OUTPUT-DIR}"
out_dir="${2:?usage: guest-run.sh INPUT-DIR OUTPUT-DIR}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_cap="${TESTHOST_GUEST_LOG_CAP:-1048576}"
started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "== testhost guest: start $started =="
bundle="$in_dir/pr.bundle"
if [ ! -f "$bundle" ]; then
    echo "== testhost guest: no input bundle; exiting without a result =="
    exit 3
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/testhost-work.XXXXXX")"
raw_log="$(mktemp "${TMPDIR:-/tmp}/testhost-log.XXXXXX")"
runas=()
if [ "$(id -u)" -eq 0 ] && id testhost >/dev/null 2>&1; then
    chown testhost "$work" "$raw_log"
    chmod 0644 "$bundle" 2>/dev/null || true
    runas=(runuser -u testhost --)
fi

echo "== testhost guest: clone =="
"${runas[@]}" git -c core.hooksPath=/dev/null clone -q --no-checkout "$bundle" "$work/src"
"${runas[@]}" git -C "$work/src" -c core.hooksPath=/dev/null checkout -q -B pr origin/head

echo "== testhost guest: checks =="
rc=0
( cd "$work/src" && "${runas[@]}" bash "$here/pr-checks.sh" origin/base ) 2>&1 | tee "$raw_log" || rc=$?
finished="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

head -c "$log_cap" "$raw_log" > "$out_dir/checks.log"
python3 - "$raw_log" "$rc" "$started" "$finished" > "$out_dir/result.json.tmp" <<'PY'
import json, re, sys
log, rc, started, finished = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
phases = []
pat = re.compile(r"^== PHASE ([a-z][a-z0-9-]{0,31}) end rc=(\d+) seconds=(\d+) ==$")
with open(log, encoding="utf-8", errors="replace") as fh:
    for line in fh:
        m = pat.match(line.rstrip("\n"))
        if m:
            phases.append({"name": m.group(1), "rc": int(m.group(2)), "seconds": int(m.group(3))})
status = "passed" if rc == 0 and phases and all(p["rc"] == 0 for p in phases) else "failed"
print(json.dumps({"version": 1, "status": status, "phases": phases,
                  "started": started, "finished": finished}))
PY
mv "$out_dir/result.json.tmp" "$out_dir/result.json"
rm -rf "$work" "$raw_log"
echo "== testhost guest: done rc=$rc =="
exit 0
