"""T-4506 — a review seat whose pinned model its harness no longer lists names itself.

policy/review-backends.yaml pinned opencode to zai-coding-plan/glm-5.2 after Z.AI retired it,
and every opencode seat died with 'Unexpected server error'. lib/review_model_preflight.py
compares each pin with `opencode models <provider>`; fw doctor WARNs and fw reviewer judge
does not dispatch the retired kind."""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import review_model_preflight as pf  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
from t3852_unavailable_seat_test import KV4, hrepo4  # noqa: E402,F401
from t3580_judge_cli_test import NOCAP, TID, repo  # noqa: E402,F401
import _review_runtime as rt  # noqa: E402

LISTING = "zai-coding-plan/glm-5.3\nzai-coding-plan/glm-5.3-flash\nzai-coding-plan/glm-5.3-highspeed\n"
OC = {"id": "opencode", "worker_kind": "opencode", "binary": "/x/opencode"}


def _lister(rc=0, text=LISTING, calls=None):
    def f(binary, provider):
        if calls is not None:
            calls.append((binary, provider))
        return rc, text
    return f


def _have(_b):
    return "/x/opencode"


def test_a_listed_pin_is_ok():
    r = pf.check([{**OC, "model": "zai-coding-plan/glm-5.3"}], _lister(), _have)
    assert [x["status"] for x in r] == ["ok"], r


def test_a_retired_pin_names_the_model_and_the_listed_ones():
    r = pf.check([{**OC, "model": "zai-coding-plan/glm-5.2"}], _lister(), _have)
    assert r[0]["status"] == "retired", r
    assert "zai-coding-plan/glm-5.2" in r[0]["detail"] and "glm-5.3-flash" in r[0]["detail"], r
    assert pf.retired_kinds(r) == {"opencode": r[0]["detail"]}


def test_opencode_absent_skips_cleanly():
    r = pf.check([{**OC, "model": "zai-coding-plan/glm-5.2"}], _lister(), lambda b: "")
    assert [x["status"] for x in r] == ["skipped"], r
    assert pf.retired_kinds(r) == {}


def test_a_failed_listing_is_unchecked_never_retired():
    for rc, text in ((1, "Error: Provider not found"), (124, ""), (0, "")):
        r = pf.check([{**OC, "model": "zai-coding-plan/glm-5.2"}], _lister(rc, text), _have)
        assert r[0]["status"] == "unchecked", (rc, r)
        assert pf.retired_kinds(r) == {}


def test_only_opencode_backends_with_provider_models_are_checked_and_listed_once():
    calls: list = []
    backends = [{"id": "codex", "worker_kind": "codex", "model": "gpt-6-astra", "binary": "/x/codex"},
                {"id": "claude", "worker_kind": "claude"},
                {**OC, "model": "zai-coding-plan/glm-5.3"},
                {**OC, "id": "opencode-2", "model": "zai-coding-plan/glm-5.3-flash"}]
    r = pf.check(backends, _lister(calls=calls), _have)
    assert [x["backend"] for x in r] == ["opencode", "opencode-2"], r
    assert calls == [("/x/opencode", "zai-coding-plan")], calls


def test_the_committed_registry_pin_is_not_the_retired_glm_5_2():
    text = (_HERE / "policy/review-backends.yaml").read_text()
    block = text.split("id: opencode", 1)[1].split("- id:", 1)[0]
    assert "model: zai-coding-plan/glm-5.3\n" in block, block


def _judge(root, monkeypatch, preflight):
    rt.unbound_spend(monkeypatch)
    return judge_cli.judge(TID, root, dry_run=True, capture=NOCAP, worker_kinds=set(KV4),
                           kind_vendors=dict(KV4), model_preflight=preflight)


def test_judge_does_not_dispatch_a_kind_whose_pin_is_retired(hrepo4, monkeypatch):
    def retired(backends):
        return pf.check([{**b, "model": "zai-coding-plan/glm-5.2"} if b.get("worker_kind") == "opencode"
                         else b for b in backends], _lister(), _have)
    res = _judge(hrepo4, monkeypatch, retired)
    assert "opencode" in res["model_retired"], res.get("model_retired")
    assert "opencode" not in res["dispatchable"], res["dispatchable"]
    assert "opencode" in res["seats"], res["seats"]     # the seat stays; it is unfilled, named


def test_control_judge_dispatches_the_kind_when_its_pin_is_listed(hrepo4, monkeypatch):
    def ok(backends):
        return pf.check([{**b, "model": "zai-coding-plan/glm-5.3"} if b.get("worker_kind") == "opencode"
                         else b for b in backends], _lister(), _have)
    res = _judge(hrepo4, monkeypatch, ok)
    assert not res.get("model_retired"), res.get("model_retired")
    assert "opencode" in res["dispatchable"], res["dispatchable"]
