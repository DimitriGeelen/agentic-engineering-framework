#!/bin/bash
# lib/tmp-hygiene.sh - owned temp dirs for AEF test runs, a bounded orphan sweep,
# and a fullness verdict for the temp filesystem (T-4846)
#
# bats makes its run dir (bats-run-XXXXXX) under $TMPDIR and removes it from its
# own EXIT handler, which a SIGKILL never reaches. The unit suite gives each file
# a TMPDIR of its own (T-4215); the P-011 Verification gate and `fw test` handed
# bats the caller's TMPDIR, i.e. the shared /tmp, a RAM tmpfs here. A killed run
# left 2.6 GB there on 2026-10-27, and /tmp filled. /tmp is shared with other
# projects on the host, so everything below touches only what it can attribute.

# fw_tmp_own_dir <label> — create "${TMPDIR:-/tmp}/aef-<label>-<pid>-XXXXXX" and
# print it. The pid ($$ of the caller) lets the next run tell an orphan from a
# live run. Labels the sweep knows: bats, verify.
fw_tmp_own_dir() {
    mktemp -d "${TMPDIR:-/tmp}/aef-$1-$$-XXXXXX"
}

# _fw_tmp_in_use <dir> — 0 when any process has its cwd or an open fd inside
# <dir>, or when that cannot be determined (no /proc, scan timed out): unknown is
# treated as in use, so the sweep never removes on a guess.
_fw_tmp_in_use() {
    local dir="$1" hits rc=0
    [ -d /proc/self/fd ] || return 0
    hits=$(timeout 10 find /proc/[0-9]*/cwd /proc/[0-9]*/fd -maxdepth 1 \
        \( -lname "$dir" -o -lname "$dir/*" \) -print -quit 2>/dev/null) || rc=$?
    # find exits 1 on the unreadable entries of exiting processes; only a
    # timeout (124) leaves the answer unknown.
    [ "$rc" -eq 124 ] && return 0
    [ -n "$hits" ]
}

# fw_tmp_sweep [root] [bats_run_age_min] [max] — remove orphans left by killed
# runs and print one removed name per line. Removes ONLY, at the top of <root>:
#   aef-bats-<pid>-* / aef-verify-<pid>-*  whose <pid> is not running
# and only when owned by this uid and no process holds a cwd or fd inside. At
# most <max> (default 20) per call, so a call stays cheap.
# Never a bare bats-run-*: /tmp is shared by every project on the host, and they
# all run bats as the same uid, so a bats-run-* dir cannot be attributed to AEF
# (parent review, T-4846). AEF's own bats runs now make theirs inside an aef-*
# dir above, so nothing AEF leaves needs that name. [bats_run_age_min] is kept
# for call compatibility and unused.
fw_tmp_sweep() {
    local root="${1:-${TMPDIR:-/tmp}}" age="${2:-1440}" max="${3:-20}"
    local n=0 d base pid
    [ -d "$root" ] || return 0
    case "$age" in ''|*[!0-9]*) age=1440 ;; esac
    while IFS= read -r -d '' d; do
        [ "$n" -ge "$max" ] && break
        base="${d##*/}"
        case "$base" in
            aef-bats-*|aef-verify-*)
                pid="${base#aef-*-}"; pid="${pid%%-*}"
                case "$pid" in ''|*[!0-9]*) continue ;; esac
                if kill -0 "$pid" 2>/dev/null || [ -d "/proc/$pid" ]; then continue; fi ;;
            *) continue ;;
        esac
        _fw_tmp_in_use "$d" && continue
        rm -rf -- "$d" 2>/dev/null && { printf '%s\n' "$base"; n=$((n + 1)); }
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -user "$(id -u)" \
                \( -name 'aef-bats-*' -o -name 'aef-verify-*' \) \
                -print0 2>/dev/null)
    return 0
}

# fw_tmp_usage_verdict <dir> <warn_pct> [timeout_s]
#   One tab-separated line, and the exit code:
#     0  OK<TAB><pct><TAB><mount>                       — at or under the threshold
#     1  WARN<TAB><pct><TAB><mount><TAB><top entries>   — over; top 3 of <dir>
#     2  ERROR<TAB><reason>                             — df failed / bad threshold
#   The du for the top entries runs only when over, so the common case costs one df.
fw_tmp_usage_verdict() {
    local dir="${1:-${TMPDIR:-/tmp}}" warn="$2" tmo="${3:-10}" line pct mnt top
    case "$warn" in ''|*[!0-9]*) printf 'ERROR\tthreshold not a whole percent: %s\n' "$warn"; return 2 ;; esac
    line=$(df -Pk -- "$dir" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5 "\t" $6}')
    pct="${line%%$'\t'*}"; mnt="${line#*$'\t'}"
    case "$pct" in ''|*[!0-9]*) printf 'ERROR\tdf -Pk %s failed\n' "$dir"; return 2 ;; esac
    if [ "$pct" -le "$warn" ]; then
        printf 'OK\t%s\t%s\n' "$pct" "$mnt"
        return 0
    fi
    top=$(cd "$dir" 2>/dev/null && find . -mindepth 1 -maxdepth 1 -print0 2>/dev/null \
        | timeout "$tmo" xargs -0 -r du -sxk -- 2>/dev/null | sort -rn | head -3 \
        | awk '{n=$2; sub(/^\.\//,"",n);
                s=$1; u="K"; if (s>=1048576) {s=s/1048576; u="G"} else if (s>=1024) {s=s/1024; u="M"}
                printf "%s%s %.1f%s", (NR>1?", ":""), n, s, u}') || true
    printf 'WARN\t%s\t%s\t%s\n' "$pct" "$mnt" "${top:-(could not size entries)}"
    return 1
}
