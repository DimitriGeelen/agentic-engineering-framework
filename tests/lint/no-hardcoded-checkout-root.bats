#!/usr/bin/env bats
# Invariant: no test under tests/ defaults its framework/project root to the literal
# path of the main checkout. A test derives its root from its own location
# ($BATS_TEST_DIRNAME/../.. in bats, Path(__file__) in python).
#
# Origin: T-4483. 50 bats files under tests/unit read
#     FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-<main checkout path>}"
# so run from a scratch clone, a worktree or a consumer they silently tested the
# MAIN checkout. Proof (T-4380 phase 1): a syntax error planted in a scratch copy's
# lib/arc.sh left four arc test files 43/43 green until FRAMEWORK_ROOT was pointed
# at the copy. On the generating host the literal always resolves, so every run
# here is green by construction and nothing ever looks.
#
# Scope (false-positive surface): only ROOT-DEFAULTING shapes are refused —
# a ${X:-<path>} default, an assignment, a bare `cd <path>`, a `[ -d <path> ]`
# probe, os.environ.get(..., "<path>") and setenv(..., "<path>"). The same path
# used as test DATA (a hook payload, a prompt string, an address under parse) is
# not a root and is left alone. tests/**/fixtures/ is frozen task corpus and is
# skipped. The literal is assembled from pieces below so this file never matches
# itself.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# _scan <dir> -> one "path:line: text" per offending line; exit 0 always
_scan() {
    python3 - "$1" <<'PY'
import os, re, sys

root = sys.argv[1]
lit = re.escape("/opt/" + "999-")
q = r"""["']?"""
shapes = [
    re.compile(r":-" + q + lit),                                   # ${X:-<path>}
    re.compile(r"^\s*(export\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=\s*" + q + lit),  # X=<path>
    re.compile(r"(^\s*|[;&|]\s*)cd\s+" + q + lit),                    # cd <path>
    re.compile(r"\[\[?\s+-[de]\s+" + q + lit),                     # [ -d <path> ]
    re.compile(r"environ\.get\([^)]*,\s*" + q + lit),              # os.environ.get(k, <path>)
    re.compile(r"setenv\([^)]*,\s*" + q + lit),                    # monkeypatch.setenv(k, <path>)
]
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = sorted(d for d in dirnames if d != "fixtures")
    for name in sorted(filenames):
        if not name.endswith((".bats", ".sh", ".py", ".bash")):
            continue
        path = os.path.join(dirpath, name)
        try:
            lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        for i, line in enumerate(lines, 1):
            if line.lstrip().startswith("#"):
                continue
            if any(s.search(line) for s in shapes):
                print(f"{os.path.relpath(path, root)}:{i}: {line.strip()}")
PY
}

@test "no test under tests/ defaults its root to the literal checkout path" {
    run _scan "$FRAMEWORK_ROOT/tests"
    [ "$status" -eq 0 ]
    if [ -n "$output" ]; then
        echo "Root-defaulting literal checkout paths (derive from \$BATS_TEST_DIRNAME / __file__):" >&2
        echo "$output" >&2
        false
    fi
}

@test "control: every refused shape fires on a planted file" {
    d="$BATS_TEST_TMPDIR/planted"
    mkdir -p "$d"
    p="/opt/""999-Agentic-Engineering-Framework"
    {
        printf 'FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-%s}"\n' "$p"
        printf 'FW=%s/bin/fw\n' "$p"
        printf '    cd %s\n' "$p"
        printf 'elif [ -d "%s/.context" ]; then\n' "$p"
    } > "$d/planted.bats"
    {
        printf 'x = os.environ.get("PROJECT_ROOT", "%s")\n' "$p"
        printf 'monkeypatch.setenv("FRAMEWORK_ROOT", "%s")\n' "$p"
        printf 'DOCS_DIR = "%s/docs"\n' "$p"
    } > "$d/test_planted.py"
    run _scan "$d"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c .)" -eq 7 ]
}

@test "control: the same path used as test data is not refused" {
    d="$BATS_TEST_TMPDIR/data"
    mkdir -p "$d/fixtures"
    p="/opt/""999-Agentic-Engineering-Framework"
    {
        printf '    run is_bash_safe_command "cd %s && bin/fw doctor"\n' "$p"
        printf "    screen=\$'root@host:%s# '\n" "$p"
        printf '    INPUT={"file_path":"%s/test.txt"}\n' "$p"
        printf '# FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-%s}"\n' "$p"
    } > "$d/data.bats"
    printf 'FW=%s/bin/fw\n' "$p" > "$d/fixtures/frozen.sh"
    run _scan "$d"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
