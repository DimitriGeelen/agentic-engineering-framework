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
#   fw designer sync --from-tag [tag] [--dry-run]
#                                      Pull-at-tag intake (T-247/D-335, T-2616): fetch artifact +
#                                      MANIFEST.yaml AT the annotated tag from the pin's read-only
#                                      `source_origin`, verify the independent sha256 against BOTH the
#                                      MANIFEST at the same tag AND the pin, install read-only.
#                                      Tag defaults to the pin's `source_tag`. --dry-run verifies the
#                                      tag's self-consistency and reports pin-match without installing
#                                      (works against any historical tag).
#   fw designer url                    Print the served Watchtower URL for the designer
#
# Boundary (T-559): both intake paths handle only frozen published bytes. --from takes a
# DELIVERED artifact (file_send fallback); --from-tag fetches a frozen annotated tag from
# the read-only origin — 832's working tree is never read. The artifact is untrusted until
# its sha256 matches the pin — that check is the whole point of the command.
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# T-2649 (OBS-097): pin is FRAMEWORK-owned (vendored for consumers) —
# FRAMEWORK_ROOT-first, PROJECT_ROOT fallback for direct invocation.
PIN_FILE="${FRAMEWORK_ROOT:-$PROJECT_ROOT}/policy/designer-pin.yaml"

_c_red=$'\033[0;31m'; _c_grn=$'\033[0;32m'; _c_yel=$'\033[0;33m'; _c_bold=$'\033[1m'; _c_off=$'\033[0m'

# Read a top-level scalar from a flat YAML file without a yq dependency.
# Capture-then-strip (L-387: never `grep | ...` under pipefail on a live producer).
_yaml_get() {
    local file="$1" key="$2" line
    line="$(grep -E "^${key}:" "$file" 2>/dev/null | head -1 || true)"
    [ -n "$line" ] || return 1
    # strip 'key:', surrounding quotes, inline comment, and whitespace
    line="${line#"${key}":}"
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
    printf '%s' "$line"
}

_pin_get() { _yaml_get "$PIN_FILE" "$1"; }

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

# Install an ALREADY-VERIFIED artifact read-only into the vendored path.
# Callers MUST have checked the sha256 against the pin before calling this.
_install_readonly() {
    local src="$1" vpath
    vpath="$(_vendored_abs)"
    mkdir -p "$(dirname "$vpath")"
    # install read-only (AC5): the vendored copy is never edited in place.
    install -m 0444 "$src" "$vpath" 2>/dev/null || { cp -f "$src" "$vpath" && chmod 0444 "$vpath"; }
    echo "${_c_grn}✓ vendored${_c_off} $(_pin_get version) → ${vpath#"$PROJECT_ROOT"/} (sha256 verified, read-only)"
    echo "  serve: fw serve → $(do_url 2>/dev/null || echo '<watchtower>/designer')"
}

do_sync() {
    local src="" tag_mode=0 tag="" dry_run=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --from) src="${2:-}"; shift 2 ;;
            --from=*) src="${1#--from=}"; shift ;;
            --from-tag)
                tag_mode=1
                if [ $# -ge 2 ] && [ "${2#--}" = "${2:-}" ]; then tag="$2"; shift 2; else shift; fi ;;
            --from-tag=*) tag_mode=1; tag="${1#--from-tag=}"; shift ;;
            --dry-run) dry_run=1; shift ;;
            *) echo "unknown arg: $1" >&2; return 2 ;;
        esac
    done
    if [ "$tag_mode" -eq 1 ]; then
        do_sync_from_tag "$tag" "$dry_run"
        return $?
    fi
    [ -n "$src" ] || { echo "${_c_red}fw designer sync requires --from <delivered-artifact> or --from-tag [<tag>]${_c_off}" >&2; return 2; }
    [ -f "$src" ] || { echo "${_c_red}source not found: $src${_c_off}" >&2; return 2; }

    local expected actual
    expected="$(_pin_get sha256)" || { echo "pin has no sha256" >&2; return 3; }
    actual="$(_sha256 "$src")"
    if [ "$actual" != "$expected" ]; then
        echo "${_c_red}sha256 MISMATCH — refusing to vendor an unpinned build${_c_off}" >&2
        echo "  expected (pin): $expected" >&2
        echo "  actual  (file): $actual" >&2
        echo "  → the delivered artifact does not match the pinned release. Do NOT install." >&2
        return 1
    fi
    _install_readonly "$src"
}

# Pull-at-tag intake (T-247/D-335, T-2616). Fetch artifact + MANIFEST at the
# annotated tag from the pin's read-only origin; verify the independently
# computed sha256 against BOTH the MANIFEST at the same tag AND the pin.
# Exit codes: 0 ok · 1 sha/bytes mismatch · 2 usage · 3 pin incomplete · 4 fetch/extract failure
do_sync_from_tag() {
    local tag="$1" dry_run="$2"
    local origin manifest_rel
    origin="$(_pin_get source_origin)" || { echo "${_c_red}pin has no source_origin — add it to policy/designer-pin.yaml (T-2616)${_c_off}" >&2; return 3; }
    if [ -z "$tag" ]; then
        tag="$(_pin_get source_tag || true)"
        [ -n "$tag" ] || { echo "${_c_red}no tag given and pin has no source_tag${_c_off}" >&2; return 2; }
    fi
    manifest_rel="$(_pin_get source_manifest || true)"
    [ -n "$manifest_rel" ] || manifest_rel="dist/MANIFEST.yaml"

    local tmp
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    echo "${_c_bold}pull-at-tag${_c_off} — fetching ${tag} from ${origin}"
    git init -q "$tmp"
    if ! git -C "$tmp" fetch -q --depth 1 "$origin" "refs/tags/${tag}:refs/tags/${tag}" 2>/dev/null; then
        # some transports refuse shallow fetch — retry full before failing
        if ! git -C "$tmp" fetch -q "$origin" "refs/tags/${tag}:refs/tags/${tag}"; then
            echo "${_c_red}fetch failed — tag '${tag}' unreachable at ${origin}${_c_off}" >&2
            return 4
        fi
    fi
    if ! git -C "$tmp" show "${tag}:${manifest_rel}" > "$tmp/MANIFEST.yaml" 2>/dev/null; then
        echo "${_c_red}no ${manifest_rel} at tag ${tag}${_c_off}" >&2
        return 4
    fi

    local m_artifact m_sha m_bytes
    m_artifact="$(_yaml_get "$tmp/MANIFEST.yaml" artifact || true)"
    m_sha="$(_yaml_get "$tmp/MANIFEST.yaml" sha256 || true)"
    m_bytes="$(_yaml_get "$tmp/MANIFEST.yaml" bytes || true)"
    [ -n "$m_artifact" ] && [ -n "$m_sha" ] || { echo "${_c_red}MANIFEST at ${tag} lacks artifact/sha256 keys${_c_off}" >&2; return 4; }

    if ! git -C "$tmp" show "${tag}:${m_artifact}" > "$tmp/artifact.html" 2>/dev/null; then
        echo "${_c_red}MANIFEST names '${m_artifact}' but it is absent at tag ${tag}${_c_off}" >&2
        return 4
    fi

    local actual bytes
    actual="$(_sha256 "$tmp/artifact.html")"
    bytes="$(stat -c '%s' "$tmp/artifact.html")"

    # Anchor 1: the release must be self-consistent — artifact vs MANIFEST at the SAME tag.
    if [ "$actual" != "$m_sha" ] || { [ -n "$m_bytes" ] && [ "$bytes" != "$m_bytes" ]; }; then
        echo "${_c_red}sha256/bytes MISMATCH vs MANIFEST at ${tag} — release is not self-consistent. Do NOT install; report on the rail.${_c_off}" >&2
        echo "  MANIFEST: sha=${m_sha} bytes=${m_bytes:-?}" >&2
        echo "  computed: sha=${actual} bytes=${bytes}" >&2
        return 1
    fi
    echo "  ${_c_grn}✓${_c_off} MANIFEST anchor: sha+bytes self-consistent at ${tag} (${m_artifact}, ${bytes} B)"

    # Anchor 2: the pin.
    local expected pin_match=0
    expected="$(_pin_get sha256)" || { echo "pin has no sha256" >&2; return 3; }
    [ "$actual" = "$expected" ] && pin_match=1

    if [ "$dry_run" -eq 1 ]; then
        if [ "$pin_match" -eq 1 ]; then
            echo "  ${_c_grn}✓${_c_off} pin anchor: sha matches current pin ($(_pin_get version))"
        else
            echo "  ${_c_yel}i${_c_off} pin anchor: sha does NOT match current pin ($(_pin_get version)) — expected for historical/newer tags"
            echo "    pin:      $expected"
            echo "    computed: $actual"
        fi
        echo "${_c_grn}dry-run OK${_c_off} — nothing installed"
        return 0
    fi

    if [ "$pin_match" -ne 1 ]; then
        echo "${_c_red}sha256 MISMATCH vs pin — refusing to vendor an unpinned build${_c_off}" >&2
        echo "  expected (pin): $expected" >&2
        echo "  actual  (tag):  $actual" >&2
        echo "  → update policy/designer-pin.yaml from the rail announce first, then re-run." >&2
        return 1
    fi
    echo "  ${_c_grn}✓${_c_off} pin anchor: sha matches pin ($(_pin_get version))"
    _install_readonly "$tmp/artifact.html"
}

do_url() {
    local base
    base="$("$PROJECT_ROOT/bin/fw" watchtower url 2>/dev/null || true)"
    [ -n "$base" ] || base="http://localhost:3000"
    printf '%s/designer\n' "$base"
}

# T-2623: draft mode — cheap iteration tier. Convention: map id prefix `draft-`
# marks a draft (excluded from lint baseline + fw search retrieval; DRAFT badge
# in the gallery; never authority). `fw designer draft new <name>` seeds a
# minimal skeleton via /api/save and prints the editor deep-link (the pair-draft
# ritual entry point: agent seeds, operator edits in UI, agent normalizes).
do_draft_new() {
    local name="${1:-}"
    if [ -z "$name" ]; then
        echo "usage: fw designer draft new <name>" >&2; return 2
    fi
    name="draft-$(printf '%s' "${name#draft-}" | tr 'A-Z _' 'a-z--')"
    local store="$PROJECT_ROOT/.context/designer/projects/$name"
    local base
    base="$("$PROJECT_ROOT/bin/fw" watchtower url 2>/dev/null || true)"
    [ -n "$base" ] || base="http://localhost:3000"
    local link="$base/designer/app?load=%2Fapi%2Fversion%3Fid%3D$name%26v%3D1"
    if [ -d "$store" ]; then
        echo "refused: draft '$name' already exists — open it instead:" >&2
        echo "  $link" >&2
        return 1
    fi
    if ! curl -sf "$base/api/list" >/dev/null 2>&1; then
        echo "Watchtower not reachable at $base — start it first: fw serve" >&2
        return 1
    fi
    local tmp_spec
    tmp_spec="$(mktemp)"
    cat > "$tmp_spec" <<SPEC
spec_version: 1
id: $name
title: $name (DRAFT)
schema_version: 2
doc: |
  DRAFT — pair-draft session seed (fw designer draft new). Agent seeds,
  operator edits in the UI, agent re-reads + normalizes. Promotion to a
  production id pays the full ceremony (T-2623).
lanes:
- id: agent
  name: "Agent · Initiative"
  abbr: agt
  authority: initiative
  height: 220
- id: human
  name: "Human · Sovereignty"
  abbr: hum
  authority: sovereignty
  height: 200
nodes:
- id: d_start
  lane: agent
  type: start
  name: session opens
  uid: d_start
  pos: [160, 100]
- id: d_sketch
  lane: agent
  type: service
  name: "sketch the flow here — every node/flow is a proposal"
  uid: d_sketch
  pos: [320, 100]
- id: d_end
  lane: agent
  type: end
  name: settled — ready for promotion ceremony
  uid: d_end
  pos: [560, 100]
flows:
- id: d_f1
  from: d_start
  to: d_sketch
  uid: d_f1
- id: d_f2
  from: d_sketch
  to: d_end
  uid: d_f2
SPEC
    if ! python3 "$PROJECT_ROOT/tools/corpus_spec.py" generate "$tmp_spec" \
            --save --url "$base" --save-id "$name" \
            --note "draft seeded by fw designer draft new (T-2623)" >/dev/null; then
        rm -f "$tmp_spec"
        echo "seed save failed (see /api/save response above)" >&2
        return 1
    fi
    rm -f "$tmp_spec"
    echo "${_c_grn}draft created:${_c_off} $name"
    echo "  edit: $link"
    if ! type fw_notify >/dev/null 2>&1 && [ -f "${FRAMEWORK_ROOT:-$PROJECT_ROOT}/lib/notify.sh" ]; then
        # shellcheck disable=SC1091
        . "${FRAMEWORK_ROOT:-$PROJECT_ROOT}/lib/notify.sh" 2>/dev/null || true
    fi
    if type fw_notify >/dev/null 2>&1; then
        fw_notify "Draft session: $name" "Editor ready — open to start the pair-draft" \
            "designer-draft" "info" "$link" 2>/dev/null || true
    fi
}

do_draft() {
    local sub="${1:-}"; shift || true
    case "$sub" in
        new) do_draft_new "$@" ;;
        *) echo "usage: fw designer draft new <name>" >&2; return 2 ;;
    esac
}

cmd="${1:-status}"; shift || true
case "$cmd" in
    status)  do_status "$@" ;;
    path)    do_path "$@" ;;
    sync)    do_sync "$@" ;;
    url)     do_url "$@" ;;
    draft)   do_draft "$@" ;;
    -h|--help|help)
        sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        ;;
    *) echo "unknown verb: $cmd (try: status|path|sync|url|draft)" >&2; exit 2 ;;
esac
