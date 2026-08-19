#!/usr/bin/env bats
# T-3089: backticks inside a DOUBLE-QUOTED bash string are command substitution,
# not Markdown. Bash expands them when the string is *evaluated* — which for a
# top-level array literal means when the file is SOURCED.
#
# Origin (T-3086): lib/config.sh's FW_CONFIG_REGISTRY carried
#     "TIER0_APPROVAL_TTL|300|... for BOTH the `fw tier0 approve` and Watchtower legs"
# Someone wrote a markdown-style `command` in a description string. bin/fw sources
# config.sh on EVERY invocation, so every `fw` call executed `fw tier0 approve`,
# which sources config.sh again. Self-replicating fork bomb: ~150 procs/sec, four
# kernel OOM crashes of the host in 22 hours, 2,135 live procs at 10.52 GB in the
# final dump. The line never reached a commit — it lived in the working tree, which
# is production for anything bin/fw sources.
#
# Sibling guard: tests/lint/no-backticks-in-inline-python.bats (T-2707) covers the
# same defect shape inside double-quoted `python3 -c "..."` blocks. It did not fire
# here because this backtick was in a plain bash string, not inline python. This
# file closes that half.
#
# SEE ALSO: tests/lint/config-registry-parity.bats checks the *names and counts* of
# FW_CONFIG_REGISTRY keys across lib/config.sh, web/blueprints/config.py and CLAUDE.md.
# It does not check that a description is inert. That is this file's half. A registry
# entry can be perfectly in parity across all three surfaces and still fork-bomb the
# host on source. Check both when touching the registry.
#
# Detection strategy: SC2006 from shellcheck, not a hand-rolled scanner. A naive
# state machine desyncs on apostrophes-in-comments, heredocs and python files that
# carry a .sh extension — the first draft of this guard false-positived 25 times on
# exactly those. shellcheck actually parses the shell grammar, so comments and
# single-quoted strings are correctly ignored. Measured at authoring time: 199 bash
# files in this tree, zero SC2006 violations. The guard starts green and stays cheap.

setup() {
    FW_ROOT="${BATS_TEST_DIRNAME}/../.."
    cd "$FW_ROOT" || exit 1
}

# Tracked bash sources, by shebang. Excludes the vendored mirror and worktrees:
# .agentic-framework/ is a copy of this tree and would double-report every finding.
_bash_files() {
    local f
    for f in $(git ls-files 'lib/*.sh' 'agents/*.sh' 'agents/**/*.sh' 'bin/*' 2>/dev/null); do
        [ -f "$f" ] || continue
        case "$f" in
            *.agentic-framework/*|*/worktrees/*) continue ;;
        esac
        head -1 "$f" | grep -qE '^#!.*\b(bash|sh)$' && echo "$f"
    done
}

@test "no legacy backticks in tracked bash sources (SC2006)" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed — the registry assertion below still runs"
    fi

    run bash -c '
        set -o pipefail
        files=$(
            for f in $(git ls-files "lib/*.sh" "agents/*.sh" "agents/**/*.sh" "bin/*" 2>/dev/null); do
                [ -f "$f" ] || continue
                case "$f" in *.agentic-framework/*|*/worktrees/*) continue ;; esac
                head -1 "$f" | grep -qE "^#!.*\b(bash|sh)$" && echo "$f"
            done
        )
        [ -n "$files" ] || { echo "NO FILES MATCHED — guard would be vacuous"; exit 3; }
        echo "$files" | xargs -P 8 -n 25 shellcheck -f gcc -i SC2006 2>/dev/null | grep SC2006 || true
    '

    [ "$status" -ne 3 ] || { echo "$output"; false; }

    if [ -n "$output" ]; then
        echo "Legacy backtick command substitution found:"
        echo "$output" | while IFS= read -r l; do echo "  $l"; done
        echo ""
        echo "Inside a DOUBLE-QUOTED string these execute when the string is evaluated."
        echo "For a top-level array literal that is at SOURCE time — see T-3086, where"
        echo "one such backtick in a config description fork-bombed the host."
        echo "Fix: single quotes for command names in prose ('fw tier0 approve'),"
        echo "     \$(...) for genuine substitution."
        false
    fi
}

# The narrow, high-value half — pure python, so it runs even where shellcheck is
# absent. Registry DESCRIPTIONS are prose; nothing in them should ever expand.
# Checks backticks AND $( AND ${: all three expand on source, and the next instance
# is as likely to be a $(...) in a description as a backtick.
_scan_registry() {
    local target="${1:-lib/config.sh}"
    python3 - "$target" <<'PY'
import re, sys

path = sys.argv[1]
src = open(path, encoding="utf-8", errors="replace").read()

m = re.search(r'^FW_CONFIG_REGISTRY=\(\s*$', src, re.M)
if not m:
    print("FW_CONFIG_REGISTRY array not found in %s — guard is vacuous" % path)
    sys.exit(3)

start = m.end()
end = re.compile(r'^\)\s*$', re.M).search(src, start)
if not end:
    print("unterminated FW_CONFIG_REGISTRY array in %s" % path)
    sys.exit(3)

block = src[start:end.start()]
base = src[:start].count("\n") + 1

# Elements are double-quoted strings; skip comment lines inside the array body.
for em in re.finditer(r'"((?:[^"\\]|\\.)*)"', block):
    body = em.group(1)
    line = base + block[: em.start()].count("\n")
    line_start = block.rfind("\n", 0, em.start()) + 1
    if block[line_start:em.start()].lstrip().startswith("#"):
        continue
    for pat, label in (("`", "backtick"), ("$(", "$( substitution"), ("${", "${ expansion")):
        if pat in body:
            print(f"{path}:{line}: {label} in registry entry: {body[:80]}")
PY
}

@test "FW_CONFIG_REGISTRY entries contain no shell-expanding syntax" {
    run _scan_registry lib/config.sh
    [ "$status" -ne 3 ] || { echo "$output"; false; }

    if [ -n "$output" ]; then
        echo "Shell-expanding syntax inside FW_CONFIG_REGISTRY prose:"
        echo "$output" | while IFS= read -r l; do echo "  $l"; done
        echo ""
        echo "These entries are evaluated when bin/fw sources lib/config.sh, i.e. on"
        echo "every fw invocation. Use single quotes for command names. (T-3086)"
        false
    fi
}

@test "negative control: scanner flags a planted backtick in a registry entry" {
    tmp=$(mktemp -d)
    cat > "$tmp/planted.sh" <<'EOF'
FW_CONFIG_REGISTRY=(
    "SOME_KEY|300|Seconds, for BOTH the `fw tier0 approve` and Watchtower legs"
)
EOF
    run _scan_registry "$tmp/planted.sh"
    rm -rf "$tmp"

    echo "$output" | grep -q "backtick" || {
        echo "scanner FAILED to flag a planted backtick — it is vacuous"
        echo "output: $output"
        false
    }
}

@test "negative control: scanner does NOT flag a backtick in a comment" {
    tmp=$(mktemp -d)
    cat > "$tmp/ok.sh" <<'EOF'
FW_CONFIG_REGISTRY=(
    # a comment naming `fw tier0 approve` — bash does not expand after #
    "SOME_KEY|300|Seconds a granted approval admits the command"
)
EOF
    run _scan_registry "$tmp/ok.sh"
    rm -rf "$tmp"

    [ -z "$output" ] || {
        echo "scanner false-positived on a comment: $output"
        false
    }
}

@test "negative control: shellcheck rule catches the T-3086 shape end to end" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed"
    fi
    tmp=$(mktemp -d)
    cat > "$tmp/planted.sh" <<'EOF'
#!/usr/bin/env bash
# a comment naming `fw tier0 approve` — must NOT be flagged
REG=(
    "SOME_KEY|300|for BOTH the `fw tier0 approve` and Watchtower legs"
)
echo "${REG[0]}"
EOF
    run shellcheck -f gcc -i SC2006 "$tmp/planted.sh"
    planted_line=$(echo "$output" | grep -c "SC2006" || true)
    comment_hit=$(echo "$output" | grep -c ":2:" || true)
    rm -rf "$tmp"

    [ "$planted_line" -ge 1 ] || { echo "SC2006 missed the planted string: $output"; false; }
    [ "$comment_hit" -eq 0 ] || { echo "SC2006 false-positived on the comment: $output"; false; }
}
