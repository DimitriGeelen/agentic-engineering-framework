"""T-3964: shell must not launch fw from the project root or the cwd.

A consumer has no bin/fw at its root (it is .agentic-framework/bin/fw), so a call through
`bin/fw` or `$PROJECT_ROOT/bin/fw` fails there. 010 found `fw arc rescore` failing every
member estimate that way ('Rescored 0, 21 failed'). T-3952 lints the Python side; this is
the shell side. fw is resolved from FRAMEWORK_ROOT.

A call that is guarded by a test that PROJECT_ROOT/bin/fw exists (framework-repo-only
checks in audit.sh and the git hooks) is allowed: it never runs in a consumer.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CWD_RELATIVE = re.compile(r"\$\(\s*bin/fw\s")                       # $(bin/fw ...)
PR_FALLBACK = re.compile(r"\$\{PROJECT_ROOT\}/bin/fw\}")              # ${FW_BIN:-${PROJECT_ROOT}/bin/fw}
PR_CALL = re.compile(r"""["']\$\{?PROJECT_ROOT\}?/bin/fw["']\s+[a-z]""")  # "$PROJECT_ROOT/bin/fw" verb
GUARD = re.compile(r"""-[xf]\s+["']\$\{?PROJECT_ROOT\}?/(bin/fw|FRAMEWORK\.md)""")


def _shell_files():
    for top in ("lib", "agents"):
        yield from (ROOT / top).rglob("*.sh")
    for f in (ROOT / "bin").iterdir():
        if f.is_file():
            try:
                first = f.open("rb").readline()
            except OSError:
                continue
            if first.startswith(b"#!") and b"sh" in first:
                yield f


def scan_lines(lines):
    """Return (lineno, line) for every offending line."""
    hits = []
    for n, line in enumerate(lines, 1):
        s = line.strip()
        # comments, echo/printf text, and markdown list lines in heredoc'd docs
        if s.startswith("#") or s.startswith(("echo ", "printf ")) or re.match(r"\d+\. ", s):
            continue
        if CWD_RELATIVE.search(line) or PR_FALLBACK.search(line):
            hits.append((n, s))
        elif PR_CALL.search(line):
            window = lines[max(0, n - 9):n]
            if not any(GUARD.search(w) for w in window):
                hits.append((n, s))
    return hits


def test_no_project_relative_fw_in_shell():
    hits = []
    for f in _shell_files():
        if "node_modules" in f.parts:
            continue
        lines = f.read_text(encoding="utf-8", errors="replace").splitlines()
        hits += [f"{f.relative_to(ROOT)}:{n}: {s}" for n, s in scan_lines(lines)]
    assert not hits, "project-relative fw in shell (breaks consumers):\n" + "\n".join(hits)


def test_control_the_lint_bites():
    assert scan_lines(['  if "${FW_BIN:-${PROJECT_ROOT}/bin/fw}" bvp estimate "$tid"; then'])
    assert scan_lines(['  wt_url="$(bin/fw watchtower url 2>/dev/null || true)"'])
    assert scan_lines(['  base="$("$PROJECT_ROOT/bin/fw" watchtower url)"'])
    # a guarded framework-repo-only call, a comment and an echo are fine
    assert not scan_lines(['if [ -x "$PROJECT_ROOT/bin/fw" ]; then', '  out=$("$PROJECT_ROOT/bin/fw" mcp check)'])
    assert not scan_lines(['# run $(bin/fw doctor) here'])
    assert not scan_lines(['5. Check web server: `WURL=$(bin/fw config get PORT)`'])
    assert not scan_lines(['echo "  run: $(bin/fw watchtower url)"'])
    assert not scan_lines(['  x="$("${FRAMEWORK_ROOT:-$PROJECT_ROOT}/bin/fw" watchtower url)"'])
