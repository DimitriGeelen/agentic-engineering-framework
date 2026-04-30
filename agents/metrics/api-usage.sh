#!/usr/bin/env bash
# T-1304/T-1308: fw metrics api-usage [--last-Nd N] [--runtime-dir PATH] [--gate-pct N]
#
# Reads <runtime_dir>/rpc-audit.jsonl, tallies per-method RPC counts, and
# reports the percentage of legacy primitives — used as the T-1166 entry
# gate (retire legacy `event.broadcast` + `inbox.*` + `file.*` once their
# share drops below 1% over 60 days).
#
# Modes:
#   - Default (no --last-Nd):       trend report across 1d / 7d / 30d / 60d
#                                   windows for incremental feedback. Exit
#                                   code reflects the 60d (gate) window.
#   - --last-Nd N:                  single window, original CI-gate behavior.
#                                   Exit 0 if legacy ≤ gate-pct, else 1.
#
# Legacy primitives (per T-1166 § Decommission):
#   event.broadcast, inbox.list, inbox.status, inbox.clear,
#   file.send, file.receive (+ chunked variants file.send.*).

set -euo pipefail

LAST_N=""
RUNTIME_DIR="${TERMLINK_RUNTIME_DIR:-/var/lib/termlink}"
GATE_PCT="1.0"
JSON_OUT="0"
CUT_READY="0"

usage() {
    cat <<EOF
fw metrics api-usage — T-1166 entry-gate telemetry (with incremental trend)

Usage:
  fw metrics api-usage [--runtime-dir PATH] [--gate-pct N] [--json]
  fw metrics api-usage --last-Nd N [--runtime-dir PATH] [--gate-pct N] [--json]

Options:
  --last-Nd N          Window in days. If omitted, prints trend across
                       1d / 7d / 30d / 60d for incremental feedback.
  --runtime-dir PATH   Hub runtime directory (default: \$TERMLINK_RUNTIME_DIR or /var/lib/termlink)
  --gate-pct N         Threshold % below which legacy traffic passes the
                       T-1166 entry gate (default: 1.0)
  --json               Emit structured JSON to stdout (T-1312). Stable shape
                       for dashboards, watchtower pages, cron aggregators.
  --cut-ready          T-1416: stricter binary gate for the T-1166 cut.
                       Exit 0 iff legacy_attributable == 0 in the chosen
                       window (default 7d). Ignores pre-T-1409 backlog
                       (ages out on its own). Compose with --json for CI
                       use: emits {cut_ready, window_days, legacy_attributable}.
  -h, --help           This message

Reads:  <runtime_dir>/rpc-audit.jsonl
Exit:   0 = gate PASS at 60d (or chosen window), 1 = FAIL or audit missing.
        With --cut-ready: 0 iff zero attributable legacy in window.

Why trend mode:  Don't wait 60 days to see if legacy traffic is dropping.
The trend report shows the trajectory at 1d / 7d / 30d / 60d so you can
verify migrations land correctly within hours, not months.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --last-Nd) LAST_N="$2"; shift 2 ;;
        --runtime-dir) RUNTIME_DIR="$2"; shift 2 ;;
        --gate-pct) GATE_PCT="$2"; shift 2 ;;
        --json) JSON_OUT="1"; shift ;;
        --cut-ready) CUT_READY="1"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# T-1416: cut-ready mode defaults the window to 7d if the operator didn't
# pass --last-Nd. The "is anyone still hitting legacy?" question doesn't
# need 60d; 7d is the bake window the operator cares about pre-cut.
if [ "$CUT_READY" = "1" ] && [ -z "$LAST_N" ]; then
    LAST_N="7"
fi

AUDIT_FILE="$RUNTIME_DIR/rpc-audit.jsonl"

if [ ! -f "$AUDIT_FILE" ]; then
    if [ "$JSON_OUT" = "1" ]; then
        # T-1312: JSON-mode error envelope on stdout.
        printf '{"error":"audit file not found","audit_file":"%s"}\n' "$AUDIT_FILE"
    else
        echo "ERROR: audit file not found: $AUDIT_FILE" >&2
        echo "  Hub may not have started since T-1304 deployed, or runtime_dir is wrong." >&2
    fi
    exit 1
fi

python3 - "$AUDIT_FILE" "$LAST_N" "$GATE_PCT" "$JSON_OUT" "$CUT_READY" <<'PY'
import sys, json, time
from collections import Counter

audit_path, last_n_s, gate_pct_s = sys.argv[1], sys.argv[2], float(sys.argv[3])
json_out = (sys.argv[4] == "1") if len(sys.argv) > 4 else False
cut_ready = (sys.argv[5] == "1") if len(sys.argv) > 5 else False

LEGACY = {
    "event.broadcast",
    "inbox.list",
    "inbox.status",
    "inbox.clear",
    "file.send",
    "file.receive",
}

def is_legacy(method: str) -> bool:
    return method in LEGACY or method.startswith("file.send.") or method.startswith("file.receive.")

# One pass over the file, bucketing per (largest) window we'll need.
# We compute (ts_ms, method, from) tuples and filter per-window in memory — this is
# fine at single-hub scale (millions of lines = tens of MB).
# T-1309: from is None for entries written before T-1309 (or by callers that
# didn't supply the field). Surfaces as "(unknown)" in the breakdown.
# T-1408: peer_pid is None for entries written before T-1407 and for TCP/TLS
# connections (which have no local PID). Surfaces in a separate
# "Legacy callers by PID" section so anonymous (no-from) callers become
# identifiable via `ps -p <pid>`.
# T-1409: peer_addr is None for entries written before T-1409 and for Unix
# connections (no TCP). Surfaces in "Legacy callers by IP" — the network
# analogue of peer_pid for callers without a `from` tag.
now_ms = time.time() * 1000
entries = []
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
            from_ = entry.get("from")
            peer_pid = entry.get("peer_pid")
            peer_addr = entry.get("peer_addr")
            entries.append((ts, method, from_, peer_pid, peer_addr))
        except json.JSONDecodeError:
            malformed += 1

UNKNOWN = "(unknown)"

def addr_to_ip(addr: str) -> str:
    """T-1410: strip ephemeral source port from peer_addr.
    IPv4: '192.168.1.5:42820' -> '192.168.1.5'
    IPv6: '[::1]:9100'         -> '[::1]'
    rsplit(':', 1) handles both because IPv6 brackets keep the colons inside.
    """
    return addr.rsplit(":", 1)[0] if ":" in addr else addr

def stats_for_window(days: int):
    cutoff = now_ms - days * 86400 * 1000
    counts = Counter()
    legacy_callers = Counter()  # (method, from) -> count
    legacy_pids = Counter()  # (method, peer_pid) -> count, peer_pid present only
    legacy_ips = Counter()   # (method, peer_ip) -> count, peer_addr present only
    total = 0
    legacy_total = 0
    # T-1414: split legacy by attribution. A line is "unattributable" if it
    # carries no source identifier at all (from, peer_pid, peer_addr all absent).
    # On the .122 hub this corresponds 1:1 with pre-T-1409 historical lines;
    # post-T-1409, every TCP line has peer_addr and every Unix line has peer_pid.
    # The split lets operators see "remaining holdouts" without the rolling
    # window blurring it via pre-deploy backlog.
    legacy_unattributable = 0
    for ts, method, from_, peer_pid, peer_addr in entries:
        if ts < cutoff:
            continue
        counts[method] += 1
        total += 1
        if is_legacy(method):
            legacy_total += 1
            legacy_callers[(method, from_ or UNKNOWN)] += 1
            if peer_pid is not None:
                legacy_pids[(method, peer_pid)] += 1
            if peer_addr:
                # T-1410: rollup by IP — ephemeral source ports otherwise
                # fragment a single host into N rows of count=1.
                legacy_ips[(method, addr_to_ip(peer_addr))] += 1
            if from_ is None and peer_pid is None and not peer_addr:
                legacy_unattributable += 1
    return counts, total, legacy_total, legacy_callers, legacy_pids, legacy_ips, legacy_unattributable

def build_top_methods(counts, total):
    """T-1312: shared helper for top-10 methods JSON shape."""
    out = []
    for method, count in counts.most_common(10):
        pct = (count / total) * 100 if total else 0.0
        out.append({
            "method": method,
            "count": count,
            "pct": round(pct, 2),
            "is_legacy": is_legacy(method),
        })
    return out

def build_legacy_callers(legacy_callers):
    """T-1312: shared helper for legacy callers JSON shape."""
    return [
        {"method": method, "from": from_, "count": count}
        for (method, from_), count in legacy_callers.most_common(15)
    ]

def build_legacy_callers_by_pid(legacy_pids):
    """T-1408: parallel breakdown by peer_pid for entries that carry it."""
    return [
        {"method": method, "peer_pid": pid, "count": count}
        for (method, pid), count in legacy_pids.most_common(15)
    ]

def build_legacy_callers_by_ip(legacy_ips):
    """T-1409/T-1410: parallel breakdown by peer_ip (TCP source IP).
    Ports stripped via addr_to_ip — one row per host, not per connection."""
    return [
        {"method": method, "peer_ip": ip, "count": count}
        for (method, ip), count in legacy_ips.most_common(15)
    ]

# T-1416: cut-ready short-circuit. Binary gate on attributable-only legacy.
# Composes with --json (compact CI shape) or human (one-line PASS/FAIL).
# Exits before the trend/single-window paths so the output is unambiguous.
if cut_ready:
    window_days = int(last_n_s) if last_n_s else 7
    _, _, legacy_total, _, _, _, legacy_unattr = stats_for_window(window_days)
    legacy_attr = legacy_total - legacy_unattr
    is_ready = (legacy_attr == 0)
    if json_out:
        print(json.dumps({
            "cut_ready": is_ready,
            "window_days": window_days,
            "legacy_attributable": legacy_attr,
            "legacy_unattributable_pre_t1409": legacy_unattr,
            "audit_file": audit_path,
        }))
    else:
        status = "READY" if is_ready else "NOT READY"
        print(f"== fw metrics api-usage --cut-ready ==")
        print(f"  Audit file:           {audit_path}")
        print(f"  Window:               last {window_days} days")
        print(f"  Legacy (attributable): {legacy_attr}")
        print(f"  Legacy (pre-T-1409):   {legacy_unattr} (ages out, ignored by gate)")
        print(f"  Cut-ready gate:        {status}")
        if not is_ready:
            print(f"  Migrate the remaining attributable callers, then re-check.")
    sys.exit(0 if is_ready else 1)

# T-1312: JSON output path. Stable shape — see docs/operations/api-usage-metrics.md.
if json_out:
    if last_n_s == "":
        # Trend mode JSON
        windows_out = []
        gate_passing = True
        for d in [1, 7, 30, 60]:
            _, total, legacy_total, _, _, _, legacy_unattr = stats_for_window(d)
            pct = (legacy_total / total) * 100 if total else 0.0
            passing = (pct <= gate_pct_s) if total > 0 else True
            windows_out.append({
                "days": d,
                "total": total,
                "legacy": legacy_total,
                "legacy_attributable": legacy_total - legacy_unattr,
                "legacy_unattributable_pre_t1409": legacy_unattr,
                "legacy_pct": round(pct, 4),
                "passing": passing,
            })
            if d == 60:
                gate_passing = passing if total > 0 else True
        counts_60, total_60, legacy_60, legacy_callers_60, legacy_pids_60, legacy_ips_60, legacy_unattr_60 = stats_for_window(60)
        out = {
            "audit_file": audit_path,
            "mode": "trend",
            "gate_pct": gate_pct_s,
            "malformed_lines": malformed,
            "windows": windows_out,
            "legacy": legacy_60,
            "legacy_attributable": legacy_60 - legacy_unattr_60,
            "legacy_unattributable_pre_t1409": legacy_unattr_60,
            "top_methods": build_top_methods(counts_60, total_60),
            "legacy_callers": build_legacy_callers(legacy_callers_60),
            "legacy_callers_by_pid": build_legacy_callers_by_pid(legacy_pids_60),
            "legacy_callers_by_ip": build_legacy_callers_by_ip(legacy_ips_60),
            "gate": {"window_days": 60, "passing": gate_passing},
        }
        print(json.dumps(out))
        sys.exit(0 if gate_passing else 1)
    else:
        last_n = int(last_n_s)
        counts, total, legacy_total, legacy_callers, legacy_pids, legacy_ips, legacy_unattr = stats_for_window(last_n)
        pct = (legacy_total / total) * 100 if total else 0.0
        passing = (pct <= gate_pct_s) if total > 0 else True
        out = {
            "audit_file": audit_path,
            "mode": "single-window",
            "gate_pct": gate_pct_s,
            "malformed_lines": malformed,
            "windows": [{
                "days": last_n,
                "total": total,
                "legacy": legacy_total,
                "legacy_attributable": legacy_total - legacy_unattr,
                "legacy_unattributable_pre_t1409": legacy_unattr,
                "legacy_pct": round(pct, 4),
                "passing": passing,
            }],
            "legacy": legacy_total,
            "legacy_attributable": legacy_total - legacy_unattr,
            "legacy_unattributable_pre_t1409": legacy_unattr,
            "top_methods": build_top_methods(counts, total),
            "legacy_callers": build_legacy_callers(legacy_callers),
            "legacy_callers_by_pid": build_legacy_callers_by_pid(legacy_pids),
            "legacy_callers_by_ip": build_legacy_callers_by_ip(legacy_ips),
            "gate": {"window_days": last_n, "passing": passing},
        }
        print(json.dumps(out))
        sys.exit(0 if passing else 1)

print(f"== fw metrics api-usage ==")
print(f"  Audit file: {audit_path}")
if malformed:
    print(f"  Malformed:  {malformed} lines (skipped)")

# Trend mode: print a 4-window table. Exit code from 60d.
if last_n_s == "":
    windows = [1, 7, 30, 60]
    print(f"  Mode:       trend (use --last-Nd N for single-window CI gate)")
    print()
    print(f"  {'Window':>8s}  {'Total':>8s}  {'Legacy':>8s}  {'Legacy %':>9s}  Status")
    print(f"  {'-'*8}  {'-'*8}  {'-'*8}  {'-'*9}  ------")
    final_pass = True
    final_total = 0
    final_unattr = 0
    for d in windows:
        _, total, legacy_total, _, _, _, legacy_unattr = stats_for_window(d)
        if total == 0:
            print(f"  {d:>5d}d    {total:>8d}  {legacy_total:>8d}  {'  N/A':>9s}  --")
            continue
        pct = (legacy_total / total) * 100
        passing = pct <= gate_pct_s
        status = "PASS" if passing else "FAIL"
        print(f"  {d:>5d}d    {total:>8d}  {legacy_total:>8d}  {pct:>8.2f}%  {status}")
        if d == 60:
            final_pass = passing
            final_total = total
            final_pct = pct
            final_legacy = legacy_total
            final_unattr = legacy_unattr

    # Top-10 methods using the 60d window (canonical T-1166 gate window)
    counts_60, total_60, legacy_60, legacy_callers_60, legacy_pids_60, legacy_ips_60, legacy_unattr_60 = stats_for_window(60)
    print()
    if total_60 > 0:
        print(f"  Top 10 methods (last 60d):")
        for method, count in counts_60.most_common(10):
            pct = (count / total_60) * 100
            marker = " ←legacy" if is_legacy(method) else ""
            print(f"    {count:>8d}  {pct:5.1f}%  {method}{marker}")

    # T-1309: who is calling legacy primitives? Operators driving T-1166 use
    # this to know which session to migrate next.
    if legacy_callers_60:
        print()
        print(f"  Legacy callers (last 60d):")
        for (method, from_), count in legacy_callers_60.most_common(15):
            print(f"    {count:>8d}  {method:<20s}  {from_}")

    # T-1408: parallel breakdown by peer_pid — closes the anonymous-caller
    # blind spot for entries written after T-1407. `ps -p <pid>` finishes
    # the identification.
    if legacy_pids_60:
        print()
        print(f"  Legacy callers by PID (last 60d):")
        for (method, pid), count in legacy_pids_60.most_common(15):
            print(f"    {count:>8d}  {method:<20s}  pid={pid}")

    # T-1409: parallel breakdown by peer_addr (TCP source) — closes the
    # anonymous-caller blind spot for network connections that have no
    # local PID. `getent hosts <ip>` or arp -n finishes the identification.
    if legacy_ips_60:
        print()
        print(f"  Legacy callers by IP (last 60d):")
        for (method, addr), count in legacy_ips_60.most_common(15):
            print(f"    {count:>8d}  {method:<20s}  {addr}")

    print()
    print(f"  Gate threshold: {gate_pct_s:.2f}% (over 60-day window — T-1166)")
    if final_total == 0:
        print(f"  60d window is empty — gate inconclusive.")
        sys.exit(0)
    # T-1414: clarify the attribution split so operators can see "remaining
    # holdouts" without the rolling window blurring it via pre-T-1409 backlog.
    if final_legacy > 0:
        attr = final_legacy - final_unattr
        print(f"  60d legacy split: {attr} attributable, {final_unattr} unattributable (pre-T-1409, ages out)")
    if not final_pass:
        print()
        print(f"  60d legacy traffic ({final_pct:.2f}%) exceeds threshold.")
        print(f"  Hunt remaining callers — see live caller breakdown above.")
        sys.exit(1)
    sys.exit(0)

# Single-window mode: original CI-gate behavior.
last_n = int(last_n_s)
counts, total, legacy_total, legacy_callers, legacy_pids, legacy_ips, legacy_unattr = stats_for_window(last_n)
print(f"  Window:     last {last_n} days")
print(f"  Total RPCs: {total}")
print()

if total == 0:
    print("  No RPC traffic in window.")
    sys.exit(0)

print(f"  Top 10 methods:")
for method, count in counts.most_common(10):
    pct = (count / total) * 100
    print(f"    {count:>8d}  {pct:5.1f}%  {method}")
print()

# T-1309: legacy caller breakdown (always shown when any legacy traffic
# exists in window, not just on FAIL — operators want this for tracking
# steady downward progress, not only when the gate trips).
if legacy_callers:
    print(f"  Legacy callers (last {last_n}d):")
    for (method, from_), count in legacy_callers.most_common(15):
        print(f"    {count:>8d}  {method:<20s}  {from_}")
    print()

# T-1408: parallel by-PID breakdown for entries with peer_pid.
if legacy_pids:
    print(f"  Legacy callers by PID (last {last_n}d):")
    for (method, pid), count in legacy_pids.most_common(15):
        print(f"    {count:>8d}  {method:<20s}  pid={pid}")
    print()

# T-1409: parallel by-addr breakdown for entries with peer_addr (TCP).
if legacy_ips:
    print(f"  Legacy callers by IP (last {last_n}d):")
    for (method, addr), count in legacy_ips.most_common(15):
        print(f"    {count:>8d}  {method:<20s}  {addr}")
    print()

legacy_pct = (legacy_total / total) * 100 if total > 0 else 0.0
gate_pass = legacy_pct <= gate_pct_s

status = "PASS" if gate_pass else "FAIL"
print(f"  Legacy primitives: {legacy_total} ({legacy_pct:.2f}% of total)")
# T-1414: surface attribution split — pre-T-1409 backlog ages out, attributable
# is the actionable number.
if legacy_total > 0:
    attr = legacy_total - legacy_unattr
    print(f"    of which: {attr} attributable, {legacy_unattr} unattributable (pre-T-1409)")
print(f"  Gate threshold:    {gate_pct_s:.2f}%  →  {status}")

if not gate_pass:
    print()
    print(f"  Legacy traffic exceeds T-1166 entry threshold.")
    print(f"  Hunt down the remaining callers — see breakdown above.")
    sys.exit(1)

sys.exit(0)
PY
