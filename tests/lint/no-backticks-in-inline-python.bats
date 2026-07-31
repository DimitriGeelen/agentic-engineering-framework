#!/usr/bin/env bats
# T-2707: backticks inside a double-quoted `python3 -c "..."` block are COMMAND
# SUBSTITUTION performed by bash before python ever sees the source.
#
# The defect shape is prose: someone writes a markdown-style `command` inside an
# explanatory comment that happens to live inside the python string. Bash runs it,
# splices its STDOUT into the python source, and if that output is multi-line the
# second line stops being a comment and becomes executable python -> SyntaxError ->
# the whole block dies. In a PreToolUse hook that means the gate fails open.
#
# Origin: T-2702 shipped a comment reading "PRINTS `fw context focus T-XXX` as the
# remedy" into agents/context/budget-gate.sh. Every hook invocation then shelled out
# to `fw context focus` (and `context init`, `context focus` -> command not found).
# When focus WAS set, `fw context focus` printed two lines, the second landed as bare
# python, and budget-gate's main block raised SyntaxError. The budget gate was
# silently disarmed for the life of that commit.
#
# Scope deliberately narrow (L-527: a false-positive guard gets ignored):
#   - backticks ONLY. `$(...)` and `$VAR` inside these blocks are overwhelmingly
#     DELIBERATE interpolation of shell values into python and must not be flagged.
#   - only inside double-quoted python3 -c blocks. Single-quoted (python3 -c '...')
#     and heredocs are not expanded by bash and are safe.
#   - shell-level comments are NOT scanned: bash does not expand after # in shell
#     context, so only text inside the quoted string can bite.

setup() {
    FW_ROOT="${BATS_TEST_DIRNAME}/../.."
    cd "$FW_ROOT" || exit 1
}

# Emits "file:line:snippet" for each backtick pair inside a double-quoted
# `python3 -c "` block. Bounded by the closing quote at start-of-line, which is the
# convention every such block in this tree uses.
_scan() {
    python3 - "$@" <<'PY'
import re, sys, os, glob

roots = []
for pat in ("agents/**/*.sh", "bin/*.sh", "lib/**/*.sh", "bin/fw"):
    roots += [p for p in glob.glob(pat, recursive=True) if os.path.isfile(p)]

OPEN = re.compile(r'python3\s+-c\s+"')

def blocks(src):
    """Yield (start,end) spans of double-quoted python3 -c bodies.

    Bounding invariant: inside `python3 -c "..."` a bare `"` cannot appear in the
    python source — it would terminate the bash string. So the FIRST unescaped `"`
    after the opening IS the terminator. Character-level, not line-level: a
    line-based heuristic silently fails to close and then reports every later
    SHELL comment in the file (bash does not expand backticks in shell comments),
    which is how the first draft of this guard produced false positives across
    bin/fw.
    """
    pos = 0
    while True:
        m = OPEN.search(src, pos)
        if not m:
            return
        i = m.end()
        while i < len(src):
            if src[i] == "\\":
                i += 2
                continue
            if src[i] == '"':
                break
            i += 1
        yield (m.end(), i)
        pos = i + 1

for f in sorted(set(roots)):
    if ".agentic-framework" in f:
        continue
    try:
        src = open(f, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for start, end in blocks(src):
        body = src[start:end]
        # Escaped backticks (\`) are LITERAL inside a double-quoted bash string and
        # are not substituted — flagging them is a false positive. Blank out every
        # backslash-escape pair, preserving length so line numbers stay accurate.
        body = re.sub(r"\\(.)", "\x00\x00", body, flags=re.S)
        for m in re.finditer(r'`([^`\n]+)`', body):
            line = src[: start + m.start()].count("\n") + 1
            print(f"{f}:{line}:{m.group(1)}")
PY
}

@test "no backticks inside double-quoted python3 -c blocks (bash would run them)" {
    run _scan
    [ "$status" -eq 0 ]

    if [ -n "$output" ]; then
        echo "Backtick command-substitution inside inline python (bash expands these):"
        echo "$output" | while IFS= read -r l; do echo "  $l"; done
        echo ""
        echo "Bash runs each backticked string and splices its STDOUT into the python"
        echo "source. Multi-line output turns the next line into bare python -> SyntaxError"
        echo "-> the block dies. Fix: use plain quotes ('like this') in these comments."
        false
    fi
}

@test "negative control: the scanner detects a planted backtick" {
    tmp=$(mktemp -d)
    mkdir -p "$tmp/agents/x"
    cat > "$tmp/agents/x/planted.sh" <<'EOF'
RESULT=$(python3 -c "
# a comment naming `fw context focus T-XXX` as the remedy
print('hi')
")
EOF
    cd "$tmp" || return 1
    run _scan
    cd "$FW_ROOT" || return 1
    rm -rf "$tmp"

    # must find the planted one — proves the scanner is not vacuously green
    echo "$output" | grep -q "fw context focus T-XXX" || {
        echo "scanner FAILED to flag a planted backtick — it is vacuous"
        echo "output: $output"
        false
    }
}

@test "negative control: scanner does NOT flag deliberate \$() interpolation" {
    tmp=$(mktemp -d)
    mkdir -p "$tmp/agents/x"
    cat > "$tmp/agents/x/ok.sh" <<'EOF'
RESULT=$(python3 -c "
status_file = '$STATUS_FILE'
n = $(wc -l < /etc/hosts)
print(status_file, n)
")
EOF
    cd "$tmp" || return 1
    run _scan
    cd "$FW_ROOT" || return 1
    rm -rf "$tmp"

    [ -z "$output" ] || {
        echo "scanner false-positived on deliberate interpolation: $output"
        false
    }
}
