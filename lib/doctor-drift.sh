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
