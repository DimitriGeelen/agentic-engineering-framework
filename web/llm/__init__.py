"""LLM provider abstraction layer.

T-377: Strategy pattern for hot-switching between Ollama and OpenRouter.

Usage:
    from web.llm import get_manager

    manager = get_manager()
    provider = manager.active
    for chunk in provider.chat_stream(model, messages):
        ...
"""

from web.llm.manager import get_manager
from web.llm.provider import LLMProvider, ModelInfo, StreamChunk

__all__ = ["get_manager", "LLMProvider", "ModelInfo", "StreamChunk"]
