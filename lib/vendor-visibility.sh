#!/usr/bin/env bash
# T-3144: after vendoring, assert the target's git can SEE what we just wrote.
#
# `fw vendor` writes executable code into a consumer tree, and `bin/fw` then
# execs several of those files by absolute path. If the consumer's `.gitignore`
# hides them, they are on disk for the developer who ran the vendor and absent
# for everyone who clones — and the failure surfaces as
#
#     python3: can't open file '<proj>/.agentic-framework/tools/corpus_explain.py'
#
# not as anything that names vendoring. Reported by 010-termlink for `tools/`.
#
# The check must run in the TARGET repo. `git check-ignore` is answered by the
# consumer's `.gitignore`, which is the thing at fault; asking our own repo the
# question returns a clean answer about the wrong tree.
#
# WHY A SNAPSHOT ALLOWLIST GOES STALE AND NOBODY NOTICES. The reported shape is
# `.agentic-framework/*` plus `!` re-includes for a fixed set of directories —
# correct on the day it was generated, and silently wrong for every include
# added afterwards. Measured against a synthetic consumer carrying that shape
# (T-3144): 62 of 2649 written files invisible, and the set is not just
# `tools/`. It is `tools/` (33), `.context/designer/projects/` (21, the maps
# that `tools/corpus_explain.py` reads), the pinned designer build, and
# `status-transitions.yaml`. Every one of those was ADDED to do_vendor's
# includes[] by a task fixing a "consumer is missing X" bug — T-2942, T-3064,
# T-2674 — and a stale allowlist re-drops each of them the moment it ships.
# That is the loop this check exists to break.

# T-3851: paths under the vendored root that are NEVER the vendor's to judge.
# Only two subtrees of .context/ and .tasks/ are in do_vendor's copy list
# (.context/designer/projects, .tasks/templates); everything else there is
# runtime state a pre-T-3671 framework wrote under FRAMEWORK_ROOT, or state a
# full framework clone carries in its own checkout. ring20 T-2226 finding 2:
# run from a full clone, `.context/sidecar/`, `scans/`, `audits/` and
# `project/` all exist in the SOURCE, so "exists in the source" counted them
# as vendored and the advice became `!.agentic-framework/.context` — which
# re-includes `.context/working/.fw-secret-key` (the T-3677 hazard).
# $1 is a path relative to the vendored root. Returns 0 = runtime, not judged.
_fw_vendor_runtime_path() {
    case "$1" in
        .context/designer/projects/*|.tasks/templates/*|.tasks/workflow/*) return 1 ;;
        .context/working/*|.context/secrets/*|.context/sidecar/*|.context/scans/*|\
        .context/audits/*|.context/project/*) return 0 ;;
        .context/*|.tasks/*|.fabric/*|.git/*|.pytest_cache/*|*/.fw-secret-key|.fw-secret-key) return 0 ;;
    esac
    return 1
}

# Returns 0 = all visible (or target is not a git repo), 1 = some invisible,
# 2 = refused (enumerated nothing — see below).
#
# T-3832: $4 (optional) is a manifest — one path per line, relative to $dest —
# of the files the vendor run actually WROTE. When given, it is the only set
# judged; everything else on disk under $dest is a leftover, counted and never
# judged. Without it the old enumeration (find under $dest, minus runtime state
# and files absent from $source) is kept for direct callers.
fw_vendor_check_visibility() {
    local dest="$1" target="$2" source="${3:-}" manifest="${4:-}"

    # A consumer that is not a git repo cannot hide anything. Not a finding.
    if ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
        return 0
    fi

    local rel="${dest#"$target"/}"

    # Enumerate what the vendor WROTE, which is not the same as what is on disk
    # under $dest. Python executing a vendored module leaves `__pycache__/`
    # beside it at RUNTIME; those files are correctly ignored, were never
    # written by any vendor run, and a check that counts them reports a
    # correctly-configured repo as broken. Measured on this repo's own
    # self-vendor before the filter: 10 of 87 "invisible" files were runtime
    # pycache. These three patterns are do_vendor's own slashless excludes —
    # the ones it applies at every depth — so the filter and the copy agree on
    # what is not framework content.
    #
    # T-3677: the same distinction applies to RUNTIME STATE that pre-T-3671
    # frameworks wrote under FRAMEWORK_ROOT (`.pytest_cache/`,
    # `.context/working/` incl. `.fw-secret-key`). Live 832 upgrade: the check
    # counted 6 such files as vendored and advised `!.agentic-framework/.context`,
    # which would have un-ignored a secret. They are never judged, never
    # advised on; they are listed as foreign so the operator can move them.
    # When the vendor source is known, a file also has to exist there to count
    # as something the vendor wrote.
    local -a files=() foreign=()
    local f
    if [ -n "$manifest" ] && [ -f "$manifest" ]; then
        # Judged set = the manifest (deduped, only files really on disk).
        while IFS= read -r f; do
            [ -n "$f" ] && [ -f "$dest/$f" ] || continue
            _fw_vendor_runtime_path "$f" && continue
            files+=("$rel/$f")
        done < <(sort -u "$manifest")
        # Leftovers = on disk but not written by this run. Counted, not judged.
        while IFS= read -r f; do
            [ -n "$f" ] && foreign+=("$f")
        # T-3982: comm must compare in the same collation its inputs were sorted in
        # (LC_ALL=C below); under a user locale it warned "not in sorted order".
        done < <(LC_ALL=C comm -23 \
            <(cd "$target" && find "$rel" -type f -not -path '*/__pycache__/*' \
                -not -name '*.pyc' -not -name '.DS_Store' 2>/dev/null | LC_ALL=C sort -u) \
            <(sed "s|^|$rel/|" "$manifest" | LC_ALL=C sort -u))
    else
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if _fw_vendor_runtime_path "${f#"$rel"/}"; then
            foreign+=("$f"); continue
        fi
        if [ -n "$source" ] && [ ! -e "$source/${f#"$rel"/}" ]; then
            foreign+=("$f"); continue
        fi
        files+=("$f")
    done < <(cd "$target" && find "$rel" -type f \
        -not -path '*/__pycache__/*' \
        -not -name '*.pyc' \
        -not -name '.DS_Store' 2>/dev/null)
    fi

    if [ "${#foreign[@]}" -gt 0 ]; then
        echo "" >&2
        echo "NOTE: ${#foreign[@]} file(s) under $rel were NOT written by the vendor (runtime leftovers," >&2
        echo "  or consumer-local files kept by .fwvendor-preserve.yaml — T-3850); not judged for git" >&2
        echo "  visibility and never advised for un-ignoring. Runtime leftovers should move out:" >&2
        printf '    %s\n' "${foreign[@]:0:10}" >&2
        if [ "${#foreign[@]}" -gt 10 ]; then
            echo "    ... and $(( ${#foreign[@]} - 10 )) more" >&2
        fi
    fi

    # T-3144 AC4. A vendor that wrote nothing and a vendor whose file list was
    # never populated produce the same "nothing ignored" answer, and the second
    # is this repo's recurring false-green shape (L-575, T-3140): a check that
    # cannot see its subject reports what a satisfied check reports. Refuse
    # instead of returning success over an empty set.
    if [ "${#files[@]}" -eq 0 ]; then
        echo "" >&2
        echo "REFUSING to report vendor visibility: enumerated 0 files under $rel" >&2
        echo "  This is not 'nothing was ignored' — it is 'nothing was looked at'." >&2
        echo "  Either the vendor wrote nothing, or the destination path is wrong." >&2
        return 2
    fi

    # TWO PASSES, and the reason is a false positive this check shipped with for
    # exactly one run. `git check-ignore -v` prints a line for every path that
    # matches ANY pattern — including a NEGATION. A path matched by
    # `!.agentic-framework/FRAMEWORK.md` is VISIBLE, and appears in -v output
    # looking identical to a hidden one. The first draft counted those lines and
    # reported FRAMEWORK.md and metrics.sh as invisible while git could see them
    # perfectly well.
    #
    # Plain `check-ignore --stdin` prints ONLY genuinely-ignored paths, so it is
    # the authority on WHICH. `-v` is then asked only about paths already known
    # to be ignored, where every match is positive by construction, and supplies
    # the WHICH-RULE. Parsing the pattern out of -v's first field to spot a
    # leading `!` would also work and is worse: the field is
    # `<source>:<line>:<pattern>` and the source is a path that may contain a
    # colon, so the split is ambiguous exactly when someone's repo is unusual.
    local ignored_paths ignored
    ignored_paths=$(cd "$target" && printf '%s\n' "${files[@]}" \
        | git check-ignore --stdin 2>/dev/null) || true

    if [ -z "$ignored_paths" ]; then
        return 0
    fi

    ignored=$(cd "$target" && printf '%s\n' "$ignored_paths" \
        | git check-ignore -v --stdin 2>/dev/null) || true

    local n_hidden
    n_hidden=$(printf '%s\n' "$ignored" | grep -c . || true)

    echo "" >&2
    echo "FAIL: $n_hidden of ${#files[@]} vendored file(s) are invisible to git in the target." >&2
    echo "  Target: $target" >&2
    echo "" >&2
    echo "  They are on disk here and will be absent from every clone. bin/fw execs" >&2
    echo "  several of them by absolute path, so the consequence is a runtime error" >&2
    echo "  that names python3 and a missing file, never vendoring." >&2
    echo "" >&2

    # `git check-ignore -v --stdin` emits "<source>:<line>:<pattern>\t<path>".
    # Group by the first path component under the vendored root so the operator
    # sees directories, not 62 individual lines, and name the rule responsible.
    # Grouped by (directory, RULE) rather than by directory alone. A single
    # representative rule per directory is how this report first lied to its own
    # author: it showed `web  55 file(s)  .gitignore:65:*.png` when 54 of those
    # 55 were hidden by a different rule entirely, because awk kept whichever
    # rule it saw first. A column that names a cause has to be true for every
    # row it is printed beside, or it is worse than no column.
    printf '%s\n' "$ignored" | awk -F'\t' -v rel="$rel" '
        {
            rule = $1; path = $2
            sub("^" rel "/", "", path)
            n = index(path, "/")
            top = (n > 0) ? substr(path, 1, n - 1) : path
            count[top SUBSEP rule]++
        }
        END {
            for (k in count) {
                split(k, a, SUBSEP)
                printf "    %-30s %4d file(s)   %s\n", a[1], count[k], a[2]
            }
        }
    ' | sort -k2 -rn >&2

    # T-3832: two vendored artefacts are easy to lose to a consumer .gitignore
    # and fail far from vendoring when they are — name them outright.
    local _pin_hidden _dist_hidden
    _pin_hidden=$(printf '%s\n' "$ignored_paths" | grep -E "^$rel/vendor/designer/aef-workflow-designer-[^/]*\.html$" || true)
    _dist_hidden=$(printf '%s\n' "$ignored_paths" | grep -cE "^$rel/lib/ts/dist/[^/]*\.js$" || true)
    if [ -n "$_pin_hidden" ] || [ "${_dist_hidden:-0}" -gt 0 ]; then
        echo "" >&2
        echo "  Named, because they fail far from here:" >&2
        if [ -n "$_pin_hidden" ]; then
            printf '    pinned designer build (T-3064): %s\n' "$_pin_hidden" | head -3 >&2
            echo "      → /designer renders an error page in every clone without it" >&2
        fi
        if [ "${_dist_hidden:-0}" -gt 0 ]; then
            echo "    lib/ts/dist/*.js: $_dist_hidden compiled file(s) invisible ($rel/lib/ts/dist/)" >&2
            echo "      → lib/runtime.sh and init validation run these; absent in every clone" >&2
        fi
    fi

    echo "" >&2
    echo "  Fix in the TARGET's .gitignore — re-include each path above:" >&2
    # T-3851: never advise re-including .context — it is the parent of
    # .context/working/ (.fw-secret-key, T-3677). Its vendored subtree gets a
    # warning that names the hazard instead of a one-line `!` that hides it.
    printf '%s\n' "$ignored" | awk -F'\t' -v rel="$rel" '
        { path = $2; sub("^" rel "/", "", path)
          n = index(path, "/"); top = (n > 0) ? substr(path, 1, n - 1) : path
          if (top == ".context") next
          if (!(top in seen)) { seen[top] = 1; printf "    !%s/%s\n", rel, top } }
    ' | sort >&2
    if printf '%s\n' "$ignored_paths" | grep -q "^$rel/\.context/"; then
        echo "" >&2
        echo "  $rel/.context/designer/projects/ (the corpus maps tools/ reads) is hidden too." >&2
        echo "  Do NOT re-include $rel/.context as a whole: it is the parent of" >&2
        echo "  .context/working/, which holds .fw-secret-key (T-3677). Re-include only the" >&2
        echo "  designer/projects subtree, and confirm afterwards that" >&2
        echo "  'git check-ignore $rel/.context/working/x' still reports it ignored." >&2
    fi
    echo "" >&2
    echo "  Override (logged Tier-2): FW_ALLOW_INVISIBLE_VENDOR=1" >&2
    echo "" >&2
    return 1
}
