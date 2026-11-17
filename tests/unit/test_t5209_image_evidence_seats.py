"""T-5209 (T-5199 GO): image-evidence panels seat only vision-capable kinds.

832's T-893 AC1 cites screenshots but names no route, so the T-4944/T-4978 exclusion (render or
page only, `vision: false` only) never fired: opencode sat it and was counted green. The judge now
marks any criterion that names an image file or a screenshot `image`, seats only kinds whose
committed vision is `true` for it, says how to add a vision kind when rung 5 cannot reach two
vision vendors, and tells image seats to judge the images as given. probe-vision's default image
ships with the framework.
"""
from __future__ import annotations

import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

_HERE = Path(__file__).resolve().parent
ROOT = _HERE.parent.parent
sys.path.insert(0, str(ROOT))

from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
from lib.reviewer import probe_vision as pv  # noqa: E402

KINDS = ["claude", "codex", "opencode", "antigravity", "mystery"]
VENDORS = {"claude": "anthropic", "codex": "openai", "opencode": "zai", "antigravity": "google",
           "mystery": "acme"}
VISION = {"claude": True, "codex": True, "antigravity": True, "opencode": False}   # mystery: undeclared


def _crit(text: str, **flags) -> dict:
    return {"index": 1, "ac_index": 1, "text": text, "body": text, "class": "unclassified",
            "render": False, "page": False, **flags}


def _run(monkeypatch, tmp_path, crit, *, vision=VISION, kinds=KINDS, rung=5):
    monkeypatch.setattr(judge_cli, "_backends",
                        lambda root: ([{"id": k, "kind": k} for k in KINDS], []))
    monkeypatch.setattr(vl, "kind_vision", lambda root, revision="": dict(vision))
    monkeypatch.setattr(vl, "_head_sha", lambda root: "0" * 40)
    monkeypatch.setattr(vl, "task_required_strength", lambda *a, **k: (rung, "test"))
    monkeypatch.setattr(judge_cli.review_policy, "ceiling_decision",
                        lambda *a, **k: {"granted": rung, "note": "", "spent": 0, "ceiling": 0})
    monkeypatch.setattr(judge_cli, "_partition", lambda *a, **k: ([crit], []))
    monkeypatch.setattr(judge_cli, "_load_task",
                        lambda *a, **k: {"text": "", "path": tmp_path / "t.md", "frontmatter": {}})
    monkeypatch.setattr(judge_cli, "_impact", lambda *a, **k: {"inputs": {}})
    monkeypatch.setattr(judge_cli, "_gather_evidence",
                        lambda *a, **k: {"needed": False, "shots": [], "error": "", "pages": [],
                                         "partial": [], "captures": []})
    monkeypatch.setattr(judge_cli, "_oversized_evidence", lambda *a, **k: [])
    seen = {}
    real_plan = judge_cli._plan_seats

    def plan(*a, **k):
        seen["plan"] = real_plan(*a, **k)
        return seen["plan"]
    monkeypatch.setattr(judge_cli, "_plan_seats", plan)
    res = judge_cli.judge("T-9", tmp_path, dry_run=True, worker_kinds=set(kinds),
                          kind_vendors={k: VENDORS[k] for k in kinds}, model_preflight=None)
    return res, seen["plan"]


# ── which criteria are image-evidence ───────────────────────────────────────

@pytest.mark.parametrize("text", [
    "The evidence in docs/screens/x.png shows the new layout",
    "Screenshots under .context/visual/T-1/ show 4 tiles",
    "the screenshot of the widget shows a green bar",
    "logo.SVG and photo.jpeg and a.webp", "chart.gif", "pic.jpg",
])
def test_names_image_true(text):
    assert judge_cli.names_image(text)


@pytest.mark.parametrize("text", [
    "docs/reports/T-4978.md exists", "the png library is installed", "the operator decides",
    "run tests/x.py",
])
def test_names_image_false(text):
    assert not judge_cli.names_image(text)


def test_partition_marks_image_criterion_without_route(monkeypatch, tmp_path):
    text = ("---\nid: T-9\n---\n## Acceptance Criteria\n\n### Human\n"
            "- [ ] [REVIEW] The new layout is clean (evidence: `docs/screens/x.png`)\n"
            "  **Steps:** open it\n  **Expected:** clean\n  **If not:** note it\n"
            "- [ ] [REVIEW] The tone of the release notes suits consumers\n"
            "  **Steps:** read them\n  **Expected:** plain\n  **If not:** note it\n")

    class Ctx:
        def __init__(self, *a):
            pass

        def classify(self, crit):
            return SimpleNamespace(cls="taste", delegation_class=judge_cli.REVIEWER_JUDGES, reason="")
    monkeypatch.setattr(vl, "_Ctx", Ctx)
    judged, _ = judge_cli._partition({"text": text, "path": tmp_path / "t.md"}, tmp_path, "T-9")
    assert [(c["render"], c["page"], c["image"]) for c in judged] == [
        (False, False, True), (False, False, False)]


# ── AC1: an image criterion naming no route seats only vision: true kinds ────

def test_image_criterion_seats_only_vision_kinds(monkeypatch, tmp_path):
    res, plan = _run(monkeypatch, tmp_path, _crit("layout clean, see docs/screens/x.png", image=True))
    seated = [s["kind"] for s in plan["seats"]]
    assert seated == ["claude", "codex", "antigravity"]
    assert "opencode" not in seated and "mystery" not in seated
    assert set(res["blind_kinds"]) == {"opencode", "mystery"}
    assert res["criteria"][0]["image"] is True
    assert "vision_shortfall" not in res


def test_page_criterion_also_drops_undeclared(monkeypatch, tmp_path):
    _res, plan = _run(monkeypatch, tmp_path, _crit("/classic shows 4 tiles", page=True),
                      kinds=["mystery", "opencode", "claude", "codex", "antigravity"])
    assert {s["kind"] for s in plan["seats"]} == {"claude", "codex", "antigravity"}


# ── AC2: a non-image criterion's plan is unchanged ───────────────────────────

def test_non_image_plan_unchanged(monkeypatch, tmp_path):
    res, plan = _run(monkeypatch, tmp_path, _crit("the tone of the notes suits consumers"))
    before = judge_cli._plan_seats(tmp_path, 5, set(KINDS), VENDORS, exclude_kinds=frozenset())
    assert [s["kind"] for s in plan["seats"]] == [s["kind"] for s in before["seats"]] \
        == ["claude", "codex", "opencode"]
    assert "blind_kinds" not in res and "vision_shortfall" not in res


# ── AC3: one vision kind at rung 5 names the count and the probe command ─────

def test_one_vision_kind_names_count_and_probe(monkeypatch, tmp_path, capsys):
    res, plan = _run(monkeypatch, tmp_path, _crit("see docs/screens/x.png", image=True),
                     vision={"claude": True, "opencode": False})
    assert [s["kind"] for s in plan["dispatch"]] == ["claude"]
    msg = res["vision_shortfall"]
    assert "only 1 vision kind on this host (claude" in msg
    assert "fw reviewer probe-vision <kind>" in msg
    judge_cli._print_result(res)
    out = capsys.readouterr().out
    assert "only 1 vision kind on this host" in out and "fw reviewer probe-vision" in out


def test_no_shortfall_below_rung5(monkeypatch, tmp_path):
    res, _ = _run(monkeypatch, tmp_path, _crit("see docs/screens/x.png", image=True),
                  vision={"claude": True}, rung=3)
    assert "vision_shortfall" not in res


# ── AC4: the brief's image wording, only for image criteria ─────────────────

@pytest.mark.parametrize("kind", ["claude", "codex"])
def test_brief_image_wording(kind):
    img = judge_cli._build_brief("T-9", [_crit("see docs/screens/x.png", image=True)], kind=kind)
    assert "Judge the supplied images; do not re-run the harness" in img
    assert "cannot reproduce" in img and '"cannot view"' in img and "not-evaluated" in img
    plain = judge_cli._build_brief("T-9", [_crit("the tone suits consumers")], kind=kind)
    assert "Judge the supplied images" not in plain
    assert "cannot reproduce" not in plain and "cannot view" not in plain


# ── AC5: probe-vision's default image resolves inside the framework install ──

def test_shipped_default_image_exists_and_is_tracked_path():
    assert (ROOT / pv.DEFAULT_IMAGE).is_file()
    assert not pv.DEFAULT_IMAGE.startswith(".context/")


def test_probe_default_image_from_vendored_framework(monkeypatch, tmp_path):
    project = tmp_path / "consumer"
    fw = project / ".agentic-framework"
    shipped = fw / pv.DEFAULT_IMAGE
    shipped.parent.mkdir(parents=True)
    shipped.write_bytes(b"\x89PNG vendored")
    monkeypatch.setenv("FRAMEWORK_ROOT", str(fw))
    monkeypatch.setenv("PROJECT_ROOT", str(project))
    assert pv.default_image() == shipped
    seen = {}

    def launcher(argv, env_extra, cwd, timeout):
        seen["bytes"] = (Path(cwd) / "probe.png").read_bytes()
        return 0, "CARDS: 8\nTITLE: x\nMECHANISM: m\n", ""
    rec = pv.run_probe("codex", root=project, binary="/bin/codex", launcher=launcher)
    assert seen["bytes"] == b"\x89PNG vendored"
    assert rec["image"] == f".agentic-framework/{pv.DEFAULT_IMAGE}"
    assert not (project / ".context/visual").exists()


# ── AC6: the two-vendor bar is unchanged ──────────────────────────────────────

def test_min_evaluating_seats_still_two():
    assert vl.MIN_EVALUATING_SEATS == 2
