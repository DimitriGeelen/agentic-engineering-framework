#!/usr/bin/env bash
# T-1304: fw metrics api-usage --last-Nd [--runtime-dir PATH] [--gate-pct N]
#
# Reads <runtime_dir>/rpc-audit.jsonl, filters to entries with ts >= now - N days,
# tallies per-method counts, and reports total + top 10 + legacy-primitive
# percentage. Exits 0 if legacy primitives ≤ gate-pct, else 1 (so it can be used
# as the T-1166 entry gate in CI).
#
# Legacy primitives (per T-1166 § Decommission):
#   event.broadcast, inbox.list, inbox.status, inbox.clear,
#   file.send, file.receive (+ chunked variants file.send.*)

set -euo pipefail

LAST_N=60
RUNTIME_DIR="${TERMLINK_RUNTIME_DIR:-/var/lib/termlink}"
GATE_PCT="1.0"

usage() {
    cat <<EOF
fw metrics api-usage — T-1166 entry-gate telemetry

Usage:
  fw metrics api-usage [--last-Nd N] [--runtime-dir PATH] [--gate-pct N]

Options:
  --last-Nd N          Window in days (default: 60)
  --runtime-dir PATH   Hub runtime directory (default: \$TERMLINK_RUNTIME_DIR or /var/lib/termlink)
  --gate-pct N         Exit non-zero if legacy primitives exceed N% (default: 1.0)
  -h, --help           This message

Reads:  <runtime_dir>/rpc-audit.jsonl
Exit:   0 = legacy ≤ gate-pct, 1 = legacy > gate-pct (or audit file missing)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --last-Nd) LAST_N="$2"; shift 2 ;;
        --runtime-dir) RUNTIME_DIR="$2"; shift 2 ;;
        --gate-pct) GATE_PCT="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

AUDIT_FILE="$RUNTIME_DIR/rpc-audit.jsonl"

if [ ! -f "$AUDIT_FILE" ]; then
    echo "ERROR: audit file not found: $AUDIT_FILE" >&2
    echo "  Hub may not have started since T-1304 deployed, or runtime_dir is wrong." >&2
    exit 1
fi

python3 - "$AUDIT_FILE" "$LAST_N" "$GATE_PCT" <<'PY'
import sys, json, time
from collections import Counter

audit_path, last_n, gate_pct_s = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])

cutoff_ms = (time.time() - last_n * 86400) * 1000

counts = Counter()
total = 0
malformed = 0
with open(audit_path, "r") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            ts = entry.get("ts")
            method = entry.get("method")
            if ts is None or method is None:
                malformed += 1
                continue
            if ts < cutoff_ms:
                continue
            counts[method] += 1
            total += 1
        except json.JSONDecodeError:
            malformed += 1

LEGACY = {
    "event.broadcast",
    "inbox.list",
    "inbox.status",
    "inbox.clear",
    "file.send",
    "file.receive",
}

legacy_total = sum(c for m, c in counts.items() if m in LEGACY or m.startswith("file.send.") or m.startswith("file.receive."))

print(f"== fw metrics api-usage ==")
print(f"  Audit file: {audit_path}")
print(f"  Window:     last {last_n} days")
print(f"  Total RPCs: {total}")
if malformed:
    print(f"  Malformed:  {malformed} lines (skipped)")
print()

if total == 0:
    print("  No RPC traffic in window.")
    sys.exit(0)

print(f"  Top 10 methods:")
for method, count in counts.most_common(10):
    pct = (count / total) * 100
    print(f"    {count:>8d}  {pct:5.1f}%  {method}")
print()

legacy_pct = (legacy_total / total) * 100 if total > 0 else 0.0
gate_pass = legacy_pct <= gate_pct_s

status = "PASS" if gate_pass else "FAIL"
print(f"  Legacy primitives: {legacy_total} ({legacy_pct:.2f}% of total)")
print(f"  Gate threshold:    {gate_pct_s:.2f}%  →  {status}")

if not gate_pass:
    print()
    print("  Legacy traffic exceeds T-1166 entry threshold.")
    print("  Hunt down the remaining callers before retiring legacy primitives.")
    print()
    print("  Live callers in window:")
    for m in sorted(LEGACY):
        c = counts.get(m, 0)
        if c > 0:
            print(f"    {c:>8d}  {m}")
    sys.exit(1)

sys.exit(0)
PY
