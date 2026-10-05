#!/usr/bin/env bash
# lib/sidecar-audit.sh — arc-011 sidecar slice 8 (T-3420).
#
# One fact function for the audit rail. It reads the sidecar's OWN durable
# state through `fw sidecar status --json` (lib/sidecar_cli.py) and never the
# hub — the same out-of-band guarantee slice 6 (T-3417) established, carried
# into the cron'd audit unchanged. There is deliberately no `termlink`
# invocation anywhere in this file: a hub that answers "delivered" cannot
# move these numbers because nothing here asks it.
#
#   fw_sidecar_ledger_facts <project_root>
#
#     stdout : one tab-separated line
#              UNKNOWN<TAB>EXPIRED_UNSWEPT<TAB>STORED<TAB>DELIVERED<TAB>TOTAL<TAB>DEAD_LETTERS
#
#              DEAD_LETTERS (T-3434) is a SUBSET of UNKNOWN: the rows the
#              universal retry ladder gave up on, `ladder-exhausted` after 16
#              attempts or `ladder-unretryable` when the durable message file
#              went missing. It is appended last so a caller reading five
#              fields keeps working.
#     rc 0   : facts printed
#     rc 1   : the sidecar has never been used under <project_root>
#              (no .context/sidecar/outbox/) — the caller stays silent
#     rc 2   : the outbox exists but the ledger could not be read — the
#              caller should say so rather than report zeros
#
# The rc-1/rc-2 split matters: `status` mkdirs the outbox on first call, so
# the existence test MUST run before it, or a consumer project that has never
# sent a consult would acquire an empty outbox and a PASS line it never earned.

fw_sidecar_ledger_facts() {
    local root="${1:?fw_sidecar_ledger_facts: project root required}"
    [ -d "$root/.context/sidecar/outbox" ] || return 1

    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [ -f "$lib_dir/sidecar_cli.py" ] || return 2

    local snap
    # T-3717: PROJECT_ROOT, not FRAMEWORK_ROOT. Since T-3671 the sidecar reads its
    # state from the consumer PROJECT_ROOT (else the cwd's project); setting only
    # FRAMEWORK_ROOT made <root> inert and the facts described whatever project
    # the caller happened to be standing in.
    snap=$(PROJECT_ROOT="$root" python3 "$lib_dir/sidecar_cli.py" status --json 2>/dev/null) || return 2
    [ -n "$snap" ] || return 2

    printf '%s' "$snap" | python3 -c '
import json, sys
try:
    s = json.load(sys.stdin)
    l = s["ledger"]
    # T-3717: T-3561 renamed INJECTED_NOW to HUB_ACCEPTED; legacy rows are
    # folded into HUB_ACCEPTED by outbox._read_ledger. The INJECTED_NOW key is
    # still summed so an older status producer keeps counting.
    delivered = (int(l.get("HUB_ACCEPTED", 0)) + int(l.get("INJECTED_NOW", 0))
                 + int(l.get("INJECTED_LATER", 0)))
    print("\t".join(str(x) for x in (
        int(l.get("UNKNOWN", 0)), int(s.get("expired_unswept", 0)),
        int(l.get("STORED", 0)), delivered, int(s.get("messages_total", 0)),
        int(s.get("dead_letters", 0)))))
except Exception:
    sys.exit(2)
' || return 2
    return 0
}

# fw_sidecar_dm_stale_facts <project_root> [threshold_hours]
#
#   T-3442: DM rails (dm:<a>:<b>) are TermLink's own two-identity topics, not
#   ours to create or receive into automatically — nothing drains them, so a
#   rail addressed to our identity can sit unread indefinitely (origin:
#   832's clause-2 answer sat 3+ weeks unread while five drives reported the
#   artefacts it named as absent). This is deliberately NOT the same
#   out-of-band guarantee `fw_sidecar_ledger_facts` above relies on — a
#   DM rail's unread count has no durable local answer, only the hub knows,
#   so this function calls the hub (via `fw sidecar dm-stale`) rather than
#   reading files. It degrades the same way: rc 1 when there is nothing to
#   check, rc 2 when the check could not run at all, never printing zeros
#   for a check that did not happen.
#
#     stdout : one line per stale rail, TAB-separated: TOPIC<TAB>UNREAD<TAB>AGE_HOURS
#     rc 0   : facts printed (possibly empty — no rail is stale)
#     rc 1   : termlink is not installed, or no identity fingerprint could
#              be derived — the caller stays silent, same as an unused sidecar
#     rc 2   : sidecar_cli.py is missing, or the dm-stale call itself failed
#              to produce parseable JSON — the caller should say so
fw_sidecar_dm_stale_facts() {
    local root="${1:?fw_sidecar_dm_stale_facts: project root required}"
    local threshold_hours="${2:-24}"
    command -v termlink >/dev/null 2>&1 || return 1

    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [ -f "$lib_dir/sidecar_cli.py" ] || return 2

    local rows
    # T-3719: PROJECT_ROOT, not FRAMEWORK_ROOT — since T-3671 the sidecar
    # resolves its state root from PROJECT_ROOT (else cwd), so FRAMEWORK_ROOT
    # alone left <root> inert and the check read the caller's ambient project.
    rows=$(PROJECT_ROOT="$root" timeout 30 python3 "$lib_dir/sidecar_cli.py" \
           dm-stale --threshold-hours "$threshold_hours" --json 2>/dev/null) || return 2
    [ -n "$rows" ] || return 2

    printf '%s' "$rows" | python3 -c '
import json, sys
try:
    rows = json.load(sys.stdin)
    for r in rows:
        print("\t".join(str(r[k]) for k in ("topic", "unread", "age_hours")))
except Exception:
    sys.exit(2)
' || return 2
    return 0
}

# fw_sidecar_inbox_stale_facts <project_root> [threshold_hours]
#
#   T-3544 / OBS-567: the INBOUND consult backlog. Third sibling to the two
#   functions above, and the one whose absence had a measured cost — 832 waited
#   six days on a consult that had arrived, durably, because every surface
#   watching the sidecar watched the outbound ledger or the dm:* rails and
#   nothing counted what was unread on the rail peers are told to use. The
#   outbound PASS line ("49 consult(s), 49 delivered, 0 in flight") reads like a
#   verdict on the sidecar as a whole, which is exactly why the gap survived.
#
#   Hub-calling, like dm-stale and unlike the ledger: how many records sit past
#   our cursor has no durable local answer. Same degradation shape — rc 1 when
#   there is nothing to check, rc 2 when the check could not run, never zeros
#   for a check that did not happen.
#
#   AGE_HOURS may be the literal string `unknown`: an unread consult whose
#   envelope carries no usable timestamp is still owed work and is reported
#   rather than dropped. Callers must not arithmetic on it blindly.
#
#     stdout : one line per stale topic, TAB-separated:
#              TOPIC<TAB>UNREAD<TAB>AGE_HOURS<TAB>OLDEST_FROM
#     rc 0   : facts printed (possibly empty — nothing is stale)
#     rc 1   : the sidecar has never been used under <project_root>, or
#              termlink is not installed — the caller stays silent
#     rc 2   : sidecar_cli.py is missing, or the inbox-stale call itself failed
#              to produce parseable JSON — the caller should say so
fw_sidecar_inbox_stale_facts() {
    local root="${1:?fw_sidecar_inbox_stale_facts: project root required}"
    local threshold_hours="${2:-24}"
    command -v termlink >/dev/null 2>&1 || return 1
    [ -d "$root/.context/sidecar" ] || return 1

    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [ -f "$lib_dir/sidecar_cli.py" ] || return 2

    local rows
    # T-3719: PROJECT_ROOT, not FRAMEWORK_ROOT (see fw_sidecar_dm_stale_facts).
    rows=$(PROJECT_ROOT="$root" timeout 60 python3 "$lib_dir/sidecar_cli.py" \
           inbox-stale --threshold-hours "$threshold_hours" --json 2>/dev/null) || return 2
    [ -n "$rows" ] || return 2

    printf '%s' "$rows" | python3 -c '
import json, sys
try:
    rows = json.load(sys.stdin)
    for r in rows:
        age = r.get("age_hours")
        print("\t".join((
            str(r["topic"]), str(r["unread"]),
            "unknown" if age is None else str(age),
            str(r.get("oldest_from") or "unknown"))))
except Exception:
    sys.exit(2)
' || return 2
    return 0
}

# T-3685 (arc-011 S-LIVE, R7/R14/R15). The watcher's liveness verdict, read by
# fw doctor and fw audit. Reads .context/sidecar/liveness.yaml through
# `fw sidecar liveness --json` — our own file, no hub call.
#
#   fw_sidecar_watcher_facts <project_root>
#     stdout : STATE<TAB>SEQ<TAB>AGE_S<TAB>PROBE_LATENCY_MS<TAB>TERMLINK<TAB>REASONS ("; "-joined)<TAB>WAKE
#              WAKE (T-3855) is `none` when this agent has a sidecar inbox and nothing
#              would wake it on arrival (watcher not live), else `ok` / `no-inbox`.
#              Appended last so a caller reading six fields keeps working.
#              STATE is live | not-live | absent (see lib/sidecar/watcher.py:liveness_verdict)
#     rc 0   : facts printed
#     rc 2   : the verdict could not be read — the caller says so
fw_sidecar_watcher_facts() {
    local root="${1:?fw_sidecar_watcher_facts: project root required}"
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [ -f "$lib_dir/sidecar_cli.py" ] || return 2
    local out
    out=$(PROJECT_ROOT="$root" timeout 60 python3 "$lib_dir/sidecar_cli.py" liveness --json 2>/dev/null)
    [ -n "$out" ] || return 2
    printf '%s' "$out" | python3 -c '
import json, sys
try:
    v = json.load(sys.stdin)
    live = v.get("liveness") or {}
    w = v.get("wake") or {}
    wake = "none" if w.get("nothing_wakes") else ("ok" if w.get("has_inbox") else "no-inbox")
    print("\t".join((v["state"], str(live.get("seq")), str(v.get("age_s")),
                     str(live.get("last_probe_latency_ms")), str(v.get("injection_transport")),
                     "; ".join(v.get("reasons") or []) or "-", wake)))
except Exception:
    sys.exit(2)
' || return 2
    return 0
}
