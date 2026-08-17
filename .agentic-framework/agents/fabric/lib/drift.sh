#!/bin/bash
# Fabric Agent - drift detection commands
# Implements: fw fabric drift, fw fabric validate

do_drift() {
    ensure_fabric_dirs

    local watch_file="$FABRIC_DIR/watch-patterns.yaml"
    local summary_flag="${1:-}"

    echo -e "${BOLD}Fabric Drift Report${NC}"
    echo ""

    # 1. Check for unregistered files
    local unregistered=0
    local orphaned=0
    local stale=0

    if [ -f "$watch_file" ]; then
        # T-1842: delegate pattern expansion to expand_patterns.py — single
        # source of truth for glob + exclude. Was previously a parallel copy
        # of do_scan's reader and dropped exclude: identically (Penelope
        # T-1458, 22-day undetected silent-junk class).
        local registered
        registered=$(grep "^location:" "$COMPONENTS_DIR"/*.yaml 2>/dev/null | sed 's/.*location: //' | sort -u)

        echo -e "${CYAN}Unregistered components:${NC}"
        while IFS= read -r rel_path; do
            [ -z "$rel_path" ] && continue
            # T-2518: was `echo "$registered" | grep -qx "$rel_path"`. Under the
            # inherited `set -euo pipefail`, when grep -q short-circuits on an
            # early match it closes the pipe and `echo` takes SIGPIPE (141);
            # pipefail then makes the pipeline exit 141, so `! 141` → true and a
            # genuinely-registered file is falsely flagged. The race is timing-
            # dependent (files whose location sorts early are hit more often),
            # which is why drift reported a different random subset of carded
            # files each run (OBS-092). Herestring has no producer process to
            # receive SIGPIPE; -F makes the path a fixed string (dots in paths
            # are no longer regex). Same L-387/L-402 class.
            if ! grep -qxF "$rel_path" <<<"$registered" 2>/dev/null; then
                echo "  ! $rel_path"
                unregistered=$((unregistered + 1))
            fi
        done < <(python3 "$LIB_DIR/expand_patterns.py" "$watch_file" "$PROJECT_ROOT" 2>/dev/null)
        [ "$unregistered" -eq 0 ] && echo "  (none)"
    fi

    echo ""

    # 2. Check for orphaned cards (file referenced doesn't exist)
    echo -e "${CYAN}Orphaned cards:${NC}"
    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        local loc
        loc=$({ grep "^location:" "$card" 2>/dev/null || true; } | head -1 | sed 's/^location: //')
        # T-3049: a URL location is not a path, and "does this file exist" has no
        # answer for it — so decline the question instead of answering no. Cards
        # for hosted services (saas-account cards in consumer projects) carry
        # https:// locations and were flagged (file missing) permanently.
        # Neither existing escape catches it: the T-1673 branch below tests only
        # for a leading /, and git check-ignore on a URL string returns
        # not-ignored, so T-2519's exemption passes it through to the warning.
        # Requires the full :// separator — a path containing a bare colon, or a
        # malformed http:/single-slash, is still a path and still checked.
        case "$loc" in
            [a-zA-Z]*://*) continue ;;
        esac
        # T-1673: handle absolute paths (cross-repo cards from T-1652) — don't
        # join with PROJECT_ROOT when the location is already absolute.
        local resolved
        if [ -n "$loc" ] && [ "${loc:0:1}" = "/" ]; then
            resolved="$loc"
        else
            resolved="$PROJECT_ROOT/$loc"
        fi
        if [ -n "$loc" ] && [ ! -f "$resolved" ]; then
            # T-2519: a missing location that is gitignored is a runtime/generated
            # data artifact (e.g. F-004 budget-gate-counter → .budget-gate-counter,
            # created lazily by the budget-gate hook, gitignored, absent between
            # sessions / after a .context/working/ clean). Its transient absence is
            # expected state, not real drift — the same class the stale-edges check
            # already exempts (T-2427/G-070, section 3). A genuinely-deleted
            # *tracked* source file is NOT gitignored, so it still flags. git
            # check-ignore only runs on the rare missing-file branch → no scan
            # slowdown. Exit codes: 0 = ignored (skip), 1 = not ignored (flag),
            # 128 = no git repo / path outside repo (treated as not-ignored →
            # flag, preserving pre-fix behavior — no regression).
            if git -C "$PROJECT_ROOT" check-ignore --quiet -- "$loc" 2>/dev/null; then
                continue
            fi
            local name
            name=$({ grep "^name:" "$card" 2>/dev/null || true; } | head -1 | sed 's/^name: //')
            echo "  ! $name → $loc (file missing)"
            orphaned=$((orphaned + 1))
        fi
    done
    [ "$orphaned" -eq 0 ] && echo "  (none)"

    echo ""

    # 3. Check for stale edges (depends_on targets that don't resolve)
    # T-1674: single python3 pass instead of 2 spawns × N cards (was ~11min on
    # 508 cards). Stdout = unresolved lines for the operator. The count comes
    # back via a final ##STALE_COUNT=N## sentinel which we strip before
    # printing. Output lines preserved byte-for-byte vs the prior impl.
    # T-2427/G-070: target-exists-on-disk → silent (data-artifact dep), only
    # missing-on-disk → stale. Also treats system binaries (no /, no ., found
    # in $PATH) as resolved. Distinguishes real drift from runtime-data noise.
    echo -e "${CYAN}Stale edges:${NC}"
    local _stale_raw _stale_count=0
    _stale_raw=$(python3 - "$COMPONENTS_DIR" "$PROJECT_ROOT" <<'PYEOF' 2>/dev/null
import glob, os, shutil, sys, yaml

components_dir = sys.argv[1]
project_root = sys.argv[2]
SKIP = {'fw-cli', 'cron-audit', 'transcript',
        'check-active-task', 'check-tier0', 'error-watchdog'}

cards = []
known = set()
for cp in sorted(glob.glob(f"{components_dir}/*.yaml")):
    try:
        with open(cp) as cf:
            cd = yaml.safe_load(cf)
    except Exception:
        continue
    if not cd:
        continue
    cards.append(cd)
    known.add(cd.get('id', ''))
    known.add(cd.get('name', ''))
    known.add(cd.get('location', ''))

def _resolves_on_disk(target, root):
    """T-2427/G-070: True if target points at a real on-disk artifact.

    Data-artifact dependencies (logs, ledgers, runtime files, dirs that
    receive output) legitimately have no fabric card but reflect real
    runtime relationships. Only missing-from-disk targets are real drift.
    """
    if not target:
        return False
    # Absolute path → check verbatim
    if target.startswith('/'):
        return os.path.exists(target)
    # Relative path with slash → join against PROJECT_ROOT
    if '/' in target:
        return os.path.exists(os.path.join(root, target))
    # Bare name with no slash + no extension → check $PATH (system binary)
    # e.g. `gh`, `jq`, `dotnet`. Bare names WITH extension also try project-relative first.
    if '.' not in target and shutil.which(target):
        return True
    # Bare name (with or without extension) → also check project-relative
    return os.path.exists(os.path.join(root, target))

# T-2427/G-070: edge types whose semantics make a missing target NOT drift.
# `writes*` declares the script creates the target lazily on first invocation;
# the absence-from-disk is expected pre-bootstrap state, not real drift.
WRITE_TYPES = {'writes', 'writes_data', 'writes_runtime'}

count = 0
for cd in cards:
    name = cd.get('name', '')
    for dep in cd.get('depends_on', []) or []:
        if not isinstance(dep, dict):
            continue
        target = dep.get('target', '')
        edge_type = dep.get('type', '')
        if not target or target in known or target.startswith('all ') or target in SKIP:
            continue
        # T-2427/G-070: skip if target resolves to a real on-disk artifact
        if _resolves_on_disk(target, project_root):
            continue
        # T-2427/G-070: skip write-targets — script creates them, missing is expected
        if edge_type in WRITE_TYPES:
            continue
        print(f"  ! {name} → {target} (unresolved)")
        count += 1
print(f"##STALE_COUNT={count}##")
PYEOF
    )
    if [ -n "$_stale_raw" ]; then
        # Last line is the sentinel; everything before is operator output.
        local _stale_lines
        _stale_lines=$(printf '%s\n' "$_stale_raw" | sed '$d')
        _stale_count=$(printf '%s\n' "$_stale_raw" | tail -1 | sed -n 's/^##STALE_COUNT=\([0-9]*\)##$/\1/p')
        : "${_stale_count:=0}"
        if [ -n "$_stale_lines" ]; then
            printf '%s\n' "$_stale_lines"
        fi
    fi
    stale=$((stale + _stale_count))
    [ "$stale" -eq 0 ] && echo "  (none)"

    echo ""
    echo -e "${BOLD}Summary:${NC} unregistered: $unregistered, orphaned: $orphaned, stale: $stale"

    if [ "$summary_flag" = "--summary" ]; then
        echo "unregistered: $unregistered"
        echo "orphaned: $orphaned"
        echo "stale: $stale"
    fi

    return 0
}

do_validate() {
    ensure_fabric_dirs

    local component="${1:-}"
    if [ -z "$component" ]; then
        echo "Validating all components..."
        for card in "$COMPONENTS_DIR"/*.yaml; do
            [ -f "$card" ] || continue
            local name
            name=$({ grep "^name:" "$card" 2>/dev/null || true; } | head -1 | sed 's/^name: //')
            echo -e "${CYAN}$name${NC}: checking..."
            # TODO: deep validation per card
        done
    else
        echo "Validating: $component"
        # TODO: deep validation for specific component
    fi
    echo -e "${YELLOW}Deep validation not yet implemented — use 'fw fabric drift' for basic checks${NC}"
    return 0
}
