"""Settings blueprint — LLM engine selection, API key management, config persistence.

T-379: Settings page with engine selector and config persistence.
"""

import logging

import yaml
from flask import Blueprint, Response, jsonify, request

from web.config import Config
from web.shared import PROJECT_ROOT, render_page

log = logging.getLogger(__name__)

bp = Blueprint("settings", __name__)

SETTINGS_FILE = PROJECT_ROOT / ".context" / "settings.yaml"


def _load_settings() -> dict:
    """Load settings from YAML file."""
    if SETTINGS_FILE.exists():
        try:
            return yaml.safe_load(SETTINGS_FILE.read_text()) or {}
        except Exception:
            return {}
    return {}


def _save_settings(data: dict) -> None:
    """Save settings to YAML file."""
    SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
    SETTINGS_FILE.write_text(yaml.dump(data, default_flow_style=False))


@bp.route("/settings/")
def settings_page():
    """Render the settings page."""
    from web.llm import get_manager
    from web.secrets_store import list_configured_keys

    manager = get_manager()
    providers = manager.list_providers()
    keys = list_configured_keys()
    settings = _load_settings()

    return render_page(
        "settings.html",
        page_title="Settings",
        active_endpoint="settings.settings_page",
        providers=providers,
        active_provider=manager.active_name,
        api_keys=keys,
        settings=settings,
        primary_model=settings.get("primary_model", Config.PRIMARY_MODEL),
        fallback_model=settings.get("fallback_model", Config.FALLBACK_MODEL),
    )


@bp.route("/settings/save", methods=["POST"])
def save_settings():
    """Save settings via htmx."""
    from web.llm import get_manager

    provider = request.form.get("provider", "ollama")
    primary_model = request.form.get("primary_model", "").strip()
    fallback_model = request.form.get("fallback_model", "").strip()

    manager = get_manager()

    # Switch provider
    try:
        manager.switch(provider)
    except ValueError as e:
        return Response(f'<div class="notice error">{e}</div>', status=400)

    # Persist settings
    settings = _load_settings()
    settings["provider"] = provider
    if primary_model:
        settings["primary_model"] = primary_model
    if fallback_model:
        settings["fallback_model"] = fallback_model
    _save_settings(settings)

    return Response(
        '<div role="alert" style="padding:0.5rem 1rem;background:var(--pico-primary-focus);'
        'border-radius:var(--pico-border-radius);margin-top:0.5rem">'
        'Settings saved. Provider: <strong>{}</strong></div>'.format(provider)
    )


@bp.route("/settings/save-key", methods=["POST"])
def save_api_key():
    """Save an API key via htmx."""
    from web.secrets_store import set_api_key
    from web.llm.manager import _manager
    from web.llm.openrouter_provider import OpenRouterProvider

    name = request.form.get("key_name", "").strip()
    value = request.form.get("key_value", "").strip()

    if not name or not value:
        return Response(
            '<div role="alert" style="color:var(--pico-del-color)">Name and value required</div>',
            status=400,
        )

    set_api_key(name, value)

    # Hot-register OpenRouter if this is the first key
    if name == "openrouter" and _manager is not None:
        if not _manager.get("openrouter"):
            provider = OpenRouterProvider(api_key=value)
            _manager.register(provider)

    return Response(
        '<div role="alert" style="padding:0.5rem 1rem;background:var(--pico-primary-focus);'
        'border-radius:var(--pico-border-radius);margin-top:0.5rem">'
        'Key <strong>{}</strong> saved (encrypted)</div>'.format(name)
    )


@bp.route("/settings/delete-key", methods=["POST"])
def delete_api_key_route():
    """Delete an API key via htmx."""
    from web.secrets_store import delete_api_key

    name = request.form.get("key_name", "").strip()
    if name:
        delete_api_key(name)

    return Response(
        '<div role="alert" style="padding:0.5rem 1rem;background:var(--pico-primary-focus);'
        'border-radius:var(--pico-border-radius);margin-top:0.5rem">'
        'Key <strong>{}</strong> deleted</div>'.format(name)
    )


@bp.route("/settings/test-connection", methods=["POST"])
def test_connection():
    """Test if the active provider is reachable."""
    from web.llm import get_manager

    manager = get_manager()
    provider = manager.active

    if provider.is_available():
        models = provider.list_models()
        model_names = [m.id for m in models[:5]]
        return Response(
            '<div role="alert" style="padding:0.5rem 1rem;background:var(--pico-ins-color);'
            'color:#fff;border-radius:var(--pico-border-radius);margin-top:0.5rem">'
            'Connected to <strong>{}</strong>. {} models available: {}</div>'.format(
                manager.active_name, len(models), ", ".join(model_names)
            )
        )
    else:
        return Response(
            '<div role="alert" style="padding:0.5rem 1rem;background:var(--pico-del-color);'
            'color:#fff;border-radius:var(--pico-border-radius);margin-top:0.5rem">'
            'Cannot connect to <strong>{}</strong></div>'.format(manager.active_name)
        )


@bp.route("/settings/models")
def list_models():
    """Return model list for the active provider (htmx)."""
    from web.llm import get_manager

    manager = get_manager()
    models = manager.active.list_models()

    if not models:
        return Response("<option value=''>No models available</option>")

    options = []
    for m in models:
        options.append(f'<option value="{m.id}">{m.id}</option>')
    return Response("\n".join(options))
