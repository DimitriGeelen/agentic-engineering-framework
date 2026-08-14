#!/usr/bin/env bash
# T-2990 — root-level pollution detector.
#
# Four ImageMagick PostScript files accumulated in the repo root over three
# months ('os' 36MB, 'sys' 14MB, 'yaml,sys' 6.8MB, 'yaml' 5.9KB) without anything
# noticing. They were written by the framework's own P-011 verification gate:
# it evals each LINE of the Verification section separately, so the Python body
# of a multi-line inline-python command runs as bash, and 'import yaml,sys'
# reaches ImageMagick's screenshot tool — which writes to the repo root, the
# gate's cwd. (Quotes here are deliberately plain, not backticks: this file is
# scanned by tests/lint/no-backticks-in-inline-python.bats, and prose ABOUT an
# inline-python command trips it just as real code would.)
#
# T-2991 prevents that at the gate. This is the other half: whatever writes a
# binary into the repo root next — a different tool, a different mechanism, a
# bypass — surfaces within a day instead of within three months.
#
# WHY A CONTENT PREDICATE AND NOT A NAME LIST. The obvious detector is "warn on
# files named after Python modules". That detector is written from the instances
# that already announced themselves and is bounded by them (L-543) — it would
# have caught `os` and `sys` and missed a file named `d` or `result`. What every
# instance shares is not the name: it is a binary/PostScript payload sitting
# loose at the top of a repo whose root is otherwise text.
#
# WHY THE ROOT ONLY. Depth 1 is where the harm is (the gate cds there, and the
# root is the one directory a human reads as a table of contents) and it is also
# the only place a cheap scan stays cheap. Subdirectories legitimately hold
# binaries; the root does not.

# Files at repo root that are allowed to be non-text. Extend deliberately.
# Extensions are matched case-insensitively.
FW_ROOT_POLLUTION_ALLOWED_EXT="png|jpg|jpeg|gif|svg|ico|pdf|woff|woff2"

# fw_root_pollution_scan <project_root>
#
# Prints one `<size_bytes>\t<name>\t<type>` line per offending file. Returns 0
# when the root is clean, 1 when at least one offender was found — so callers
# can branch on the exit code without parsing.
#
# An offender is a regular file directly in <project_root> that:
#   * is not tracked by git (tracked binaries are the large-file gate's job,
#     T-1845 — this rail is for the untracked ones nothing else watches), and
#   * does not carry an allowed extension, and
#   * `file` reports as something other than text.
fw_root_pollution_scan() {
    local root="${1:-${PROJECT_ROOT:-$PWD}}"
    local found=0
    local f name type size

    [ -d "$root" ] || return 0

    for f in "$root"/*; do
        [ -f "$f" ] || continue
        name="$(basename "$f")"

        # Allowed by extension.
        if [[ "${name,,}" =~ \.(${FW_ROOT_POLLUTION_ALLOWED_EXT})$ ]]; then
            continue
        fi

        # Tracked files belong to the large-file gate, not here. Deliberately
        # checked BEFORE the `file` probe: a tracked binary is a different
        # finding with a different remedy, and reporting it twice under two
        # names makes both reports easier to dismiss.
        if git -C "$root" ls-files --error-unmatch "$name" >/dev/null 2>&1; then
            continue
        fi

        type="$(file -b "$f" 2>/dev/null)"
        [ -n "$type" ] || continue

        # ORDER MATTERS, and this is the whole subtlety of the check.
        #
        # The obvious rule is "skip anything `file` calls text". It does not
        # work, and it fails in the one direction that matters: `file` describes
        # the real offenders as "PostScript document TEXT conforming DSC level
        # 3.0". A not-text rule therefore skips exactly the class this rail was
        # built for — the first draft did, and the planted-junk tests caught it.
        #
        # So document formats are matched positively FIRST, and only then does
        # the text allowance apply. Anything added to the first list is a
        # deliberate statement that the format has no business loose at a repo
        # root, whatever `file` calls it.
        case "$type" in
            *PostScript*|*PDF*|*"image data"*|*ELF*|*Mach-O*|*archive*|\
            *compressed*|*"Composite Document"*|*"shared object"*)
                ;;  # fall through — these are findings regardless of "text"
                    # NB: do not add a bare *executable* arm here. `file` calls
                    # every script "ASCII text executable", so that arm flags
                    # mod.py and script.sh. Real binaries are named by format
                    # (ELF, Mach-O) and are already covered.
            *text*|empty|*"very short file"*)
                continue ;;
        esac

        size=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
        printf '%s\t%s\t%s\n' "$size" "$name" "$type"
        found=1
    done

    [ "$found" -eq 0 ]
}
