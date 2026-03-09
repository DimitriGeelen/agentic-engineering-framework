"""OpenRouter LLM provider — uses the OpenAI-compatible API.

T-377: OpenRouter is fully OpenAI-compatible (base_url swap).
"""

import logging
from typing import Generator

from web.llm.provider import LLMProvider, ModelInfo, StreamChunk

log = logging.getLogger(__name__)


class OpenRouterProvider(LLMProvider):
    """OpenRouter cloud provider via OpenAI-compatible API."""

    BASE_URL = "https://openrouter.ai/api/v1"

    def __init__(self, api_key: str):
        self._api_key = api_key
        self._client = None

    def _get_client(self):
        if self._client is None:
            import openai
            self._client = openai.OpenAI(
                api_key=self._api_key,
                base_url=self.BASE_URL,
            )
        return self._client

    @property
    def name(self) -> str:
        return "openrouter"

    def chat_stream(
        self,
        model: str,
        messages: list[dict],
        thinking: bool = False,
    ) -> Generator[StreamChunk, None, None]:
        client = self._get_client()

        kwargs = {
            "model": model,
            "messages": messages,
            "stream": True,
        }

        # OpenRouter supports reasoning via extra_body
        if thinking:
            kwargs["extra_body"] = {"reasoning": {"effort": "high"}}

        try:
            response = client.chat.completions.create(**kwargs)

            for chunk in response:
                choice = chunk.choices[0] if chunk.choices else None
                if not choice:
                    continue

                delta = choice.delta

                # Check for reasoning content (OpenRouter thinking)
                reasoning = getattr(delta, "reasoning", None)
                if reasoning:
                    yield StreamChunk(type="thinking", content=reasoning)
                    continue

                # Answer tokens
                token = delta.content or ""
                if token:
                    yield StreamChunk(type="token", content=token)

                if choice.finish_reason:
                    break

        except Exception as e:
            log.error("OpenRouter streaming error: %s", e)
            yield StreamChunk(type="error", content=f"OpenRouter error: {e}")

        yield StreamChunk(type="done")

    def list_models(self) -> list[ModelInfo]:
        try:
            client = self._get_client()
            resp = client.models.list()
            return [
                ModelInfo(id=m.id, name=m.id, provider="openrouter")
                for m in resp.data
            ]
        except Exception as e:
            log.warning("Failed to list OpenRouter models: %s", e)
            return []

    def is_available(self) -> bool:
        if not self._api_key:
            return False
        try:
            self._get_client().models.list()
            return True
        except Exception:
            return False
