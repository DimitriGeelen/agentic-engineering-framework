"""T-4475: concurrent embed batches for the bulk reindex (FW_EMBED_WORKERS).

Adapted from 010-termlink proposal 344 (their T-3336). Pinned here:
  1. the default is serial — one batch in flight at a time — so no consumer's
     embedding server sees more load unless they opt in;
  2. with >1 workers batches really overlap, and the result stays in INPUT
     order even when later batches finish first (the reindex zips vectors
     against metadata rows, so a reorder would silently mislabel the index);
  3. a malformed or <1 value falls back to 1 rather than failing the reindex.
"""

import threading
import time

import pytest

emb = pytest.importorskip("web.embeddings")


def _fake_embed_factory(delays):
    """Fake _embed: returns one tag per text; sleeps per batch; tracks overlap."""
    state = {"in_flight": 0, "peak": 0}
    lock = threading.Lock()

    def fake(batch, host=None):
        with lock:
            state["in_flight"] += 1
            state["peak"] = max(state["peak"], state["in_flight"])
        time.sleep(delays.get(batch[0], 0.0))
        with lock:
            state["in_flight"] -= 1
        return [f"v:{t}".encode() for t in batch]

    return fake, state


def test_default_is_serial(monkeypatch):
    monkeypatch.delenv("FW_EMBED_WORKERS", raising=False)
    assert emb._embed_workers() == 1
    texts = [f"t{i}" for i in range(10)]
    fake, state = _fake_embed_factory({"t0": 0.02, "t4": 0.02})
    monkeypatch.setattr(emb, "_embed", fake)
    out = emb._embed_batches(texts, 2)
    assert out == [f"v:{t}".encode() for t in texts]
    assert state["peak"] == 1


def test_workers_overlap_and_preserve_order(monkeypatch):
    monkeypatch.setenv("FW_EMBED_WORKERS", "3")
    texts = [f"t{i}" for i in range(9)]
    # First batch is slowest, last is fastest: completion order is reversed.
    fake, state = _fake_embed_factory({"t0": 0.15, "t3": 0.08, "t6": 0.0})
    monkeypatch.setattr(emb, "_embed", fake)
    out = emb._embed_batches(texts, 3)
    assert out == [f"v:{t}".encode() for t in texts]
    assert state["peak"] > 1


@pytest.mark.parametrize("raw", ["0", "-2", "three", ""])
def test_malformed_value_falls_back_to_one(monkeypatch, raw):
    monkeypatch.setenv("FW_EMBED_WORKERS", raw)
    assert emb._embed_workers() == 1


def test_host_is_forwarded(monkeypatch):
    monkeypatch.setenv("FW_EMBED_WORKERS", "2")
    seen = []

    def fake(batch, host=None):
        seen.append(host)
        return [b"x"] * len(batch)

    monkeypatch.setattr(emb, "_embed", fake)
    assert len(emb._embed_batches(["a", "b", "c"], 1, host="bulk:11434")) == 3
    assert seen == ["bulk:11434"] * 3
