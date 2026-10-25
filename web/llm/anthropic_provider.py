"""Anthropic LLM provider — uses the official `anthropic` Python SDK.

T-4749: streaming chat with adaptive thinking, model list, and the
server-side refusal fallback. The SDK is an optional import: without it
the provider reports unavailable, as OpenRouter does without `openai`.
"""
from __future__ import annotations


import logging
from typing import Generator

from web.llm.provider import LLMProvider, ModelInfo, StreamChunk

log = logging.getLogger(__name__)


class AnthropicProvider(LLMProvider):
    """Anthropic cloud provider via the official SDK."""

    DEFAULT_MODEL = "claude-opus-5-5"
    MAX_TOKENS = 64000
    FALLBACK_BETA = "server-side-fallback-2026-07-01"

    def __init__(self, api_key: str):
        self._api_key = api_key
        self._client = None
        self.unavailable_reason = ""

    def _get_client(self):
        if self._client is None:
            import anthropic
            self._client = anthropic.Anthropic(api_key=self._api_key)
        return self._client

    @property
    def name(self) -> str:
        return "anthropic"

    @staticmethod
    def _describe_error(e: Exception) -> str:
        """Exception class plus HTTP status, never the message (it may echo request data)."""
        status = getattr(e, "status_code", None)
        if status is not None:
            return "{} (status {})".format(type(e).__name__, status)
        return type(e).__name__

    def chat_stream(
        self,
        model: str,
        messages: list[dict],
        thinking: bool = False,
    ) -> Generator[StreamChunk, None, None]:
        # Adaptive thinking is always on for the default model (it cannot be
        # disabled), so summaries are streamed whatever `thinking` says, as
        # OpenRouter streams reasoning whenever the model returns it.
        try:
            client = self._get_client()
        except ImportError:
            yield StreamChunk(type="error", content="Anthropic SDK not installed (pip install anthropic).")
            yield StreamChunk(type="done")
            return

        system_parts = [m["content"] for m in messages if m.get("role") == "system"]
        chat = [m for m in messages if m.get("role") != "system"]

        kwargs = {
            "model": model or self.DEFAULT_MODEL,
            "max_tokens": self.MAX_TOKENS,
            "messages": chat,
            "thinking": {"type": "adaptive", "display": "summarized"},
            "betas": [self.FALLBACK_BETA],
            "fallbacks": "default",
        }
        if system_parts:
            kwargs["system"] = "\n\n".join(system_parts)

        try:
            block_types: dict[int, str] = {}
            with client.beta.messages.stream(**kwargs) as stream:
                for event in stream:
                    if event.type == "content_block_start":
                        block_types[event.index] = event.content_block.type
                    elif event.type == "content_block_delta":
                        if event.delta.type == "text_delta":
                            if event.delta.text:
                                yield StreamChunk(type="token", content=event.delta.text)
                        elif event.delta.type == "thinking_delta":
                            if event.delta.thinking:
                                yield StreamChunk(type="thinking", content=event.delta.thinking)
                    elif event.type == "content_block_stop":
                        if block_types.get(event.index) == "thinking":
                            yield StreamChunk(type="thinking_done")
                final = stream.get_final_message()

            # Never a silent ok on a truncated or declined answer (1409's rule)
            if final.stop_reason == "refusal":
                category = getattr(getattr(final, "stop_details", None), "category", None)
                detail = " (category: {})".format(category) if category else ""
                yield StreamChunk(type="error", content="Anthropic declined the request: stop_reason=refusal{}".format(detail))
            elif final.stop_reason == "max_tokens":
                yield StreamChunk(type="error", content="Answer truncated: stop_reason=max_tokens ({} tokens)".format(self.MAX_TOKENS))

        except Exception as e:
            reason = self._describe_error(e)
            log.error("Anthropic streaming error: %s", reason)
            yield StreamChunk(type="error", content="Anthropic API error: {}".format(reason))

        yield StreamChunk(type="done")

    def list_models(self) -> list[ModelInfo]:
        try:
            client = self._get_client()
            return [
                ModelInfo(id=m.id, name=getattr(m, "display_name", None) or m.id, provider="anthropic")
                for m in client.models.list()
            ]
        except Exception as e:
            log.warning("Failed to list Anthropic models: %s", self._describe_error(e))
            return []

    def is_available(self) -> bool:
        if not self._api_key:
            self.unavailable_reason = "no Anthropic API key configured"
            return False
        try:
            import anthropic  # noqa: F401
        except ImportError:
            self.unavailable_reason = "anthropic SDK not installed (pip install anthropic)"
            return False
        try:
            self._get_client().models.list()
            self.unavailable_reason = ""
            return True
        except Exception as e:
            self.unavailable_reason = self._describe_error(e)
            return False
