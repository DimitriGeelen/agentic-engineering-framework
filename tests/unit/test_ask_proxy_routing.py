"""Hermetic tests for T-2417: fw ask routes through the litellm proxy with a
graceful direct-ollama fallback, and the litellm config carries openrouter
fallback routes. No live server, no network calls — everything is mocked.
"""
import importlib.util
import os
import types

import pytest
import yaml

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASK_PATH = os.path.join(REPO, "lib", "ask.py")
CONFIG_PATH = os.path.join(REPO, ".context", "litellm-config.yaml")


@pytest.fixture()
def ask_mod(monkeypatch):
    """Load lib/ask.py as a standalone module with heavy web deps stubbed."""
    # Stub the web.* imports the module pulls at load time so the test stays
    # hermetic (no embeddings/qdrant). Insert fake modules before exec.
    web_ask = types.ModuleType("web.ask")
    web_ask.get_model = lambda: "qwen3:14b"
    web_ask.should_think = lambda q: False
    web_ask.SYSTEM_PROMPT = "SYS"
    web_ask.format_rag_context = lambda chunks: "CTX"
    web_emb = types.ModuleType("web.embeddings")
    web_emb.rag_retrieve = lambda q, limit=10: []
    web_emb.build_index = lambda *a, **k: None
    web_pkg = types.ModuleType("web")
    import sys
    monkeypatch.setitem(sys.modules, "web", web_pkg)
    monkeypatch.setitem(sys.modules, "web.ask", web_ask)
    monkeypatch.setitem(sys.modules, "web.embeddings", web_emb)

    spec = importlib.util.spec_from_file_location("fw_ask_under_test", ASK_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_resolve_proxy_disabled(ask_mod, monkeypatch):
    monkeypatch.setenv("FW_ASK_NO_PROXY", "1")
    assert ask_mod._resolve_proxy() is None


def test_resolve_proxy_reads_master_key(ask_mod, monkeypatch):
    monkeypatch.delenv("FW_ASK_NO_PROXY", raising=False)
    monkeypatch.delenv("LITELLM_MASTER_KEY", raising=False)
    base, key = ask_mod._resolve_proxy()
    assert base == "http://localhost:4000/v1"
    assert key == "sk-litellm-local-dev"  # from general_settings.master_key


def test_chat_via_proxy_targets_proxy_endpoint(ask_mod, monkeypatch):
    captured = {}

    class _Msg:
        content = "42"
        reasoning_content = "because"

    class _Resp:
        choices = [types.SimpleNamespace(message=_Msg())]

    class _FakeClient:
        def __init__(self, base_url, api_key):
            captured["base_url"] = base_url
            captured["api_key"] = api_key
            self.chat = types.SimpleNamespace(
                completions=types.SimpleNamespace(create=self._create)
            )

        def _create(self, model, messages, extra_body=None):
            captured["model"] = model
            captured["extra_body"] = extra_body
            return _Resp()

    import openai
    monkeypatch.setattr(openai, "OpenAI", _FakeClient)
    monkeypatch.delenv("FW_ASK_NO_PROXY", raising=False)

    content, thinking = ask_mod._chat_via_proxy(
        "qwen3:14b", [{"role": "user", "content": "hi"}], use_thinking=True
    )
    assert content == "42"
    assert thinking == "because"
    assert captured["base_url"] == "http://localhost:4000/v1"
    assert captured["model"] == "qwen3:14b"
    assert captured["extra_body"] == {"think": True}


def test_ask_falls_back_to_direct_ollama_on_proxy_error(ask_mod, monkeypatch, capsys):
    def _boom(*a, **k):
        raise ConnectionError("proxy down")

    monkeypatch.setattr(ask_mod, "_chat_via_proxy", _boom)
    monkeypatch.setattr(
        ask_mod, "_chat_via_ollama",
        lambda model, messages, use_thinking: ("DIRECT-OK", "t"),
    )
    out = ask_mod.ask("what is x?")
    assert out["answer"] == "DIRECT-OK"
    # fallback must be non-silent (stderr warning)
    assert "falling back to direct ollama" in capsys.readouterr().err


def test_ask_uses_proxy_when_available(ask_mod, monkeypatch):
    monkeypatch.setattr(
        ask_mod, "_chat_via_proxy",
        lambda model, messages, use_thinking: ("PROXY-OK", ""),
    )
    monkeypatch.setattr(
        ask_mod, "_chat_via_ollama",
        lambda *a, **k: pytest.fail("should not hit direct ollama when proxy works"),
    )
    out = ask_mod.ask("what is x?")
    assert out["answer"] == "PROXY-OK"


def test_litellm_config_has_openrouter_fallbacks():
    cfg = yaml.safe_load(open(CONFIG_PATH))
    names = [m["model_name"] for m in cfg["model_list"]]
    # openrouter siblings present, each with an os.environ key (no hard-coded key)
    siblings = [m for m in cfg["model_list"] if m["model_name"].endswith("-openrouter")]
    assert siblings, "expected -openrouter sibling aliases"
    for m in siblings:
        assert m["litellm_params"]["api_key"] == "os.environ/OPENROUTER_API_KEY"
        assert m["litellm_params"]["model"].startswith("openrouter/")
    # raw ask.py model names resolve as proxy aliases
    assert "qwen3:14b" in names
    assert "dolphin-llama3:8b" in names
    # fallbacks map each key→sibling, all resolvable
    fb = cfg["litellm_settings"]["fallbacks"]
    nameset = set(names)
    for entry in fb:
        (k, v), = entry.items()
        assert k in nameset and v[0] in nameset
    fbkeys = {list(e.keys())[0] for e in fb}
    assert "qwen3:14b" in fbkeys and "dolphin-llama3:8b" in fbkeys
