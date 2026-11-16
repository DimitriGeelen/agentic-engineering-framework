"""T-5188: P-010 counted 0 criteria behind a mid-line or unclosed `<!--`.

`check_acceptance_criteria` stripped comments with `sed '/<!--/,/-->/d'`, which opens on ANY
line containing `<!--` (deleting that criterion) and, with no `-->`, runs to the end of the
section. The gate now uses the structural rule in lib/comment_strip.py and refuses on an
unclosed span. Every case is driven end to end through update-task.sh.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

FW = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW / "tests" / "unit"))
sys.path.insert(0, str(FW))

from test_t5181_accepted_miss import _close, _task, proj  # noqa: E402,F401  (fixture)


def _set(p: Path, old: str, new: str) -> None:
    t = p.read_text()
    assert old in t, old
    p.write_text(t.replace(old, new))


def test_control_all_met_with_closed_inline_comment_closes(proj):
    p = _task(proj, box2="x")
    _set(p, "- [x] Third thing done", "- [x] Third thing done <!-- a note -->")
    r = _close(proj)
    assert r.returncode == 0, (r.stdout + r.stderr)[-2000:]


def test_midline_comment_closed_later_still_counts_the_boxes_between(proj):
    # old sed: the range opened on box 1 (deleting it) and ran to `-->`, deleting the open box 2
    p = _task(proj)
    _set(p, "- [x] First thing done", "- [x] First thing done <!-- a mid-line note")
    _set(p, "- [x] Third thing done", "- [x] Third thing done\n-->")
    r = _close(proj)
    assert r.returncode != 0, (r.stdout + r.stderr)[-2000:]
    assert p.exists()


def test_unclosed_midline_comment_does_not_hide_later_open_box(proj):
    # the review's repro: `- [~] one <!-- z` with no `-->` gave total=0
    p = _task(proj)
    _set(p, "- [x] First thing done", "- [x] First thing done <!-- z")
    r = _close(proj)
    assert r.returncode != 0, (r.stdout + r.stderr)[-2000:]
    assert "Run was done the canonical way" in r.stderr
    assert p.exists()


def test_unclosed_whole_line_comment_refuses_and_names_it(proj):
    p = _task(proj, box2="x")
    _set(p, "- [x] Third thing done", "<!-- forgot to close\n- [x] Third thing done\n- [ ] Fourth still open")
    r = _close(proj)
    assert r.returncode != 0, (r.stdout + r.stderr)[-2000:]
    assert "unclosed HTML comment" in r.stderr and "forgot to close" in r.stderr
    assert p.exists()


def test_invalid_utf8_byte_never_counts_zero(proj):
    p = _task(proj)
    raw = p.read_bytes().replace(b"Run was done the canonical way", b"Run was done the \xff canonical way")
    p.write_bytes(raw)
    r = _close(proj)
    assert r.returncode != 0, (r.stdout + r.stderr)[-2000:]
    assert p.exists()


def test_no_range_sed_strip_left_in_update_task():
    src = (FW / "agents" / "task-create" / "update-task.sh").read_text()
    code = [ln for ln in src.split("\n") if not ln.lstrip().startswith("#")]
    assert not any("sed '/<!--/,/-->/d'" in ln for ln in code)


def test_unclosed_comment_line_unit():
    from lib.comment_strip import unclosed_comment_line
    assert unclosed_comment_line("a\n<!-- x -->\nb") is None
    assert unclosed_comment_line("a\n<!--\nb\n-->\nc") is None
    assert unclosed_comment_line("a\n  <!-- open\nb") == 2
    assert unclosed_comment_line("- [ ] one <!-- z\nb") is None  # mid-line opens nothing
    r = subprocess.run([sys.executable, str(FW / "lib" / "comment_strip.py"), "--lenient",
                        "--fail-unclosed"], input=b"a\n<!-- open\n- [ ] b\n", capture_output=True)
    assert r.returncode == 3 and b"line 2" in r.stderr
