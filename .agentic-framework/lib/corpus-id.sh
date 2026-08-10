#!/bin/bash
# lib/corpus-id.sh — serialisation-independent max-id lookup for the YAML memory corpus
#
# Origin: T-2902. `.context/project/{learnings,patterns,decisions}.yaml` are read by
# hand-written grep patterns at many independent sites, each encoding an assumption
# about how the YAML is serialised. On 2026-04-13 a bulk mining run rewrote
# learnings.yaml with yaml.dump(sort_keys=True), moving `id:` off the list-item line:
#
#     - id: L-001              ->    - application: TBD
#       learning: "..."                context: ...
#                                      id: L-001        # moved
#
# Every scan keyed on the old shape began matching zero rows. Four sites broke this
# way and were discovered one at a time over four months (T-1369 learning.sh,
# T-2672 / 832 T-295 resolve.sh x2, T-2906 status.sh — the last still open). Each was
# fixed by widening a regex, which makes the site match today's known serialisations
# and does nothing when a third arrives.
#
# THE HAZARD THIS FILE EXISTS FOR, stated plainly because it is invisible at the call
# site: max-over-nothing and count-over-nothing both return the seed value. A scan
# that matches zero rows in a 608-entry file is indistinguishable from a genuinely
# empty corpus. The allocator does not fail — it confidently returns 1, and mints an
# id that is already live. 24 duplicate ids in learnings.yaml came from exactly this.
# Class sibling: L-570 (`fw_config ... 2>/dev/null` returning "" read identically to
# "not configured").
#
# So: DO NOT "fix" a caller of this by widening its regex. The point is that the
# authoritative path parses the YAML and has no pattern to widen, and the degraded
# path refuses rather than guessing.

[[ -n "${_FW_CORPUS_ID_LOADED:-}" ]] && return 0
_FW_CORPUS_ID_LOADED=1

# corpus_max_id FILE PREFIX
#
# Print the highest numeric suffix among ids of the form <PREFIX>-<digits> in FILE.
# Prints nothing (exit 0) when FILE is absent, or holds no id with that prefix — both
# legitimate "start at 1" states.
#
# Exit 2 (with a message on stderr, printing nothing on stdout) when the corpus is
# NON-EMPTY but no id of that prefix could be read AND the file does contain ids of
# some other prefix. That combination means the reader is looking at a shape it does
# not understand, not at an empty corpus. Callers MUST treat exit 2 as fatal — seeding
# 1 there is the T-2902 bug.
corpus_max_id() {
    local file="$1" prefix="$2"
    [ -f "$file" ] || return 0

    # --- Authoritative path: parse the YAML. No serialisation assumption. ---
    if command -v python3 >/dev/null 2>&1; then
        local out rc
        out=$(python3 - "$file" "$prefix" <<'PY' 2>/dev/null
import sys, yaml, re
path, prefix = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = yaml.safe_load(f)
except Exception:
    sys.exit(3)            # unparseable -> let the caller fall back to grep
if data is None:
    print("EMPTY"); sys.exit(0)
if not isinstance(data, (dict, list)):
    # Parsed, but not a corpus. `:::junk` and most clobbered files load cleanly as a
    # bare string — no exception, no ids, so the naive answer is "empty, start at 1".
    # That is the T-2902 defect with a different cause, so refuse instead. Found by
    # the test leg for this, which was written expecting a parse error and got a str.
    sys.exit(4)

ids = []
def walk(node):
    if isinstance(node, dict):
        v = node.get("id")
        if isinstance(v, str):
            ids.append(v)
        for x in node.values():
            walk(x)
    elif isinstance(node, list):
        for x in node:
            walk(x)
walk(data)

pat = re.compile(r"^" + re.escape(prefix) + r"-0*(\d+)$")
nums = [int(m.group(1)) for m in (pat.match(i) for i in ids) if m]
if nums:
    print(max(nums))
elif ids:
    # Ids exist, none of ours. Legitimate: a consumer project whose corpus holds
    # only L- while we allocate PL-, or vice versa. Not an error.
    print("NONE_OF_PREFIX")
else:
    print("EMPTY")
PY
        )
        rc=$?
        if [ $rc -eq 0 ]; then
            case "$out" in
                EMPTY|NONE_OF_PREFIX) return 0 ;;
                *) printf '%s' "$out"; return 0 ;;
            esac
        fi
        if [ $rc -eq 4 ]; then
            echo "corpus-id: ERROR — $file parsed, but not as a mapping or list." >&2
            echo "  A clobbered corpus loads cleanly as a bare scalar: no exception, no ids," >&2
            echo "  and the naive answer is 'empty, start at 1' — which reissues live ids." >&2
            echo "  Fix: restore $file from git before allocating." >&2
            return 2
        fi
        # rc 3 = YAML raised on parse; fall through to the degraded path.
    fi

    # --- Degraded path: grep, with a cross-check that refuses to guess. ---
    # Reached only when python3 or PyYAML is unavailable, or the file does not parse.
    # PyYAML is already a hard dependency of audit, doctor, consolidate.py and the
    # Watchtower, so this path is close to unreachable in a working install — which is
    # why it is allowed to be conservative to the point of refusing.
    #
    # KNOWN LIMITATION, stated rather than hidden: this scan matches an id TOKEN
    # anywhere in the file, including inside a learning's prose. Our own corpus quotes
    # ids in text ("Removed duplicate L-013 entry"), so a degraded read can return a
    # max higher than any real entry. That errs toward over-allocation, which wastes
    # ids but never reissues a live one — the opposite polarity to the bug this file
    # exists for. It is still L-506 leg 1 (no plausibility bound) and is the reason
    # the authoritative path is a parser rather than a better regex.
    #
    # Loud, per L-570: a degraded read must not be silently indistinguishable from a
    # confident one.
    echo "corpus-id: WARNING — YAML parse unavailable for $file; using pattern scan" >&2

    local mine any
    mine=$(grep -Eo "\b${prefix}-[0-9]+" "$file" 2>/dev/null | sed "s/.*${prefix}-0*//" | sort -n | tail -1)
    if [ -n "$mine" ]; then
        printf '%s' "$mine"
        return 0
    fi

    # No id of our prefix. Distinguish "empty corpus" from "scan did not understand
    # this file" by looking for ANY id of ANY prefix — a much weaker assumption than
    # the per-site patterns this file replaces.
    any=$(grep -Eo "\b[A-Z]+-[0-9]+" "$file" 2>/dev/null | head -1)
    if [ -n "$any" ]; then
        # Ids are present but none match our prefix. Ambiguous between the legitimate
        # cross-prefix case and a genuine scan failure, and we cannot tell which
        # without a parser — so refuse rather than seed 1.
        echo "corpus-id: ERROR — $file holds ids ($any) but none matched '${prefix}-'." >&2
        echo "  Cannot distinguish 'no ${prefix}- ids yet' from 'this file's shape is unreadable'" >&2
        echo "  without a YAML parser. Seeding 1 here is how T-2902 minted 24 duplicate ids." >&2
        echo "  Fix: install PyYAML (python3 -c 'import yaml'), or repair $file." >&2
        return 2
    fi

    # No ids at all, of any prefix — a genuinely empty corpus. Start at 1.
    return 0
}
