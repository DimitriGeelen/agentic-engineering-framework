"""Typed liveness classification for the embedding provider (T-3006, slice 1 of T-3005).

Why this module exists
----------------------
The embedding path had exactly one failure mode as far as any caller could tell:
nothing happened. `agents/context/lib/focus.sh:152` runs the briefing under
`2>/dev/null || true`, so a dead provider, a missing model, a contended provider
and a healthy provider with no relevant hits were the same observable event —
silence. Semantic recall sat at 0% for an unknown period and every instrument
read healthy (T-3004 F3, T-3005 C1).

The fix is not "log more". It is to make the failure *typed*, so a caller can
tell "this host has no Ollama, which is expected" apart from "Ollama is up and
refusing us, which is a fault". Those two need opposite responses, and collapsing
them is what produced the outage.

The classes are deliberately behavioural, not HTTP-shaped — the caller wants to
know what to do, not what the wire said:

    ok            provider answered with a usable embedding
    ollama-down   nothing is listening / connection refused
    model-absent  provider is up, the embedding model is not pulled
    contention    provider is up and healthy for other work, but refuses ours
    degraded      provider accepted and then failed or timed out
    error         anything unrecognised — never silently folded into another class

`contention` is its own class because of the T-3006 origin: with
`OLLAMA_MAX_LOADED_MODELS=1`, a chat model holding the only slot on a
continuously-renewed lease makes every *unloaded* model 503 instantly, while the
loaded model answers 200 in under a second. Measured: gemma4 200/0.87s,
embeddinggemma 503/0.17s, same server, same second. A generic "ollama is broken"
verdict would be wrong and would send the operator to restart a service that is
working fine — the actual remedy is a separate endpoint or a second model slot.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, asdict

# Behavioural classes. `ok` plus five ways to not be ok.
OK = "ok"
OLLAMA_DOWN = "ollama-down"
MODEL_ABSENT = "model-absent"
CONTENTION = "contention"
DEGRADED = "degraded"
ERROR = "error"

# Classes worth retrying: the condition may clear on its own.
# `contention` is included even though the T-3006 instance was permanent — a
# transient slot conflict is the common case and costs one short backoff to ride
# out. Retry is bounded precisely because the permanent case exists.
RETRYABLE = frozenset({CONTENTION, DEGRADED})

# Classes worth retrying on a *different* host (T-3017). All three are properties
# of the endpoint, not of the request: the host is unreachable, the host does not
# hold the model, or the host's slots are taken. A second host may have none of
# those problems. `error` is deliberately absent — an unclassifiable failure is
# most likely the request itself, and retrying it elsewhere just fails twice.
# `degraded` is absent too: a slow host is still answering, and racing it against
# a second host would double the load for a condition that resolves itself.
FAILOVER = frozenset({OLLAMA_DOWN, MODEL_ABSENT, CONTENTION})

# Classes a caller should treat as "expected on this host" rather than a fault:
# a machine with no Ollama at all is a normal consumer, not a broken install.
# Keeping this distinct is what stops the tri-state alarm design (T-3005
# constraint 4) from degenerating back into noise that someone silences.
EXPECTED_DEGRADED = frozenset({OLLAMA_DOWN, MODEL_ABSENT})


@dataclass
class EmbedHealth:
    """One probe result. `status` is always one of the classes above."""

    status: str
    detail: str
    host: str = ""
    model: str = ""
    latency_ms: int = 0

    @property
    def ok(self) -> bool:
        return self.status == OK

    @property
    def is_fault(self) -> bool:
        """True when this warrants a loud warning rather than a quiet note.

        A provider that is absent is not a fault (the operator may simply not run
        one here); a provider that is present and refusing is.
        """
        return not self.ok and self.status not in EXPECTED_DEGRADED

    def as_dict(self) -> dict:
        return asdict(self)


class EmbedUnavailable(RuntimeError):
    """Raised when embedding cannot be performed, carrying the class with it.

    The point is the `status` attribute. Callers previously received a bare
    Ollama string ("server busy, please try again") which named neither the
    subsystem nor the remedy, and which `2>/dev/null` then erased anyway.
    """

    def __init__(self, health: EmbedHealth):
        self.health = health
        self.status = health.status
        super().__init__(f"embedding unavailable [{health.status}]: {health.detail}")


def classify(exc: Exception) -> tuple[str, str]:
    """Map an exception from the Ollama client onto a behavioural class.

    Matching is on message text as well as type: the `ollama` package surfaces
    several transport failures as its own wrapper types, and the status code is
    not reliably present on every path. Text matching is a compromise, so the
    fallthrough is `error` — an unrecognised failure must not be silently
    absorbed into a neighbouring class, which is the mistake this whole module
    exists to correct.
    """
    status_code = getattr(exc, "status_code", None)

    # Some transport paths raise with an empty message and carry only the status
    # code. An empty detail reaches the log as "embedding unavailable []: " and
    # tells the reader nothing — synthesise something diagnosable.
    msg = str(exc) or (f"HTTP {status_code}" if status_code
                       else exc.__class__.__name__)
    low = msg.lower()

    # Provider unreachable — nothing is listening, DNS fails, socket refused.
    if isinstance(exc, (ConnectionError, ConnectionRefusedError)):
        return OLLAMA_DOWN, msg
    for probe in ("connection refused", "failed to establish", "cannot connect",
                  "connection error", "name or service not known", "no route to host"):
        if probe in low:
            return OLLAMA_DOWN, msg

    # Model not pulled on the provider.
    if status_code == 404 or "not found" in low or "no such model" in low:
        return MODEL_ABSENT, msg

    # Provider up, refusing this request — the T-3006 case.
    if status_code == 503 or "server busy" in low or "maximum pending requests" in low:
        return CONTENTION, msg

    # Accepted then failed to finish in time.
    if isinstance(exc, TimeoutError) or "timeout" in low or "timed out" in low:
        return DEGRADED, msg

    return ERROR, msg


def probe(client, model: str, host: str = "", timeout_note: str = "") -> EmbedHealth:
    """Embed a fixed token and classify the outcome.

    Uses a real embed call rather than `/api/tags` or a socket connect on
    purpose: those confirm the provider is *reachable*, which is exactly the
    check that read healthy all through the outage. Only an actual embedding
    exercises model loading, which is where the failure was.
    """
    started = time.monotonic()
    try:
        resp = client.embed(model=model, input=["fw-embed-probe"])
    except Exception as exc:  # noqa: BLE001 — classification is the whole job
        status, detail = classify(exc)
        return EmbedHealth(
            status=status,
            detail=detail or timeout_note,
            host=host,
            model=model,
            latency_ms=int((time.monotonic() - started) * 1000),
        )

    latency_ms = int((time.monotonic() - started) * 1000)

    # A 200 that carries no usable vector is not success. Treat it as degraded
    # rather than ok — an empty embedding would poison the index silently, which
    # is the same failure shape one layer down.
    embeddings = getattr(resp, "embeddings", None) or []
    if not embeddings or not embeddings[0]:
        return EmbedHealth(
            status=DEGRADED,
            detail="provider returned no embedding vector",
            host=host,
            model=model,
            latency_ms=latency_ms,
        )

    return EmbedHealth(
        status=OK,
        detail=f"dim={len(embeddings[0])}",
        host=host,
        model=model,
        latency_ms=latency_ms,
    )


def remedy(status: str) -> str:
    """One actionable line per class, for humans and agents reading a warning.

    Kept next to the classes so a new class cannot be added without someone
    having to answer "and what does the reader do about it?".
    """
    return {
        OK: "",
        OLLAMA_DOWN: (
            "No embedding provider reachable. Start one, or point FW_EMBED_HOST "
            "at a host that runs it. Semantic recall is unavailable until then; "
            "keyword recall still works."
        ),
        MODEL_ABSENT: (
            "Provider is up but the embedding model is not pulled. "
            "Run: ollama pull <FW_EMBEDDING_MODEL>"
        ),
        CONTENTION: (
            "Provider is up but refusing this model — typically a single model "
            "slot held by another model (OLLAMA_MAX_LOADED_MODELS=1). Point "
            "FW_EMBED_HOST at a dedicated embedding endpoint, or raise the slot "
            "count on the provider."
        ),
        DEGRADED: (
            "Provider accepted the request but did not return a usable vector "
            "in time. Check provider load and FW_OLLAMA_TIMEOUT."
        ),
        ERROR: "Unrecognised embedding failure — see detail.",
    }.get(status, "")
