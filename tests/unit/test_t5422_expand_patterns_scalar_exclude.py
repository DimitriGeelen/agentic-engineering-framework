"""T-5422 (050 item 4): a watch-patterns exclude written as one string is honoured.

expand_patterns.py did `list(exclude)`. For `exclude: "vendor/*"` that is
['v','e','n',…]: no path matches a one-character pattern, so the exclude was ignored
without a word and excluded files showed up as fabric drift.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPANDER = ROOT / "agents/fabric/lib/expand_patterns.py"


def _project(tmp_path, watch: str):
    for rel in ("lib/a.py", "lib/vendor/b.py", "lib/c.py"):
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("x\n")
    (tmp_path / ".fabric").mkdir()
    (tmp_path / ".fabric/watch-patterns.yaml").write_text(watch)
    return tmp_path


def _expand(root):
    r = subprocess.run([sys.executable, str(EXPANDER), str(root / ".fabric/watch-patterns.yaml"), str(root)],
                       capture_output=True, text=True)
    return sorted(r.stdout.split()), r.stderr, r.returncode


def test_per_pattern_string_exclude_equals_list_form(tmp_path):
    s = _project(tmp_path / "s", 'patterns:\n  - glob: "lib/**/*.py"\n    exclude: "lib/vendor/*"\n')
    l = _project(tmp_path / "l", 'patterns:\n  - glob: "lib/**/*.py"\n    exclude: ["lib/vendor/*"]\n')
    assert _expand(s)[0] == _expand(l)[0] == ["lib/a.py", "lib/c.py"]


def test_top_level_string_exclude(tmp_path):
    p = _project(tmp_path, 'exclude: "lib/vendor/*"\npatterns:\n  - glob: "lib/**/*.py"\n')
    assert _expand(p)[0] == ["lib/a.py", "lib/c.py"]


def test_other_types_are_reported_not_silently_ignored(tmp_path):
    p = _project(tmp_path, 'patterns:\n  - glob: "lib/**/*.py"\n    exclude: {bad: 1}\n')
    out, err, rc = _expand(p)
    assert rc == 0 and "lib/vendor/b.py" in out
    assert "not a string or list" in err


def test_t5433_leading_doublestar_also_matches_the_root(tmp_path):
    """050's exclude list: '**/node_modules/**' must drop a root-level node_modules/ too."""
    for rel in ("app.js", "node_modules/top/e.js", "src/node_modules/pkg/c.js", "src/dist/b.js"):
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("x\n")
    (tmp_path / ".fabric").mkdir()
    (tmp_path / ".fabric/watch-patterns.yaml").write_text(
        'exclude:\n  - "src/dist/**"\n  - "**/node_modules/**"\npatterns:\n  - glob: "**/*.js"\n')
    assert _expand(tmp_path)[0] == ["app.js"]
