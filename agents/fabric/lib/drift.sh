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

    # 4. Under-populated cards (T-3430). A card that says nothing is invisible
    # to every class above: it IS registered, its file DOES exist, and its
    # absent edges cannot be stale. 792 of 1314 cards on this repo carried the
    # template TODO and no health check had an opinion about it.
    echo -e "${CYAN}Under-populated cards:${NC}"
    local under_populated=0 up_todo=0 up_unknown=0 up_noedges=0
    local _up_raw
    _up_raw=$(python3 "$LIB_DIR/underpopulated.py" "$COMPONENTS_DIR" 2>/dev/null || true)
    if [ -n "$_up_raw" ]; then
        local _up_lines
        _up_lines=$({ printf '%s\n' "$_up_raw" | grep -v '^##UP_' || true; })
        [ -n "$_up_lines" ] && printf '%s\n' "$_up_lines"
        up_todo=$(printf '%s\n' "$_up_raw" | sed -n 's/^##UP_TODO=\([0-9]*\)##$/\1/p')
        up_unknown=$(printf '%s\n' "$_up_raw" | sed -n 's/^##UP_UNKNOWN=\([0-9]*\)##$/\1/p')
        up_noedges=$(printf '%s\n' "$_up_raw" | sed -n 's/^##UP_NOEDGES=\([0-9]*\)##$/\1/p')
        under_populated=$(printf '%s\n' "$_up_raw" | sed -n 's/^##UP_TOTAL=\([0-9]*\)##$/\1/p')
    fi
    : "${up_todo:=0}" "${up_unknown:=0}" "${up_noedges:=0}" "${under_populated:=0}"
    if [ "$under_populated" -eq 0 ]; then
        echo "  (none)"
    else
        echo "  TODO purpose: $up_todo, unknown subsystem: $up_unknown, no edges: $up_noedges"
        echo "  Fix: bin/fw fabric enrich --describe-only"
    fi

    # Section 5 — watch-set coverage (cards vs watch set).
    #
    # Section 1 computes: unregistered = expand_patterns(watch-patterns.yaml) - card_locations,
    # i.e. "is there a watched file with no card". Every term on the right is bounded by the
    # watch set, so the check can only ever produce a finding about a file the watch set already
    # reaches. Nothing asked the converse — whether the watch set still reaches everywhere the
    # fabric ALREADY HOLDS CARDS. When it does not, `unregistered: 0` is not evidence of a
    # registered tree; it is evidence of a narrow glob, and the two are indistinguishable.
    #
    # Measured in a consumer project on 2026-09-25: 76 of 724 on-disk card locations (10.5%) lay
    # outside the watch set across 39 directories. Worked example — a `src/config/` holding three
    # files, two carded (so the project already decided the directory is in-fabric) and the third,
    # with 38 importers, uncarded. No pattern covered that directory, so section 1 could never
    # flag it and reported 0.
    #
    # Deliberately NOT a policy check: it does not decide which files deserve cards. It reports
    # only where the fabric's own cards prove a directory is in scope while the watch set
    # disagrees. Severity is informational on purpose — exit status is untouched.
    echo ""

    # 5. Divergent cards — card vs source. Section 3 walks the edges a card
    # DECLARES and asks whether the targets still resolve. Nothing above walks
    # the converse: whether the source imports something the card never
    # mentions. So a card can name one edge out of ten and every check above
    # agrees it is fine, because each one only ever audits what the map already
    # says. Section 4 catches the degenerate zero-edge case; it has no opinion
    # about three declared edges against ten real imports.
    #
    # Detection is delegated to enrich.py --report-divergence, which is
    # read-only and shares detect_raw_edges() with the enricher's write path.
    # Reusing the enricher instead of writing a second detector here is the
    # point: two detectors would be free to disagree, and a drift report that
    # disagrees with the enricher sends readers to add edges the enricher then
    # declines to write.
    echo -e "${CYAN}Divergent cards (card vs source):${NC}"
    local divergent=0 _div_raw _div_rc=0 _div_edges=0 _div_extra=0 _div_unres=0
    # `|| _div_rc=$?` for two distinct reasons:
    # (1) under the inherited `set -e`, a failing command substitution inside an
    #     assignment aborts the function — drift would die mid-section having
    #     printed this header and nothing else, with the summary never reached.
    # (2) without the rc, a detector that CANNOT RUN is indistinguishable from a
    #     detector that found nothing. "divergent: 0" on a broken reader is
    #     precisely the failure this section exists to abolish, so it must not be
    #     reachable from here — hence UNKNOWN below, never 0.
    _div_raw=$(PROJECT_ROOT="$PROJECT_ROOT" python3 "$LIB_DIR/enrich.py" \
        --report-divergence 2>/dev/null) || _div_rc=$?
    if [ "$_div_rc" -ne 0 ] || ! grep -q '^##DIVERGENT_CARDS=' <<<"$_div_raw"; then
        echo "  ? UNKNOWN — the divergence detector did not run (enrich.py" \
             "--report-divergence exited $_div_rc). This is NOT 'no divergence'."
        divergent="UNKNOWN"
    else
        divergent=$(sed -n 's/^##DIVERGENT_CARDS=\([0-9]*\)##$/\1/p' <<<"$_div_raw")
        _div_edges=$(sed -n 's/^##DIVERGENT_EDGES=\([0-9]*\)##$/\1/p' <<<"$_div_raw")
        _div_extra=$(sed -n 's/^##DIVERGENT_EXTRA=\([0-9]*\)##$/\1/p' <<<"$_div_raw")
        _div_unres=$(sed -n 's/^##DIVERGENT_UNRESOLVED_ACTIONABLE=\([0-9]*\)##$/\1/p' <<<"$_div_raw")
        : "${divergent:=0}" "${_div_edges:=0}" "${_div_extra:=0}" "${_div_unres:=0}"
        # Cap the listing like section 4 does: the counts are always exact, only
        # the enumeration is abridged, and it says so.
        local _shown=0
        while IFS=$'\t' read -r _tag _loc _missing; do
            [ "$_tag" = "DIVERGENT" ] || continue
            if [ "$_shown" -lt 10 ]; then
                echo "  ! $_loc → undeclared: $_missing"
                _shown=$((_shown + 1))
            fi
        done <<<"$_div_raw"
        if [ "$divergent" -gt "$_shown" ]; then
            echo "  … and $((divergent - _shown)) more"
        fi
        if [ "$divergent" -eq 0 ]; then
            echo "  (none)"
        else
            echo "  $divergent card(s), $_div_edges undeclared edge(s)"
            echo "  Fix: bin/fw fabric enrich"
        fi
        if [ "$_div_extra" -gt 0 ] || [ "$_div_unres" -gt 0 ]; then
            echo "  (informational: $_div_extra declared edge(s) the detectors" \
                 "cannot see; $_div_unres detected import(s) whose target is a" \
                 "real file with no card)"
        fi
    fi

    echo ""
    echo -e "${CYAN}Watch-set coverage (cards vs watch set):${NC}"
    local unwatched=0 _wc_raw _wc_rc=0 _wc_dirs=0
    # `|| _wc_rc=$?` because under `set -e` a failing command substitution aborts the function,
    # and a detector that cannot run must never be indistinguishable from one that found nothing.
    _wc_raw=$(python3 "$LIB_DIR/watchset_coverage.py" "$watch_file" "$PROJECT_ROOT" \
        "$COMPONENTS_DIR" 2>/dev/null) || _wc_rc=$?
    if [ "$_wc_rc" -ne 0 ] || ! grep -q '^##UNWATCHED_LOCATIONS=' <<< "$_wc_raw"; then
        echo "  ? UNKNOWN — the coverage reader did not run (watchset_coverage.py exited" \
             "$_wc_rc). This is NOT 'fully covered'."
        unwatched="UNKNOWN"
    else
        unwatched=$(sed -n 's/^##UNWATCHED_LOCATIONS=\([0-9]*\)##$/\1/p' <<< "$_wc_raw")
        _wc_dirs=$(sed -n 's/^##UNWATCHED_DIRS=\([0-9]*\)##$/\1/p' <<< "$_wc_raw")
        : "${unwatched:=0}" "${_wc_dirs:=0}"
        local _wc_shown=0
        while IFS= read -r _wc_line; do
            case "$_wc_line" in
                '  ! '*) ;;
                *) continue ;;
            esac
            if [ "$_wc_shown" -lt 25 ]; then
                echo "$_wc_line"
                _wc_shown=$((_wc_shown + 1))
            fi
        done <<< "$_wc_raw"
        if [ "$_wc_dirs" -gt "$_wc_shown" ]; then
            echo "  … $((_wc_dirs - _wc_shown)) more director(ies) (full list:" \
                 "python3 $LIB_DIR/watchset_coverage.py $watch_file $PROJECT_ROOT $COMPONENTS_DIR)"
        fi
        if [ "$unwatched" -eq 0 ]; then
            echo "  (none)"
        else
            echo "  → $unwatched card location(s) in $_wc_dirs director(ies) the watch set" \
                 "never scans; section 1 cannot report on anything there."
        fi
    fi

    echo ""
    echo -e "${BOLD}Summary:${NC} unregistered: $unregistered, orphaned: $orphaned, stale: $stale, under-populated: $under_populated, divergent: $divergent, unwatched: $unwatched"

    if [ "$summary_flag" = "--summary" ]; then
        echo "unregistered: $unregistered"
        echo "orphaned: $orphaned"
        echo "stale: $stale"
        echo "under-populated: $under_populated"
        echo "under-populated-todo-purpose: $up_todo"
        echo "under-populated-unknown-subsystem: $up_unknown"
        echo "under-populated-no-edges: $up_noedges"
        echo "divergent: $divergent"
        echo "divergent-edges: $_div_edges"
        echo "unwatched: $unwatched"
        echo "unwatched_dirs: $_wc_dirs"
    fi

    # Unchanged on purpose. Every section above is advisory and do_drift has
    # always returned 0; a newly-added class must not be the thing that turns a
    # consumer's pipeline red on upgrade. UNKNOWN is reported in the output and
    # in the --summary keys, never in the exit status.
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
