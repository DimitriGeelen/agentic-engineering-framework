#!/bin/bash
# lib/scratch-size.sh - size verdict for .context/scratch (T-4703)
#
# .context/scratch is git-ignored, so neither git status nor audit sees it. Release
# work dirs (full repo clones, 1-10 GB each) piled up there to 28 GB before anyone
# measured it. fw doctor calls this with SCRATCH_WARN_GB; release_scratch_prune
# (lib/release.sh) removes shipped release lanes, this catches everything else.

# fw_scratch_size_verdict <dir> <warn_kb> [timeout_s]
#   Prints one tab-separated line and exits:
#     0  OK<TAB><kb>                          — under the threshold, or no dir
#     1  WARN<TAB><kb><TAB><top subdirs>      — over; top 3 as "name SIZE, ..."
#     2  ERROR<TAB><reason>                   — du failed or timed out
#   The threshold is in KB so tests can use a tiny fixture; the doctor converts GB.
fw_scratch_size_verdict() {
    local dir="$1" warn_kb="$2" tmo="${3:-30}"
    if [ ! -d "$dir" ]; then
        printf 'OK\t0\n'
        return 0
    fi
    case "$warn_kb" in ''|*[!0-9]*) printf 'ERROR\tthreshold not a whole number of KB: %s\n' "$warn_kb"; return 2 ;; esac
    local kb
    kb=$(timeout "$tmo" du -sk -- "$dir" 2>/dev/null | awk '{print $1}')
    case "$kb" in ''|*[!0-9]*) printf 'ERROR\tdu -sk %s failed or exceeded %ss\n' "$dir" "$tmo"; return 2 ;; esac
    if [ "$kb" -le "$warn_kb" ]; then
        printf 'OK\t%s\n' "$kb"
        return 0
    fi
    local top
    top=$(timeout "$tmo" du -sk -- "$dir"/*/ 2>/dev/null | sort -rn | head -3 \
        | awk '{n=$2; sub(/\/$/,"",n); sub(/.*\//,"",n);
                s=$1; u="K"; if (s>=1048576) {s=s/1048576; u="G"} else if (s>=1024) {s=s/1024; u="M"}
                printf "%s%s %.1f%s", (NR>1?", ":""), n, s, u}')
    printf 'WARN\t%s\t%s\n' "$kb" "$top"
    return 1
}
