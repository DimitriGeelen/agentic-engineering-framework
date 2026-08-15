"""Environment-based configuration for Watchtower.

All hardcoded values (model names, paths, timeouts) are centralised here
and overridable via environment variables for production deployment.
"""

import logging
import os
from pathlib import Path

import yaml as _yaml

_logger = logging.getLogger(__name__)

# Resolve PROJECT_ROOT once (same logic as shared.py)
_APP_DIR = Path(__file__).resolve().parent
_FRAMEWORK_ROOT = _APP_DIR.parent
_PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", str(_FRAMEWORK_ROOT)))

# Load persisted settings (T-395: config survives restarts)
_SETTINGS_FILE = _PROJECT_ROOT / ".context" / "settings.yaml"
_saved = {}
try:
    if _SETTINGS_FILE.exists():
        _saved = _yaml.safe_load(_SETTINGS_FILE.read_text()) or {}
except Exception as e:
    _logger.warning("Failed to parse settings %s: %s", _SETTINGS_FILE, e)


class Config:
    """Watchtower configuration — reads from environment with sensible defaults."""

    # -- Ollama ----------------------------------------------------------
    OLLAMA_HOST = os.environ.get(
        "OLLAMA_HOST", _saved.get("ollama_host", "http://localhost:11434")
    )
    # T-3006: embeddings may need a *different* endpoint from chat. On a host
    # where OLLAMA_MAX_LOADED_MODELS=1, a resident chat model starves every
    # other model — the embed path 503s instantly while chat answers 200. When
    # unset this is OLLAMA_HOST, so existing installs are unaffected.
    EMBED_HOST = os.environ.get(
        "FW_EMBED_HOST", _saved.get("embed_host", "")
    ) or OLLAMA_HOST
    # T-3016: bulk reindex is a different workload from a query and belongs on a
    # different host. A query is one 768-dim vector where warm latency decides
    # everything (measured: 208 ms shared vs 210 ms sidecar — indistinguishable),
    # so EMBED_HOST stays on the contention-immune sidecar. A reindex is ~394k
    # vectors where throughput decides everything, and the two hosts are not
    # close: 1.9 chunks/s on the CPU sidecar vs 69.9 chunks/s on the GPU host,
    # which is the difference between a 29-hour bootstrap and a 1.6-hour one.
    # T-3008 recorded this split as open item (a) and deferred it at urgent
    # budget; this is that item. Defaults to OLLAMA_HOST — installs with no
    # sidecar have EMBED_HOST == OLLAMA_HOST already and see no change.
    EMBED_BULK_HOST = os.environ.get(
        "FW_EMBED_BULK_HOST", _saved.get("embed_bulk_host", "")
    ) or OLLAMA_HOST
    # Bounded retry for transient embed failures (contention / degraded only).
    # Bounded because the T-3006 instance was *permanent*: retrying a starved
    # slot forever would turn a fast failure into a hang on every task start.
    EMBED_RETRIES = int(os.environ.get("FW_EMBED_RETRIES", "2"))
    EMBED_RETRY_BACKOFF = float(os.environ.get("FW_EMBED_RETRY_BACKOFF", "0.25"))
    PRIMARY_MODEL = os.environ.get("FW_PRIMARY_MODEL", "qwen3:14b")
    FALLBACK_MODEL = os.environ.get("FW_FALLBACK_MODEL", "dolphin-llama3:8b")
    EMBEDDING_MODEL = os.environ.get("FW_EMBEDDING_MODEL", "nomic-embed-text-v2-moe")
    RERANKER_MODEL = os.environ.get(
        "FW_RERANKER_MODEL", "dengcao/Qwen3-Reranker-0.6B"
    )

    # -- Paths -----------------------------------------------------------
    VECTOR_DB_PATH = Path(
        os.environ.get(
            "VECTOR_DB_PATH",
            str(_PROJECT_ROOT / ".context" / "working" / "fw-vec-index.db"),
        )
    )

    # -- Flask -----------------------------------------------------------
    SECRET_KEY = os.environ.get("FW_SECRET_KEY", "")
    HOST = os.environ.get("FW_HOST", "0.0.0.0")
    PORT = int(os.environ.get("FW_PORT", "3000"))

    # -- Timeouts --------------------------------------------------------
    OLLAMA_TIMEOUT = int(os.environ.get("FW_OLLAMA_TIMEOUT", "120"))
