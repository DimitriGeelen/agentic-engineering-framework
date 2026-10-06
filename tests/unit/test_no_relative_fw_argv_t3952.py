"""T-3952: no subprocess argv may launch fw as a cwd-relative "bin/fw".

A consumer project has no bin/fw at its root (it is .agentic-framework/bin/fw), so every call
that ran `["bin/fw", ...]` with cwd=PROJECT_ROOT crashed there: auto-promotion (T-3807), the
Watchtower arc buttons (approve/remove driver, scoped weight, arc close) and the BVP driver
forms (T-3952). fw is resolved from the framework root instead. This lint keeps it that way.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# An argv element: "bin/fw" opening a list, or alone at the start of a line followed by a
# quoted subcommand (the multi-line cmd = [ ... ] form).
ARGV = re.compile(r"""\[\s*["']bin/fw["']|^\s*["']bin/fw["']\s*,\s*["'][a-z]""")


def test_no_cwd_relative_fw_in_argv():
    hits = []
    for top in ("web", "lib", "agents"):
        for f in (ROOT / top).rglob("*.py"):
            if "__pycache__" in f.parts:
                continue
            for n, line in enumerate(f.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                if ARGV.search(line):
                    hits.append(f"{f.relative_to(ROOT)}:{n}: {line.strip()}")
    assert not hits, "cwd-relative bin/fw in argv (breaks consumers):\n" + "\n".join(hits)


def test_control_the_pattern_catches_both_forms():
    assert ARGV.search('cmd = ["bin/fw", "arc", "close"]')
    assert ARGV.search('        "bin/fw", "bvp", "driver",')
    assert not ARGV.search('edges.append(("bin/fw", "tests"))')      # a fabric path, not argv
