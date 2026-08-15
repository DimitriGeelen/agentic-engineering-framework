"""T-3006: the embed-path liveness classifier and the bounded retry.

Why these tests exist
---------------------
The outage this fixes (T-3004 / T-3005) was not caused by a wrong branch. It was
caused by every instrument being unable to report a failure at all: the caller
discarded stderr, the readiness check counted rows, and the freshness field
reported its own read time. So the thing worth pinning here is not "does classify
return a string" but:

  1. each failure shape maps to a *distinct* class, because collapsing them is
     what produced a silent outage;
  2. an unrecognised failure lands in `error` rather than being absorbed into a
     neighbouring class — silent absorption is the original sin;
  3. the retry is genuinely bounded, because the T-3006 instance was permanent
     starvation and an unbounded retry would hang every task start;
  4. absent-provider and refusing-provider differ in `is_fault`, since the whole
     tri-state alarm design (T-3005 constraint 4) rests on that distinction.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web import embed_health as EH  # noqa: E402


# --------------------------------------------------------------------------
# classify() — one class per failure shape
# --------------------------------------------------------------------------

class _Resp(Exception):
    """Stands in for ollama._types.ResponseError, which carries a status_code."""

    def __init__(self, message, status_code):
        super().__init__(message)
        self.status_code = status_code


@pytest.mark.parametrize("exc,expected", [
    # The T-3006 origin, verbatim from the live provider.
    (_Resp("server busy, please try again.  maximum pending requests exceeded", 503),
     EH.CONTENTION),
    # Same class reached by status code alone, without the message.
    (_Resp("", 503), EH.CONTENTION),
    (_Resp("model 'nomic-embed-text-v2-moe' not found", 404), EH.MODEL_ABSENT),
    (_Resp("no such model", 400), EH.MODEL_ABSENT),
    (ConnectionRefusedError("[Errno 111] Connection refused"), EH.OLLAMA_DOWN),
    (Exception("Failed to establish a new connection"), EH.OLLAMA_DOWN),
    (TimeoutError("read timed out"), EH.DEGRADED),
    (Exception("request timeout after 120s"), EH.DEGRADED),
])
def test_classify_maps_each_failure_shape_to_its_own_class(exc, expected):
    status, detail = EH.classify(exc)
    assert status == expected, f"{exc!r} classified as {status}, expected {expected}"
    assert detail, "detail must carry the original message for debugging"


def test_unrecognised_failure_is_error_not_absorbed():
    """An unknown failure must not be folded into a known class.

    Guessing would reintroduce the defect: a novel failure would be reported as
    something with a confident, wrong remedy attached.
    """
    status, _ = EH.classify(Exception("wharrgarbl"))
    assert status == EH.ERROR


def test_every_class_has_a_remedy():
    """A class with no remedy line is a dead end for whoever reads the warning."""
    for status in (EH.OK, EH.OLLAMA_DOWN, EH.MODEL_ABSENT,
                   EH.CONTENTION, EH.DEGRADED, EH.ERROR):
        if status == EH.OK:
            assert EH.remedy(status) == ""
        else:
            assert EH.remedy(status).strip(), f"{status} has no remedy text"


# --------------------------------------------------------------------------
# is_fault — the tri-state distinction the alarm design rests on
# --------------------------------------------------------------------------

def test_absent_provider_is_not_a_fault_but_refusing_provider_is():
    """A consumer with no Ollama is expected-degraded; a refusing one is a fault.

    If both warned, every task start on every consumer would warn, and someone
    would silence it — which is precisely how the original `2>/dev/null` got
    there. See T-3005 constraint 4.
    """
    assert not EH.EmbedHealth(EH.OLLAMA_DOWN, "no provider").is_fault
    assert not EH.EmbedHealth(EH.MODEL_ABSENT, "not pulled").is_fault
    assert EH.EmbedHealth(EH.CONTENTION, "503").is_fault
    assert EH.EmbedHealth(EH.DEGRADED, "timeout").is_fault
    assert EH.EmbedHealth(EH.ERROR, "unknown").is_fault
    assert not EH.EmbedHealth(EH.OK, "dim=768").is_fault


# --------------------------------------------------------------------------
# probe() — a 200 carrying nothing is not success
# --------------------------------------------------------------------------

class _FakeClient:
    def __init__(self, embeddings=None, raises=None):
        self._embeddings = embeddings
        self._raises = raises
        self.calls = 0

    def embed(self, model, input):  # noqa: A002 — mirrors the ollama signature
        self.calls += 1
        if self._raises:
            raise self._raises
        return type("R", (), {"embeddings": self._embeddings})()


def test_probe_ok_reports_dimension():
    health = EH.probe(_FakeClient(embeddings=[[0.1] * 768]), "m", host="h")
    assert health.status == EH.OK
    assert health.ok and not health.is_fault
    assert "768" in health.detail


def test_probe_treats_empty_vector_as_degraded_not_ok():
    """An empty embedding would silently poison the index — same failure, lower."""
    assert EH.probe(_FakeClient(embeddings=[[]]), "m").status == EH.DEGRADED
    assert EH.probe(_FakeClient(embeddings=[]), "m").status == EH.DEGRADED


def test_probe_never_raises():
    """Callers use this to decide what to say; it must not become the failure."""
    health = EH.probe(_FakeClient(raises=_Resp("boom", 503)), "m", host="h")
    assert health.status == EH.CONTENTION
    assert health.host == "h"


# --------------------------------------------------------------------------
# _embed retry — bounded, and only for retryable classes
# --------------------------------------------------------------------------

def _patch_embed_client(monkeypatch, client, retries=2, backoff=0.0):
    from web import embeddings as E
    from web.config import Config
    monkeypatch.setattr(E, "_get_embed_client", lambda host=None: client)
    monkeypatch.setattr(Config, "EMBED_RETRIES", retries, raising=False)
    monkeypatch.setattr(Config, "EMBED_RETRY_BACKOFF", backoff, raising=False)
    return E


def test_retry_is_bounded_and_then_raises_typed_error(monkeypatch):
    """Permanent contention must fail fast with the class, not retry forever.

    The T-3006 instance was permanent: a single model slot held by another
    model. An unbounded retry would convert a 0.15s failure into a hang on every
    `fw context focus`.
    """
    client = _FakeClient(raises=_Resp("maximum pending requests exceeded", 503))
    E = _patch_embed_client(monkeypatch, client, retries=2)

    with pytest.raises(EH.EmbedUnavailable) as excinfo:
        E._embed(["text"])

    assert excinfo.value.status == EH.CONTENTION
    assert client.calls == 3, f"expected 1 try + 2 retries, got {client.calls}"


def test_non_retryable_class_is_not_retried(monkeypatch):
    """A missing model will still be missing on the second attempt."""
    client = _FakeClient(raises=_Resp("model not found", 404))
    E = _patch_embed_client(monkeypatch, client, retries=5)

    with pytest.raises(EH.EmbedUnavailable) as excinfo:
        E._embed(["text"])

    assert excinfo.value.status == EH.MODEL_ABSENT
    assert client.calls == 1, "model-absent must not burn retries"


def test_retry_zero_means_a_single_attempt(monkeypatch):
    client = _FakeClient(raises=_Resp("busy", 503))
    E = _patch_embed_client(monkeypatch, client, retries=0)
    with pytest.raises(EH.EmbedUnavailable):
        E._embed(["text"])
    assert client.calls == 1


def test_transient_failure_recovers_on_retry(monkeypatch):
    """The case retry exists for: one 503, then success."""
    from web import embeddings as E
    from web.config import Config

    class _Flaky:
        def __init__(self):
            self.calls = 0

        def embed(self, model, input):  # noqa: A002
            self.calls += 1
            if self.calls == 1:
                raise _Resp("server busy", 503)
            return type("R", (), {"embeddings": [[0.5] * 4]})()

    client = _Flaky()
    monkeypatch.setattr(E, "_get_embed_client", lambda host=None: client)
    monkeypatch.setattr(Config, "EMBED_RETRIES", 2, raising=False)
    monkeypatch.setattr(Config, "EMBED_RETRY_BACKOFF", 0.0, raising=False)

    out = E._embed(["text"])
    assert client.calls == 2
    assert len(out) == 1 and isinstance(out[0], bytes)


def test_error_message_names_the_class_not_just_the_provider_string():
    """The old failure surfaced a bare Ollama string that named no subsystem."""
    err = EH.EmbedUnavailable(EH.EmbedHealth(EH.CONTENTION, "server busy"))
    assert "contention" in str(err)
