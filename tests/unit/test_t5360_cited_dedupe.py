"""T-5360 — check_vote lists each cited image once, by its resolved path. A bare Evidence name
that T-5357 resolves through its agreeing Location is not a second cited image, so the
`<stem>-<dispatch id>` name rule is not made ambiguous by the duplicate."""
import json
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from PIL import Image  # noqa: E402

from lib import vote_checker as vc  # noqa: E402

DID = "judge-t-9360-r5-claude-code-0123456789ab"
ORIG = ".context/visual/T-9360/config@1920.png"
OTHER = ".context/visual/T-9360/other.png"
NAME = f"config@1920-{DID}.png"
FULL = f".context/reviews/evidence/T-9360/{NAME}"
REGION = "region 10,10,50,20"


def _png(path: Path, colour: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", (200, 100), colour).save(path)


@pytest.fixture
def root(tmp_path):
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    _png(tmp_path / ORIG, "white")
    _png(tmp_path / FULL, "red")          # NOT byte-identical: the T-5358 content match cannot apply
    _png(tmp_path / OTHER, "black")
    return tmp_path


def _seat(root: Path, reads=()) -> Path:
    d = root / ".context" / "dispatch" / DID
    d.mkdir(parents=True, exist_ok=True)
    lines: list[dict] = [{"type": "system", "subtype": "init"}]
    for r in reads:
        lines.append({"type": "assistant", "message": {"content": [
            {"type": "tool_use", "name": "Read", "input": {"file_path": str(root / r)}}]}})
    (d / "result.jsonl").write_text("\n".join(json.dumps(x) for x in lines) + "\n")
    return d


def _vote(evidence, location):
    return {"header": {"task": "T-9360", "vote": "green", "failed": []},
            "criteria": {1: {"vote": "green", "evidence": evidence, "location": location,
                             "rule": "r", "conclusion": "c"}}}


def _cited(monkeypatch, vote, root, seat=None):
    seen = []
    real = vc.check_image

    def spy(*a, **kw):
        seen.append(list(kw.get("cited") or []))
        return real(*a, **kw)

    monkeypatch.setattr(vc, "check_image", spy)
    out = vc.check_vote(vote, root, "", seat, task="T-9360", write_crops=False)
    return seen, out


def test_bare_evidence_with_agreeing_location_is_one_cited_entry(root, monkeypatch):
    seen, _ = _cited(monkeypatch, _vote([f"image: {NAME} {REGION}"], [f"{FULL} {REGION}"]), root)
    assert seen == [[FULL]]
    assert vc.cited_image_path(f"image: {NAME} {REGION}", f"{FULL} {REGION}") == FULL


def test_same_image_bare_and_full_in_two_criteria_is_one_entry(root, monkeypatch):
    vote = _vote([f"image: {NAME} {REGION}", f"image: {FULL} {REGION}"],
                 [f"{FULL} {REGION}", f"{FULL} {REGION}"])
    seen, _ = _cited(monkeypatch, vote, root)
    assert seen[0] == [FULL]


def test_name_rule_decides_viewed_without_content_fallback(root):
    out = vc.check_vote(_vote([f"image: {NAME} {REGION}"], [f"{FULL} {REGION}"]), root, "",
                        _seat(root, reads=[ORIG]), task="T-9360", write_crops=False)
    item = out["criteria"]["1"]["items"][0]
    assert item["image"] == FULL and item["cited_name"] == NAME
    assert item["seat_viewed"] is True and item["view_proof"] == "logged"
    assert "viewed_same_bytes_as" not in item         # the name rule, not the content match


def test_name_rule_decides_not_viewed(root):
    out = vc.check_vote(_vote([f"image: {NAME} {REGION}"], [f"{FULL} {REGION}"]), root, "",
                        _seat(root, reads=[OTHER]), task="T-9360", write_crops=False)
    assert out["criteria"]["1"]["items"][0]["seat_viewed"] is False


def test_two_different_images_stay_two_entries(root, monkeypatch):
    vote = _vote([f"image: {NAME} {REGION}", f"image: {OTHER} {REGION}"],
                 [f"{FULL} {REGION}", f"{OTHER} {REGION}"])
    seen, _ = _cited(monkeypatch, vote, root)
    assert seen[0] == [FULL, OTHER]
