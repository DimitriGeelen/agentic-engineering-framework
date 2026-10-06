"""T-3953 (dimitri-mint-dev G-009): the reranker must actually rank.

_rerank_score sent `system=` with `raw=True` (Ollama 0.33.1: HTTP 400 "raw mode does not
support template, system, or context"), logged at DEBUG and returned 0.5 — so rerank() was a
silent no-op for fw ask / fw recall / Watchtower search. These tests pin the request shape
and the scoring with a fake client; no model is needed.
"""
import logging
import math
import sys
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from web import embeddings as e  # noqa: E402


def _tok(token, p):
    return SimpleNamespace(token=token, logprob=math.log(p))


class FakeClient:
    def __init__(self, top=None, raise_with=None):
        self.top, self.raise_with, self.calls = top, raise_with, []

    def generate(self, **kw):
        self.calls.append(kw)
        if self.raise_with:
            raise self.raise_with
        return SimpleNamespace(response="x",
                               logprobs=[SimpleNamespace(token="x", logprob=0.0, top_logprobs=self.top)])


def test_request_has_no_system_field_and_asks_for_logprobs(monkeypatch):
    fake = FakeClient(top=[_tok("yes", 0.9), _tok("no", 0.1)])
    monkeypatch.setattr(e, "_get_ollama_client", lambda: fake)
    e._rerank_score("q", "d")
    kw = fake.calls[0]
    assert "system" not in kw and kw["raw"] is True
    assert kw["logprobs"] is True and kw["top_logprobs"] >= 2
    assert kw["prompt"].startswith("<|im_start|>system\n") and "<Query>: q" in kw["prompt"]


def test_score_is_graded_and_case_insensitive(monkeypatch):
    # yes 0.6 + Yes 0.2 vs no 0.1 + No 0.1 -> 0.8 / 1.0
    fake = FakeClient(top=[_tok("yes", 0.6), _tok("Yes", 0.2), _tok("no", 0.1), _tok("No", 0.1)])
    monkeypatch.setattr(e, "_get_ollama_client", lambda: fake)
    assert abs(e._rerank_score("q", "d") - 0.8) < 1e-9


def test_distinct_scores_order_relevant_above_irrelevant(monkeypatch):
    hi = FakeClient(top=[_tok("yes", 0.95), _tok("no", 0.05)])
    lo = FakeClient(top=[_tok("yes", 0.02), _tok("No", 0.98)])
    monkeypatch.setattr(e, "_get_ollama_client", lambda: hi)
    s_hi = e._rerank_score("q", "relevant")
    monkeypatch.setattr(e, "_get_ollama_client", lambda: lo)
    s_lo = e._rerank_score("q", "irrelevant")
    assert s_hi > 0.9 > 0.1 > s_lo


def test_error_warns_and_falls_back_to_neutral(monkeypatch, caplog):
    fake = FakeClient(raise_with=RuntimeError("raw mode does not support system"))
    monkeypatch.setattr(e, "_get_ollama_client", lambda: fake)
    with caplog.at_level(logging.WARNING):
        assert e._rerank_score("q", "d") == 0.5
    assert any("Reranker error" in r.getMessage() and r.levelno == logging.WARNING
               for r in caplog.records)


def test_neither_yes_nor_no_is_neutral(monkeypatch):
    fake = FakeClient(top=[_tok("I", 0.9), _tok("The", 0.1)])
    monkeypatch.setattr(e, "_get_ollama_client", lambda: fake)
    assert e._rerank_score("q", "d") == 0.5
