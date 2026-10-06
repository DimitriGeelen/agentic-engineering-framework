"""T-3955 / T-3956: fw upgrade never overwrites a consumer's own version of a template file.

010-termlink (origin of the doorbell+mail toolkit) lost 15 newer files and its customised
/resume to "drift → replace" on upgrade. lib/upgrade_template_sync.py now updates only a stock
copy (equal to what the framework last wrote) and keeps everything else, writing the template
beside it as <file>.upstream.
"""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

import upgrade_template_sync as uts  # noqa: E402

REL = "scripts/doorbell.sh"


def _setup(tmp_path, dst_text=None, stamp_text=None, manifest=None):
    target = tmp_path / "proj"
    (target / "scripts").mkdir(parents=True)
    (target / ".context").mkdir()
    src = tmp_path / "tmpl.sh"
    src.write_text("#!/bin/sh\necho NEW-TEMPLATE\n")
    if dst_text is not None:
        (target / REL).write_text(dst_text)
    if stamp_text is not None:
        sha = hashlib.sha256(stamp_text.encode()).hexdigest()
        (target / uts.STAMP).write_text(json.dumps({REL: sha}))
    if manifest is not None:
        (target / uts.MANIFEST).write_text(manifest)
    return target, src


def test_missing_file_is_created_and_stamped(tmp_path):
    target, src = _setup(tmp_path)
    assert uts.decide(target, src, REL, False, True)[0] == "CREATED"
    assert "NEW-TEMPLATE" in (target / REL).read_text()
    assert json.loads((target / uts.STAMP).read_text())[REL] == uts._sha(src)


def test_stock_copy_is_updated(tmp_path):
    target, src = _setup(tmp_path, dst_text="old stock\n", stamp_text="old stock\n")
    assert uts.decide(target, src, REL, False, True)[0] == "UPDATED"
    assert "NEW-TEMPLATE" in (target / REL).read_text()


def test_customised_copy_is_kept_with_upstream_beside_it(tmp_path):
    target, src = _setup(tmp_path, dst_text="MY EDIT\n", stamp_text="old stock\n")
    st, why = uts.decide(target, src, REL, False, True)
    assert st == "KEPT" and "differs from what the framework last wrote" in why
    assert (target / REL).read_text() == "MY EDIT\n"
    assert "NEW-TEMPLATE" in (target / (REL + ".upstream")).read_text()


def test_no_stamp_and_differing_is_kept_never_overwritten(tmp_path):
    """010's case: the consumer is the ORIGIN and holds a NEWER file; no stamp exists yet."""
    target, src = _setup(tmp_path, dst_text="#!/bin/sh\necho NEWER-AT-ORIGIN\n")
    st, why = uts.decide(target, src, REL, False, True)
    assert st == "KEPT" and "no record" in why
    assert "NEWER-AT-ORIGIN" in (target / REL).read_text()


def test_manifest_claimed_file_is_preserved(tmp_path):
    target, src = _setup(tmp_path, dst_text="old stock\n", stamp_text="old stock\n",
                         manifest="project_files:\n  - scripts/*.sh\n")
    st, _ = uts.decide(target, src, REL, False, True)
    assert st == "PRESERVED"
    assert (target / REL).read_text() == "old stock\n"     # even a stock copy, when claimed


def test_manifest_dot_path_is_preserved_t3965(tmp_path):
    """T-3965: `lstrip("./")` stripped the dot of `.claude/...`, so no dot-path entry ever matched."""
    rel = ".claude/commands/resume.md"
    target, src = _setup(tmp_path, manifest="project_files:\n  - .claude/commands/resume.md\n")
    (target / ".claude/commands").mkdir(parents=True)
    (target / rel).write_text("MY RESUME\n")
    assert uts.decide(target, src, rel, False, False)[0] == "PRESERVED"
    (target / uts.MANIFEST).write_text("project_files:\n  - ./.claude/commands/*.md\n")
    assert uts.decide(target, src, rel, False, False)[0] == "PRESERVED"


def test_known_shipped_version_without_stamp_is_updated_t3965(tmp_path):
    target, src = _setup(tmp_path, dst_text="v1 stock\n")
    known = {hashlib.sha256(b"v1 stock\n").hexdigest()}
    assert uts.decide(target, src, REL, False, True, known)[0] == "UPDATED"
    assert "NEW-TEMPLATE" in (target / REL).read_text()
    # a customised file is not in the shipped set and stays KEPT
    target2, src2 = _setup(tmp_path / "b", dst_text="MY EDIT\n")
    assert uts.decide(target2, src2, REL, False, True, known)[0] == "KEPT"


def test_dry_run_writes_nothing(tmp_path):
    target, src = _setup(tmp_path, dst_text="MY EDIT\n")
    assert uts.decide(target, src, REL, True, True)[0] == "WOULD-KEPT"
    assert not (target / (REL + ".upstream")).exists()
    assert not (target / uts.STAMP).exists()


def test_converges_once_the_operator_accepts_upstream(tmp_path):
    target, src = _setup(tmp_path, dst_text="MY EDIT\n")
    uts.decide(target, src, REL, False, True)                       # KEPT, .upstream written
    (target / REL).write_text((target / (REL + ".upstream")).read_text())   # operator accepts
    assert uts.decide(target, src, REL, False, True)[0] == "OK"     # in sync, stamp written
    src.write_text("#!/bin/sh\necho NEXT-RELEASE\n")
    assert uts.decide(target, src, REL, False, True)[0] == "UPDATED"   # now a stock copy
