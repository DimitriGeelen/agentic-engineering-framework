"""T-5357 — an image cited by a bare file name in Evidence is read through the paired
Location's full path when the Location agrees (same file name, same region/selector)."""
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from PIL import Image  # noqa: E402

from lib import vote_checker as vc  # noqa: E402

NAME = "config@1920-judge-x.png"
FULL = f".context/reviews/evidence/T-9357/{NAME}"
REGION = "region 10,10,50,20"


@pytest.fixture
def root(tmp_path):
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    f = tmp_path / FULL
    f.parent.mkdir(parents=True)
    Image.new("RGB", (200, 100), "white").save(f)
    return tmp_path


def _check(root, evidence, location):
    return vc.check_image(evidence, location, root, "", task="T-9357", write_crops=False)


def test_bare_name_with_agreeing_location_exists(root):
    r = _check(root, f"image: {NAME} {REGION}", f"{FULL} {REGION}")
    assert r["image_exists"] is True
    assert r["image"] == FULL and r["cited_name"] == NAME
    assert r["region_inside"] is True and r["location_agrees"] is True
    assert r["result"] == "ok"


def test_bare_name_with_location_naming_other_file_is_missing(root):
    other = FULL.replace(NAME, "other.png")
    r = _check(root, f"image: {NAME} {REGION}", f"{other} {REGION}")
    assert r["image_exists"] is False and r["image"] == NAME
    assert "cited_name" not in r


def test_bare_name_with_location_disagreeing_region_is_missing(root):
    r = _check(root, f"image: {NAME} {REGION}", f"{FULL} region 0,0,5,5")
    assert r["image_exists"] is False and r["image"] == NAME


def test_bare_name_without_location_path_is_missing(root):
    r = _check(root, f"image: {NAME} {REGION}", "")
    assert r["image_exists"] is False and r["image"] == NAME
    assert r["result"] == "problem"


def test_full_path_evidence_unchanged(root):
    r = _check(root, f"image: {FULL} {REGION}", f"{FULL} {REGION}")
    assert r["image_exists"] is True and r["image"] == FULL
    assert "cited_name" not in r and r["result"] == "ok"
