"""Ollama LLM provider — wraps the ollama Python library.

T-377: Extracted from web/ask.py.
"""
from __future__ import annotations


import logging
from typing import Generator

import ollama

from web.llm.provider import LLMProvider, ModelInfo, StreamChunk

log = logging.getLogger(__name__)


class OllamaProvider(LLMProvider):
    """Local Ollama provider."""

    def __init__(self, host: str = "http://localhost:11434"):
        self._host = host
        self._client = ollama.Client(host=host)

    @property
    def name(self) -> str:
        return "ollama"

    def chat_stream(
        self,
        model: str,
        messages: list[dict],
        thinking: bool = False,
    ) -> Generator[StreamChunk, None, None]:
        try:
            response = self._client.chat(
                model=model,
                messages=messages,
                stream=True,
                think=thinking,
            )

            in_thinking = thinking
            for chunk in response:
                msg = chunk.get("message", {})

                # Thinking tokens (Qwen3/Ollama)
                thinking_token = msg.get("thinking", "")
                if thinking_token:
                    yield StreamChunk(type="thinking", content=thinking_token)
                    continue

                # Answer tokens
                token = msg.get("content", "")
                if token:
                    if in_thinking:
                        in_thinking = False
                        yield StreamChunk(type="thinking_done")
                    yield StreamChunk(type="token", content=token)

                if chunk.get("done"):
                    break

        except Exception as e:
            log.error("Ollama streaming error: %s", e)
            yield StreamChunk(type="error", content="AI service unavailable. Check that Ollama is running.")

        yield StreamChunk(type="done")

    def list_models(self) -> list[ModelInfo]:
        try:
            resp = self._client.list()
            return [
                ModelInfo(id=m.model, name=m.model, provider="ollama")
                for m in resp.models
            ]
        except Exception as e:
            log.warning("Failed to list Ollama models: %s", e)
            return []

    def is_available(self) -> bool:
        try:
            self._client.list()
            return True
        except Exception:
            return False
