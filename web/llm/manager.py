"""Provider manager — registration, selection, hot-switching.

T-377: Manages which LLM provider is active and handles failover.
"""

import logging
import os

from web.llm.provider import LLMProvider, ModelInfo

log = logging.getLogger(__name__)


class ProviderManager:
    """Registry and selector for LLM providers.

    Supports hot-switching without server restart.
    """

    def __init__(self):
        self._providers: dict[str, LLMProvider] = {}
        self._active_name: str = "ollama"  # default

    def register(self, provider: LLMProvider) -> None:
        """Register a provider by its name."""
        self._providers[provider.name] = provider
        log.info("Registered LLM provider: %s", provider.name)

    @property
    def active(self) -> LLMProvider:
        """Get the currently active provider."""
        if self._active_name in self._providers:
            return self._providers[self._active_name]
        # Fallback to first available
        for name, provider in self._providers.items():
            log.warning("Active provider '%s' not found, falling back to '%s'",
                        self._active_name, name)
            self._active_name = name
            return provider
        raise RuntimeError("No LLM providers registered")

    @property
    def active_name(self) -> str:
        return self._active_name

    def switch(self, name: str) -> None:
        """Switch the active provider (hot-swap, no restart needed)."""
        if name not in self._providers:
            raise ValueError(f"Unknown provider: {name}. Available: {list(self._providers)}")
        self._active_name = name
        log.info("Switched LLM provider to: %s", name)

    def list_providers(self) -> list[dict]:
        """List all registered providers with availability status."""
        result = []
        for name, provider in self._providers.items():
            result.append({
                "name": name,
                "active": name == self._active_name,
                "available": provider.is_available(),
            })
        return result

    def get(self, name: str) -> LLMProvider | None:
        """Get a provider by name."""
        return self._providers.get(name)


# ---------------------------------------------------------------------------
# Singleton instance — initialized at import time
# ---------------------------------------------------------------------------

_manager: ProviderManager | None = None


def get_manager() -> ProviderManager:
    """Get or create the global provider manager.

    Lazily initializes providers on first call.
    """
    global _manager
    if _manager is not None:
        return _manager

    from web.config import Config
    from web.llm.ollama_provider import OllamaProvider

    _manager = ProviderManager()

    # Always register Ollama (local-first)
    ollama_provider = OllamaProvider(host=Config.OLLAMA_HOST)
    _manager.register(ollama_provider)

    # Register OpenRouter if API key is available
    api_key = os.environ.get("OPENROUTER_API_KEY", "")

    # Try settings-based key storage (T-378, when available)
    if not api_key:
        try:
            from web.secrets_store import get_api_key
            api_key = get_api_key("openrouter") or ""
        except ImportError:
            pass

    if api_key:
        from web.llm.openrouter_provider import OpenRouterProvider
        openrouter_provider = OpenRouterProvider(api_key=api_key)
        _manager.register(openrouter_provider)

    # Check for saved provider preference
    active = os.environ.get("FW_LLM_PROVIDER", "ollama")
    if active in [p["name"] for p in _manager.list_providers()]:
        _manager.switch(active)

    return _manager
