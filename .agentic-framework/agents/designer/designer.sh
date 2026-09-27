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
#   fw designer install                Install the pinned build from the VENDORED copy that ships
#                                      inside .agentic-framework/ — the ONBOARDING path (T-3064).
#                                      Purely local: no network, same sha256-vs-pin verification
#                                      and same reject-on-mismatch as `sync --from`.
#   fw designer url                    Print the served Watchtower URL for the designer
#   fw designer check-currency         Standalone CURRENCY probe (T-3158): is a newer
#                                      `designer-v*` tag published at the pin's own
#                                      `source_origin` than `version:`? Advisory only —
#                                      always exits 0; prints a WARN/OK/SKIP line. This
#                                      is the same check `fw doctor` runs inline; reach
#                                      for this verb to run it in isolation (CI, cron,
#                                      manual probe) without a full doctor pass.
#
# Boundary (T-559): both intake paths handle only frozen published bytes. --from takes a
# DELIVERED artifact (file_send fallback); --from-tag fetches a frozen annotated tag from
# the read-only origin — 832's working tree is never read. The artifact is untrusted until
# its sha256 matches the pin — that check is the whole point of the command.
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# T-2649 (OBS-097): pin is FRAMEWORK-owned (vendored for consumers) —
# FRAMEWORK_ROOT-first, PROJECT_ROOT fallback for direct invocation.
# FW_DESIGNER_PIN_FILE (T-2547 hermetic-test hook, T-3119/T-3158): points every verb in
# this script at a temp pin copy so bats never mutates the live tracked pin file.
PIN_FILE="${FW_DESIGNER_PIN_FILE:-${FRAMEWORK_ROOT:-$PROJECT_ROOT}/policy/designer-pin.yaml}"

_c_red=$'\033[0;31m'; _c_grn=$'\033[0;32m'; _c_yel=$'\033[0;33m'; _c_cyn=$'\033[0;36m'; _c_bold=$'\033[1m'; _c_off=$'\033[0m'

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
    # T-3064: clear an existing target first. It was installed 0444, and neither
    # `install` nor `cp` can write over a read-only file, so re-installing the
    # same version (repairing a corrupted local copy) failed on the fallback too.
    # AFTER verification, never before: the caller has already matched these bytes
    # against the pin, so this only ever removes a file about to be replaced by a
    # verified one.
    rm -f "$vpath" 2>/dev/null || true
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

# T-3064 (A2/A4/A5): install the pinned build from the VENDORED copy — the path
# onboarding takes. `fw init` calls this against a freshly vendored consumer, so
# it is what decides whether a newly-onboarded project has a designer or a pin
# naming a file that was never delivered.
#
# Reads FRAMEWORK_ROOT (the vendored .agentic-framework/ in a consumer), writes
# PROJECT_ROOT — the two are the SAME directory only in the framework repo, where
# the already-installed branch below returns first.
#
# A3 — verification is not re-implemented here. Once the source file is located,
# this delegates to `do_sync --from`, so the sha256-vs-pin comparison and the
# refusal on mismatch are literally the same lines the delivered-artifact path
# has always run. A new call path cannot weaken a check it does not own.
#
# A4 — no network, ever. The bytes are already on disk because `fw vendor` put
# them there; `--from-tag` (which does reach 832's internal OneDev) stays the
# framework-repo intake verb and is NOT reachable from onboarding. So there is no
# remote to hang on, and the absent-source case below exits NON-ZERO with a named
# cause rather than returning success over a project with no designer.
#
# Exit codes: 0 installed or already present · 1 sha256 mismatch (refused)
#             3 pin incomplete · 5 no vendored build to install from
do_install() {
    local rel vpath src expected
    rel="$(_pin_get vendored_path)" || rel=""
    [ -n "$rel" ] || { echo "${_c_red}pin has no vendored_path — cannot install${_c_off}" >&2; return 3; }
    expected="$(_pin_get sha256)" || expected=""
    [ -n "$expected" ] || { echo "${_c_red}pin has no sha256 — refusing to install an unverifiable build${_c_off}" >&2; return 3; }
    vpath="$PROJECT_ROOT/$rel"

    if [ -f "$vpath" ] && [ "$(_sha256 "$vpath")" = "$expected" ]; then
        echo "${_c_grn}✓ designer already installed${_c_off} $(_pin_get version) → ${rel} (sha256 matches pin)"
        return 0
    fi

    src="${FRAMEWORK_ROOT:-$PROJECT_ROOT}/$rel"
    if [ ! -f "$src" ]; then
        # LOUD and specific. The failure this whole task exists to close was a
        # quiet one — a check that read as inapplicable — so the absent-source
        # case names the file, the reason, and the verb that fixes it.
        echo "${_c_yel}designer NOT installed${_c_off} — the pin names ${rel}, but no vendored build is present at:" >&2
        echo "  ${src}" >&2
        echo "  → this framework copy was vendored before the designer shipped with it." >&2
        echo "  → refresh it (fw upgrade), or in the framework repo: fw designer sync --from-tag" >&2
        return 5
    fi

    # Same verification path as the delivered-artifact flow (A3).
    do_sync --from "$src"
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

# Compare two dotted version strings as INTEGER TUPLES — never as strings (T-3158
# AC-1/AC-4, PL-021: lexical sort ranks "0.9.0" above "0.10.0"/"0.11.0", which is
# exactly backwards). Returns 0 (true) if $1 > $2, 1 otherwise (including equal).
# Missing trailing components pad as 0 ("1.2" vs "1.2.0" compares equal).
_version_gt() {
    local -a a b
    IFS='.' read -r -a a <<< "$1"
    IFS='.' read -r -a b <<< "$2"
    local n=${#a[@]} i ai bi
    [ ${#b[@]} -gt "$n" ] && n=${#b[@]}
    for ((i = 0; i < n; i++)); do
        ai="${a[i]:-0}"; ai="${ai//[^0-9]/}"; ai="${ai:-0}"
        bi="${b[i]:-0}"; bi="${bi//[^0-9]/}"; bi="${bi:-0}"
        if ((10#$ai > 10#$bi)); then return 0; fi
        if ((10#$ai < 10#$bi)); then return 1; fi
    done
    return 1
}

# fw designer check-currency (T-3158) — standalone CURRENCY probe.
#
# Sibling of, but distinct from, `do_status`'s EXPOSURE check (does the vendored
# build's sha256 match the pin). This asks CURRENCY: is `version:` still the newest
# `designer-v*` tag the pin's own `source_origin:` publishes? Both green is required —
# designer-v0.9.0 through v0.11.0 sat unconsumed for three releases with EXPOSURE
# green throughout, because nothing asked this question (T-3119 origin).
#
# Advisory only: ALWAYS exits 0, regardless of WARN/OK/SKIP. An advisory that can
# fail a caller's gate gets disabled the first time it is inconvenient, and then it
# protects nothing (001-CashWeb's rationale for their `scripts/check-designer-
# currency.py`, adopted verbatim here — no such file was found on this rail at
# authoring time, so this is an independent implementation of the same contract,
# not a port; attribution stays owed if 001-CashWeb's file is ever handed over).
#
# `fw doctor` calls this verb (rather than duplicating the probe inline) so there is
# exactly one implementation; this verb is also directly reachable for CI/cron/manual
# use without a full doctor pass. Network call is bounded (`timeout 10`) and refuses
# to prompt for credentials, so an unreachable/slow origin cannot hang the caller.
do_check_currency() {
    local ver origin ls latest="" newest v line
    ver="$(_pin_get version)" || ver=""
    origin="$(_pin_get source_origin)" || origin=""
    if [ -z "$ver" ] || [ -z "$origin" ]; then
        echo -e "${_c_cyn}SKIP${_c_off}  designer pin currency not checkable (pin has no version/source_origin)"
        return 0
    fi
    if ls=$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5" timeout 10 git ls-remote --tags "$origin" 'designer-v*' 2>/dev/null); then
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            v="${line#designer-v}"
            if [ -z "$latest" ] || _version_gt "$v" "$latest"; then
                latest="$v"
            fi
        done <<< "$(printf '%s\n' "$ls" | sed -e 's|.*refs/tags/||' -e 's|\^{}$||' | grep '^designer-v' || true)"
        if [ -z "$latest" ]; then
            echo -e "${_c_cyn}SKIP${_c_off}  designer pin currency unknown — origin publishes no designer-v* tags"
            echo -e "         origin: $origin"
        elif [ "$latest" != "$ver" ] && _version_gt "$latest" "$ver"; then
            echo -e "${_c_yel}WARN${_c_off}  designer pin is behind its origin — pinned $ver, newest released $latest"
            echo -e "         tag designer-v$latest at $origin"
            echo -e "         Run: fw designer sync --from-tag   (re-pin + sha256-verify at the tag)"
        else
            echo -e "${_c_grn}OK${_c_off}  designer pin current with origin (newest released $latest)"
        fi
    else
        echo -e "${_c_cyn}SKIP${_c_off}  designer pin currency UNKNOWN — could not reach origin $origin"
        echo -e "         This is not 'current': the origin's newest release was never read."
        echo -e "         Set FW_SKIP_DESIGNER_CURRENCY=1 to skip this probe on offline runs."
    fi
    return 0
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
    install) do_install "$@" ;;
    url)     do_url "$@" ;;
    draft)   do_draft "$@" ;;
    check-currency) do_check_currency "$@" ;;
    -h|--help|help)
        sed -n '2,36p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        ;;
    *) echo "unknown verb: $cmd (try: status|path|sync|install|url|draft)" >&2; exit 2 ;;
esac
