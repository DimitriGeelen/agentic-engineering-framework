#!/usr/bin/env bash
# lib/doctor-drift.sh — T-3778
#
# Two `fw doctor` content-drift checks, lifted out of do_doctor so they can be
# called on their own. Doctor sources this file and calls both functions in the
# same place the inline blocks used to sit; the output is unchanged.
#
# Why they live here: the bats files that cover these checks used to run a whole
# `bin/fw doctor` per test (~50 s quiet, 180-600 s under the unit-suite pool) to
# assert on one line, and doctor_designer_pin_drift.bats (5 tests) /
# t2243_doctor_self_vendor_templates.bats (4 tests) kept crossing the 900 s
# per-file cap. Callable functions let each file keep ONE full-doctor wiring
# test and exercise every state directly.
#
# Contract (same as any other doctor block): prints `  OK|WARN|SKIP  …` lines
# using the caller's colour variables and increments the caller's `warnings`
# counter (bash dynamic scope — do_doctor's `local warnings` is visible here).

# doctor_check_designer_pin
#
# Designer pin ↔ vendored build drift (T-2524, T-2521 integration hardening).
# Sibling of the MCP manifest + cron registry→generated drift classes. Content-compares
# (sha256, never mtime — T-2290/T-2432) the vendored Workflow Designer build against
# policy/designer-pin.yaml. Catches a pin bump without re-sync, or an edit to the
# (read-only) vendored HTML. Designer is an AEF-specific feature → PROJECT_ROOT; no
# pin (consumers) means no check at all.
# FW_DESIGNER_PIN_FILE lets tests point the check at a temp pin copy so the live
# tracked policy/designer-pin.yaml is never mutated (T-2547 hermetic-test fix).
# vendored_path still resolves against PROJECT_ROOT, so the real vendor dir is used
# regardless of which pin file is read.
doctor_check_designer_pin() {
    local _dz_pin="${FW_DESIGNER_PIN_FILE:-$PROJECT_ROOT/policy/designer-pin.yaml}"
    [ -f "$_dz_pin" ] || return 0
    local _dz_want _dz_vp _dz_file _dz_have
    _dz_want=$(python3 -c "import yaml;d=yaml.safe_load(open('$_dz_pin'));print(d.get('sha256','') or '')" 2>/dev/null)
    _dz_vp=$(python3 -c "import yaml;d=yaml.safe_load(open('$_dz_pin'));print(d.get('vendored_path','') or '')" 2>/dev/null)
    _dz_file="$PROJECT_ROOT/$_dz_vp"
    if [ -z "$_dz_want" ] || [ -z "$_dz_vp" ]; then
        echo -e "  ${CYAN}SKIP${NC}  designer pin present but missing sha256/vendored_path"
    elif [ ! -f "$_dz_file" ]; then
        # T-3064 A1: WARN, not SKIP. A pin that names a build the project does
        # not have is an actionable condition, not an inapplicable check — the
        # designer IS wanted here, that is what the pin says. SKIP reads as "not
        # applicable to this project", so the state needing attention rendered as
        # unremarkable while mere pin-drift (the *less* serious condition, below)
        # got the louder verdict. Same false-green shape as T-3062.
        echo -e "  ${YELLOW}WARN${NC}  designer pinned but not vendored — /designer will render an error page"
        echo -e "         Run: fw designer sync --from-tag   (or --from <build> for a delivered file)"
        warnings=$((warnings + 1))
    else
        _dz_have=$(sha256sum "$_dz_file" 2>/dev/null | cut -d' ' -f1)
        if [ "$_dz_have" = "$_dz_want" ]; then
            echo -e "  ${GREEN}OK${NC}  designer vendored build matches pin (${_dz_want:0:12}...)"
        else
            echo -e "  ${YELLOW}WARN${NC}  designer vendored build drifted from pin"
            echo -e "         pin=${_dz_want:0:12}... vendored=${_dz_have:0:12}... — run: fw designer sync --from <build>"
            warnings=$((warnings + 1))
        fi
    fi
}

# doctor_check_designer_currency
#
# Designer pin CURRENCY — is a newer release available upstream? (T-3119, T-3158
# extraction; moved here by T-3801 so t3119_designer_currency.bats calls it without
# a whole doctor per test). Sibling of, but distinct from, the drift check above:
# that one measures EXPOSURE (does what we run match what we pinned); this one
# measures CURRENCY (is what we pinned still the newest thing the origin publishes).
# Only both-green means "consistent AND up to date" — designer-v0.9.0 through
# v0.11.0 sat unconsumed for three releases with every instrument reporting OK.
#
# The probe itself (newest `designer-v*` tag at `source_origin:` by INTEGER-TUPLE
# version compare — never lexical — WARN when behind, OK when current, SKIP with its
# own distinct line when the origin cannot be read) lives in ONE place:
# `agents/designer/designer.sh do_check_currency` (`fw designer check-currency`).
# This shells out to it rather than duplicating the comparison.
#
# An unreachable origin gets its OWN state and never reads as "current" (L-575 /
# T-2916). It does not count as a warning. The probe is bounded by `timeout`, with
# GIT_TERMINAL_PROMPT=0 and ssh BatchMode=yes, so it cannot hang doctor. It is a
# network probe: --quick skips it (via do_doctor's _doctor_quick_skip, which must be
# defined by the caller) and FW_SKIP_DESIGNER_CURRENCY=1 skips it in full mode. Both
# skips print a line — never silence, which would read as "current".
# FW_DESIGNER_PIN_FILE points the check at a temp pin copy for tests (T-2547),
# forwarded to the delegate verb so both sides of a hermetic test read the same pin.
doctor_check_designer_currency() {
    local _dc_pin="${FW_DESIGNER_PIN_FILE:-$PROJECT_ROOT/policy/designer-pin.yaml}"
    [ -f "$_dc_pin" ] || return 0
    if [ "${FW_SKIP_DESIGNER_CURRENCY:-0}" = "1" ]; then
        echo -e "  ${CYAN}SKIP${NC}  designer pin currency probe disabled (FW_SKIP_DESIGNER_CURRENCY=1)"
    elif _doctor_quick_skip "designer pin currency (origin ls-remote)"; then
        :
    else
        local _dc_out _dc_line
        _dc_out=$(FW_DESIGNER_PIN_FILE="$_dc_pin" PROJECT_ROOT="$PROJECT_ROOT" "$AGENTS_DIR/designer/designer.sh" check-currency 2>&1) || true
        while IFS= read -r _dc_line; do
            echo -e "  $_dc_line"
        done <<< "$_dc_out"
        if printf '%s\n' "$_dc_out" | sed 's/\x1b\[[0-9;]*m//g' | grep -q '^WARN'; then
            warnings=$((warnings + 1))
        fi
    fi
}

# doctor_check_mcp_manifest
#
# Framework MCP manifest (T-2265, arc-010 Slice 2) — moved here by T-3801 so
# t2290_doctor_mcp_content_check.bats runs it on a fixture instead of a whole
# doctor per test (and no longer mutates the live tool-set.yaml / manifest).
# T-2461: framework ASSETS (manifest, tool-set, manifest.py) live under
# FRAMEWORK_ROOT — which equals PROJECT_ROOT in the framework repo, but is
# the vendored .agentic-framework/ in a consumer. Using PROJECT_ROOT made
# doctor SKIP misleadingly on every consumer (manifest IS present, vendored;
# and "fw mcp emit-manifest" can't run there — no tool-set.yaml). The pid
# file below is RUNTIME state → stays on PROJECT_ROOT.
doctor_check_mcp_manifest() {
    local _fw_root="${FRAMEWORK_ROOT:-$PROJECT_ROOT}"
    local _mcp_mf="$_fw_root/agents/mcp/framework-mcp-manifest.json"
    local _mcp_ts="$_fw_root/policy/capability-overlay/tool-set.yaml"
    if [ -f "$_mcp_mf" ]; then
        local _mcp_tools _mcp_gated _mcp_msg
        _mcp_tools=$(python3 -c "import json; m=json.load(open('$_mcp_mf')); print(len(m.get('tools',[])))" 2>/dev/null || echo "?")
        _mcp_gated=$(python3 -c "import json; m=json.load(open('$_mcp_mf')); print(sum(1 for t in m.get('tools',[]) if t.get('gated')))" 2>/dev/null || echo "?")
        local _mcp_pid_f="$PROJECT_ROOT/.context/working/framework-mcp.pid"
        if [ -f "$_mcp_pid_f" ] && kill -0 "$(cat "$_mcp_pid_f" 2>/dev/null)" 2>/dev/null; then
            _mcp_msg="running (pid $(cat "$_mcp_pid_f"))"
        else
            _mcp_msg="stopped (manifest ready; start: fw mcp start --background)"
        fi
        # T-2290: mtime is a cheap fast-path that triggers a content check.
        # Touch/checkout/vendor-sync update mtime without changing content; the
        # mtime-only test produced operator-facing WARN false positives. When
        # mtime suggests staleness, re-emit the manifest in-memory and md5 it
        # against the on-disk file — content match → still OK, content diff → WARN.
        if [ -f "$_mcp_ts" ] && [ "$_mcp_ts" -nt "$_mcp_mf" ]; then
            local _mcp_emitted_md5 _mcp_ondisk_md5
            _mcp_emitted_md5=$(python3 "$_fw_root/agents/mcp/manifest.py" show 2>/dev/null | md5sum 2>/dev/null | cut -d' ' -f1)
            _mcp_ondisk_md5=$(md5sum "$_mcp_mf" 2>/dev/null | cut -d' ' -f1)
            if [ -n "$_mcp_emitted_md5" ] && [ "$_mcp_emitted_md5" = "$_mcp_ondisk_md5" ]; then
                echo -e "  ${GREEN}OK${NC}  framework MCP $_mcp_tools tools (gated: $_mcp_gated) — $_mcp_msg"
            else
                echo -e "  ${YELLOW}WARN${NC}  framework MCP manifest stale relative to tool-set.yaml"
                echo -e "         Run: fw mcp emit-manifest"
                warnings=$((warnings + 1))
            fi
        else
            echo -e "  ${GREEN}OK${NC}  framework MCP $_mcp_tools tools (gated: $_mcp_gated) — $_mcp_msg"
        fi
    else
        # Genuinely absent. In the framework repo: emit it. In a consumer
        # (FRAMEWORK_ROOT vendored under .agentic-framework) the manifest ships
        # vendored, so absence means a broken/stale vendor → re-vendor via upgrade.
        if [ "$_fw_root" != "$PROJECT_ROOT" ]; then
            echo -e "  ${CYAN}SKIP${NC}  framework MCP manifest absent in vendored framework — run: fw upgrade"
        else
            echo -e "  ${CYAN}SKIP${NC}  framework MCP manifest absent — run: fw mcp emit-manifest"
        fi
    fi
}

# doctor_check_vendored_drift <framework_root>
#
# Check 2b (T-1434): vendored-source drift between <root>/{bin,lib,agents,web,
# .tasks/templates,.tasks/workflow} and their copies under <root>/.agentic-framework.
# Doctor only calls it in the framework repo (consumers have one copy, not two).
# The root is a parameter so tests can run it on a fixture instead of mutating
# the live vendored tree (that mutation raced concurrent `fw vendor self` runs).
doctor_check_vendored_drift() {
    local _root="$1"
    [ -d "$_root/.agentic-framework" ] || return 0
    # T-2243: count libs and templates classes separately so each class
    # always gets visibility in the WARN list — pre-T-2243 the global
    # "first 5" bucket let large libs drift bury small templates drift
    # (4-test exploration found 64 libs drifts could mask 1 templates
    # drift entirely). Per-class lists mirror the pre-push gate's
    # "would sync N <class>(s)" shape from T-2240/T-2241.
    local _vdrift_libs=0 _vdrift_tpl=0
    local _vdrift_libs_list="" _vdrift_tpl_list=""
    local _f _vf _rel
    # T-1521: Walk the vendored tree itself, not a hand-curated source glob.
    # T-1434's original glob list missed agents/handover, agents/audit,
    # agents/git, lib/reviewer, web/blueprints — all synced by `fw vendor`.
    # Walking the vendor tree guarantees coverage of whatever vendor put there.
    while IFS= read -r _vf; do
        _rel="${_vf#$_root/.agentic-framework/}"
        _f="$_root/$_rel"
        [ -f "$_f" ] || continue
        if ! diff -q "$_f" "$_vf" >/dev/null 2>&1; then
            _vdrift_libs=$((_vdrift_libs + 1))
            if [ "$_vdrift_libs" -le 5 ]; then
                _vdrift_libs_list="$_vdrift_libs_list\n           - $_rel"
            fi
        fi
    done < <(find "$_root/.agentic-framework"/{bin,lib,agents,web} -type f \
                \( -name "*.sh" -o -name "*.py" -o -name "fw" -o -name "*.html" \) \
                -not -path "*/__pycache__/*" \
                2>/dev/null)
    # T-2243: templates class (T-2241 sibling). _self_vendor_templates()
    # syncs .tasks/templates/*.md into .agentic-framework/.tasks/templates/.
    # Separate find — adding `.md` to the libs find pattern above would
    # also flag lib/templates/*.md and agents/*/AGENT.md files, which
    # aren't part of the self-vendor scope.
    if [ -d "$_root/.agentic-framework/.tasks/templates" ]; then
        while IFS= read -r _vf; do
            _rel="${_vf#$_root/.agentic-framework/}"
            _f="$_root/$_rel"
            [ -f "$_f" ] || continue
            if ! diff -q "$_f" "$_vf" >/dev/null 2>&1; then
                _vdrift_tpl=$((_vdrift_tpl + 1))
                if [ "$_vdrift_tpl" -le 5 ]; then
                    _vdrift_tpl_list="$_vdrift_tpl_list\n           - $_rel"
                fi
            fi
        done < <(find "$_root/.agentic-framework/.tasks/templates" \
                      "$_root/.agentic-framework/.tasks/workflow" -type f -name "*.md" 2>/dev/null)
    fi
    local _vdrift=$((_vdrift_libs + _vdrift_tpl))
    if [ "$_vdrift" -eq 0 ]; then
        echo -e "  ${GREEN}OK${NC}  No vendored-source drift"
    else
        echo -e "  ${YELLOW}WARN${NC}  Vendored-source drift: $_vdrift file(s) out of sync"
        echo -e "         Run: fw vendor  (sync .agentic-framework/ with source)"
        if [ "$_vdrift_libs" -gt 0 ]; then
            echo -e "         libs ($_vdrift_libs) — first $([ $_vdrift_libs -gt 5 ] && echo 5 || echo $_vdrift_libs):$_vdrift_libs_list"
        fi
        if [ "$_vdrift_tpl" -gt 0 ]; then
            echo -e "         templates ($_vdrift_tpl) — first $([ $_vdrift_tpl -gt 5 ] && echo 5 || echo $_vdrift_tpl):$_vdrift_tpl_list"
        fi
        warnings=$((warnings + 1))
    fi
}
