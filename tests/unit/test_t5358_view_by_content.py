"""T-5358 — a LOGGED view of any file whose sha256 equals the cited image's counts as a view of
the cited image (same bytes, same pixels). Attached-at-launch bytes alone stay 'attached' proof
(T-5327); the name rules (exact path, `<stem>-<dispatch id>` copy) are unchanged."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from PIL import Image  # noqa: E402

from lib import vote_checker as vc  # noqa: E402

DID = "judge-t-9358-r5-claude-code-0123456789ab"
ORIG = ".context/visual/T-9358/config@1920.png"
COPY = ".context/reviews/evidence/T-9358/shot-copy.png"
OTHER = ".context/visual/T-9358/other.png"
REGION = "region 10,10,50,20"


def _png(path: Path, colour: str) -> bytes:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", (200, 100), colour).save(path)
    return path.read_bytes()


@pytest.fixture
def root(tmp_path):
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    _png(tmp_path / ORIG, "white")
    (tmp_path / COPY).parent.mkdir(parents=True, exist_ok=True)
    (tmp_path / COPY).write_bytes((tmp_path / ORIG).read_bytes())    # byte-identical copy
    _png(tmp_path / OTHER, "black")
    return tmp_path


def _seat(root: Path, reads=(), attached=()) -> Path:
    """A claude stream-json seat record that Read `reads`; `attached`: attached at launch."""
    d = root / ".context" / "dispatch" / DID
    d.mkdir(parents=True, exist_ok=True)
    lines: list[dict] = [{"type": "system", "subtype": "init"}]
    for r in reads:
        lines.append({"type": "assistant", "message": {"content": [
            {"type": "tool_use", "name": "Read", "input": {"file_path": str(root / r)}}]}})
    (d / "result.jsonl").write_text("\n".join(json.dumps(x) for x in lines) + "\n")
    if attached:
        (d / vc.ATTACHED_MANIFEST).write_text(json.dumps({"attached": [
            {"path": a, "sha256": hashlib.sha256((root / a).read_bytes()).hexdigest()}
            for a in attached]}))
    return d


def _check(root, seat, image):
    views = vc.seat_viewed_images(seat)
    return vc.check_image(f"image: {image} {REGION}", f"{image} {REGION}", root, "",
                          task="T-9358", views=views, views_known=True, write_crops=False,
                          cited=[image])


def test_logged_view_of_original_counts_for_byte_identical_copy(root):
    r = _check(root, _seat(root, reads=[ORIG]), COPY)
    assert r["seat_viewed"] is True
    assert r["view_proof"] == "logged"
    assert r["viewed_same_bytes_as"].endswith(ORIG)


def test_logged_view_of_different_image_does_not_count(root):
    r = _check(root, _seat(root, reads=[OTHER]), COPY)
    assert r["seat_viewed"] is False
    assert "view_proof" not in r


def test_attached_only_identical_bytes_is_not_a_logged_view(root):
    r = _check(root, _seat(root, attached=[ORIG]), COPY)
    assert r["seat_viewed"] is True                      # T-5309: attached at launch
    assert r["view_proof"] == "attached"                 # T-5327: not a logged view
    assert "viewed_same_bytes_as" not in r
    assert vc.attached_only_reasons({"criteria": {"1": {"items": [r]}}}, render=True)


def test_exact_path_view_unchanged(root):
    r = _check(root, _seat(root, reads=[COPY]), COPY)
    assert r["seat_viewed"] is True and r["view_proof"] == "logged"
    assert "viewed_same_bytes_as" not in r


def test_stem_dispatch_copy_rule_unchanged_even_with_different_bytes(root):
    copy = f".context/reviews/evidence/T-9358/config@1920-{DID}.png"
    _png(root / copy, "red")                             # not byte-identical: the name rule decides
    r = _check(root, _seat(root, reads=[ORIG]), copy)
    assert r["seat_viewed"] is True and r["view_proof"] == "logged"
    assert "viewed_same_bytes_as" not in r


def test_image_viewed_without_read_is_name_rules_only(root):
    views = vc.seat_viewed_images(_seat(root, reads=[ORIG]))
    sha = hashlib.sha256((root / COPY).read_bytes()).hexdigest()
    assert vc.image_viewed(views, COPY, sha, [COPY]) is False
    assert vc.image_viewed(views, COPY, sha, [COPY], read=lambda p: Path(p).read_bytes()) is True


def test_live_shape_bare_name_copy_via_check_vote(root):
    """The T-5329 shape: bare-name Evidence, Location naming the `<stem>-<dispatch id>` copy,
    the seat Read the original. Name rules alone answer None (the bare and the resolved name
    look like two cited images); the content match makes it a logged view."""
    name = f"config@1920-{DID}.png"
    full = f".context/reviews/evidence/T-9358/{name}"
    (root / full).write_bytes((root / ORIG).read_bytes())
    seat = _seat(root, reads=[ORIG])
    vote = {"header": {"task": "T-9358", "vote": "green", "failed": []},
            "criteria": {1: {"vote": "green", "evidence": [f"image: {name} {REGION}"],
                             "location": [f"{full} {REGION}"], "rule": "r", "conclusion": "c"}}}
    out = vc.check_vote(vote, root, "", seat, task="T-9358", write_crops=False)
    item = out["criteria"]["1"]["items"][0]
    assert item["image"] == full
    assert item["seat_viewed"] is True and item["view_proof"] == "logged"
