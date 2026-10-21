#!/usr/bin/env bats
# T-4552 (G-122): the T-4515 doctor check counted every commented line below the
# T-4403 header as a disabled PROJECT line. On dimitri-mint-dev every one of them
# was a fragment of an OLDER framework hook (VERSION markers, framework echoes,
# _version=...), so doctor WARNed about gates that were never the consumer's.
# Framework-owned lines must not WARN; a genuine project line still must.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
load ../git_fence   # T-3610: hook installs must not walk up into a repo above the temp dir

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJ="$TEST_TMP/proj"
    HOOKS="$PROJ/.git/hooks"
    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

_doctor() {
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active" "$PROJ/.tasks/completed" "$PROJ/.tasks/templates"
    echo "# template" > "$PROJ/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    cd "$PROJ"
    run env FW_DOCTOR_SMOKE=0 PROJECT_ROOT="$PROJ" timeout 240 "$FRAMEWORK_ROOT/bin/fw" doctor --quick
}

# _kept HOOK LINE... — append the T-4403 header and LINEs commented out its way.
_kept() {
    local hook="$1"; shift
    echo "# T-4403: kept from the previous $hook by fw git install-hooks (commented out — uncomment the lines that are yours); original: $hook.pre-fw-block" >> "$HOOKS/$hook"
    local l
    for l in "$@"; do printf '# %s\n' "$l" >> "$HOOKS/$hook"; done
}

_field_fragments() {
    _kept commit-msg '# VERSION=1.17' '                echo "  Configure: fw config set inception_commit_limit N"'
    _kept pre-commit '# VERSION=1.5' '    echo "If this is a false positive: add a regex to .secret-scan-allowlist." >&2'
    _kept pre-push "_version=\$(git describe --tags --match 'v[0-9]*' 2>/dev/null) || true"
}

@test "T-4552: old framework hook fragments under the T-4403 header do not WARN" {
    _field_fragments
    _doctor
    [[ "$output" == *"Git commit-msg hook"* ]]   # the hook section ran
    [[ "$output" != *"commented out by install-hooks"* ]]
}

@test "T-4552: a genuine project line among the framework fragments still WARNs, counted alone" {
    _field_fragments
    printf '# %s\n' './scripts/project-lint.sh || exit 1' >> "$HOOKS/pre-commit"
    _doctor
    [[ "$output" == *"commented out by install-hooks (T-4403): pre-commit(1) —"* ]]
}

@test "T-4552: the catalogue holds every field fragment verbatim (trimmed)" {
    cat="$FRAMEWORK_ROOT/agents/git/lib/framework-hook-lines.txt"
    grep -qxF 'echo "  Configure: fw config set inception_commit_limit N"' "$cat"
    grep -qxF 'echo "If this is a false positive: add a regex to .secret-scan-allowlist." >&2' "$cat"
    grep -qxF "_version=\$(git describe --tags --match 'v[0-9]*' 2>/dev/null) || true" "$cat"
}
