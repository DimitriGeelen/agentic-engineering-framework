"""T-4933: a harness review seat runs in a `git archive` export without `.context/`, so the
screenshots its brief cites were missing and the opencode seat ended with no verdict on every
render judge. The cited evidence files, and only those, are copied into the export."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_ROOT))

from lib import review_seat_evidence as rse  # noqa: E402

BRIEF = """## Rendered pages
- `.context/working/judge-evidence/T-9/01-tasks.png`
- `.context/working/judge-evidence/T-9/02-missing.png`
### Visual evidence
- `.context/visual/T-9/state@1024.png`
Steps are in `.context/visual/T-9/state.capture.json`.
Not evidence: `.context/working/focus.yaml`, `.context/visual/../secrets/key`,
`.context/visual/T-9/escape.png`
"""


def _project(tmp_path: Path) -> tuple[Path, Path]:
    proj, tree = tmp_path / "proj", tmp_path / "tree"
    for rel, data in [(".context/working/judge-evidence/T-9/01-tasks.png", b"png1"),
                      (".context/visual/T-9/state@1024.png", b"png2"),
                      (".context/visual/T-9/state.capture.json", b"{}"),
                      (".context/working/focus.yaml", b"focus"),
                      (".context/secrets/key", b"SECRET")]:
        p = proj / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
    os.symlink(proj / ".context/secrets/key", proj / ".context/visual/T-9/escape.png")
    tree.mkdir()
    return proj, tree


def test_copies_only_cited_evidence_files(tmp_path):
    proj, tree = _project(tmp_path)
    copied = rse.copy_cited(BRIEF, proj, tree)
    assert copied == [".context/working/judge-evidence/T-9/01-tasks.png",
                      ".context/visual/T-9/state@1024.png",
                      ".context/visual/T-9/state.capture.json"]
    assert (tree / ".context/working/judge-evidence/T-9/01-tasks.png").read_bytes() == b"png1"
    assert (tree / ".context/visual/T-9/state@1024.png").read_bytes() == b"png2"


def test_never_copies_outside_the_evidence_areas(tmp_path):
    proj, tree = _project(tmp_path)
    rse.copy_cited(BRIEF, proj, tree)
    assert not (tree / ".context/working/focus.yaml").exists()      # cited, not an evidence area
    assert not (tree / ".context/secrets").exists()                  # `..` path
    assert not (tree / ".context/visual/T-9/escape.png").exists()    # symlink out of the area
    assert not (tree / ".context/working/judge-evidence/T-9/02-missing.png").exists()


def test_cli_runs_and_reports(tmp_path):
    proj, tree = _project(tmp_path)
    brief = tmp_path / "brief.md"
    brief.write_text(BRIEF)
    out = subprocess.run([sys.executable, str(_ROOT / "lib/review_seat_evidence.py"),
                          str(brief), str(proj), str(tree)], capture_output=True, text=True)
    assert out.returncode == 0 and "copied 3" in out.stdout


def test_run_sh_copies_before_fingerprinting():
    src = (_ROOT / "agents/termlink/termlink.sh").read_text()
    copy_at = src.index("lib/review_seat_evidence.py\" \"$WDIR/brief.md\"")
    fp_at = src.index('TREE_FP_BEFORE="$(_tree_fp)"')
    export_at = src.index("archive --format=tar \"${FW_REVIEW_REVISION:-HEAD}\"")
    assert export_at < copy_at < fp_at


def test_harness_brief_states_the_time_limit_and_the_copied_evidence():
    from lib.reviewer import judge_cli
    crit = [{"index": 1, "ac_index": 1, "body": "- [ ] [REVIEW] x", "render": False,
             "title": "x", "digest": "d"}]
    for kind, expect in (("opencode", True), ("claude", False)):
        brief = judge_cli._build_brief("T-9", crit, rung=3, kind=kind, revision="abc")
        assert ("Time limit: this run is stopped after 15 minutes" in brief) is expect
        assert ("copied into the export at those same relative paths" in brief) is expect
