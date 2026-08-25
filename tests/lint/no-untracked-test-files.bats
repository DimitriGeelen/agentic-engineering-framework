#!/usr/bin/env bats
# T-3074 — every test file a runner would collect must be tracked by git.
#
# Origin: T-3061 split its work between the parent session and a dispatched
# TermLink worker. The worker wrote two bats files — 8 tests pinning the
# unclosed-but-satisfied rule in both directions, 5 pinning the audit
# integration — ran them green, and never `git add`ed them. T-3061 closed. The
# files sat untracked for a day, passing on one machine and existing nowhere
# else.
#
# An untracked test is worse than an absent one. It runs locally for whoever
# wrote it, so the work reads as covered; it is in no clone, no CI, no `fw
# test`; and a single `git clean` removes it leaving no evidence it was ever
# there. Same family as no-orphaned-test-dirs.bats (T-2697) — a guard that
# reports success by not running — one level down: there, a directory no runner
# globbed; here, a file no repository holds.
#
# Dispatch makes this structural rather than careless. A worker's write lands in
# the parent's working tree, and the parent integrates by committing what it
# knows about. Anything the worker created but did not mention is invisible to a
# `git add <paths>` and survives only until someone runs `git status` and reads
# past the noise.
#
# Scope: `??` entries from git, so .gitignore is respected. A deliberately
# ignored test file is an explicit, reviewable decision recorded in a tracked
# file; an untracked one is nobody's decision at all.

TESTS_ROOT="$BATS_TEST_DIRNAME/.."
FW_ROOT="$BATS_TEST_DIRNAME/../.."

# What a runner would actually collect: bats runs *.bats, pytest collects
# test_*.py and *_test.py. Matching the runners rather than "looks like a test"
# is what keeps helpers out — tests/scripts/yaml_parse_all_tasks.py is called
# from task `## Verification` blocks and is correctly not collected, so flagging
# it would be a false positive (L-527: a guard with false positives is not a
# weaker guard, it is one that gets ignored).
_is_collectable() {
    case "$(basename "$1")" in
        *.bats|test_*.py|*_test.py) return 0 ;;
        *) return 1 ;;
    esac
}

@test "every collectable test file under tests/ is tracked by git" {
    cd "$FW_ROOT"
    local untracked=()
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        _is_collectable "$f" && untracked+=("$f")
    done < <(git status --porcelain --untracked-files=all -- tests/ 2>/dev/null \
             | sed -n 's/^?? //p')

    [ "${#untracked[@]}" -eq 0 ] || {
        echo "Test files a runner would collect, absent from git:"
        printf '  %s\n' "${untracked[@]}"
        echo ""
        echo "They pass where they were written and nowhere else. Either 'git add'"
        echo "them, or record the exclusion in .gitignore so the choice is visible."
        false
    }
}

@test "the collection predicate matches real test files (positive control)" {
    # Without this, the assertion above is satisfied by a predicate that matches
    # nothing at all — and an empty offender list looks identical whether the
    # guard is clean or blind (L-616: two empty sets are equal). Anchored on the
    # three shapes the runners collect, one known instance each.
    _is_collectable "tests/lint/no-orphaned-test-dirs.bats"
    _is_collectable "tests/unit/test_t3061_audit_wiring.py"
    if _is_collectable "tests/scripts/yaml_parse_all_tasks.py"; then false; fi
    ! _is_collectable "tests/README.md"
}

@test "the guard reads git, not the filesystem (negative control)" {
    # A version of this that walked the tree with `find` and asked "does this
    # look committed?" would be guessing. This one asks git, so the check is
    # only as good as the query — pin that the query shape returns something
    # when there IS an untracked collectable file, using a temporary one.
    cd "$FW_ROOT"
    local probe="tests/lint/.t3074-probe_test.py"
    printf 'def test_probe():\n    assert True\n' > "$probe"
    run bash -c "git status --porcelain --untracked-files=all -- tests/ | sed -n 's/^?? //p' | grep -F '$probe'"
    rm -f "$probe"
    [ "$status" -eq 0 ] || {
        echo "git status did not report a freshly-created untracked test file."
        echo "The query in the first test cannot be detecting anything either."
        false
    }
}
