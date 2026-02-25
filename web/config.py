"""Environment-based configuration for Watchtower.

All hardcoded values (model names, paths, timeouts) are centralised here
and overridable via environment variables for production deployment.
"""

import os
from pathlib import Path

# Resolve PROJECT_ROOT once (same logic as shared.py)
_APP_DIR = Path(__file__).resolve().parent
_FRAMEWORK_ROOT = _APP_DIR.parent
_PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", str(_FRAMEWORK_ROOT)))


class Config:
    """Watchtower configuration — reads from environment with sensible defaults."""

    # -- Ollama ----------------------------------------------------------
    OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
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
