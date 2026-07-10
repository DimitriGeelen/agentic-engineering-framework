#!/usr/bin/env bash
# fw designer — vendor + serve a pinned Workflow Designer build (T-2521, T-173 beachhead).
#
# 832-Workflow-designer is SoT. AEF vendors a RELEASED single-file build (never source,
# never edited in place) and serves it via the Watchtower `/designer` blueprint.
#
# Verbs:
#   fw designer status                 Show the pin + whether the vendored build is present/valid
#   fw designer path                   Print the absolute path of the vendored build (for the blueprint)
#   fw designer sync --from <file>     Verify a DELIVERED artifact's sha256 against the pin and install
#                                      it read-only into the vendored path. Rejects (exit 1) on mismatch.
#   fw designer url                    Print the served Watchtower URL for the designer
#
# Why --from (not a pull): the T-559 project-boundary rail forbids this session from
# reading /opt/832 paths. 832 (the SoT) DELIVERS its released build into AEF; `sync`
# then verifies + installs it. The delivered file is untrusted until its sha256 matches
# the pin — that check is the whole point of the command.
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PIN_FILE="$PROJECT_ROOT/policy/designer-pin.yaml"

_c_red=$'\033[0;31m'; _c_grn=$'\033[0;32m'; _c_yel=$'\033[0;33m'; _c_bold=$'\033[1m'; _c_off=$'\033[0m'

# Read a top-level scalar from the pin YAML without a yq dependency.
# Capture-then-strip (L-387: never `grep | ...` under pipefail on a live producer).
_pin_get() {
    local key="$1" line
    line="$(grep -E "^${key}:" "$PIN_FILE" 2>/dev/null | head -1 || true)"
    [ -n "$line" ] || return 1
    # strip 'key:', surrounding quotes, inline comment, and whitespace
    line="${line#"${key}":}"
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
    printf '%s' "$line"
}

_vendored_abs() {
    local rel; rel="$(_pin_get vendored_path)" || return 1
    printf '%s/%s' "$PROJECT_ROOT" "$rel"
}

_sha256() { sha256sum "$1" | cut -d' ' -f1; }

do_status() {
    local ver sha bytes vpath present actual
    ver="$(_pin_get version)"; sha="$(_pin_get sha256)"; bytes="$(_pin_get bytes)"
    vpath="$(_vendored_abs)"
    echo "${_c_bold}fw designer${_c_off} — pinned Workflow Designer (SoT: 832-Workflow-designer)"
    echo "  version:      $ver"
    echo "  sha256:       $sha"
    echo "  bytes:        $bytes"
    echo "  vendored at:  ${vpath#"$PROJECT_ROOT"/}"
    if [ -f "$vpath" ]; then
        actual="$(_sha256 "$vpath")"
        if [ "$actual" = "$sha" ]; then
            echo "  status:       ${_c_grn}PRESENT ✓ (sha256 matches pin)${_c_off}"
        else
            echo "  status:       ${_c_red}PRESENT but sha256 MISMATCH${_c_off}"
            echo "                on-disk: $actual"
            return 1
        fi
    else
        echo "  status:       ${_c_yel}NOT SYNCED — 832 must deliver the build, then: fw designer sync --from <file>${_c_off}"
    fi
    return 0
}

do_path() {
    local vpath; vpath="$(_vendored_abs)"
    [ -f "$vpath" ] || { echo "designer build not synced (run: fw designer status)" >&2; return 1; }
    printf '%s\n' "$vpath"
}

do_sync() {
    local src=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --from) src="${2:-}"; shift 2 ;;
            --from=*) src="${1#--from=}"; shift ;;
            *) echo "unknown arg: $1" >&2; return 2 ;;
        esac
    done
    [ -n "$src" ] || { echo "${_c_red}fw designer sync requires --from <delivered-artifact>${_c_off}" >&2; return 2; }
    [ -f "$src" ] || { echo "${_c_red}source not found: $src${_c_off}" >&2; return 2; }

    local expected actual vpath
    expected="$(_pin_get sha256)" || { echo "pin has no sha256" >&2; return 3; }
    actual="$(_sha256 "$src")"
    if [ "$actual" != "$expected" ]; then
        echo "${_c_red}sha256 MISMATCH — refusing to vendor an unpinned build${_c_off}" >&2
        echo "  expected (pin): $expected" >&2
        echo "  actual  (file): $actual" >&2
        echo "  → the delivered artifact does not match the pinned release. Do NOT install." >&2
        return 1
    fi
    vpath="$(_vendored_abs)"
    mkdir -p "$(dirname "$vpath")"
    # install read-only (AC5): the vendored copy is never edited in place.
    install -m 0444 "$src" "$vpath" 2>/dev/null || { cp "$src" "$vpath" && chmod 0444 "$vpath"; }
    echo "${_c_grn}✓ vendored${_c_off} $(_pin_get version) → ${vpath#"$PROJECT_ROOT"/} (sha256 verified, read-only)"
    echo "  serve: fw serve → $(do_url 2>/dev/null || echo '<watchtower>/designer')"
}

do_url() {
    local base
    base="$("$PROJECT_ROOT/bin/fw" watchtower url 2>/dev/null || true)"
    [ -n "$base" ] || base="http://localhost:3000"
    printf '%s/designer\n' "$base"
}

cmd="${1:-status}"; shift || true
case "$cmd" in
    status)  do_status "$@" ;;
    path)    do_path "$@" ;;
    sync)    do_sync "$@" ;;
    url)     do_url "$@" ;;
    -h|--help|help)
        sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        ;;
    *) echo "unknown verb: $cmd (try: status|path|sync|url)" >&2; exit 2 ;;
esac
