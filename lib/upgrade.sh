#!/bin/bash
# fw upgrade - Sync framework improvements to a consumer project
#
# Runs in a consumer project directory, reads .framework.yaml to find the
# framework, then updates governance sections, templates, hooks, and seeds.
# Project-specific content is preserved.

# T-2755: the version-relation comparator is a hard dependency of BOTH the
# "Pinned:" header line and the T-1912 precheck below it. bin/fw:688 sources it
# with `2>/dev/null || true`, so an absent or unreadable file degrades silently —
# and what degrades is the loudest line in the output. Source it here too, next
# to the code that needs it (L-399: a contract split across files drifts).
# Idempotent — skipped when bin/fw already provided it.
if ! declare -f fw_version_relation >/dev/null 2>&1; then
    # shellcheck source=version-relation.sh
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/version-relation.sh"
fi

# T-1481: Opt-in remediation for OBS-023's structural cause. Removes
# framework hooks from $HOME/.claude/settings.json that duplicate
# project-level. Always creates a timestamped backup. Honors dry-run.
# Args: 1=user-level path, 2=project-level path, 3=dry-run bool
_do_dedupe_user_hooks() {
    local user_settings="$1"
    local proj_settings="$2"
    local dry_run="$3"

    local result rc
    result=$(USER_FILE="$user_settings" PROJ_FILE="$proj_settings" python3 -c "
import json, os, sys

def fw_hook_set(path):
    s = set()
    try:
        with open(path) as f:
            data = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError, OSError):
        return s
    for event, entries in data.get('hooks', {}).items():
        for entry in entries:
            for hook in entry.get('hooks', []):
                cmd = hook.get('command', '')
                if 'fw hook' in cmd:
                    name = cmd.split('fw hook ')[-1].strip().split()[0]
                elif '.agentic-framework' in cmd:
                    name = cmd.strip().split('/')[-1]
                else:
                    continue
                s.add((event, name))
    return s

proj = fw_hook_set(os.environ['PROJ_FILE'])
try:
    with open(os.environ['USER_FILE']) as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError, OSError) as e:
    print(f'ERROR|{e}')
    sys.exit(0)

removed = []
new_hooks = {}
for event, entries in data.get('hooks', {}).items():
    new_entries = []
    for entry in entries:
        kept = []
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            tup = None
            if 'fw hook' in cmd:
                name = cmd.split('fw hook ')[-1].strip().split()[0]
                tup = (event, name)
            elif '.agentic-framework' in cmd:
                name = cmd.strip().split('/')[-1]
                tup = (event, name)
            if tup is not None and tup in proj:
                removed.append(f'{tup[0]}:{tup[1]}')
            else:
                kept.append(hook)
        if kept:
            ne = dict(entry)
            ne['hooks'] = kept
            new_entries.append(ne)
    if new_entries:
        new_hooks[event] = new_entries

data['hooks'] = new_hooks
print('REMOVED|' + ','.join(removed))
print('JSON_START')
print(json.dumps(data, indent=2))
print('JSON_END')
" 2>/dev/null) || true
    rc=0

    # Detect ERROR
    if echo "$result" | grep -q '^ERROR|'; then
        echo -e "  ${YELLOW}WARN${NC}  $user_settings: $(echo "$result" | grep '^ERROR|' | head -1 | sed 's/^ERROR|//')"
        return 1
    fi

    local removed_list
    # T-1560 / L-302: pipefail guard. If $result has no REMOVED| line, line 92's
    # `[ -z "$removed_list" ]` branch is the intended path — without the guard,
    # set -e -o pipefail kills the function before line 92 runs.
    removed_list=$( { echo "$result" | grep '^REMOVED|' || true; } | head -1 | sed 's/^REMOVED|//')

    if [ -z "$removed_list" ]; then
        echo -e "  ${GREEN}OK${NC}  --dedupe-user-hooks: no duplicates in $user_settings"
        return 0
    fi

    local removed_count
    removed_count=$(echo "$removed_list" | tr ',' '\n' | wc -l)

    if [ "$dry_run" = true ]; then
        echo -e "  ${CYAN}WOULD REMOVE${NC}  $removed_count duplicate hook(s) from $user_settings"
        echo -e "    Pairs: $(echo "$removed_list" | tr ',' ' ')"
        return 0
    fi

    local backup="${user_settings}.bak-$(date +%s)"
    cp "$user_settings" "$backup"
    # Extract the JSON block between markers
    echo "$result" | sed -n '/^JSON_START$/,/^JSON_END$/p' | sed '1d;$d' > "$user_settings"
    echo -e "  ${GREEN}REMOVED${NC}  $removed_count duplicate hook(s) from $user_settings"
    echo -e "    Pairs: $(echo "$removed_list" | tr ',' ' ')"
    echo -e "    Backup: $backup"
    return 0
}

# T-2095 (T-2078 V1-D, F2): self-vendor extraction.
#
# Refreshes the framework's own .agentic-framework/lib/ from FRAMEWORK_ROOT/lib/.
# Origin: T-1217 — without this, new lib/*.sh files (e.g., watchtower.sh from
# T-1154) go stale in the vendored copy, causing pre-push audit errors for the
# framework repo itself.
#
# Was inlined in do_upgrade body until T-2095 — extracted so it can be invoked
# explicitly via `fw vendor self` (cron / pre-push / manual) AND opted out of
# do_upgrade via `--no-self-vendor` (operators who have wired pre-push and don't
# want the inline redundancy).
#
# Structural consumer-safety: the function early-returns when
# $FRAMEWORK_ROOT/.agentic-framework/lib does not exist — this is the case for
# any consumer's vendored copy (no nested .agentic-framework/lib/). T-1217's
# guard is preserved unchanged; the extraction is pure refactor.
#
# Args:
#   $1 — dry_run flag ("true" / "false"). When "true", reports what would
#        be synced without copying files.
# Return:
#   0 — sync completed (or nothing to sync, or consumer-skip)
_self_vendor_libs() {
    local dry_run="${1:-false}"
    local _self_vendor="$FRAMEWORK_ROOT/.agentic-framework"
    # T-1217 structural guard — consumer's .agentic-framework/ has no nested
    # .agentic-framework/lib/, so this branch is the consumer-safe early exit.
    if [ ! -d "$_self_vendor/lib" ]; then
        return 0
    fi
    local _sv_updated=0
    local _sv_src _sv_rel _sv_dst _sv_dst_dir
    # T-2307 (T-2304 follow-on): recursive + `*.sh + *.py + *.md` filter — parity
    # with `_self_vendor_agents` (T-2266+T-2304) and the audit's libs-class drift
    # scanner. Replaces the prior non-recursive `lib/*.sh` glob which silently
    # skipped 33 tracked `.md` siblings under lib/templates/ and
    # lib/templates/skills/. T-2455 (OBS-085): added `*.py` — the audit
    # (agents/audit/audit.sh check_self_vendor_drift) scans `*.sh + *.py + fw + *.md`,
    # but this helper had only `*.sh + *.md`, so every `lib/**/*.py` (40 files incl.
    # lib/reviewer/static_scan.py, the govd_*.py fabric, lib/integrate.py) was
    # silently un-vendorable. When source `.py` drifted, the audit FAILed and
    # `fw vendor self` could NOT clear it → all pushes blocked. The filter now
    # matches the audit set exactly so coverage parity is mechanical. Recursive:
    # lib/ has subdirectories (templates/, templates/skills/, reviewer/, ts/, etc.);
    # helper mirrors the tree under .agentic-framework/lib/, creating missing
    # subdirs at real-run only.
    while IFS= read -r _sv_src; do
        [ -f "$_sv_src" ] || continue
        _sv_rel="${_sv_src#$FRAMEWORK_ROOT/lib/}"
        _sv_dst="$_self_vendor/lib/$_sv_rel"
        if [ ! -f "$_sv_dst" ] || ! diff -q "$_sv_src" "$_sv_dst" > /dev/null 2>&1; then
            if [ "$dry_run" != true ]; then
                _sv_dst_dir=$(dirname "$_sv_dst")
                [ -d "$_sv_dst_dir" ] || mkdir -p "$_sv_dst_dir"
                cp "$_sv_src" "$_sv_dst"
                [ -x "$_sv_src" ] && chmod +x "$_sv_dst"
            fi
            _sv_updated=$((_sv_updated + 1))
        fi
    done < <(find "$FRAMEWORK_ROOT/lib" \( -path '*/node_modules/*' -o -path '*/__pycache__/*' -o -path '*/.git/*' \) -prune -o -type f \( -name "*.sh" -o -name "*.py" -o -name "*.md" \) -print 2>/dev/null)
    if [ "$_sv_updated" -gt 0 ]; then
        # T-2239: dry-run reports what WOULD happen; real-run reports what DID.
        # Same prefix, distinct verb — preserves the count semantic for both modes
        # and prevents the message from lying about state when the cp guard above
        # is honoured. T-2240 pre-push gate's regex (`would sync`) catches this
        # class along with all six other _self_vendor_* helpers via one match.
        if [ "$dry_run" = true ]; then
            echo -e "  ${GREEN}Self-vendor:${NC} would sync $_sv_updated file(s) to .agentic-framework/lib/"
        else
            echo -e "  ${GREEN}Self-vendor:${NC} synced $_sv_updated file(s) to .agentic-framework/lib/"
        fi
    fi
    return 0
}

# T-2241 (F2 N×M follow-on): self-vendor the framework's own .tasks/templates/
# from FRAMEWORK_ROOT/.tasks/templates/ to .agentic-framework/.tasks/templates/.
# Sibling to _self_vendor_libs — same shape, same dry-run/real-run wording split,
# same structural consumer-safety. T-2240 pre-push gate greps for "would sync" —
# this helper's output uses the identical prefix so the gate catches BOTH classes
# automatically (libs + templates) with one regex.
#
# Origin: T-2240 close surfaced template drift as a sibling class — vendored copy
# of `.tasks/templates/default.md` lacked `arc_id` + `bvp_scores` comment blocks
# the master had (T-1849 / T-1918). Without this helper, every consumer vendoring
# from origin would inherit stale templates and miss schema fields.
#
# Inputs:
#   $1 — dry_run ("true" / "false"). When "true", computes what WOULD sync
#        without copying files.
# Return:
#   0 — sync completed (or nothing to sync, or consumer-skip)
_self_vendor_templates() {
    local dry_run="${1:-false}"
    local _self_vendor="$FRAMEWORK_ROOT/.agentic-framework"
    # Structural guard mirror of _self_vendor_libs: consumer's vendored copy has
    # no nested .agentic-framework/.tasks/templates/, so this branch is the
    # consumer-safe early exit. Also covers the (unlikely but valid) case of a
    # fresh framework checkout where .agentic-framework/ exists but the templates
    # dir hasn't been created yet — fall through silently.
    if [ ! -d "$_self_vendor/.tasks/templates" ]; then
        return 0
    fi
    local _svt_updated=0
    local _svt_src _svt_name _svt_dst
    for _svt_src in "$FRAMEWORK_ROOT/.tasks/templates/"*.md; do
        [ -f "$_svt_src" ] || continue
        _svt_name=$(basename "$_svt_src")
        _svt_dst="$_self_vendor/.tasks/templates/$_svt_name"
        if [ ! -f "$_svt_dst" ] || ! diff -q "$_svt_src" "$_svt_dst" > /dev/null 2>&1; then
            if [ "$dry_run" != true ]; then
                cp "$_svt_src" "$_svt_dst"
            fi
            _svt_updated=$((_svt_updated + 1))
        fi
    done
    if [ "$_svt_updated" -gt 0 ]; then
        if [ "$dry_run" = true ]; then
            echo -e "  ${GREEN}Self-vendor:${NC} would sync $_svt_updated template(s) to .agentic-framework/.tasks/templates/"
        else
            echo -e "  ${GREEN}Self-vendor:${NC} synced $_svt_updated template(s) to .agentic-framework/.tasks/templates/"
        fi
    fi
    return 0
}

# T-2263 (arc-006 Slice 2C): self-vendor the framework's own BVP-policy templates
# from FRAMEWORK_ROOT/policy/{value-drivers.yaml,bvp-scoring-rubric.md} to
# .agentic-framework/policy/. Sibling to _self_vendor_libs (T-2095) and
# _self_vendor_templates (T-2241) — same shape, same dry-run/real-run wording
# split, same structural consumer-safety. T-2240 pre-push gate's regex
# (`would sync`) catches all three classes (libs + templates + policy) via one
# match, so policy-file drift in the framework repo blocks push the same way
# lib/ drift does.
#
# Explicit sync set (NOT a wildcard over `policy/`): the framework's `policy/`
# dir also contains arc-specific subdirs (capability-overlay/, prompts/) that
# are NOT framework→consumer governance templates. Only the two BVP files are
# in scope; future BVP-arc additions should be added here explicitly.
#
# Inputs:
#   $1 — dry_run ("true" / "false"). When "true", computes what WOULD sync
#        without copying files.
# Return:
#   0 — sync completed (or nothing to sync, or consumer-skip)
_self_vendor_policy() {
    local dry_run="${1:-false}"
    local _self_vendor="$FRAMEWORK_ROOT/.agentic-framework"
    # Structural guard mirror of siblings: consumer's vendored copy has no
    # nested .agentic-framework/policy/, so this branch is the consumer-safe
    # early exit. The framework repo carries the dir; a one-time bootstrap
    # (mkdir .agentic-framework/policy/ + cp the two templates) primed it
    # under T-2263.
    if [ ! -d "$_self_vendor/policy" ]; then
        return 0
    fi
    local _svp_updated=0
    local _svp_name _svp_src _svp_dst _svp_dst_dir
    # T-2287: capability-overlay/tool-set.yaml lives in a subdirectory — the
    # destination needs `mkdir -p` since `.agentic-framework/policy/capability-overlay/`
    # is absent in fresh vendored copies. The two original flat-list entries
    # (value-drivers.yaml, bvp-scoring-rubric.md) don't need mkdir; the guard
    # is harmless for them.
    # T-2329 (termlink): anti-patterns.yaml + escalation-patterns.yaml are the two
    # catalogues static_scan.py loads — omitting them left the reviewer's inputs
    # out of the vendored mirror (reviewer silently disabled in consumers).
    # T-3064 (found while scoping A2, not original scope): designer-pin.yaml was
    # ALREADY git-tracked at .agentic-framework/policy/ — committed by a wholesale
    # resync under T-2992 — but was never in this list. The two copies were
    # byte-identical purely by accident of that one resync, so the next pin bump
    # would have moved policy/designer-pin.yaml and left the vendored copy behind.
    # A consumer would then verify the CORRECT artifact against a STALE sha256 and
    # refuse it. Failing closed is the safe direction, but the symptom is "the
    # designer refuses to install" with no visible cause. Load-bearing from A2
    # onward, because A2 is what makes the vendored pin the thing consumers verify
    # against. Parity pinned by tests/unit/t3064_self_vendor_designer.bats.
    for _svp_name in value-drivers.yaml bvp-scoring-rubric.md capability-overlay/tool-set.yaml anti-patterns.yaml escalation-patterns.yaml designer-pin.yaml; do
        _svp_src="$FRAMEWORK_ROOT/policy/$_svp_name"
        _svp_dst="$_self_vendor/policy/$_svp_name"
        [ -f "$_svp_src" ] || continue
        if [ ! -f "$_svp_dst" ] || ! diff -q "$_svp_src" "$_svp_dst" > /dev/null 2>&1; then
            if [ "$dry_run" != true ]; then
                _svp_dst_dir="$(dirname "$_svp_dst")"
                [ -d "$_svp_dst_dir" ] || mkdir -p "$_svp_dst_dir"
                cp "$_svp_src" "$_svp_dst"
            fi
            _svp_updated=$((_svp_updated + 1))
        fi
    done
    if [ "$_svp_updated" -gt 0 ]; then
        if [ "$dry_run" = true ]; then
            echo -e "  ${GREEN}Self-vendor:${NC} would sync $_svp_updated file(s) to .agentic-framework/policy/"
        else
            echo -e "  ${GREEN}Self-vendor:${NC} synced $_svp_updated file(s) to .agentic-framework/policy/"
        fi
    fi
    return 0
}

# T-2264: self-vendor the framework's own bin/fw shim. Fourth sibling of
# _self_vendor_libs (T-2095) / _self_vendor_templates (T-2241) / _self_vendor_policy
# (T-2263) — same shape, same dry-run/real-run wording split, same structural
# consumer-safety. T-2240 pre-push gate's regex (`would sync`) catches all four
# classes via one match.
#
# Why: developer edits bin/fw without re-vendoring → `.agentic-framework/bin/fw`
# silently diverges. Consumers vendoring from origin then inherit the stale shim.
# Caught live during T-2263 close (13-line drift after Slice 2C wiring landed in
# bin/fw without a follow-up vendor refresh).
#
# Scope intentionally narrow: ONLY bin/fw, NOT agents/. Closing agents/ drift
# is a larger surface (~30 dirs, subprocess invocations) that needs its own
# design pass.
#
# Inputs:
#   $1 — dry_run ("true" / "false"). When "true", computes what WOULD sync
#        without copying files.
# Return:
#   0 — sync completed (or nothing to sync, or consumer-skip)
_self_vendor_shim() {
    local dry_run="${1:-false}"
    local _self_vendor="$FRAMEWORK_ROOT/.agentic-framework"
    # Structural guard mirror of siblings: consumer's vendored copy has no
    # nested .agentic-framework/bin/, so this branch is the consumer-safe
    # early exit.
    if [ ! -d "$_self_vendor/bin" ]; then
        return 0
    fi
    # T-2711: ENUMERATE bin/, do not name files.
    #
    # This helper used to carry a hardcoded list — `for _shim in fw claude-fw` —
    # while the audit gate (agents/audit/audit.sh check_self_vendor_drift) scans
    # ALL of .agentic-framework/bin for `*.sh + *.py + fw + claude-fw + *.md`.
    # Everything in bin/ outside those two names was therefore gated by the audit
    # and synced by nobody: `fw vendor self` reported success, `--check` reported
    # in-sync, and the T-2240 pre-push gate still refused — pointing the operator
    # at a verb that could not fix it. Four files were in that hole:
    # hook-enable.sh, integrate-go-live.sh, migrate-horizon-null-completed.sh,
    # watchtower.sh.
    #
    # Third instance of the shape (T-2266 agents/, T-2502 claude-fw, now bin/*.sh).
    # The first two were closed by adding the missing NAME. Naming is the defect —
    # each new bin/ script silently re-opened the hole. The three sibling helpers
    # (_self_vendor_libs / _agents / _web) already enumerate; this one now matches
    # them, so the set is derived, not maintained (L-399).
    local _svs_updated=0
    local _svs_src _svs_rel _svs_dst
    while IFS= read -r _svs_src; do
        [ -f "$_svs_src" ] || continue
        _svs_rel="${_svs_src#$FRAMEWORK_ROOT/bin/}"
        _svs_dst="$_self_vendor/bin/$_svs_rel"
        if [ ! -f "$_svs_dst" ] || ! diff -q "$_svs_src" "$_svs_dst" > /dev/null 2>&1; then
            if [ "$dry_run" != true ]; then
                mkdir -p "$(dirname "$_svs_dst")"
                cp "$_svs_src" "$_svs_dst"
                [ -x "$_svs_src" ] && chmod +x "$_svs_dst"
            fi
            _svs_updated=$((_svs_updated + 1))
        fi
    # Recursive, matching the audit's own scan. bin/ is flat today, so -maxdepth 1
    # would pass right now — and would silently re-open this exact hole the first
    # time someone adds bin/<subdir>/foo.sh. Parity means matching the gate's
    # traversal, not just its current results.
    # T-2793: enumerate EVERY file in bin/, not a name list.
    #
    # T-2711 fixed this helper to enumerate the directory instead of naming two
    # files — but kept a name FILTER (*.sh, *.py, fw, claude-fw, *.md), so the
    # hole only narrowed. `bin/fw-shim` and `bin/fw-router` are extensionless and
    # match none of them: neither was ever synced or gated. T-2304 added *.md,
    # T-2502 added claude-fw, T-2711 added enumeration; each closed the instance
    # in front of it and left the shape intact.
    #
    # bin/ holds executables and nothing else, so "every regular file" is the
    # honest predicate. agents/audit/audit.sh:check_self_vendor_drift scans bin/
    # the same way — the two must agree or the gate refuses what the helper
    # cannot fix (L-399 producer/consumer parity).
    done < <(find "$FRAMEWORK_ROOT/bin" \( -path '*/node_modules/*' -o -path '*/__pycache__/*' -o -path '*/.git/*' \) -prune -o -type f ! -name "*.pyc" -print 2>/dev/null)
    if [ "$_svs_updated" -gt 0 ]; then
        # T-2711: report the real count. This printed a hardcoded "1 file(s)"
        # regardless of how many were copied — a status line that agreed with
        # reality only by coincidence.
        if [ "$dry_run" = true ]; then
            echo -e "  ${GREEN}Self-vendor:${NC} would sync $_svs_updated file(s) to .agentic-framework/bin/"
        else
            echo -e "  ${GREEN}Self-vendor:${NC} synced $_svs_updated file(s) to .agentic-framework/bin/"
        fi
    fi
    return 0
}

# T-2266: self-vendor the framework's own agents/ tree. Fifth sibling of
# _self_vendor_libs (T-2095) / _self_vendor_templates (T-2241) / _self_vendor_policy
# (T-2263) / _self_vendor_shim (T-2264). Same shape, same dry-run/real-run wording
# split, same structural consumer-safety. T-2240 pre-push gate's regex
# (`would sync`) catches all five classes via one match.
#
# Why: agents/ holds *.sh + *.py executed by the framework (audit, context,
# task-create, dispatch, etc.). Developer edits agents/ without re-vendoring →
# `.agentic-framework/agents/` silently diverges. Audit at agents/audit/audit.sh:1534
# scans bin+lib+agents+web for drift; agents/ was flagged on the same regex but
# `fw vendor self` could not fix it pre-T-2266. Mitigation pointed at full
# `fw vendor` (consumer-direction) — wrong tool, wrong direction.
#
# Recursive: agents/ has subdirectories (audit/, context/, git/, ...). Helper
# mirrors the directory tree under .agentic-framework/agents/, creating missing
# subdirs at real-run only.
#
# Filter: `*.sh + *.py + *.md` — matches audit.sh:check_self_vendor_drift's
# exact set so coverage parity is mechanical. T-2304 (OBS-068) added `.md`
# because AGENT.md files (intelligence siblings of agents/*/AGENT.sh) drift
# silently between source agents/ and vendored .agentic-framework/agents/.
# Origin: T-2301 hit this on the resume agent.
#
# Inputs:
#   $1 — dry_run ("true" / "false"). When "true", computes what WOULD sync
#        without copying files (and without creating directories).
# Return:
#   0 — sync completed (or nothing to sync, or consumer-skip)
_self_vendor_agents() {
    local dry_run="${1:-false}"
    local _self_vendor="$FRAMEWORK_ROOT/.agentic-framework"
    # Structural guard mirror of siblings: consumer's vendored copy has no
    # nested .agentic-framework/agents/, so this branch is the consumer-safe
    # early exit.
    if [ ! -d "$_self_vendor/agents" ]; then
        return 0
    fi
    local _sva_updated=0
    local _sva_src _sva_rel _sva_dst _sva_dst_dir
    while IFS= read -r _sva_src; do
        [ -f "$_sva_src" ] || continue
        _sva_rel="${_sva_src#$FRAMEWORK_ROOT/agents/}"
        _sva_dst="$_self_vendor/agents/$_sva_rel"
        if [ ! -f "$_sva_dst" ] || ! diff -q "$_sva_src" "$_sva_dst" > /dev/null 2>&1; then
            if [ "$dry_run" != true ]; then
                _sva_dst_dir=$(dirname "$_sva_dst")
                [ -d "$_sva_dst_dir" ] || mkdir -p "$_sva_dst_dir"
                cp "$_sva_src" "$_sva_dst"
                [ -x "$_sva_src" ] && chmod +x "$_sva_dst"
            fi
            _sva_updated=$((_sva_updated + 1))
        fi
    done < <(find "$FRAMEWORK_ROOT/agents" \( -path '*/node_modules/*' -o -path '*/__pycache__/*' -o -path '*/.git/*' \) -prune -o -type f \( -name "*.sh" -o -name "*.py" -o -name "*.md" \) -print 2>/dev/null)
    if [ "$_sva_updated" -gt 0 ]; then
        if [ "$dry_run" = true ]; then
            echo -e "  ${GREEN}Self-vendor:${NC} would sync $_sva_updated agents/ file(s) to .agentic-framework/agents/"
        else
            echo -e "  ${GREEN}Self-vendor:${NC} synced $_sva_updated agents/ file(s) to .agentic-framework/agents/"
        fi
    fi
    return 0
}

# T-2267: self-vendor the framework's own web/ tree. Sixth (and current-final)
# sibling of _self_vendor_libs (T-2095) / _self_vendor_templates (T-2241) /
# _self_vendor_policy (T-2263) / _self_vendor_shim (T-2264) / _self_vendor_agents
# (T-2266). Same shape, same dry-run/real-run wording split, same structural
# consumer-safety. T-2240 pre-push gate's regex (`would sync`) catches all six
# classes via one match.
#
# Why: web/ holds *.sh + *.py — Flask app, blueprints, shared helpers, smoke
# tests. Developer edits web/ without re-vendoring → `.agentic-framework/web/`
# silently diverges. Audit at agents/audit/audit.sh:1534 scans bin+lib+agents+web
# for drift; pre-T-2267 web/ was flagged but `fw vendor self` could not fix it
# (mitigation pointed at full `fw vendor` — wrong tool, wrong direction).
#
# Recursive: web/ has subdirectories (blueprints/, etc.). Helper mirrors the
# directory tree under .agentic-framework/web/, creating missing subdirs at
# real-run only.
#
# Filter: `*.sh + *.py` — matches audit.sh:1534's exact set so coverage parity
# is mechanical. Templates (web/templates/*.html) and static assets
# (web/static/*) are NOT scanned by audit, so this helper deliberately leaves
# them untouched (out-of-scope per T-2267 fence).
#
# Inputs:
#   $1 — dry_run ("true" / "false"). When "true", computes what WOULD sync
#        without copying files (and without creating directories).
# Return:
#   0 — sync completed (or nothing to sync, or consumer-skip)
_self_vendor_web() {
    local dry_run="${1:-false}"
    local _self_vendor="$FRAMEWORK_ROOT/.agentic-framework"
    # Structural guard mirror of siblings: consumer's vendored copy has no
    # nested .agentic-framework/web/, so this branch is the consumer-safe
    # early exit.
    if [ ! -d "$_self_vendor/web" ]; then
        return 0
    fi
    local _svw_updated=0
    local _svw_src _svw_rel _svw_dst _svw_dst_dir
    while IFS= read -r _svw_src; do
        [ -f "$_svw_src" ] || continue
        _svw_rel="${_svw_src#$FRAMEWORK_ROOT/web/}"
        _svw_dst="$_self_vendor/web/$_svw_rel"
        if [ ! -f "$_svw_dst" ] || ! diff -q "$_svw_src" "$_svw_dst" > /dev/null 2>&1; then
            if [ "$dry_run" != true ]; then
                _svw_dst_dir=$(dirname "$_svw_dst")
                [ -d "$_svw_dst_dir" ] || mkdir -p "$_svw_dst_dir"
                cp "$_svw_src" "$_svw_dst"
                [ -x "$_svw_src" ] && chmod +x "$_svw_dst"
            fi
            _svw_updated=$((_svw_updated + 1))
        fi
    done < <(find "$FRAMEWORK_ROOT/web" \( -path '*/node_modules/*' -o -path '*/__pycache__/*' -o -path '*/.git/*' \) -prune -o -type f \( -name "*.sh" -o -name "*.py" -o -name "*.html" -o -name "*.css" -o -name "*.js" -o -name "*.svg" -o -name "*.j2" -o -name "*.jinja2" \) -print 2>/dev/null)
    if [ "$_svw_updated" -gt 0 ]; then
        if [ "$dry_run" = true ]; then
            echo -e "  ${GREEN}Self-vendor:${NC} would sync $_svw_updated web/ file(s) to .agentic-framework/web/"
        else
            echo -e "  ${GREEN}Self-vendor:${NC} synced $_svw_updated web/ file(s) to .agentic-framework/web/"
        fi
    fi
    return 0
}

# T-2793 (OBS-151): self-vendor the VERSION file. Seventh sibling of
# _self_vendor_libs / _templates / _policy / _shim / _agents / _web.
#
# Why it was missing and why that matters more now. `fw vendor self` synced six
# classes of CONTENT and never the copy's identity, so .agentic-framework/VERSION
# held whatever the last full `do_vendor` wrote — measured at 1.6.234 against a
# source at 1.6.114, a number from a different era. Anything comparing the two
# (fw_version_relation, doctor's pinned-vs-installed, consumer-recovery ordering)
# was reasoning about a version nothing had ever run.
#
# It stops being cosmetic once the CLI is vendored (T-2793): a vendored copy has
# no .git, so _derive_version falls through to this file, and VERSION becomes the
# ONLY statement of which framework a consumer is running.
#
# SYNC-ONLY — bin/fw calls this outside the --check set, and that asymmetry is the
# whole design. The VERSION file is rewritten in the working tree on every commit
# (it carries the git-derived major.minor.commits-since-tag; measured 1.6.114 ->
# 1.6.120 across six commits in one session). A checked class would therefore go
# red again the moment you commit the sync that cleared it — the T-2240 pre-push
# gate refuses, `fw vendor self` fixes it, the commit re-breaks it. A gate that
# cannot be satisfied is worse than one that does not fire.
#
# Stated plainly because it IS the unwitnessable-check shape (T-2726): a sync with
# no verifier. Accepted here only because the drift is guaranteed rather than
# occasional, harmless between vendor runs, and cleared by every mutating run. If
# VERSION ever stops moving per commit, this belongs back inside --check.
#
# (An earlier revision of this comment claimed VERSION "moves only at release" and
# used that to justify checking it. That was wrong — the per-commit rewrite was
# observed immediately afterwards. Left recorded rather than deleted: the claim
# was load-bearing for the design and the correction is the reason it changed.)
#
# Inputs:  $1 — dry_run ("true"/"false")
# Return:  0 always (nothing to sync, or consumer-skip)
_self_vendor_version() {
    local dry_run="${1:-false}"
    local _self_vendor="$FRAMEWORK_ROOT/.agentic-framework"
    local _svv_src="$FRAMEWORK_ROOT/VERSION"
    local _svv_dst="$_self_vendor/VERSION"
    # Consumer-safety mirror of the siblings: a consumer's vendored copy has no
    # nested .agentic-framework/, so this is the early exit there.
    [ -d "$_self_vendor" ] || return 0
    [ -f "$_svv_src" ] || return 0
    if [ ! -f "$_svv_dst" ] || ! diff -q "$_svv_src" "$_svv_dst" >/dev/null 2>&1; then
        if [ "$dry_run" = true ]; then
            echo -e "  ${GREEN}Self-vendor:${NC} would sync VERSION ($(tr -d '\n' < "$_svv_dst" 2>/dev/null || echo none) → $(tr -d '\n' < "$_svv_src")) to .agentic-framework/"
        else
            cp "$_svv_src" "$_svv_dst"
            echo -e "  ${GREEN}Self-vendor:${NC} synced VERSION ($(tr -d '\n' < "$_svv_src")) to .agentic-framework/"
        fi
    fi
    return 0
}

# T-3064: read `vendored_path:` out of a designer pin without a YAML parser.
#
# grep/sed rather than python3 on purpose: the only other caller is do_vendor in
# bin/fw, which must work on a fresh machine carrying nothing beyond bash and
# coreutils (§Consumer-Facing Command Hygiene, T-1633). That caller inlines the
# same four lines rather than sourcing this file — see the note at its use site
# for why a shared definition was rejected there.
#
# Capture-then-strip, never `grep | sed` on a live producer (L-387).
#
# Inputs:  $1 — path to a designer-pin.yaml
# Output:  the relative artifact path, or nothing when the key is absent
# Return:  0 always (absence is a valid answer, not an error)
_designer_pin_vendored_path() {
    local _dpv_pin="$1" _dpv_line
    _dpv_line="$(grep -E '^vendored_path:' "$_dpv_pin" 2>/dev/null | head -1 || true)"
    [ -n "$_dpv_line" ] || return 0
    _dpv_line="${_dpv_line#vendored_path:}"
    _dpv_line="${_dpv_line%%#*}"
    printf '%s' "$_dpv_line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//'
    return 0
}

# T-3064 (A2/A5): self-vendor the SINGLE PINNED Workflow Designer build from
# FRAMEWORK_ROOT/vendor/designer/<pinned> into .agentic-framework/vendor/designer/.
# Eighth sibling of _self_vendor_libs (T-2095) / _templates (T-2241) / _policy
# (T-2263) / _shim (T-2264) / _agents (T-2266) / _web (T-2267) / _version (T-2793)
# — same shape, same dry-run/real-run wording split, so the T-2240 pre-push gate's
# `would sync` regex catches this class through the same one match.
#
# ONE FILE, NOT THE DIRECTORY. vendor/designer/ holds nine historical builds
# (~7.7 MB) of which exactly one is pinned; vendoring the directory would put the
# framework repo's release history into every consumer. The pinned name is read
# from policy/designer-pin.yaml `vendored_path:`, so a pin bump retargets the sync
# by itself — and the superseded build is pruned from the vendored tree rather
# than left to accumulate.
#
# Why the artifact is vendored at all (the A5 decision, recorded in T-3064's
# `## Decisions`): the DECLARATION was already vendored and the ARTIFACT was not,
# so every consumer carried a pin naming a file it had never been given.
# Fetch-at-onboarding was rejected — 832-Workflow-designer lives on an internal
# OneDev a consumer may have no route or credentials to, which would put a network
# round-trip in the one path that must not fail open (A4).
#
# Inputs:
#   $1 — dry_run ("true" / "false"). When "true", computes what WOULD sync
#        without copying files.
# Return:
#   0 — sync completed (or nothing to sync, or consumer-skip)
_self_vendor_designer() {
    local dry_run="${1:-false}"
    local _self_vendor="$FRAMEWORK_ROOT/.agentic-framework"
    local _svd_pin="$FRAMEWORK_ROOT/policy/designer-pin.yaml"
    # Consumer-safety mirror of the siblings: a consumer's vendored copy has no
    # nested .agentic-framework/, so this is the early exit there.
    [ -d "$_self_vendor" ] || return 0
    [ -f "$_svd_pin" ] || return 0
    local _svd_rel
    _svd_rel="$(_designer_pin_vendored_path "$_svd_pin")"
    [ -n "$_svd_rel" ] || return 0
    local _svd_src="$FRAMEWORK_ROOT/$_svd_rel"
    local _svd_dst="$_self_vendor/$_svd_rel"
    # No source artifact: nothing to sync, and NOT this helper's job to report it.
    # `fw doctor` already WARNs on pinned-but-absent (T-3064 A1) at the surface an
    # operator reads; a second voice here would fire on every vendor run.
    [ -f "$_svd_src" ] || return 0

    local _svd_updated=0 _svd_pruned=0 _svd_dir _svd_old
    _svd_dir="$(dirname "$_svd_dst")"

    if [ ! -f "$_svd_dst" ] || ! cmp -s "$_svd_src" "$_svd_dst"; then
        if [ "$dry_run" != true ]; then
            [ -d "$_svd_dir" ] || mkdir -p "$_svd_dir"
            # rm first: the vendored copy is installed 0444 (never edited in
            # place, same contract as `fw designer sync`), so cp over it fails.
            rm -f "$_svd_dst"
            cp "$_svd_src" "$_svd_dst"
            chmod 0444 "$_svd_dst"
        fi
        _svd_updated=1
    fi

    # Prune superseded builds so a pin bump does not leave the old artifact
    # behind — a vendored tree that accumulates one ~900 KB build per release is
    # the directory-vendoring outcome arriving slowly.
    if [ -d "$_svd_dir" ]; then
        for _svd_old in "$_svd_dir"/aef-workflow-designer-*.html; do
            [ -f "$_svd_old" ] || continue
            # `[ a = b ] && continue` would be an AND-list evaluating to 1 on the
            # common (non-matching) branch, and this file is sourced into bin/fw's
            # `set -e` — which would abort the whole vendor run on the first
            # superseded build it found. Explicit if, deliberately.
            if [ "$_svd_old" = "$_svd_dst" ]; then
                continue
            fi
            [ "$dry_run" = true ] || rm -f "$_svd_old"
            _svd_pruned=$((_svd_pruned + 1))
        done
    fi

    if [ "$_svd_updated" -gt 0 ] || [ "$_svd_pruned" -gt 0 ]; then
        local _svd_what="$_svd_updated file(s)"
        [ "$_svd_pruned" -gt 0 ] && _svd_what="$_svd_what + $_svd_pruned superseded"
        if [ "$dry_run" = true ]; then
            echo -e "  ${GREEN}Self-vendor:${NC} would sync $_svd_what to .agentic-framework/$(dirname "$_svd_rel")/"
        else
            echo -e "  ${GREEN}Self-vendor:${NC} synced $_svd_what to .agentic-framework/$(dirname "$_svd_rel")/"
        fi
    fi
    return 0
}

# T-2755 — render the "Pinned:" header line from a COMPUTED relation.
#
# fw_upgrade_render_pin_line <consumer_version> <framework_version> <relation> <force_downgrade>
#
# Extracted from do_upgrade so the wording is reachable by a test without
# standing up a whole consumer. That is not incidental tidiness: the defect this
# replaces survived because the only way to see the line was to run a real
# upgrade against a real mismatched consumer, which no test did.
#
# `relation` is whatever fw_version_relation produced — this function never
# compares versions itself. One comparator, one answer, two readers (this line
# and the T-1912 guard below it).
fw_upgrade_render_pin_line() {
    local cversion="$1" fversion="$2" relation="$3" force_downgrade="${4:-false}"

    # The suffix comes from the same predicate the guard obeys, so the header
    # cannot promise an outcome the guard is about to contradict two lines later.
    local note=""
    if fw_version_relation_should_refuse "$relation"; then
        if [ "$force_downgrade" = true ]; then
            note=" — --force-downgrade given, proceeding anyway"
        else
            note=" — upgrade will refuse"
        fi
    fi

    case "$relation" in
        same)
            echo -e "  Pinned:    v${cversion} ${GREEN}(current)${NC}" ;;
        behind)
            echo -e "  Pinned:    v${cversion} ${YELLOW}(behind v${fversion})${NC}" ;;
        ahead)
            echo -e "  Pinned:    v${cversion} ${RED}(AHEAD of v${fversion}${note})${NC}" ;;
        diverged)
            echo -e "  Pinned:    v${cversion} ${RED}(diverged from v${fversion}${note})${NC}" ;;
        foreign-source)
            # T-2762: the fault is the SOURCE, not the consumer's pin — so the line
            # names the source. Rendering this as "undecidable" (the old fallthrough)
            # understated it: undecidable proceeds by default, this refuses.
            echo -e "  Pinned:    v${cversion} ${RED}(source does not contain this consumer's commit${note})${NC}" ;;
        *)
            # undecidable, or a relation this function has not been taught.
            # Say so — do NOT fall through to "behind". Claiming a direction we
            # cannot compute is the entire defect (see lib/version-relation.sh).
            echo -e "  Pinned:    v${cversion} ${YELLOW}(direction undecidable vs v${fversion}${note})${NC}" ;;
    esac
}

# T-2839: classify an upstream_repo value into something `git clone` can use.
#
# Prints the resolved clone source and returns 0; returns 2 when the value is
# not classifiable. Split out of do_upgrade so it can be tested directly — the
# bug it fixes was one inline `if` whose else-branch was unreachable by any test.
#
# Origin: a consumer carried `upstream_repo: /opt/agentic-engineering-framework`.
# The old logic recognised a fixed set of URL prefixes and treated EVERYTHING
# else as GitHub owner/repo shorthand, so an absolute path became
# `https://github.com//opt/agentic-engineering-framework.git` and the operator
# got `Repository not found` from GitHub — pointing at the wrong system, since
# the fault was in local config. "Not a URL I recognise" is not evidence of
# GitHub shorthand; it is evidence of not knowing, and that now refuses.
_fw_classify_upstream_source() {
    local _v="$1"
    [ -n "$_v" ] || return 2

    # Recognised URL schemes and git's SSH shorthand — pass through untouched.
    if printf '%s' "$_v" | grep -qE '^(https?|ssh|git|file)://|^git@'; then
        printf '%s\n' "$_v"
        return 0
    fi

    # Local filesystem paths. git clones these natively; they are never GitHub
    # shorthand. This is the leg whose absence caused the reported failure.
    # The tilde is QUOTED on purpose: bash performs tilde expansion on `case`
    # patterns, so an unquoted ~/* silently becomes /root/* (or whatever $HOME
    # is) and never matches a literal "~/…". Caught by exercising the classifier
    # rather than by reading it.
    case "$_v" in
        /*|./*|../*|'~'/*|'~') printf '%s\n' "$_v"; return 0 ;;
    esac

    # Strict GitHub shorthand: exactly owner/repo, both segments non-empty, no
    # leading or trailing slash. Deliberately strict — the previous permissive
    # fallback is what manufactured the bogus URL.
    if printf '%s' "$_v" | grep -qE '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'; then
        printf 'https://github.com/%s.git\n' "$_v"
        return 0
    fi

    return 2
}

do_upgrade() {
    local target_dir=""
    local dry_run=false
    local force=false
    local dedupe_user_hooks=false
    # T-1634: explicit upstream URL for bare-from-consumer auto-clone path.
    # Empty by default — bare-from-consumer detection falls back to
    # $target_dir/.framework.yaml's upstream_repo field.
    local from_upstream=""
    # T-1839: opt-in escape hatch for legitimate downgrade scenarios (e.g.
    # operator rolling consumer back to an older framework version on purpose).
    # Default refuses ahead→behind direction with diagnostic + T-1828 context.
    local force_downgrade=false
    # T-2093 F4 (T-2078 V1-B): opt-in strict mode — any per-step non-zero
    # aborts the upgrade and emits a PARTIAL diagnostic. Off by default for
    # backward-compat; the same per-step counter (failed_steps) drives a
    # non-blocking footer warning when off.
    local strict=false
    local failed_steps=0
    local _strict_abort_step=""
    # T-2095 (T-2078 V1-D, F2): opt-out of the inline self-vendor call. Off by
    # default — preserves T-1217's invariant (framework's .agentic-framework/lib/
    # stays in sync with FRAMEWORK_ROOT/lib/) on every developer machine that
    # hasn't yet wired `fw vendor self` into pre-push. Operators who have wired
    # pre-push (no inline redundancy needed) opt out via --no-self-vendor.
    local no_self_vendor=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) dry_run=true; shift ;;
            --force) force=true; shift ;;
            --force-downgrade) force_downgrade=true; shift ;;
            --strict) strict=true; shift ;;
            --no-self-vendor) no_self_vendor=true; shift ;;
            --dedupe-user-hooks) dedupe_user_hooks=true; shift ;;
            --from-upstream)
                from_upstream="$2"; shift 2 ;;
            --from-upstream=*)
                from_upstream="${1#--from-upstream=}"; shift ;;
            -h|--help)
                echo -e "${BOLD}fw upgrade${NC} - Sync framework improvements to consumer project"
                echo ""
                echo "Usage: fw upgrade [target-dir] [options]"
                echo ""
                echo "Arguments:"
                echo "  target-dir              Project to upgrade (default: current directory)"
                echo ""
                echo "Options:"
                echo "  --dry-run               Show what would change without modifying files"
                echo "  --force                 Overwrite even if project files are newer"
                echo "  --strict                Abort on the first per-step failure with a PARTIAL"
                echo "                          diagnostic (T-2093 V1-B, F4). Without this flag the"
                echo "                          upgrade continues on step failure (current behaviour)"
                echo "                          but a PARTIAL footer surfaces the count."
                echo "  --no-self-vendor        Skip the inline framework self-vendor refresh"
                echo "                          (T-2095 V1-D, F2). Default: keep inline (T-1217"
                echo "                          invariant). Opt-out for operators who fire"
                echo "                          'fw vendor self' from pre-push and don't want the"
                echo "                          per-upgrade redundancy."
                echo "  --force-downgrade       Allow upgrade to rewrite the consumer's pinned version"
                echo "                          to a LOWER framework version (T-1839 guard bypass)."
                echo "                          Default: refuse with diagnostic referencing T-1828."
                echo "  --dedupe-user-hooks     Remove framework hooks from \$HOME/.claude/settings.json"
                echo "                          that duplicate project-level (T-1481, addresses OBS-023)."
                echo "                          A timestamped backup is created before modification."
                echo "  --from-upstream URL     Clone the given upstream framework repo to a tempdir and"
                echo "                          use it as the upgrade source (T-1634). Bypasses the"
                echo "                          upstream_repo field in .framework.yaml. Tempdir is"
                echo "                          cleaned up on exit."
                echo "  -h, --help              Show this help"
                echo ""
                echo "What gets upgraded:"
                echo "  - CLAUDE.md governance sections (project-specific sections preserved)"
                echo "  - Task templates"
                echo "  - Seed files (practices, decisions, patterns — universal items only)"
                echo "  - Git hooks"
                echo "  - .claude/settings.json (hook config)"
                echo "  - .claude/commands/resume.md"
                echo "  - .claude/commands/doorbell+mail toolkit (be-reachable, peers, recent-chat, recent-dm, broadcast-chat, pulse, conversations, check-arc, agent-handoff) — T-1867"
                echo "  - scripts/doorbell+mail supporting toolkit (11 .sh) — T-1867"
                echo "  - lib/*.sh (fw subcommands: inception, upgrade, init, etc.)"
                echo "  - Agent scripts (task-create, handover, git, healing, fabric, etc.)"
                echo "  - bin/fw (CLI entry point)"
                return 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                return 1
                ;;
            *)
                target_dir="$1"; shift
                ;;
        esac
    done

    # T-2094 F8 (T-2078 V1-C): pre-flight tooling check. Fail fast BEFORE any
    # mutation if a required tool is missing — minimal LXC / Alpine containers
    # can lack one of python3/git/diff/sed/mktemp and the existing flow crashes
    # mid-step with a generic "command not found" and no rollback. Cheap
    # insurance per T-2078 §F8 ("Fix shape: explicit pre-flight at the top of
    # do_upgrade after arg parse").
    local _t2094_missing=()
    for _t2094_required in python3 git diff sed mktemp; do
        command -v "$_t2094_required" >/dev/null 2>&1 || _t2094_missing+=("$_t2094_required")
    done
    if [ "${#_t2094_missing[@]}" -gt 0 ]; then
        for _t2094_t in "${_t2094_missing[@]}"; do
            echo "ERROR: required tool missing: $_t2094_t" >&2
        done
        echo "Aborting before any file mutation. Install the missing tool(s) and re-run." >&2
        return 1
    fi

    # Default to PROJECT_ROOT or current directory
    if [ -z "$target_dir" ]; then
        target_dir="${PROJECT_ROOT:-$PWD}"
    fi

    # Resolve to absolute path
    target_dir="$(cd "$target_dir" 2>/dev/null && pwd)" || {
        echo -e "${RED}ERROR: Directory does not exist: $target_dir${NC}" >&2
        return 1
    }

    # Must have .framework.yaml
    if [ ! -f "$target_dir/.framework.yaml" ]; then
        echo -e "${RED}ERROR: Not a framework project — no .framework.yaml found in $target_dir${NC}" >&2
        echo "Run 'fw init $target_dir' first."
        return 1
    fi

    # Don't upgrade the framework itself
    if [ "$target_dir" = "$FRAMEWORK_ROOT" ]; then
        echo -e "${RED}ERROR: Cannot upgrade the framework project itself${NC}" >&2
        return 1
    fi

    # T-1542: Detect bare-from-consumer invocation (FRAMEWORK_ROOT is the
    # consumer's vendored copy). Source and target collapse — do_vendor's late
    # guard at step 4b would fire AFTER steps 1-4a have mutated state. Fail
    # fast BEFORE any mutation with a copy-pasteable corrected command.
    local _consumer_vendor_canon=""
    if [ -d "$target_dir/.agentic-framework" ]; then
        _consumer_vendor_canon=$(cd "$target_dir/.agentic-framework" 2>/dev/null && pwd -P) || _consumer_vendor_canon=""
    fi
    local _fw_root_canon
    _fw_root_canon=$(cd "$FRAMEWORK_ROOT" 2>/dev/null && pwd -P) || _fw_root_canon="$FRAMEWORK_ROOT"
    if [ -n "$_consumer_vendor_canon" ] && [ "$_fw_root_canon" = "$_consumer_vendor_canon" ]; then
        # T-1634: bare-from-consumer auto-clone path. Source and target
        # collapse — instead of erroring (T-1542 behaviour), try to clone
        # upstream to a tempdir and re-run with that as source.

        # Resolve upstream URL — three-leg fallback chain (T-2232):
        #   1. --from-upstream flag (explicit operator override)
        #   2. .framework.yaml upstream_repo: (auto-filled by fw init since T-575)
        #   3. vendored .agentic-framework/.upstream sentinel (T-2232 self-healing
        #      for legacy consumers init'd before T-575 or without a framework
        #      origin at init time — the durable fix for ring20-dashboard's
        #      .121do field failure class)
        # _upstream_source records which leg fired, used for the observability
        # line below and for the self-healing yaml-persist step at the end.
        local _upstream_url="$from_upstream"
        local _upstream_source=""
        [ -n "$_upstream_url" ] && _upstream_source="--from-upstream flag"
        if [ -z "$_upstream_url" ] && [ -f "$target_dir/.framework.yaml" ]; then
            _upstream_url=$(grep "^upstream_repo:" "$target_dir/.framework.yaml" 2>/dev/null \
                | head -1 \
                | sed -E 's/^upstream_repo:[[:space:]]*//' \
                | sed -E 's/[[:space:]]+$//')
            [ -n "$_upstream_url" ] && _upstream_source=".framework.yaml upstream_repo:"
        fi
        # T-2232 leg 3: vendored .upstream sentinel (written by do_vendor in
        # bin/fw — see the parallel block there). Read first line that is not
        # a comment and not empty; that's the URL.
        local _sentinel_path="$_consumer_vendor_canon/.upstream"
        if [ -z "$_upstream_url" ] && [ -f "$_sentinel_path" ]; then
            _upstream_url=$(grep -v '^[[:space:]]*#' "$_sentinel_path" 2>/dev/null \
                | grep -v '^[[:space:]]*$' \
                | head -1 \
                | sed -E 's/[[:space:]]+$//')
            [ -n "$_upstream_url" ] && _upstream_source="vendored .agentic-framework/.upstream sentinel (T-2232)"
        fi

        if [ -z "$_upstream_url" ]; then
            echo -e "${RED}ERROR: fw upgrade invoked from inside the consumer's vendored framework, and no upstream URL is known${NC}" >&2
            echo "" >&2
            echo "  FRAMEWORK_ROOT: $_fw_root_canon" >&2
            echo "  target_dir:     $target_dir" >&2
            echo "  Vendored copy:  $_consumer_vendor_canon" >&2
            echo "" >&2
            echo "  Source and target collapse — would self-copy and corrupt state." >&2
            echo "  No changes made." >&2
            echo "" >&2
            echo -e "${BOLD}Remediation (pick one):${NC}" >&2
            echo "" >&2
            echo "  1. Add the upstream URL to .framework.yaml (one-time, persists):" >&2
            echo "       echo 'upstream_repo: https://github.com/OWNER/REPO.git' >> $target_dir/.framework.yaml" >&2
            echo "       fw upgrade" >&2
            echo "" >&2
            echo "  2. Specify upstream URL inline:" >&2
            echo "       fw upgrade --from-upstream https://github.com/OWNER/REPO.git" >&2
            echo "" >&2
            echo "  3. Run from an upstream framework checkout with explicit target:" >&2
            echo "       cd /path/to/agentic-engineering-framework && bin/fw upgrade $target_dir" >&2
            echo "" >&2
            return 1
        fi

        # T-2839: classify before cloning, and refuse rather than guess. Applied
        # to all three resolution legs (flag, .framework.yaml, sentinel) so the
        # rule cannot differ by where the value came from — the reported failure
        # existed on the yaml leg only, which is exactly how it stayed unnoticed.
        local _upstream_clone_src
        if ! _upstream_clone_src=$(_fw_classify_upstream_source "$_upstream_url"); then
            echo -e "${RED}ERROR: upstream repo value is not a clone source fw can use${NC}" >&2
            echo "" >&2
            echo "  Value:        $_upstream_url" >&2
            echo "  Supplied by:  $_upstream_source" >&2
            echo "" >&2
            echo "  fw accepts:" >&2
            echo "    - a URL:            https://… ssh://… git://… file://… git@host:path" >&2
            echo "    - a local path:     /abs/path, ./rel, ../rel, ~/path" >&2
            echo "    - GitHub shorthand: owner/repo  (exactly two segments)" >&2
            echo "" >&2
            echo "  Fix the value named above — this is local configuration, not a" >&2
            echo "  problem with any remote. No changes made." >&2
            echo "" >&2
            return 1
        fi
        _upstream_url="$_upstream_clone_src"

        echo -e "${BOLD}Bare-from-consumer detected — auto-cloning upstream${NC}"
        echo "  Upstream URL:  $_upstream_url"
        echo "  Resolved via:  $_upstream_source"
        echo "  Target:        $target_dir"
        echo ""

        # Tempdir with trap-based cleanup. Use a sentinel filename component
        # so a stuck/corrupted dir is easy to identify and clean up manually.
        local _tmpd
        _tmpd=$(mktemp -d -t fw-upstream-XXXXXX) || {
            echo -e "${RED}ERROR: mktemp failed${NC}" >&2
            return 1
        }
        # shellcheck disable=SC2064  # expand _tmpd now, not at trap time
        trap "rm -rf '$_tmpd'" EXIT INT TERM HUP

        if [ "$dry_run" = true ]; then
            echo "  [dry-run] would clone $_upstream_url into $_tmpd/fw"
            echo "  [dry-run] would re-invoke: $_tmpd/fw/bin/fw upgrade $target_dir --dry-run"
            rm -rf "$_tmpd"
            trap - EXIT INT TERM HUP
            return 0
        fi

        echo -n "  Cloning... "
        if ! git clone --depth=1 --quiet "$_upstream_url" "$_tmpd/fw" 2>"$_tmpd/clone.err"; then
            echo "FAILED"
            echo -e "${RED}ERROR: git clone failed${NC}" >&2
            sed 's/^/    /' "$_tmpd/clone.err" >&2 2>/dev/null || true
            return 1
        fi
        echo "ok"

        # Replay arg flags to the upstream's bin/fw
        local _replay_args=("upgrade" "$target_dir")
        [ "$force" = true ] && _replay_args+=("--force")
        [ "$dedupe_user_hooks" = true ] && _replay_args+=("--dedupe-user-hooks")
        # NOTE: do not replay --from-upstream — the upstream IS the source
        # now, the target is local-path-based from the upstream's PoV.

        echo -e "  ${GREEN}Handing off to upstream's bin/fw:${NC} ${_replay_args[*]}"
        echo ""
        # T-2099 (fork-bomb fix, SEV-1): explicitly scope FRAMEWORK_ROOT + PROJECT_ROOT
        # for the cloned upstream's bin/fw. Without this, the cloned fw re-runs
        # resolve_framework which (per T-498 preference) picks the CONSUMER's vendored
        # copy again → infinite recursion → fork bomb. The companion fix in bin/fw
        # makes resolve_framework honour a caller-supplied FRAMEWORK_ROOT.
        # Origin: /opt/termlink ran fw upgrade twice in one hour, fork-bombed both
        # times. Forensic evidence + recipe via framework.upgrade.report TermLink topic.
        env FRAMEWORK_ROOT="$_tmpd/fw" PROJECT_ROOT="$target_dir" \
            "$_tmpd/fw/bin/fw" "${_replay_args[@]}"
        local _rc=$?
        # T-2232 self-healing: if the upstream resolved via the vendored
        # .upstream sentinel (precedence-3 leg) and the auto-clone succeeded,
        # persist the URL to .framework.yaml so the next upgrade skips the
        # sentinel fallback. Operator gets a clean .framework.yaml without
        # having to remediate by hand. Skipped on dry-run (handled above) and
        # on failure (we only want to durably commit a known-good URL).
        if [ "$_rc" -eq 0 ] \
           && [ "$_upstream_source" = "vendored .agentic-framework/.upstream sentinel (T-2232)" ] \
           && [ -f "$target_dir/.framework.yaml" ] \
           && ! grep -q "^upstream_repo:" "$target_dir/.framework.yaml" 2>/dev/null; then
            echo "upstream_repo: $_upstream_url" >> "$target_dir/.framework.yaml"
            echo -e "  ${GREEN}Self-heal:${NC} persisted upstream_repo to .framework.yaml (T-2232)"
        fi
        # trap fires on return — tempdir cleaned up
        return $_rc
    fi

    # T-1217 / T-2095 (T-2078 V1-D, F2): self-vendor refresh.
    # Inline call preserved by default for backward compat (T-1217 invariant).
    # Operators who have wired `fw vendor self` into pre-push can opt out with
    # --no-self-vendor to eliminate the per-upgrade redundancy. The helper
    # itself is structurally consumer-safe: it early-returns when the framework
    # vendored copy doesn't exist (consumer scenario).
    if [ "$no_self_vendor" = true ]; then
        echo -e "  ${YELLOW}Self-vendor skipped${NC} (--no-self-vendor)"
    else
        _self_vendor_libs "$dry_run"
        # T-2241: sibling sync — templates drift class, same flag gates both
        _self_vendor_templates "$dry_run"
        # T-2263: sibling sync — BVP-policy drift class (arc-006 Slice 2C),
        # same flag, same prefix → caught by T-2240 pre-push gate regex
        _self_vendor_policy "$dry_run"
        # T-2264: sibling sync — bin/fw shim drift class, same flag, same prefix
        _self_vendor_shim "$dry_run"
        # T-2266: sibling sync — agents/ drift class (5th class). Recursive over
        # subdirs (audit/, context/, git/, ...) filtered to *.sh + *.py to mirror
        # the audit drift scan's exact filter at agents/audit/audit.sh:1534.
        _self_vendor_agents "$dry_run"
        # T-2267: sibling sync — web/ drift class (6th and current-final class
        # under the audit drift-scan shape). Same *.sh + *.py filter; templates
        # and static assets stay untouched (out-of-scope per audit's filter).
        _self_vendor_web "$dry_run"
        # T-3064: sibling sync — pinned Workflow Designer build. Outside the
        # audit drift-scan shape (that scans {bin,lib,agents,web} only), so this
        # class is carried by `fw vendor self --check` and its own bats file.
        _self_vendor_designer "$dry_run"
    fi

    local project_name
    project_name=$(basename "$target_dir")
    local changes=0
    local skipped=0

    # Version comparison
    local fw_version="${FW_VERSION:-unknown}"
    local project_version=""
    if [ -f "$target_dir/.framework.yaml" ]; then
        project_version=$(grep "^version:" "$target_dir/.framework.yaml" 2>/dev/null | sed 's/^version:[[:space:]]*//' || true)
    fi

    # T-2755: compute the relation ONCE, here, and let both the header and the
    # T-1912 precheck below read the same answer.
    #
    # The header used to be `[ "$project_version" = "$fw_version" ]` — equality,
    # not direction. Every mismatch therefore rendered "(behind)", including the
    # ones the guard was about to refuse. Field instance (2026-08-03,
    # /opt/002-Claude-Partner-Network): the same output carried
    #     Pinned:  v1.6.354 (behind v1.6.8)
    #     REFUSED  Consumer v1.6.354 is AHEAD of framework v1.6.8
    # two lines apart. A reader who trusts the header reaches for
    # --force-downgrade at the exact moment the guard is protecting them.
    #
    # The comparator already existed — T-2713 replaced `sort -V` with git
    # ancestry precisely because a resetting counter cannot order. It was wired
    # into the guard and not into the sentence above it, so the loudest line in
    # the output was the one line still guessing.
    local _rel="" _rel_sha=""
    if [ -n "$project_version" ]; then
        _rel_sha=$(grep "^version_sha:" "$target_dir/.framework.yaml" 2>/dev/null | sed 's/^version_sha:[[:space:]]*//' || true)
        # Bare call, not $(...) — the reason travels via a global (see lib/version-relation.sh).
        fw_version_relation "$project_version" "$fw_version" "$_rel_sha" "$FRAMEWORK_ROOT" >/dev/null
        _rel="$FW_VERSION_RELATION"
    fi

    echo -e "${BOLD}fw upgrade${NC} - Syncing framework improvements"
    echo ""
    echo "  Project:   $target_dir ($project_name)"
    echo "  Framework: $FRAMEWORK_ROOT (v${fw_version})"
    if [ -n "$project_version" ]; then
        fw_upgrade_render_pin_line "$project_version" "$fw_version" "$_rel" "$force_downgrade"
    else
        echo -e "  Pinned:    ${YELLOW}<none>${NC} (version tracking will be added)"
    fi
    if [ "$dry_run" = true ]; then
        echo -e "  Mode:      ${YELLOW}DRY RUN${NC} (no changes will be made)"
    fi
    echo ""

    # T-1912: pre-step-1 version-ahead precheck.
    # Mirrors the step-9 T-1839 guard (lib/upgrade.sh:1100-1112) but fires
    # BEFORE any mutation. The step-9 guard correctly protects the pinned
    # version in .framework.yaml, but step 4b's do_vendor (line ~620) had
    # already copied framework runtime files over the consumer's newer
    # runtime by then — split-brain (runtime older, pin newer). Worked
    # example: 2026-05-18 dimitri-mint-dev consumer at v1.6.260 against
    # framework at v1.6.225. T-1839 closed the pin door; T-1912 closes
    # the runtime door at the same checkpoint so the guard is complete.
    if [ -n "$project_version" ] \
       && [ "$project_version" != "$fw_version" ] \
       && [ "$fw_version" != "unknown" ] \
       && [ "$force_downgrade" != true ]; then
        # T-2713: relation via git ancestry, not `sort -V`. The guard below is
        # unchanged in intent; it is simply no longer fed a fabricated direction.
        local _precheck_direction _precheck_sha
        _precheck_sha=$(grep "^version_sha:" "$target_dir/.framework.yaml" 2>/dev/null | sed 's/^version_sha:[[:space:]]*//' || true)
        # Bare call, not $(...) — the reason travels via a global (see lib/version-relation.sh).
        fw_version_relation "$project_version" "$fw_version" "$_precheck_sha" "$FRAMEWORK_ROOT" >/dev/null
        _precheck_direction="$FW_VERSION_RELATION"
        if fw_version_relation_should_refuse "$_precheck_direction"; then
            echo -e "${RED}REFUSED${NC}  Consumer v$project_version vs framework v$fw_version: ${_precheck_direction}." >&2
            echo -e "          ${FW_VERSION_RELATION_REASON}." >&2
            if [ "$_precheck_direction" = "foreign-source" ]; then
                # T-2762: different fault, different remedy. The consumer is fine;
                # the SOURCE is wrong, so "force the downgrade" is the wrong verb to
                # put in front of the reader. Naming the targeted bypass is L-399
                # discipline — a block message that offers only a mechanism aimed at
                # another failure is how agents end up routing around the gate.
                echo -e "          Upgrading from it would overwrite the consumer's files with a" >&2
                echo -e "          history that never held them." >&2
                echo -e "          Likely cause: a stale global shim. Check which fw is running:" >&2
                echo -e "            readlink -f \"\$(command -v fw)\"" >&2
                echo -e "          Then re-run from the consumer's own vendored framework, or from an" >&2
                echo -e "          upstream checkout that contains the consumer's commit." >&2
                echo -e "          To proceed anyway: ${BOLD}FW_ALLOW_FOREIGN_SOURCE=1${NC} (logged Tier-2)." >&2
            else
                echo -e "          Running fw upgrade here would downgrade the runtime (.agentic-framework/)" >&2
                echo -e "          AND the pinned version, creating a split-brain state (T-1912 class)." >&2
                echo -e "          To proceed anyway: re-run with ${BOLD}--force-downgrade${NC}." >&2
            fi
            return 1
        fi
        if [ "$_precheck_direction" = "undecidable" ]; then
            echo -e "${YELLOW}WARN${NC}    Version relation undetermined: ${FW_VERSION_RELATION_REASON}." >&2
            echo -e "          Proceeding (T-2713 default). This upgrade records version_sha, so the" >&2
            echo -e "          next comparison will be decidable. Set FW_UNDECIDABLE_VERSION_PROCEED=0 to refuse instead." >&2
        fi
    fi

    # ── 0. Directory skeleton (T-2758) ──
    #
    # Step 8 below has always created the .context/ subdirectories. It runs FIVE
    # STEPS TOO LATE: step 3 copies seed files into .context/project/, and on a
    # consumer that doesn't have that directory yet the cp fails, `fw upgrade`
    # exits 1, and steps 4-10 — hooks, resume.md, shim, vendor — never run. The
    # consumer is left half-upgraded, having already taken steps 1 and 2.
    #
    # The ordering was invisible because every consumer that reached step 3 had
    # been through `fw init`, which creates the tree. The shape that breaks is a
    # project holding .framework.yaml and little else — which is exactly what the
    # tests construct, and why lib_upgrade.bats had three red tests attributed to
    # resume.md drift when the run was dying long before resume.md.
    #
    # Creating the skeleton up front rather than adding a mkdir at the one line
    # observed failing: the next step added below is written against a consumer
    # that already has its directories, and would inherit the same bug.
    if [ "$dry_run" != true ]; then
        local _skel
        for _skel in audits bus episodic handovers inbox project qa scans working; do
            mkdir -p "$target_dir/.context/$_skel"
        done
        mkdir -p "$target_dir/.tasks/templates" "$target_dir/.claude/commands" "$target_dir/policy"
    fi

    # ── 1. CLAUDE.md — preserve project sections, update governance ──
    echo -e "${YELLOW}[1/10] CLAUDE.md governance sections${NC}"

    local project_claude="$target_dir/CLAUDE.md"
    local template_file="$FRAMEWORK_ROOT/lib/templates/claude-project.md"

    if [ -f "$project_claude" ] && [ -f "$template_file" ]; then
        # Extract project-specific sections (everything before "## Core Principle")
        local project_header
        project_header=$(sed -n '1,/^## Core Principle$/{ /^## Core Principle$/d; p; }' "$project_claude")

        # Extract governance sections from template (from "## Core Principle" onwards)
        local governance
        governance=$(sed -n '/^## Core Principle$/,$ p' "$template_file")

        if [ -z "$project_header" ]; then
            # No project header found — file might be the raw template or custom
            project_header="# CLAUDE.md

Claude Code integration for the Agentic Engineering Framework.
For the provider-neutral framework guide, see \`FRAMEWORK.md\`.

This file is auto-loaded by Claude Code. It contains the full operating guide
plus Claude Code-specific integration notes.

## Project Overview

**Project:** $project_name

<!-- Add your project description, tech stack, and conventions below -->

## Tech Stack and Conventions

<!-- Define your project's tech stack, coding standards, and conventions here -->

## Project-Specific Rules

<!-- Add any project-specific rules that agents must follow -->

"
        fi

        # Fix any leftover placeholders in existing file
        if grep -q "__PROJECT_NAME__" "$project_claude" 2>/dev/null; then
            if [ "$dry_run" != true ]; then
                _sed_i "s|__PROJECT_NAME__|$project_name|g" "$project_claude"
                echo -e "  ${GREEN}FIXED${NC}  Replaced __PROJECT_NAME__ placeholder"
                changes=$((changes + 1))
            else
                echo -e "  ${CYAN}WOULD FIX${NC}  __PROJECT_NAME__ placeholder"
                changes=$((changes + 1))
            fi
        fi

        # Compare current governance with template
        local current_governance
        current_governance=$(sed -n '/^## Core Principle$/,$ p' "$project_claude")

        if [ "$current_governance" = "$governance" ]; then
            echo -e "  ${GREEN}OK${NC}  Already up to date"
        else
            changes=$((changes + 1))
            if [ "$dry_run" = true ]; then
                local current_lines new_lines
                current_lines=$(echo "$current_governance" | wc -l)
                new_lines=$(echo "$governance" | wc -l)
                echo -e "  ${CYAN}WOULD UPDATE${NC}  Governance sections ($current_lines → $new_lines lines)"
            else
                # Backup before overwriting
                cp "$project_claude" "${project_claude}.bak"
                # Write combined file, fix any leftover placeholders
                project_header="${project_header//__PROJECT_NAME__/$project_name}"
                printf '%s\n%s\n' "$project_header" "$governance" > "$project_claude"
                echo -e "  ${GREEN}UPDATED${NC}  Governance sections refreshed from framework template. Backup: CLAUDE.md.bak"

                # T-1629/G-055: Detect inline-customization regressions in
                # governance sections. The wholesale-replace above cannot
                # preserve project-specific INLINE additions inside governance
                # (extra rows in tables, modified bullet text). Surface lost
                # lines so the operator decides whether to re-apply them.
                # Without this audit the regression goes silent — observed
                # 2026-05-03 (PL-124 hit twice within 7d → G-055).
                local lost_lines lost_count
                lost_lines=$(grep -Fxv -f "$project_claude" "${project_claude}.bak" 2>/dev/null \
                    | grep -vE '^[[:space:]]*$' || true)
                if [ -n "$lost_lines" ]; then
                    lost_count=$(printf '%s\n' "$lost_lines" | wc -l)
                    echo -e "  ${YELLOW}!${NC}  $lost_count line(s) in CLAUDE.md.bak are absent from the new CLAUDE.md."
                    echo -e "      These may be project-specific inline customizations the template"
                    echo -e "      merge cannot preserve. First lines:"
                    printf '%s\n' "$lost_lines" | head -8 | sed 's/^/        /'
                    if [ "$lost_count" -gt 8 ]; then
                        echo "        ... ($((lost_count - 8)) more — full diff: diff CLAUDE.md.bak CLAUDE.md)"
                    fi
                    echo -e "      ${YELLOW}Review and re-apply if needed, then remove CLAUDE.md.bak to clear.${NC}"
                    echo -e "      Background: G-055 / PL-124 (.context/project/{concerns,learnings}.yaml)"
                fi
            fi
        fi
    elif [ ! -f "$project_claude" ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  CLAUDE.md from template"
        else
            sed "s|__PROJECT_NAME__|$project_name|g" "$template_file" > "$project_claude"
            echo -e "  ${GREEN}CREATED${NC}  CLAUDE.md from template"
        fi
    else
        echo -e "  ${YELLOW}SKIP${NC}  Template not found at $template_file"
        skipped=$((skipped + 1))
    fi

    # ── 2. Task templates ──
    echo -e "${YELLOW}[2/10] Task templates${NC}"

    local tmpl_updated=0
    for tmpl in "$FRAMEWORK_ROOT/.tasks/templates/"*.md; do
        [ -f "$tmpl" ] || continue
        local tmpl_name
        tmpl_name=$(basename "$tmpl")
        local target_tmpl="$target_dir/.tasks/templates/$tmpl_name"

        if [ ! -f "$target_tmpl" ] || ! diff -q "$tmpl" "$target_tmpl" > /dev/null 2>&1; then
            tmpl_updated=$((tmpl_updated + 1))
            if [ "$dry_run" != true ]; then
                mkdir -p "$target_dir/.tasks/templates"
                cp "$tmpl" "$target_tmpl"
            fi
        fi
    done

    if [ "$tmpl_updated" -gt 0 ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD UPDATE${NC}  $tmpl_updated template(s)"
        else
            echo -e "  ${GREEN}UPDATED${NC}  $tmpl_updated template(s)"
        fi
    else
        echo -e "  ${GREEN}OK${NC}  All templates current"
    fi

    # ── 3. Seed files (universal governance items) ──
    echo -e "${YELLOW}[3/10] Seed files (universal governance)${NC}"

    local seed_updated=0
    for seed_name in practices decisions patterns; do
        local seed_file="$FRAMEWORK_ROOT/lib/seeds/${seed_name}.yaml"
        local project_file="$target_dir/.context/project/${seed_name}.yaml"

        [ -f "$seed_file" ] || continue

        if [ ! -f "$project_file" ]; then
            seed_updated=$((seed_updated + 1))
            if [ "$dry_run" != true ]; then
                cp "$seed_file" "$project_file"
            fi
        elif ! diff -q "$seed_file" "$project_file" > /dev/null 2>&1; then
            # File differs — check if project has added project-specific items
            # Count items in each
            local seed_count project_count
            seed_count=$(grep -c "^  - " "$seed_file" 2>/dev/null || true)
            project_count=$(grep -c "^  - " "$project_file" 2>/dev/null || true)
            seed_count=${seed_count:-0}
            project_count=${project_count:-0}

            if [ "$project_count" -gt "$seed_count" ]; then
                # Project has more items — has been customized, skip
                echo -e "  ${YELLOW}SKIP${NC}  ${seed_name}.yaml (has project-specific items — manual merge recommended)"
                skipped=$((skipped + 1))
            else
                seed_updated=$((seed_updated + 1))
                if [ "$dry_run" != true ]; then
                    cp "$seed_file" "$project_file"
                fi
            fi
        fi
    done

    if [ "$seed_updated" -gt 0 ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD UPDATE${NC}  $seed_updated seed file(s)"
        else
            echo -e "  ${GREEN}UPDATED${NC}  $seed_updated seed file(s)"
        fi
    elif [ "$skipped" -eq 0 ]; then
        echo -e "  ${GREEN}OK${NC}  All seeds current"
    fi

    # ── 3b. Cron registry (T-448/T-653) ──
    local cron_seeded=0
    if [ ! -d "$target_dir/.context/cron" ]; then
        cron_seeded=$((cron_seeded + 1))
        if [ "$dry_run" != true ]; then
            mkdir -p "$target_dir/.context/cron"
        fi
    fi
    if [ ! -f "$target_dir/.context/cron-registry.yaml" ]; then
        cron_seeded=$((cron_seeded + 1))
        if [ "$dry_run" != true ]; then
            cat > "$target_dir/.context/cron-registry.yaml" << 'CRONREGEOF'
# Cron Registry — Structured source of truth for scheduled jobs (T-448)
# Read by web/blueprints/cron.py and fw cron generate.
jobs: []
CRONREGEOF
        fi
    fi
    if [ "$cron_seeded" -gt 0 ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD SEED${NC}  Cron registry + directory"
        else
            echo -e "  ${GREEN}SEEDED${NC}  Cron registry + directory"
        fi
    fi

    # ── 3c. BVP policy files (T-2262 / arc-006 Slice 2B) ──
    # Sibling of T-2261's lib/init.sh wiring. Seed BVP-policy files on consumers
    # that pre-date T-2261. Copy-on-missing only — consumer customisation survives.
    local bvp_seeded=0
    if [ ! -f "$target_dir/policy/value-drivers.yaml" ] && [ -f "$FRAMEWORK_ROOT/policy/value-drivers.yaml" ]; then
        bvp_seeded=$((bvp_seeded + 1))
        if [ "$dry_run" != true ]; then
            mkdir -p "$target_dir/policy"
            cp "$FRAMEWORK_ROOT/policy/value-drivers.yaml" "$target_dir/policy/value-drivers.yaml"
        fi
    fi
    if [ ! -f "$target_dir/policy/bvp-scoring-rubric.md" ] && [ -f "$FRAMEWORK_ROOT/policy/bvp-scoring-rubric.md" ]; then
        bvp_seeded=$((bvp_seeded + 1))
        if [ "$dry_run" != true ]; then
            mkdir -p "$target_dir/policy"
            cp "$FRAMEWORK_ROOT/policy/bvp-scoring-rubric.md" "$target_dir/policy/bvp-scoring-rubric.md"
        fi
    fi
    if [ "$bvp_seeded" -gt 0 ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD SEED${NC}  BVP policy files ($bvp_seeded file(s))"
        else
            echo -e "  ${GREEN}SEEDED${NC}  BVP policy files ($bvp_seeded file(s))"
        fi
    fi

    # ── 4. Git hooks ──
    echo -e "${YELLOW}[4/10] Git hooks${NC}"

    # T-3129: `-e` — see lib/setup.sh; install-hooks itself is already
    # worktree-correct, this gate was the blind spot.
    if [ -e "$target_dir/.git" ]; then
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD REINSTALL${NC}  Git hooks"
            changes=$((changes + 1))
        else
            if PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks > /dev/null 2>&1; then
                echo -e "  ${GREEN}UPDATED${NC}  Git hooks reinstalled"
                changes=$((changes + 1))
            else
                echo -e "  ${YELLOW}WARN${NC}  Git hook installation failed"
                skipped=$((skipped + 1))
            fi
        fi
    else
        echo -e "  ${CYAN}SKIP${NC}  Not a git repository"
    fi

    # ── 4b. Vendored framework scripts (.agentic-framework/) ──
    # T-1157: Collapsed from 120-line handcrafted per-file sync into single do_vendor call.
    # do_vendor (bin/fw:118) maintains the canonical includes list (bin lib agents web docs
    # .tasks/templates FRAMEWORK.md metrics.sh). This eliminates the enumeration-divergence
    # bug that caused fw upgrade to silently skip web/ (T-1109 RCA).
    echo -e "${YELLOW}[4b/9] Vendored framework scripts${NC}"

    local vendored_dir="$target_dir/.agentic-framework"
    if [ -d "$vendored_dir" ]; then
        # T-2093 F5 fix: capture do_vendor's exit via PIPESTATUS — the pipe
        # through `sed` always exits 0 and used to mask vendor failures
        # (T-1109's enumeration-divergence class). Without this, a vendor
        # source missing a file produced a silent "Upgrade Complete".
        local _vendor_rc=0
        if [ "$dry_run" = true ]; then
            do_vendor --target "$target_dir" --source "$FRAMEWORK_ROOT" --dry-run 2>&1 | sed 's/^/  /'
            _vendor_rc=${PIPESTATUS[0]}
        else
            do_vendor --target "$target_dir" --source "$FRAMEWORK_ROOT" 2>&1 | sed 's/^/  /'
            _vendor_rc=${PIPESTATUS[0]}
        fi
        if [ "$_vendor_rc" -ne 0 ]; then
            echo -e "  ${YELLOW}WARN${NC}  do_vendor exited $_vendor_rc — vendor sync may be partial (F5)"
            failed_steps=$((failed_steps + 1))
            if [ "$strict" = true ]; then
                echo -e "  ${RED}STRICT ABORT${NC}  step 4b (vendor) failed — see T-2093 F4 + spec §F4"
                _strict_abort_step="4b (vendor)"
                return 1
            fi
        fi
        changes=$((changes + 1))
    else
        echo -e "  ${CYAN}SKIP${NC}  No .agentic-framework/ directory"
    fi

    # ── 4c. Shim migration + global install sync ──
    echo -e "${YELLOW}[4c/9] Shim migration + global install sync${NC}"

    # T-665: Migrate ~/.local/bin/fw from global symlink to project-detecting shim
    local local_bin="$HOME/.local/bin"
    # T-2793: prefer bin/fw-router (supersedes bin/fw-shim — same walk-up, plus
    # an announced global fallback so `fw init` still works in a bare directory).
    local shim_src="$FRAMEWORK_ROOT/bin/fw-router"
    [ -f "$shim_src" ] || shim_src="$FRAMEWORK_ROOT/bin/fw-shim"
    if [ -f "$shim_src" ] && [ -d "$local_bin" ]; then
        local current_fw="$local_bin/fw"
        if [ -L "$current_fw" ]; then
            # Current fw is a symlink (old style) — replace with shim
            local link_target
            link_target=$(readlink -f "$current_fw" 2>/dev/null || echo "")
            if [[ "$link_target" == *".agentic-framework/bin/fw"* ]] || [[ "$link_target" == *"/bin/fw" ]]; then
                if [ "$dry_run" = true ]; then
                    echo -e "  ${CYAN}WOULD MIGRATE${NC}  Replace symlink with project-detecting shim"
                else
                    # T-1278: defence-in-depth — if the resolved target sits
                    # next to a FRAMEWORK.md, refuse. It's a framework repo's
                    # bin/fw, not a PATH shim location.
                    # T-2759: MUST NOT be named target_dir. do_upgrade binds
                    # target_dir to the consumer at :566, and a second `local`
                    # in the same function scope REBINDS it rather than scoping
                    # a new one. Steps 5-10 then wrote .claude/settings.json,
                    # .mcp.json, resume.md, scripts/, the context subdirs, the
                    # .framework.yaml version pin and the enforcement baseline
                    # into dirname(readlink -f ~/.local/bin/fw) — while the run
                    # printed "=== Upgrade Complete ===" and exited 0.
                    local _shim_link_dir
                    _shim_link_dir=$(dirname "$link_target" 2>/dev/null || echo "")
                    if [ -n "$_shim_link_dir" ] && [ -f "$_shim_link_dir/../FRAMEWORK.md" ]; then
                        echo -e "  ${RED}REFUSED${NC}  $current_fw resolves into a framework repo ($_shim_link_dir/..)"
                        echo -e "         Refusing to overwrite a framework repo's bin/fw with the shim."
                        echo -e "         Inspect: ls -la $current_fw && readlink -f $current_fw"
                        return 1
                    fi
                    # T-1278: remove symlink before copy. Plain `cp` follows the
                    # destination symlink and writes the shim *through* it into
                    # the framework repo's bin/fw, corrupting the real CLI into
                    # a shim → every fw call then infinite-exec-loops.
                    rm -f "$current_fw"
                    cp "$shim_src" "$current_fw"
                    chmod +x "$current_fw"
                    changes=$((changes + 1))
                    echo -e "  ${GREEN}MIGRATED${NC}  Replaced global symlink with project-detecting shim"
                    echo -e "  ${CYAN}INFO${NC}  Shim migration: fw now routes to the project you're standing in"
                    echo -e "  ${CYAN}INFO${NC}  Each project uses its own framework version (no global install dependency)"
                fi
            fi
        elif [ -f "$current_fw" ] && ! grep -q 'find_fw' "$current_fw" 2>/dev/null; then
            # fw exists but isn't the shim — leave it alone (manual install)
            echo -e "  ${CYAN}SKIP${NC}  $current_fw exists but is not a symlink or shim"
        else
            echo -e "  ${GREEN}OK${NC}  fw shim already installed"
        fi
    fi

    # T-660 global-install sync REMOVED (T-2854, completing D-377).
    #
    # This block copied bin/fw, lib/*.sh and agents/context/*.sh into
    # $HOME/.agentic-framework on every upgrade, whenever that directory
    # existed. Since T-2800/T-2809 nothing creates it, so the only directories
    # it could still feed were pre-T-2800 residue — which is how one reached
    # 341MB on the origin host and stayed current enough to keep being used.
    #
    # Keeping a stale copy fed is worse than leaving it stale: a maintained
    # residue is indistinguishable from a supported install, and bin/fw-router
    # no longer consults it at all. Detection stays in `fw doctor`, which
    # reports the directory and the rm -rf to run.

    # ── 5. .claude/settings.json (hooks config) ──
    echo -e "${YELLOW}[5/10] Claude Code hooks (.claude/settings.json)${NC}"

    local settings_file="$target_dir/.claude/settings.json"
    local fw_settings="$FRAMEWORK_ROOT/.claude/settings.json"

    # T-2912: hook-gap detection extracted into a function so it can be run
    # BOTH before and after regeneration. The bug this closes: the block used
    # to compute "reason" once (before), regenerate, then print "UPDATED
    # (reason)" unconditionally — describing the trigger, not the result. If
    # the regenerator's own template doesn't know the missing hook (T-2710's
    # class), the after-state is identical to the before-state and the report
    # is a false positive. Compare hooks by TYPE enumeration (T-615: not count).
    # Source of truth: framework's own .claude/settings.json.
    _t2912_hook_gap() {
        local sfile="$1"
        local analysis
        analysis=$(FW_FILE="$fw_settings" CONSUMER_FILE="$sfile" FW_LIB="$FRAMEWORK_ROOT/lib" python3 -c "
import json, os, sys

# T-3113: extract_hooks was a third inline copy of the predicate that
# lib/hook-parity.sh (T-3112) had already consolidated for doctor's two call
# sites. Imported now, not copied. Same shape as lib/hook_portability.py below.
# NOTE the parse policy: this caller wants the LENIENT one (strict=False, an
# unparseable settings.json yields an empty set → missing = everything →
# needs_regen → the broken file gets regenerated). That is T-2912's shipped
# behaviour and it is the correct response here; doctor wants the strict policy
# instead. Both live in the module.
sys.path.insert(0, os.environ['FW_LIB'])
from hook_parity import extract_hooks

def check_stale_paths(path):
    stale = 0
    non_framework = 0
    try:
        with open(path) as f:
            data = json.load(f)
        for event, entries in data.get('hooks', {}).items():
            for entry in entries:
                for hook in entry.get('hooks', []):
                    cmd = hook.get('command', '')
                    if '/agents/context/' in cmd or 'PROJECT_ROOT=' in cmd:
                        stale += 1
                    # T-1627 (B-1 of T-1626): bare-relative '.agentic-framework/'
                    # paths break from any subdir of the consumer. Witness:
                    # /root/ring20-dashboard 2026-04-30 — every tool call fired
                    # 'PostToolUse:Edit hook error / .agentic-framework/bin/fw:
                    # not found' because settings.json predated T-1364's
                    # absolute-path baking AND the prior stale-detector below
                    # only saw '.agentic-framework' in the cmd and assumed
                    # framework-OK. Bare-relative is structurally broken — flag.
                    elif cmd and cmd.lstrip().startswith('.agentic-framework/'):
                        stale += 1
                    # T-679: Detect non-framework hooks (e.g., pre-existing project hooks)
                    # Framework hooks always contain 'fw hook' or '.agentic-framework'
                    elif cmd and 'fw hook' not in cmd and '.agentic-framework' not in cmd:
                        non_framework += 1
    except (json.JSONDecodeError, FileNotFoundError):
        pass
    return stale + non_framework

fw_hooks = extract_hooks(os.environ['FW_FILE'])
consumer_hooks = extract_hooks(os.environ['CONSUMER_FILE'])
stale = check_stale_paths(os.environ['CONSUMER_FILE'])

missing = fw_hooks - consumer_hooks
missing_names = '; '.join(f'{e}:{n}' for e, n in sorted(missing)) if missing else ''
print(f'{len(fw_hooks)}|{len(consumer_hooks)}|{len(missing)}|{stale}|{missing_names}')
" 2>/dev/null || echo "0|0|0|0|parse-error")

        # T-2709 (T-2704 §5.1 — "this is the trap"): the two predicates above are
        # blind to a hook command carrying the GENERATING host's absolute checkout
        # path. Such a command contains 'fw hook' (so not non_framework), is not
        # bare-relative (so not stale), and its hook NAME matches (so missing = 0)
        # — reason never fires, no regeneration, and the consumer stays broken
        # across every `fw upgrade`. Same shared predicate as bin/fw doctor Check 6;
        # one module, two call sites (L-399: a contract shipped on one side only is
        # how this class recurs).
        local nonportable
        nonportable=$(python3 "$FRAMEWORK_ROOT/lib/hook_portability.py" "$sfile" 2>/dev/null | cut -d'|' -f2)
        [ -z "$nonportable" ] && nonportable=0
        echo "${analysis}|${nonportable}"
    }

    if [ -f "$settings_file" ]; then
        local hook_analysis
        hook_analysis=$(_t2912_hook_gap "$settings_file")
        local fw_total consumer_total missing_count stale_hooks missing_names hook_nonportable
        fw_total=$(echo "$hook_analysis" | cut -d'|' -f1)
        consumer_total=$(echo "$hook_analysis" | cut -d'|' -f2)
        missing_count=$(echo "$hook_analysis" | cut -d'|' -f3)
        stale_hooks=$(echo "$hook_analysis" | cut -d'|' -f4)
        missing_names=$(echo "$hook_analysis" | cut -d'|' -f5)
        hook_nonportable=$(echo "$hook_analysis" | cut -d'|' -f6)

        local needs_regen=false
        [ "$missing_count" -gt 0 ] && needs_regen=true
        [ "${stale_hooks:-0}" -gt 0 ] && needs_regen=true
        [ "${hook_nonportable:-0}" -gt 0 ] && needs_regen=true

        if [ "$needs_regen" = true ]; then
            local reason=""
            if [ "$missing_count" -gt 0 ]; then
                reason="missing $missing_count hook(s): $missing_names"
            fi
            if [ "${stale_hooks:-0}" -gt 0 ]; then
                [ -n "$reason" ] && reason="$reason + "
                reason="${reason}${stale_hooks} hardcoded paths"
            fi
            if [ "${hook_nonportable:-0}" -gt 0 ]; then
                [ -n "$reason" ] && reason="$reason + "
                reason="${reason}${hook_nonportable} non-portable path(s) (host checkout baked in; expected \${CLAUDE_PROJECT_DIR})"
            fi
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}WOULD UPDATE${NC}  $reason"
                changes=$((changes + 1))
            else
                # T-2912: verify the regeneration's OWN effect — never trust the
                # pre-write "reason" string as a report of outcome. Snapshot the
                # file, regenerate, then diff and re-run the SAME detector on the
                # result. Only a run that both (a) mutated the file and (b) no
                # longer trips the detector reports UPDATED; anything else is
                # FAILED or PARTIAL, and no .bak survives a run that changed
                # nothing (a backup is evidence of a mutation that didn't happen).
                local _t2912_pre
                _t2912_pre=$(mktemp)
                cp "$settings_file" "$_t2912_pre"

                # T-2093 F6 (T-2078 V1-B): subshell-scope the force=true override.
                # The old save_force / restore-on-exit pattern leaked force=true into
                # the rest of do_upgrade if generate_claude_code_config exited via
                # set -e mid-function — a stuck-on force=true crosses governance
                # (the flag is a sovereignty bypass). Subshell makes the override
                # impossible to leak; the parent's `force` stays untouched.
                ( force=true; generate_claude_code_config "$target_dir" ) >/dev/null

                local hook_analysis_after missing_count_after missing_names_after stale_after nonportable_after
                hook_analysis_after=$(_t2912_hook_gap "$settings_file")
                missing_count_after=$(echo "$hook_analysis_after" | cut -d'|' -f3)
                missing_names_after=$(echo "$hook_analysis_after" | cut -d'|' -f5)
                stale_after=$(echo "$hook_analysis_after" | cut -d'|' -f4)
                nonportable_after=$(echo "$hook_analysis_after" | cut -d'|' -f6)
                local gap_remains=false
                [ "${missing_count_after:-0}" -gt 0 ] && gap_remains=true
                [ "${stale_after:-0}" -gt 0 ] && gap_remains=true
                [ "${nonportable_after:-0}" -gt 0 ] && gap_remains=true

                if cmp -s "$_t2912_pre" "$settings_file"; then
                    # No mutation actually occurred — the generator's own
                    # template does not carry what the detector is asking for
                    # (T-2710's class: template lags the framework's real
                    # hook set). Do not write a .bak for a no-op, and do not
                    # call it OK — the detector still trips.
                    rm -f "$_t2912_pre"
                    if [ "$gap_remains" = true ]; then
                        echo -e "  ${RED}FAILED${NC}  Regeneration made no change; still $reason. lib/init.sh generate_claude_code_config's template does not know these hooks — fix the template, not the consumer."
                        failed_steps=$((failed_steps + 1))
                        if [ "$strict" = true ]; then
                            echo -e "  ${RED}STRICT ABORT${NC}  step 5 (hooks) failed to converge"
                            _strict_abort_step="5 (hooks)"
                            return 1
                        fi
                    else
                        echo -e "  ${GREEN}OK${NC}  Hooks already current (no-op)"
                    fi
                else
                    cp "$_t2912_pre" "${settings_file}.bak"
                    rm -f "$_t2912_pre"
                    changes=$((changes + 1))
                    if [ "$gap_remains" = true ]; then
                        echo -e "  ${YELLOW}PARTIAL${NC}  Hooks regenerated but gap remains: missing $missing_count_after hook(s): $missing_names_after. Backup: settings.json.bak"
                        failed_steps=$((failed_steps + 1))
                        if [ "$strict" = true ]; then
                            echo -e "  ${RED}STRICT ABORT${NC}  step 5 (hooks) partial convergence"
                            _strict_abort_step="5 (hooks)"
                            return 1
                        fi
                    else
                        echo -e "  ${GREEN}UPDATED${NC}  Hooks regenerated ($reason). Backup: settings.json.bak"
                    fi
                fi
            fi
        else
            echo -e "  ${GREEN}OK${NC}  $consumer_total/$fw_total hooks present (all types matched)"
        fi

        # T-1479: Duplicate framework hook detection.
        # If $HOME/.claude/settings.json registers framework hooks for the same
        # (event, hook_name) tuples as the project-level config, every Claude
        # Code event fires both. Symptom: dual handover commits (OBS-023, fixed
        # in-script by T-1478's time-window dedup). Surface the overlap so the
        # consumer can choose which to keep — we don't auto-remove user state.
        local user_settings="$HOME/.claude/settings.json"
        if [ -f "$user_settings" ]; then
            local dup_analysis
            dup_analysis=$(USER_FILE="$user_settings" PROJ_FILE="$settings_file" python3 -c "
import json, os

def fw_hooks(path):
    out = set()
    try:
        with open(path) as f:
            data = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError, OSError):
        return out
    for event, entries in data.get('hooks', {}).items():
        for entry in entries:
            for hook in entry.get('hooks', []):
                cmd = hook.get('command', '')
                if 'fw hook' in cmd:
                    name = cmd.split('fw hook ')[-1].strip().split()[0]
                elif '.agentic-framework' in cmd:
                    name = cmd.strip().split('/')[-1]
                else:
                    continue
                out.add((event, name))
    return out

user = fw_hooks(os.environ['USER_FILE'])
proj = fw_hooks(os.environ['PROJ_FILE'])
overlap = sorted(user & proj)
print('|'.join(f'{e}:{n}' for e, n in overlap))
" 2>/dev/null || echo "")
            if [ -n "$dup_analysis" ]; then
                local dup_count
                dup_count=$(echo "$dup_analysis" | tr '|' '\n' | wc -l)
                echo -e "  ${YELLOW}WARN${NC}  Duplicate framework hooks in $user_settings: $dup_count overlap"
                echo -e "    ${YELLOW}↳${NC}  Pairs: $(echo "$dup_analysis" | tr '|' ' ')"
                echo -e "    ${YELLOW}↳${NC}  Both fire on every Claude Code event (cause of OBS-023). Recommend removing duplicates from $user_settings."
                echo -e "    ${YELLOW}↳${NC}  To auto-remove (with backup): fw upgrade --dedupe-user-hooks"
            fi

            # T-1481: Opt-in remediation. Removes the duplicate framework hooks
            # from the user-level settings. Always backs up first; honors --dry-run.
            if [ "$dedupe_user_hooks" = true ]; then
                _do_dedupe_user_hooks "$user_settings" "$settings_file" "$dry_run"
            fi
        fi
    else
        local fw_hook_count=0
        if [ -f "$fw_settings" ]; then
            fw_hook_count=$(python3 -c "
import json
with open('$fw_settings') as f:
    data = json.load(f)
print(sum(len(v) for v in data.get('hooks', {}).values()))
" 2>/dev/null || echo "0")
        fi
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  .claude/settings.json ($fw_hook_count hooks)"
        else
            # T-2093 F6 (T-2078 V1-B): subshell-scope force=true (see sibling
            # site ~line 916). Same mutation-leak risk; same fix.
            ( force=true; generate_claude_code_config "$target_dir" )
            echo -e "  ${GREEN}CREATED${NC}  .claude/settings.json ($fw_hook_count hooks)"
        fi
    fi

    # ── 6. .mcp.json (MCP server configuration) ──
    echo -e "${YELLOW}[6/10] MCP server configuration (.mcp.json)${NC}"

    local mcp_file="$target_dir/.mcp.json"
    # Framework-recommended MCP servers
    local recommended_servers='{"context7":1,"playwright":1,"termlink":1,"fw":1}'

    if [ -f "$mcp_file" ]; then
        # Check for missing recommended servers. T-1354: servers live under
        # top-level `mcpServers` key (Claude Code schema). If an older file
        # has servers at the root, treat that as the full server map (the
        # merge path below will migrate it into mcpServers).
        local mcp_analysis
        mcp_analysis=$(RECOMMENDED="$recommended_servers" MCP_FILE="$mcp_file" python3 -c "
import json, os, sys
recommended = json.loads(os.environ['RECOMMENDED'])
try:
    with open(os.environ['MCP_FILE']) as f:
        raw = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    raw = {}
servers = raw.get('mcpServers') if isinstance(raw.get('mcpServers'), dict) else raw
if not isinstance(servers, dict):
    servers = {}
missing = [k for k in recommended if k not in servers]
print(f'{len(servers)}|{len(missing)}|{\",\".join(missing)}')
" 2>/dev/null || echo "0|0|parse-error")
        local existing_count missing_mcp_count missing_mcp_names
        existing_count=$(echo "$mcp_analysis" | cut -d'|' -f1)
        missing_mcp_count=$(echo "$mcp_analysis" | cut -d'|' -f2)
        missing_mcp_names=$(echo "$mcp_analysis" | cut -d'|' -f3)

        if [ "$missing_mcp_count" -gt 0 ] && [ "$missing_mcp_names" != "parse-error" ]; then
            changes=$((changes + 1))
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}WOULD ADD${NC}  Missing MCP servers: $missing_mcp_names"
            else
                # Merge missing servers into existing config (preserves custom servers).
                # T-1354: writes under `mcpServers` wrapper; migrates old flat schema.
                RECOMMENDED="$recommended_servers" MCP_FILE="$mcp_file" python3 -c "
import json, os
recommended_keys = json.loads(os.environ['RECOMMENDED'])
mcp_file = os.environ['MCP_FILE']
with open(mcp_file) as f:
    raw = json.load(f)
servers = raw.get('mcpServers') if isinstance(raw.get('mcpServers'), dict) else dict(raw)
defaults = {
    'context7': {'command': 'npx', 'args': ['-y', '@upstash/context7-mcp']},
    'playwright': {'command': 'npx', 'args': ['@playwright/mcp@latest', '--no-sandbox']},
    'termlink': {'command': 'termlink', 'args': ['mcp', 'serve']},
    'fw': {'command': 'python3', 'args': ['.agentic-framework/agents/mcp/framework_mcp_server.py']},
}
for key in recommended_keys:
    if key not in servers and key in defaults:
        servers[key] = defaults[key]
with open(mcp_file, 'w') as f:
    json.dump({'mcpServers': servers}, f, indent=2)
    f.write('\n')
" 2>/dev/null
                echo -e "  ${GREEN}UPDATED${NC}  Added missing MCP servers: $missing_mcp_names (preserved $existing_count existing)"
            fi
        else
            echo -e "  ${GREEN}OK${NC}  $existing_count MCP server(s) configured (all recommended present)"
        fi
    else
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  .mcp.json (context7, playwright, termlink, fw)"
        else
            cat > "$mcp_file" << 'MCPJSON'
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--no-sandbox"]
    },
    "termlink": {
      "command": "termlink",
      "args": ["mcp", "serve"]
    },
    "fw": {
      "command": "python3",
      "args": [".agentic-framework/agents/mcp/framework_mcp_server.py"]
    }
  }
}
MCPJSON
            echo -e "  ${GREEN}CREATED${NC}  .mcp.json (MCP servers: context7, playwright, termlink, fw)"
        fi
    fi

    # ── 7. .claude/commands/resume.md ──
    # T-1383 (closes G-056): compare consumer file against shared template and
    # refresh on drift. Prior behavior preserved existing file regardless of
    # template changes, so upstream fixes never propagated.
    echo -e "${YELLOW}[7/10] Claude Code commands${NC}"

    local resume_file="$target_dir/.claude/commands/resume.md"
    local resume_tmpl="$FRAMEWORK_ROOT/lib/templates/resume-md.md"

    if [ ! -f "$resume_tmpl" ]; then
        echo -e "  ${YELLOW}WARN${NC}  template missing at lib/templates/resume-md.md — skipping drift check"
    elif [ -f "$resume_file" ]; then
        if diff -q "$resume_tmpl" "$resume_file" >/dev/null 2>&1; then
            echo -e "  ${GREEN}OK${NC}  resume.md matches template"
        else
            changes=$((changes + 1))
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}WOULD UPDATE${NC}  resume.md (drift from template detected)"
            else
                cp "$resume_file" "$resume_file.bak"
                cp "$resume_tmpl" "$resume_file"
                echo -e "  ${GREEN}UPDATED${NC}  resume.md refreshed from template. Backup: resume.md.bak"
            fi
        fi
    else
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  .claude/commands/resume.md"
        else
            mkdir -p "$target_dir/.claude/commands"
            cp "$resume_tmpl" "$resume_file"
            echo -e "  ${GREEN}CREATED${NC}  .claude/commands/resume.md from template"
        fi
    fi

    # ── 7b. Doorbell+mail toolkit propagation (T-1867) ──
    # Propagates skills + supporting scripts from upstream lib/templates/
    # to project-root .claude/commands/ and scripts/. Mirrors the resume.md
    # drift-detection pattern: per-file compare, .bak backup on drift, update.
    # PL-124-safe by construction: only touches files explicitly enumerated
    # under lib/templates/{skills,scripts}/. Consumer-local files in the same
    # directories survive untouched.
    echo -e "${YELLOW}[7b/10] Doorbell+mail toolkit (T-1867)${NC}"

    local _t1867_skills_src="$FRAMEWORK_ROOT/lib/templates/skills"
    local _t1867_scripts_src="$FRAMEWORK_ROOT/lib/templates/scripts"
    local _t1867_changes=0

    if [ -d "$_t1867_skills_src" ]; then
        mkdir -p "$target_dir/.claude/commands"
        local _t1867_src _t1867_base _t1867_dst
        for _t1867_src in "$_t1867_skills_src"/*.md; do
            [ -f "$_t1867_src" ] || continue
            _t1867_base=$(basename "$_t1867_src")
            _t1867_dst="$target_dir/.claude/commands/$_t1867_base"
            if [ -f "$_t1867_dst" ] && diff -q "$_t1867_src" "$_t1867_dst" >/dev/null 2>&1; then
                :  # in sync
            elif [ -f "$_t1867_dst" ]; then
                _t1867_changes=$((_t1867_changes + 1))
                if [ "$dry_run" = true ]; then
                    echo -e "  ${CYAN}WOULD UPDATE${NC}  .claude/commands/$_t1867_base (drift)"
                else
                    cp "$_t1867_dst" "$_t1867_dst.bak"
                    cp "$_t1867_src" "$_t1867_dst"
                    echo -e "  ${GREEN}UPDATED${NC}  .claude/commands/$_t1867_base (backup: .bak)"
                fi
            else
                _t1867_changes=$((_t1867_changes + 1))
                if [ "$dry_run" = true ]; then
                    echo -e "  ${CYAN}WOULD CREATE${NC}  .claude/commands/$_t1867_base"
                else
                    cp "$_t1867_src" "$_t1867_dst"
                    echo -e "  ${GREEN}CREATED${NC}  .claude/commands/$_t1867_base"
                fi
            fi
        done
    fi

    if [ -d "$_t1867_scripts_src" ]; then
        mkdir -p "$target_dir/scripts"
        for _t1867_src in "$_t1867_scripts_src"/*.sh; do
            [ -f "$_t1867_src" ] || continue
            _t1867_base=$(basename "$_t1867_src")
            _t1867_dst="$target_dir/scripts/$_t1867_base"
            if [ -f "$_t1867_dst" ] && diff -q "$_t1867_src" "$_t1867_dst" >/dev/null 2>&1; then
                :  # in sync
            elif [ -f "$_t1867_dst" ]; then
                _t1867_changes=$((_t1867_changes + 1))
                if [ "$dry_run" = true ]; then
                    echo -e "  ${CYAN}WOULD UPDATE${NC}  scripts/$_t1867_base (drift)"
                else
                    cp "$_t1867_dst" "$_t1867_dst.bak"
                    cp "$_t1867_src" "$_t1867_dst"
                    chmod +x "$_t1867_dst"
                    echo -e "  ${GREEN}UPDATED${NC}  scripts/$_t1867_base (backup: .bak)"
                fi
            else
                _t1867_changes=$((_t1867_changes + 1))
                if [ "$dry_run" = true ]; then
                    echo -e "  ${CYAN}WOULD CREATE${NC}  scripts/$_t1867_base"
                else
                    cp "$_t1867_src" "$_t1867_dst"
                    chmod +x "$_t1867_dst"
                    echo -e "  ${GREEN}CREATED${NC}  scripts/$_t1867_base"
                fi
            fi
        done
    fi

    if [ "$_t1867_changes" -eq 0 ]; then
        echo -e "  ${GREEN}OK${NC}  doorbell+mail toolkit in sync (0 changes)"
    else
        changes=$((changes + _t1867_changes))
    fi

    # ── 8. Context subdirectories (create missing) ──
    echo -e "${YELLOW}[8/10] Context subdirectories${NC}"

    local ctx_created=0
    for ctx_subdir in audits bus episodic handovers inbox project qa scans working; do
        local ctx_path="$target_dir/.context/$ctx_subdir"
        if [ ! -d "$ctx_path" ]; then
            ctx_created=$((ctx_created + 1))
            if [ "$dry_run" != true ]; then
                mkdir -p "$ctx_path"
            fi
        fi
    done

    if [ "$ctx_created" -gt 0 ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  $ctx_created missing subdirectory(ies)"
        else
            echo -e "  ${GREEN}CREATED${NC}  $ctx_created missing subdirectory(ies)"
        fi
    else
        echo -e "  ${GREEN}OK${NC}  All context subdirectories present"
    fi

    # ── 9. Version tracking (.framework.yaml) ──
    echo -e "${YELLOW}[9/10] Version tracking${NC}"

    # T-2713: `version:` is a tag counter that resets (1.6.354 → 1.6.121 →
    # 1.6.176), so it can never answer "is this consumer behind?". The commit
    # SHA can, via git ancestry. Writer lives in lib/version-relation.sh next to
    # the reader that consumes it.

    local fw_version="${FW_VERSION:-unknown}"
    local yaml_file="$target_dir/.framework.yaml"

    if [ -f "$yaml_file" ]; then
        local current_pinned
        current_pinned=$(grep "^version:" "$yaml_file" 2>/dev/null | sed 's/^version:[[:space:]]*//' || true)

        if [ "$current_pinned" = "$fw_version" ]; then
            echo -e "  ${GREEN}OK${NC}  Version $fw_version already recorded"
            # T-2713: backfill the SHA even when the counter already matches —
            # otherwise a same-version consumer stays permanently undecidable.
            if [ "$dry_run" != true ]; then
                fw_record_version_sha "$yaml_file" "$FRAMEWORK_ROOT"
            fi
        else
            # T-1839: silent-downgrade guard. If consumer's pinned version is
            # AHEAD of the framework's version, refuse to rewrite — that would
            # be a silent downgrade. T-1828 family: framework VERSION rollback
            # leaves consumers in this state, and pre-T-1838 doctor advice
            # could send operators here unwittingly.
            if [ -n "$current_pinned" ] && [ "$current_pinned" != "$fw_version" ]; then
                # T-2713: ancestry, not string order (see lib/version-relation.sh).
                local _direction _pinned_sha
                _pinned_sha=$(grep "^version_sha:" "$yaml_file" 2>/dev/null | sed 's/^version_sha:[[:space:]]*//' || true)
                fw_version_relation "$current_pinned" "$fw_version" "$_pinned_sha" "$FRAMEWORK_ROOT" >/dev/null
                _direction="$FW_VERSION_RELATION"
                if fw_version_relation_should_refuse "$_direction" && [ "$force_downgrade" != true ]; then
                    echo -e "  ${RED}REFUSED${NC}  Consumer v$current_pinned vs framework v$fw_version: ${_direction}."
                    echo -e "          ${FW_VERSION_RELATION_REASON}."
                    echo -e "          Running fw upgrade here would downgrade the pinned version."
                    echo -e "          To proceed anyway: re-run with ${BOLD}--force-downgrade${NC}."
                    return 1
                fi
            fi
            changes=$((changes + 1))
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}WOULD UPDATE${NC}  version: ${current_pinned:-<none>} → $fw_version"
            else
                # Record upgraded_from before overwriting version
                if [ -n "$current_pinned" ]; then
                    if grep -q "^upgraded_from:" "$yaml_file" 2>/dev/null; then
                        _sed_i "s/^upgraded_from:.*/upgraded_from: $current_pinned/" "$yaml_file"
                    else
                        echo "upgraded_from: $current_pinned" >> "$yaml_file"
                    fi
                fi
                if grep -q "^version:" "$yaml_file" 2>/dev/null; then
                    _sed_i "s/^version:.*/version: $fw_version/" "$yaml_file"
                else
                    echo "version: $fw_version" >> "$yaml_file"
                fi
                # T-2713: record the framework commit alongside the counter.
                # VERSION resets, so it can never answer "does the framework
                # contain this consumer's code?". A SHA can, via git ancestry.
                fw_record_version_sha "$yaml_file" "$FRAMEWORK_ROOT"
                # Record last_upgrade timestamp
                local upgrade_ts
                upgrade_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                if grep -q "^last_upgrade:" "$yaml_file" 2>/dev/null; then
                    _sed_i "s/^last_upgrade:.*/last_upgrade: $upgrade_ts/" "$yaml_file"
                else
                    echo "last_upgrade: $upgrade_ts" >> "$yaml_file"
                fi
                echo -e "  ${GREEN}UPDATED${NC}  version: ${current_pinned:-<none>} → $fw_version"
            fi
        fi
    else
        echo -e "  ${YELLOW}SKIP${NC}  No .framework.yaml found"
        skipped=$((skipped + 1))
    fi

    # ── 8b. Upgrade audit trail (.context/audits/upgrades.yaml) ──
    if [ "$dry_run" != true ] && [ -n "${current_pinned:-}" ] && [ "${current_pinned:-}" != "$fw_version" ]; then
        local audit_file="$target_dir/.context/audits/upgrades.yaml"
        mkdir -p "$(dirname "$audit_file")"
        if [ ! -f "$audit_file" ]; then
            echo "# Upgrade audit trail (T-617)" > "$audit_file"
            echo "upgrades:" >> "$audit_file"
        fi
        local upgrade_ts
        upgrade_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        cat >> "$audit_file" <<EOF
  - timestamp: $upgrade_ts
    from_version: "${current_pinned:-unknown}"
    to_version: "$fw_version"
    framework_root: "$FRAMEWORK_ROOT"
EOF
        echo -e "  ${GREEN}LOGGED${NC}  Upgrade trail → .context/audits/upgrades.yaml"
    fi

    # ── 10. Enforcement baseline (T-884: auto-create if missing) ──
    echo -e "${YELLOW}[10/10] Enforcement baseline${NC}"
    local ef_baseline="$target_dir/.context/project/enforcement-baseline.sha256"
    local ef_settings="$target_dir/.claude/settings.json"
    if [ -f "$ef_baseline" ]; then
        echo -e "  ${GREEN}OK${NC}  Enforcement baseline exists"
    elif [ -f "$ef_settings" ]; then
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  Enforcement baseline"
            changes=$((changes + 1))
        else
            if PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/bin/fw" enforcement baseline >/dev/null 2>&1; then
                echo -e "  ${GREEN}CREATED${NC}  Enforcement baseline"
                changes=$((changes + 1))
            else
                echo -e "  ${YELLOW}SKIP${NC}  Could not create enforcement baseline"
                skipped=$((skipped + 1))
            fi
        fi
    else
        echo -e "  ${YELLOW}SKIP${NC}  No settings.json — enforcement baseline not applicable"
        skipped=$((skipped + 1))
    fi

    # T-1323: Detect stale tracked __pycache__ files inside vendored framework.
    # do_vendor now ships a .gitignore that prevents future leaks; this advisory
    # tells the consumer how to clean up files already added to their git index.
    if [ -d "$target_dir/.agentic-framework" ] && command -v git &>/dev/null; then
        # T-1824: use `wc -l` rather than `grep -c ... || echo 0`. grep -c exits 1
        # on zero matches DESPITE outputting `0`; the || echo 0 then appends a
        # second line so pyc_count becomes "0\n0" and breaks the integer test
        # below. wc -l always exits 0 — and prints 0 on empty input — so a
        # single newline-free integer is captured.
        local pyc_count
        # T-2092: trailing `|| true` is critical. `set -euo pipefail` is in
        # effect (bin/fw line 12); when no tracked pyc files exist (a clean
        # consumer — the common field state, NOT the framework dev tree
        # which has tracked .pyc files in .agentic-framework/), grep -E exits
        # 1, pipefail propagates to the pipeline, set -e then kills do_upgrade
        # silently BEFORE the "Upgrade Complete" summary prints. The consumer
        # sees all 10 steps "OK" but `fw upgrade` returns 1 with no error
        # message. T-1824 fixed the *output* shape but the *pipeline exit*
        # remained pipefail-unsafe. Found by T-2092 docker live-sim gate on
        # first run — exactly the class T-2078 F3 said was untested.
        pyc_count=$(cd "$target_dir" && git ls-files .agentic-framework/ 2>/dev/null \
            | grep -E '__pycache__|\.pyc$' | wc -l || true)
        if [ "$pyc_count" -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}WARN${NC}  Vendored framework has $pyc_count tracked __pycache__/.pyc file(s)"
            echo -e "        Cleanup (one-time): cd $target_dir && git rm -r --cached '.agentic-framework/**/__pycache__' '.agentic-framework/**/*.pyc'"
            echo -e "        Future runs will not add these files (.gitignore now ships in vendored dir)"
        fi
    fi

    # ── Summary ──
    echo ""
    if [ "$dry_run" = true ]; then
        # T-2093 F4 (dry-run parity): when any step would have failed under
        # live mode, surface a PARTIAL hint so the operator can decide
        # whether to fix the cause or re-run with --strict. Without this
        # the dry-run lies — it announces success even when a stubbed step
        # already returned non-zero.
        if [ "$failed_steps" -gt 0 ] && [ "$strict" != true ]; then
            echo -e "${YELLOW}=== Dry Run PARTIAL ===${NC}"
            echo ""
            echo "  $failed_steps step(s) reported failure during dry-run."
            echo "  Run with ${BOLD}--strict${NC} to fail-fast on the first failure under live mode."
            echo ""
        else
            echo -e "${CYAN}=== Dry Run Complete ===${NC}"
            echo ""
        fi
        echo "  $changes change(s) would be made"
        echo "  $skipped item(s) skipped (manual review needed)"
        if [ "$failed_steps" -gt 0 ]; then
            echo "  $failed_steps step(s) reported failure"
        fi
        echo ""
        echo "Run without --dry-run to apply changes."
    else
        # T-2093 F4 (T-2078 V1-B): PARTIAL footer when failures slipped through
        # under non-strict mode. Strict mode already aborted inside the failing
        # step; this footer is the advisory equivalent — the operator sees the
        # banner and can re-run with --strict to fail-fast next time.
        if [ "$failed_steps" -gt 0 ] && [ "$strict" != true ]; then
            echo -e "${YELLOW}=== Upgrade PARTIAL ===${NC}"
            echo "  $failed_steps step(s) reported failure (non-strict mode — continue)"
            echo "  Re-run with ${BOLD}--strict${NC} to fail-fast on the first per-step failure."
        elif [ "$changes" -gt 0 ]; then
            echo -e "${GREEN}=== Upgrade Complete ===${NC}"
        else
            echo -e "${GREEN}=== Already Up To Date ===${NC}"
        fi
        echo ""
        echo "  $changes change(s) applied"
        echo "  $skipped item(s) skipped"
        if [ "$failed_steps" -gt 0 ]; then
            echo "  $failed_steps step(s) failed"
        fi

        if [ "$changes" -gt 0 ]; then
            echo ""
            echo -e "${BOLD}Next steps:${NC}"
            echo "  1. Review changes: cd $target_dir && git diff"
            echo "  2. Commit: fw git commit -m 'T-012: fw upgrade — sync framework improvements'"
            echo "  3. Run: fw doctor  # Verify health"

            # T-2094 F10 (T-2078 V1-C): post-upgrade fw doctor advisory.
            _t2094_emit_doctor_advisory "$target_dir"

            # T-3113 (R7 leg L4): the replicas beside this project are still
            # running the enforcement code they forked with. Named here because
            # this is the one moment a pull-only propagation model gets to speak.
            _t3113_emit_worktree_advisory "$target_dir"
        fi
    fi
}

# T-2094 F10 (T-2078 V1-C): post-upgrade fw doctor advisory helper.
#
# Closes the verification loop within the same invocation — operator sees
# health-check output before the next action, when working memory of "what
# just upgraded" is still warm. Non-blocking by spec: doctor exit code does
# NOT affect do_upgrade exit. Per L-387 single-pipe discipline, the
# trim+indent stage uses awk (reads all input, prints first 20 lines) rather
# than `head -20 | sed` which closes stdin early and SIGPIPEs the upstream
# echo.
#
# Extracted as a helper so the bats suite can exercise it in isolation
# without spinning up a 10-step do_upgrade integration (T-2094 tests t3-t5).
#
# Args:
#   $1 — target_dir (consumer project root; passed to fw doctor as PROJECT_ROOT)
_t2094_emit_doctor_advisory() {
    local target_dir="$1"
    local _doctor_out=""
    local _doctor_rc=0
    echo ""
    echo -e "  ${BOLD}Post-upgrade health check (advisory):${NC}"

    # T-2845: run the CONSUMER's own fw, not $FRAMEWORK_ROOT's. During
    # `fw upgrade`, FRAMEWORK_ROOT is the temporary upstream clone
    # (/tmp/fw-upstream-XXXXXX/fw), so using it health-checked the upstream and
    # merely pointed it at the consumer's directory. The vendored copy the
    # operator will actually run was never exercised, and every advisory for a
    # vendored project reported `Active mode: global … vendored copy exists but
    # was not selected` — the harness describing itself, read for a long time as
    # a consumer fault. Fall back to FRAMEWORK_ROOT for consumers that genuinely
    # have no vendored copy (shared-tooling / global installs).
    #
    # BOTH the binary and FRAMEWORK_ROOT must move together. `fw` honours an
    # inherited FRAMEWORK_ROOT over its own location, and T-2099's fork-bomb fix
    # exports it scoped to the temp clone — so invoking the consumer's binary
    # while that export is still live puts the consumer's fw back into global
    # mode against the clone, and the output is byte-identical to not having
    # changed anything. Measured: same binary, clean env → "Active mode:
    # vendored"; with FRAMEWORK_ROOT inherited → "Active mode: global … vendored
    # copy exists but was not selected".
    local _doctor_fw="$FRAMEWORK_ROOT/bin/fw"
    local _doctor_fw_root="$FRAMEWORK_ROOT"
    if [ -x "$target_dir/.agentic-framework/bin/fw" ]; then
        _doctor_fw="$target_dir/.agentic-framework/bin/fw"
        _doctor_fw_root="$target_dir/.agentic-framework"
    fi
    _doctor_out=$(PROJECT_ROOT="$target_dir" FRAMEWORK_ROOT="$_doctor_fw_root" \
                  "$_doctor_fw" doctor 2>&1) || _doctor_rc=$?
    echo "$_doctor_out" | awk 'NR<=20 {print "    " $0}'
    echo ""
    if [ "$_doctor_rc" -ne 0 ]; then
        echo -e "  ${YELLOW}Advisory:${NC} doctor exited $_doctor_rc — doctor exit code does not affect upgrade success."
    else
        echo -e "  ${GREEN}Advisory:${NC} doctor PASS (exit 0)."
    fi
    return 0  # always 0 — F10 is non-blocking by spec
}

# T-3113 (R7 leg L4): post-upgrade linked-worktree staleness advisory.
#
# `fw upgrade` refreshed the main checkout. Every linked worktree beside it is
# still running whatever enforcement code it forked with — and before this
# helper existed, `grep -c worktree lib/upgrade.sh` returned 0. The command that
# exists to propagate the framework was blind to the replicas of it.
#
# This is the LOUD half of R7. Vendored propagation is pull-only: no leg reaches
# a project that never upgrades, so the moment it does upgrade is the last moment
# available to say anything at all. L3 (T-3112) put the same information in
# `fw doctor`; this puts it where the operator is already thinking about
# staleness, with "what just changed" still warm.
#
# TWO FACTS, BOTH REPORTED. Either alone misleads:
#   - commits behind the authority's HEAD — tracked content (bin/fw, lib/, hooks
#     templates). A worktree 2000 commits behind runs 2000-commit-old enforcement.
#   - hook delta vs the authority's .claude/settings.json — NOT the same question.
#     `.claude/settings.json` drifts independently of commit distance; a worktree
#     can be 0 behind and still missing four hooks (measured: t100196-vendor-fix).
# Reporting only one produces a confident green that the other would have refuted.
#
# The hook half delegates to fw_hook_parity_delta (lib/hook-parity.sh, T-3112).
# lib/upgrade.sh holds no copy of the predicate; a bats test pins that.
#
# Non-blocking by spec, same contract as _t2094_emit_doctor_advisory above:
# always returns 0. An advisory that can fail an upgrade is an advisory operators
# learn to route around.
#
# Extracted as a helper so bats can exercise it directly without driving a
# ten-step do_upgrade — same reason _t2094 was extracted.
#
# Args:
#   $1 — target_dir (the project that was just upgraded)
_t3113_emit_worktree_advisory() {
    local target_dir="$1"
    local _hp_lib="${FRAMEWORK_ROOT:-}/lib/hook-parity.sh"

    echo ""
    echo -e "  ${BOLD}Linked worktrees (advisory):${NC}"

    if [ ! -f "$_hp_lib" ] || ! command -v git >/dev/null 2>&1; then
        echo -e "  ${YELLOW}SKIP${NC}  Cannot check — hook-parity library or git unavailable."
        echo -e "         Worktree staleness is UNCHECKED, not clean."
        return 0
    fi
    # shellcheck source=/dev/null
    source "$_hp_lib"

    local authority
    if ! authority=$(fw_hook_parity_authority_root "$target_dir" 2>/dev/null) || [ -z "$authority" ]; then
        # T-3105: an unenumerable set is stated, never passed over in silence.
        # "Not a git repo" is a legitimate state — but it is one in which this
        # advisory proves nothing, and a blank section reads as proof.
        echo -e "  ${YELLOW}SKIP${NC}  $target_dir is not a git repository — worktree set unenumerable."
        return 0
    fi

    local wt_list
    if ! wt_list=$(fw_hook_parity_linked_worktrees "$target_dir" 2>/dev/null); then
        echo -e "  ${YELLOW}SKIP${NC}  git worktree list failed — worktree set unenumerable."
        return 0
    fi

    local auth_head auth_settings="$authority/.claude/settings.json"
    auth_head=$(git -C "$authority" rev-parse HEAD 2>/dev/null || echo "")

    local wt wname behind delta stale=0 count=0
    while IFS= read -r wt; do
        [ -n "$wt" ] || continue
        count=$((count + 1))
        wname=$(basename "$wt")

        behind=""
        if [ -n "$auth_head" ]; then
            behind=$(git -C "$wt" rev-list --count "HEAD..$auth_head" 2>/dev/null || echo "")
        fi
        delta=$(fw_hook_parity_delta "$auth_settings" "$wt/.claude/settings.json")

        local behind_bad=0 hooks_bad=0
        [ -n "$behind" ] && [ "$behind" -gt 0 ] 2>/dev/null && behind_bad=1
        case "$delta" in ok*) ;; *) hooks_bad=1 ;; esac

        if [ "$behind_bad" -eq 0 ] && [ "$hooks_bad" -eq 0 ]; then
            echo -e "  ${GREEN}OK${NC}  $wname (up to date, ${delta#ok } hooks)"
            continue
        fi

        stale=$((stale + 1))
        local detail=""
        [ "$behind_bad" -eq 1 ] && detail="$behind commit(s) behind"
        if [ "$hooks_bad" -eq 1 ]; then
            [ -n "$detail" ] && detail="$detail, "
            detail="$detail$delta"
        fi
        # Unknown behind-count is reported as unknown rather than omitted — the
        # absence of a number must not read as zero.
        [ -z "$behind" ] && detail="$detail (behind-count unknown)"
        echo -e "  ${YELLOW}STALE${NC}  $wname ($detail)"
        echo -e "         $wt"
    done < <(printf '%s\n' "$wt_list")

    if [ "$count" -eq 0 ]; then
        echo -e "  ${CYAN}SKIP${NC}  examined 0 linked worktree(s) — none exist"
    elif [ "$stale" -eq 0 ]; then
        echo -e "  ${GREEN}OK${NC}  examined $count linked worktree(s), none stale"
    else
        echo ""
        echo -e "  $stale of $count linked worktree(s) run older enforcement than this project."
        echo -e "  Land and remove:  fw integrate run master --push  (then fw worktree gc)"
        echo -e "  Or refresh in place: fw upgrade <worktree-path>"
    fi
    return 0  # always 0 — advisory, never blocks the upgrade
}
