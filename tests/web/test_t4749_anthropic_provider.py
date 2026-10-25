"""T-4749: the Anthropic provider maps the SDK stream onto StreamChunks, never
reports a truncated or declined answer as ok, and is registered from the env or
the key store. A fake `anthropic` module stands in for the SDK, so no test
touches the network."""

import sys
import types
from pathlib import Path
from types import SimpleNamespace as NS

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))

import web.llm.manager as manager_mod  # noqa: E402
import web.secrets_store as store  # noqa: E402
from web.llm.anthropic_provider import AnthropicProvider  # noqa: E402


def _events(blocks):
    """Script a stream: blocks is a list of (block_type, [delta texts])."""
    out = []
    for i, (btype, parts) in enumerate(blocks):
        out.append(NS(type="content_block_start", index=i, content_block=NS(type=btype)))
        for p in parts:
            if btype == "thinking":
                delta = NS(type="thinking_delta", thinking=p)
            else:
                delta = NS(type="text_delta", text=p)
            out.append(NS(type="content_block_delta", index=i, delta=delta))
        out.append(NS(type="content_block_stop", index=i))
    out.append(NS(type="message_stop"))
    return out


class FakeStream:
    def __init__(self, events, stop_reason, stop_details=None):
        self._events = events
        self._final = NS(stop_reason=stop_reason, stop_details=stop_details)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def __iter__(self):
        return iter(self._events)

    def get_final_message(self):
        return self._final


class FakeAPIStatusError(Exception):
    def __init__(self, status_code):
        super().__init__("secret-bearing message sk-ant-should-not-leak")
        self.status_code = status_code


def install_fake_sdk(monkeypatch, script=None, models=None, raise_exc=None):
    calls = {}

    class FakeMessages:
        def stream(self, **kwargs):
            calls["stream"] = kwargs
            if raise_exc is not None:
                raise raise_exc
            return FakeStream(*script)

    class FakeModels:
        def list(self):
            return list(models or [])

    class FakeClient:
        def __init__(self, api_key=None):
            calls["api_key"] = api_key
            self.beta = NS(messages=FakeMessages())
            self.models = FakeModels()

    mod = types.ModuleType("anthropic")
    mod.Anthropic = FakeClient
    monkeypatch.setitem(sys.modules, "anthropic", mod)
    return calls


def _collect(provider):
    return list(provider.chat_stream("claude-opus-5-5", [{"role": "user", "content": "hi"}]))


def test_text_and_thinking_mapping(monkeypatch):
    calls = install_fake_sdk(monkeypatch, script=(
        _events([("thinking", ["consider", " it"]), ("text", ["Hel", "lo"])]), "end_turn"))
    chunks = _collect(AnthropicProvider("sk-ant-test"))
    assert [(c.type, c.content) for c in chunks] == [
        ("thinking", "consider"), ("thinking", " it"), ("thinking_done", ""),
        ("token", "Hel"), ("token", "lo"), ("done", ""),
    ]
    kw = calls["stream"]
    assert kw["model"] == "claude-opus-5-5"
    assert kw["max_tokens"] == 64000
    assert kw["thinking"] == {"type": "adaptive", "display": "summarized"}
    assert kw["betas"] == ["server-side-fallback-2026-07-01"]
    assert kw["fallbacks"] == "default"
    for banned in ("temperature", "top_p", "top_k"):
        assert banned not in kw


def test_system_messages_go_to_system_param(monkeypatch):
    calls = install_fake_sdk(monkeypatch, script=(_events([("text", ["ok"])]), "end_turn"))
    p = AnthropicProvider("sk-ant-test")
    list(p.chat_stream("", [{"role": "system", "content": "be brief"},
                            {"role": "user", "content": "hi"}]))
    assert calls["stream"]["system"] == "be brief"
    assert calls["stream"]["messages"] == [{"role": "user", "content": "hi"}]
    assert calls["stream"]["model"] == "claude-opus-5-5"


def test_refusal_is_an_error_chunk(monkeypatch):
    install_fake_sdk(monkeypatch, script=(
        _events([("text", ["partial"])]), "refusal", NS(category="cyber")))
    chunks = _collect(AnthropicProvider("sk-ant-test"))
    errors = [c for c in chunks if c.type == "error"]
    assert len(errors) == 1
    assert "refusal" in errors[0].content and "cyber" in errors[0].content
    assert chunks[-1].type == "done"


def test_max_tokens_is_an_error_chunk(monkeypatch):
    install_fake_sdk(monkeypatch, script=(_events([("text", ["cut"])]), "max_tokens"))
    chunks = _collect(AnthropicProvider("sk-ant-test"))
    errors = [c for c in chunks if c.type == "error"]
    assert len(errors) == 1 and "max_tokens" in errors[0].content


def test_sdk_exception_names_class_and_status_not_key(monkeypatch):
    install_fake_sdk(monkeypatch, raise_exc=FakeAPIStatusError(529))
    chunks = _collect(AnthropicProvider("sk-ant-secret-key"))
    err = [c for c in chunks if c.type == "error"][0].content
    assert "FakeAPIStatusError" in err and "529" in err
    assert "sk-ant" not in err
    assert chunks[-1].type == "done"


def test_list_models(monkeypatch):
    install_fake_sdk(monkeypatch, models=[
        NS(id="claude-opus-5-5", display_name="Claude Opus 5.5"),
        NS(id="claude-haiku-5-5", display_name="Claude Haiku 5.5"),
    ])
    models = AnthropicProvider("sk-ant-test").list_models()
    assert [(m.id, m.name, m.provider) for m in models] == [
        ("claude-opus-5-5", "Claude Opus 5.5", "anthropic"),
        ("claude-haiku-5-5", "Claude Haiku 5.5", "anthropic"),
    ]


def test_unavailable_without_sdk(monkeypatch):
    # None in sys.modules makes `import anthropic` raise ImportError
    monkeypatch.setitem(sys.modules, "anthropic", None)
    p = AnthropicProvider("sk-ant-test")
    assert p.is_available() is False
    assert "not installed" in p.unavailable_reason
    assert p.list_models() == []
    chunks = _collect(p)
    assert chunks[0].type == "error" and chunks[-1].type == "done"


def test_available_with_sdk(monkeypatch):
    install_fake_sdk(monkeypatch)
    assert AnthropicProvider("sk-ant-test").is_available() is True
    assert AnthropicProvider("").is_available() is False


@pytest.fixture()
def tmp_store(tmp_path, monkeypatch):
    monkeypatch.setattr(store, "SECRETS_DIR", tmp_path)
    monkeypatch.setattr(store, "KEYS_FILE", tmp_path / "api-keys.enc")
    for var in ("ANTHROPIC_API_KEY", "OPENROUTER_API_KEY", "FW_LLM_PROVIDER"):
        monkeypatch.delenv(var, raising=False)
    monkeypatch.setattr(manager_mod, "_manager", None)
    return tmp_path


def test_manager_registers_from_env(tmp_store, monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-ant-from-env")
    mgr = manager_mod.get_manager()
    provider = mgr.get("anthropic")
    assert isinstance(provider, AnthropicProvider)
    assert provider._api_key == "sk-ant-from-env"


def test_manager_registers_from_store(tmp_store):
    store.set_api_key("anthropic", "sk-ant-stored")
    mgr = manager_mod.get_manager()
    provider = mgr.get("anthropic")
    assert isinstance(provider, AnthropicProvider)
    assert provider._api_key == "sk-ant-stored"


def test_manager_skips_without_key(tmp_store):
    assert manager_mod.get_manager().get("anthropic") is None


def test_save_key_hot_registers(tmp_store):
    from web.app import app
    mgr = manager_mod.ProviderManager()
    manager_mod._manager = mgr
    client = app.test_client()
    with client.session_transaction() as sess:
        sess["_csrf_token"] = "t4749"
    resp = client.post("/settings/save-key", data={
        "_csrf_token": "t4749", "key_name": "anthropic", "key_value": "sk-ant-new"})
    assert resp.status_code == 200
    assert isinstance(mgr.get("anthropic"), AnthropicProvider)
    assert "sk-ant-new" not in resp.get_data(as_text=True)
