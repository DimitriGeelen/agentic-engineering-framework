"""T-4160 — fabric enrich missed three classes of real edge (832 field report).

832 compared committed cards against a fresh `fw fabric enrich` and found 154
real edges today's enricher does not produce. Three patterns, one test group
each, all run end-to-end through compute_forward_edges on a fixture tree laid
out the way a consumer project is (top-level `designer/`, not this repo's
`web|lib|agents|tools`):

  1. a shell suite runs checks by path through python3/node, or lists them in
     a `"path|message"` array → no depends_on;
  2. a script reads a source file by literal path (to mutate or load it)
     → no reads/read_by; `.mjs` files were not scanned at all;
  3. `import designer_console` where tests/ is put on sys.path → no edge.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "agents" / "fabric" / "lib"))

import enrich  # noqa: E402

FILES = {
    "designer/app.js": "export const x = 1;\n",
    "designer/style.css": "body {}\n",
    "tests/test_x.py": "def test_x():\n    pass\n",
    "tests/designer_console.py": "def run():\n    pass\n",
    "tools/_t100.sh": "#!/bin/bash\necho ok\n",
    "tools/teeth.mjs": "",
    "tools/cdp_check.py": "",
    "tools/suite.sh": "",
    "tools/console_user.py": "",
}


def _forward(tmp_path, overrides):
    """Write the fixture tree, card every file, return {source: set((target, type))}."""
    files = dict(FILES)
    files.update(overrides)
    cards, loc_to_id = {}, {}
    for i, (loc, text) in enumerate(sorted(files.items())):
        p = tmp_path / loc
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        cid = f"C-{i:03d}"
        cards[f"card-{cid}.yaml"] = {"id": cid, "location": loc}
        loc_to_id[loc] = cid
    id_to_loc = {v: k for k, v in loc_to_id.items()}
    fwd = enrich.compute_forward_edges(cards, loc_to_id, str(tmp_path))
    out = {}
    for card_path, edges in fwd.items():
        src = cards[card_path]["location"]
        out[src] = {(id_to_loc[e["target"]], e["type"]) for e in edges}
    return out


def _targets(out, src):
    return {t for t, _ in out.get(src, set())}


# ── Pattern 1: suite runs checks by path ────────────────────────────────────

def test_suite_runs_python_script_by_path(tmp_path):
    out = _forward(tmp_path, {"tools/suite.sh": (
        '#!/bin/bash\nROOT="$(cd "$(dirname "$0")/.." && pwd)"\n'
        'python3 "$ROOT/tests/test_x.py" || fail=1\n')})
    assert "tests/test_x.py" in _targets(out, "tools/suite.sh")


def test_suite_runs_node_script_by_path(tmp_path):
    out = _forward(tmp_path, {"tools/suite.sh": (
        '#!/bin/bash\nnode tools/teeth.mjs && echo ok\n')})
    assert "tools/teeth.mjs" in _targets(out, "tools/suite.sh")


def test_suite_bash_by_path_still_works(tmp_path):
    out = _forward(tmp_path, {"tools/suite.sh": (
        '#!/bin/bash\nbash "$ROOT/tools/_t100.sh"\n')})
    assert "tools/_t100.sh" in _targets(out, "tools/suite.sh")


def test_suite_file_message_array(tmp_path):
    out = _forward(tmp_path, {"tools/suite.sh": (
        '#!/bin/bash\nCHECKS=(\n'
        '  "tools/_t100.sh|t100 guard holds"\n'
        '  "tests/test_x.py|unit suite"\n)\n'
        'for c in "${CHECKS[@]}"; do f="${c%%|*}"; bash "$ROOT/$f"; done\n')})
    t = _targets(out, "tools/suite.sh")
    assert {"tools/_t100.sh", "tests/test_x.py"} <= t


def test_python_dash_c_is_not_a_script(tmp_path):
    out = _forward(tmp_path, {"tools/suite.sh": (
        '#!/bin/bash\npython3 -c "print(1)" tests/test_x.py\n')})
    assert "tests/test_x.py" not in _targets(out, "tools/suite.sh")


# ── Pattern 2: scripts that read a source file ──────────────────────────────

def test_mjs_reads_source_via_path_join(tmp_path):
    out = _forward(tmp_path, {"tools/teeth.mjs": (
        "import fs from 'node:fs';\nimport path from 'node:path';\n"
        "const src = fs.readFileSync(path.join(ROOT, 'designer', 'app.js'), 'utf8');\n")})
    assert ("designer/app.js", "reads") in out.get("tools/teeth.mjs", set())


def test_mjs_reads_source_via_literal(tmp_path):
    out = _forward(tmp_path, {"tools/teeth.mjs": (
        "const css = readFileSync('designer/style.css', 'utf8');\n")})
    assert ("designer/style.css", "reads") in out.get("tools/teeth.mjs", set())


def test_python_reads_source_any_top_level_dir(tmp_path):
    out = _forward(tmp_path, {"tools/cdp_check.py": (
        "from pathlib import Path\nROOT = Path(__file__).resolve().parents[1]\n"
        'SRC = (ROOT / "designer" / "app.js").read_text()\n'
        'CSS = open("designer/style.css").read()\n')})
    got = out.get("tools/cdp_check.py", set())
    assert ("designer/app.js", "reads") in got
    assert ("designer/style.css", "reads") in got


def test_reverse_pass_writes_read_by(tmp_path):
    assert enrich.REVERSE_EDGE_TYPE["reads"] == "read_by"


def test_comment_or_docstring_mention_is_not_a_read(tmp_path):
    out = _forward(tmp_path, {"tools/cdp_check.py": (
        '"""Pinned by `tests/test_x.py`."""\n'
        "# see designer/app.js for the shape\n")})
    assert _targets(out, "tools/cdp_check.py") == set()


def test_nonexistent_literal_is_not_an_edge(tmp_path):
    out = _forward(tmp_path, {"tools/teeth.mjs": (
        "const x = readFileSync('designer/missing.js');\n")})
    assert "designer/missing.js" not in _targets(out, "tools/teeth.mjs")


# ── Pattern 3: import by module name through sys.path ───────────────────────

def test_import_module_via_sys_path_insert(tmp_path):
    out = _forward(tmp_path, {"tools/console_user.py": (
        "import sys\nfrom pathlib import Path\n"
        "ROOT = Path(__file__).resolve().parents[1]\n"
        'sys.path.insert(0, str(ROOT / "tests"))\n'
        "import designer_console\n")})
    assert "tests/designer_console.py" in _targets(out, "tools/console_user.py")


def test_import_module_via_sys_path_append_os_join(tmp_path):
    out = _forward(tmp_path, {"tools/console_user.py": (
        "import os, sys\n"
        'sys.path.append(os.path.join(ROOT, "tests"))\n'
        "from designer_console import run\n")})
    assert "tests/designer_console.py" in _targets(out, "tools/console_user.py")
