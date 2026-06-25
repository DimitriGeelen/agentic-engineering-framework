#!/usr/bin/env bats
# T-2498: every runnable bin/*.sh script (one with a #! shebang) must be tracked
# executable (git mode 100755). A script tracked 100644 fails with "Permission
# denied" on any fresh checkout that lacks a stray local exec bit — the OBS-087
# class (fw resolver/outcome verbs shipped non-exec; here it was
# bin/integrate-go-live.sh, caught only when the operator ran the documented
# go-live command). This guard catches the next sibling at source, not in the
# field.

load ../test_helper

@test "t2498: all bin/*.sh shebang scripts are tracked executable (100755)" {
    cd "$FRAMEWORK_ROOT"
    local offenders=""
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        # Only files with a #! shebang are meant to be executed directly.
        head -1 "$f" | grep -q '^#!' || continue
        local mode
        mode="$(git ls-files -s "$f" | awk '{print $1}')"
        if [ "$mode" != "100755" ]; then
            offenders="${offenders}${f} (mode ${mode})\n"
        fi
    done < <(git ls-files 'bin/*.sh')

    if [ -n "$offenders" ]; then
        printf 'Non-executable bin scripts (OBS-087 class):\n%b' "$offenders" >&2
        false
    fi
}
