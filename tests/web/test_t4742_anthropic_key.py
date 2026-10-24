"""T-4742: the Watchtower key store accepts an Anthropic key, with
ANTHROPIC_API_KEY overriding the stored value like the other providers."""

import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))

import web.secrets_store as store  # noqa: E402


@pytest.fixture()
def tmp_store(tmp_path, monkeypatch):
    monkeypatch.setattr(store, "SECRETS_DIR", tmp_path)
    monkeypatch.setattr(store, "KEYS_FILE", tmp_path / "api-keys.enc")
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    return tmp_path


def test_anthropic_env_override_registered():
    assert store.ENV_OVERRIDES["anthropic"] == "ANTHROPIC_API_KEY"


def test_anthropic_round_trip(tmp_store):
    store.set_api_key("anthropic", "sk-ant-test-0123456789")
    assert store.get_api_key("anthropic") == "sk-ant-test-0123456789"
    names = {k["name"] for k in store.list_configured_keys()}
    assert "anthropic" in names
    assert store.delete_api_key("anthropic") is True
    assert store.get_api_key("anthropic") is None


def test_anthropic_env_wins_over_stored(tmp_store, monkeypatch):
    store.set_api_key("anthropic", "sk-ant-stored")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-ant-from-env")
    assert store.get_api_key("anthropic") == "sk-ant-from-env"


def test_settings_form_offers_anthropic():
    html = (FRAMEWORK_ROOT / "web" / "templates" / "settings.html").read_text()
    assert '<option value="anthropic">Anthropic</option>' in html
