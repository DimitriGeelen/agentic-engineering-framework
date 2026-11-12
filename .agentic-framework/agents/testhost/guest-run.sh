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
#
# T-5098 (design A, T-5009 section 8b): the run ALSO ends with one framed result block on
# stdout (the serial console), so a backend with no output disk gets the result from it:
#   ==TESTHOST-RESULT-BEGIN v1 nonce=N sha256=H bytes=B==
#   <base64 of gzip(JSON {"result": <result.json text>, "checks_log": <checks.log text>})>
#   ==TESTHOST-RESULT-END nonce=N==
# N comes from INPUT-DIR/nonce, read by this script (root in the VM) before the checks run.
# The VM's boot service copies the CD into a root-only INPUT-DIR, so the PR's code, running as
# `testhost`, cannot read N and cannot forge a block the controller accepts.
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

nonce=""
if [ -f "$in_dir/nonce" ]; then
    nonce="$(tr -cd '0-9a-f' < "$in_dir/nonce" | head -c 64)"
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/testhost-work.XXXXXX")"
raw_log="$(mktemp "${TMPDIR:-/tmp}/testhost-log.XXXXXX")"
cp "$bundle" "$work/pr.bundle"          # the PR's user never needs to reach INPUT-DIR
cp "$here/pr-checks.sh" "$work/pr-checks.sh"   # T-5099: INPUT-DIR is root-only in the VM
runas=()
if [ "$(id -u)" -eq 0 ] && id testhost >/dev/null 2>&1; then
    chown testhost "$work" "$work/pr.bundle" "$work/pr-checks.sh" "$raw_log"
    runas=(runuser -u testhost --)
fi

echo "== testhost guest: clone =="
"${runas[@]}" git -c core.hooksPath=/dev/null clone -q --no-checkout "$work/pr.bundle" "$work/src"
"${runas[@]}" git -C "$work/src" -c core.hooksPath=/dev/null checkout -q -B pr origin/head

echo "== testhost guest: checks =="
rc=0
( cd "$work/src" && "${runas[@]}" bash "$work/pr-checks.sh" origin/base ) 2>&1 | tee "$raw_log" || rc=$?
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
if [ -n "$nonce" ]; then
    python3 - "$out_dir/result.json" "$out_dir/checks.log" "$nonce" <<'PY'
import base64, gzip, hashlib, json, sys
res, log, nonce = sys.argv[1], sys.argv[2], sys.argv[3]
doc = {"result": open(res, encoding="utf-8", errors="replace").read(),
       "checks_log": open(log, encoding="utf-8", errors="replace").read()}
blob = base64.b64encode(gzip.compress(json.dumps(doc).encode("utf-8"), mtime=0)).decode("ascii")
sha = hashlib.sha256(blob.encode("ascii")).hexdigest()
out = [f"==TESTHOST-RESULT-BEGIN v1 nonce={nonce} sha256={sha} bytes={len(blob)}=="]
out += [blob[i:i + 76] for i in range(0, len(blob), 76)]
out.append(f"==TESTHOST-RESULT-END nonce={nonce}==")
sys.stdout.write("\n".join(out) + "\n")
sys.stdout.flush()
PY
fi
exit 0
