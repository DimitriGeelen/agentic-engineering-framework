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
    snap=$(FRAMEWORK_ROOT="$root" python3 "$lib_dir/sidecar_cli.py" status --json 2>/dev/null) || return 2
    [ -n "$snap" ] || return 2

    printf '%s' "$snap" | python3 -c '
import json, sys
try:
    s = json.load(sys.stdin)
    l = s["ledger"]
    delivered = int(l.get("INJECTED_NOW", 0)) + int(l.get("INJECTED_LATER", 0))
    print("\t".join(str(x) for x in (
        int(l.get("UNKNOWN", 0)), int(s.get("expired_unswept", 0)),
        int(l.get("STORED", 0)), delivered, int(s.get("messages_total", 0)),
        int(s.get("dead_letters", 0)))))
except Exception:
    sys.exit(2)
' || return 2
    return 0
}
