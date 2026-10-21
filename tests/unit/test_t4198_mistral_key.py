"""T-4198: Watchtower offers a Mistral (La Plateforme) API key.

Upstreamed from 1409 (their T-2003): without it in the framework, `fw upgrade` drops the
consumer's local addition. Two halves must agree — the settings form offers the key name,
and the secrets store resolves it from the conventional MISTRAL_API_KEY env var rather than
the generic FW_MISTRAL_API_KEY fallback.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SETTINGS = ROOT / "web" / "templates" / "settings.html"

secrets_store = pytest.importorskip("web.secrets_store")


def test_env_override_maps_mistral():
    assert secrets_store.ENV_OVERRIDES.get("mistral") == "MISTRAL_API_KEY"


def test_get_api_key_reads_mistral_env(monkeypatch):
    monkeypatch.setenv("MISTRAL_API_KEY", "t4198-sentinel")
    monkeypatch.delenv("FW_MISTRAL_API_KEY", raising=False)
    assert secrets_store.get_api_key("mistral") == "t4198-sentinel"


def test_settings_form_offers_mistral():
    txt = SETTINGS.read_text()
    m = re.search(r'<select name="key_name">(.*?)</select>', txt, re.DOTALL)
    assert m, 'could not find <select name="key_name"> in settings.html'
    assert '<option value="mistral">Mistral (La Plateforme)</option>' in m.group(1)


def test_every_offered_key_has_env_override():
    # The form and ENV_OVERRIDES must not drift: each offered key name has a mapping.
    txt = SETTINGS.read_text()
    m = re.search(r'<select name="key_name">(.*?)</select>', txt, re.DOTALL)
    assert m, 'could not find <select name="key_name"> in settings.html'
    offered =re.findall(r'<option value="([^"]+)"', m.group(1))
    assert offered, "key_name select has no options"
    missing = [k for k in offered if k not in secrets_store.ENV_OVERRIDES]
    assert not missing, f"offered key names without ENV_OVERRIDES entry: {missing}"
