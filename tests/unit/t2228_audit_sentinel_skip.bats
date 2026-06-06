#!/usr/bin/env bats
# T-2228 (T-2225 Slice 3): audit/find scanners must skip T-Test-NNN sentinel files.
#
# Verifies the `_is_test_sentinel` bash helper in agents/audit/audit.sh AND the
# `-not -name 'T-Test-*'` filters at the find/glob sites that have been patched.
# Layered with the Python sibling test_t2228_sentinel_skip.py.

load ../test_helper

setup() {
    unset PROJECT_ROOT  # T-2185 / L-456: avoid project-root leak from parent shell
    TEST_TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.context/episodic"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "audit.sh defines _is_test_sentinel helper" {
    run grep -q "^_is_test_sentinel()" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
}

@test "_is_test_sentinel matches T-Test-NNN basename" {
    # Source the helper definition (extract just the function)
    awk '/^_is_test_sentinel\(\) \{/,/^\}/' "$FRAMEWORK_ROOT/agents/audit/audit.sh" > /tmp/t2228_helper.sh
    source /tmp/t2228_helper.sh

    rc=0
    _is_test_sentinel "T-Test-001-foo.md" || rc=$?
    [ "$rc" -eq 0 ]

    rc=0
    _is_test_sentinel "/abs/path/.tasks/active/T-Test-001.md" || rc=$?
    [ "$rc" -eq 0 ]
}

@test "_is_test_sentinel rejects real T-NNNN task ids" {
    awk '/^_is_test_sentinel\(\) \{/,/^\}/' "$FRAMEWORK_ROOT/agents/audit/audit.sh" > /tmp/t2228_helper.sh
    source /tmp/t2228_helper.sh

    rc=0
    _is_test_sentinel "T-2228-some-slug.md" || rc=$?
    [ "$rc" -eq 1 ]

    rc=0
    _is_test_sentinel "/abs/path/T-9999.md" || rc=$?
    [ "$rc" -eq 1 ]
}

@test "find -not -name 'T-Test-*' filters sentinel files" {
    # Seed: a real task + a leaked sentinel
    touch "$TEST_TEMP_DIR/.tasks/active/T-2228-real.md"
    touch "$TEST_TEMP_DIR/.tasks/active/T-Test-001-leaked.md"
    touch "$TEST_TEMP_DIR/.tasks/active/T-Test-002-also-leaked.md"

    # The find pattern from lib/evolution_log.sh:105 + audit.sh:640
    count_unfiltered=$(find "$TEST_TEMP_DIR/.tasks/active" -maxdepth 1 -name 'T-*.md' -type f | wc -l)
    count_filtered=$(find "$TEST_TEMP_DIR/.tasks/active" -maxdepth 1 -name 'T-*.md' -not -name 'T-Test-*' -type f | wc -l)

    [ "$count_unfiltered" -eq 3 ]   # 3 files exist
    [ "$count_filtered" -eq 1 ]     # only T-2228-real.md survives the filter
}

@test "lib/evolution_log.sh find uses -not -name 'T-Test-*'" {
    run grep -q "T-\\*.md.*-not -name 'T-Test-\\*'" "$FRAMEWORK_ROOT/lib/evolution_log.sh"
    [ "$status" -eq 0 ]
}

@test "audit.sh frontmatter scan uses -not -name 'T-Test-*'" {
    # The find at the fm_fail_list scan (~line 640) was patched
    run grep -q "T-\\*.md.*-not -name 'T-Test-\\*'" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
}

@test "audit.sh arc-membership loop has _is_test_sentinel guard" {
    # The for tf loop at ~line 721 was patched with `_is_test_sentinel && continue`
    run grep -q "_is_test_sentinel.*continue.*T-2228" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
}

@test "audit.sh python arc-index skips T-Test- basename" {
    # Python heredoc at ~line 961 patched with `if p.name.startswith('T-Test-')`
    run grep -q "p.name.startswith.*'T-Test-'" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
}

@test "docgen scripts skip T-Test- basename in episodic glob" {
    run grep -q "T-Test-" "$FRAMEWORK_ROOT/agents/docgen/generate_article.py"
    [ "$status" -eq 0 ]

    run grep -q "T-Test-" "$FRAMEWORK_ROOT/agents/docgen/generate_component.py"
    [ "$status" -eq 0 ]
}
