"""LLM Provider abstraction — Strategy pattern for hot-switching.

T-377: Defines the provider interface and shared data types.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Generator


@dataclass
class StreamChunk:
    """Normalized streaming chunk across all providers."""
    type: str           # "token", "thinking", "thinking_done", "done", "error"
    content: str = ""   # text content (for token/thinking/error)


@dataclass
class ModelInfo:
    """Model metadata."""
    id: str
    name: str
    provider: str


class LLMProvider(ABC):
    """Abstract base class for LLM providers."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Provider name (e.g. 'ollama', 'openrouter')."""

    @abstractmethod
    def chat_stream(
        self,
        model: str,
        messages: list[dict],
        thinking: bool = False,
    ) -> Generator[StreamChunk, None, None]:
        """Stream a chat completion, yielding normalized StreamChunks."""

    @abstractmethod
    def list_models(self) -> list[ModelInfo]:
        """List available models."""

    @abstractmethod
    def is_available(self) -> bool:
        """Check if the provider is reachable."""
