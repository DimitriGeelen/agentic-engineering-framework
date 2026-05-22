"""Settings blueprint — LLM engine selection, API key management, config persistence.

T-379: Settings page with engine selector and config persistence.
"""

import logging
import re
import uuid

import yaml
from flask import Blueprint, Response, jsonify, request, session

from web.config import Config
from web.shared import PROJECT_ROOT, render_page

log = logging.getLogger(__name__)

bp = Blueprint("settings", __name__)

# ── arc-007 S1 (T-1988): appearance presets + per-user persistence ──────────
# The 6 named presets from the arc headline mechanic. Each is a curated combo
# over the S0 foundation axes (T-1991). Axis values MUST match foundations.css.
PALETTES = ("slate", "linen", "stone", "paper", "bone", "console")
TYPES = ("inter", "geist", "plex", "manrope", "newsreader", "system")
DENSITIES = ("compact", "cozy", "comfortable")
MODES = ("light", "dark")

PRESETS = {
    "calm":      {"label": "Calm",      "palette": "stone",   "type": "inter",      "density": "compact", "mode": "light"},
    "editorial": {"label": "Editorial", "palette": "linen",   "type": "newsreader", "density": "compact", "mode": "light"},
    "console":   {"label": "Console",   "palette": "console", "type": "plex",       "density": "compact", "mode": "dark"},
    "paper":     {"label": "Paper",     "palette": "paper",   "type": "geist",      "density": "compact", "mode": "light"},
    "bone":      {"label": "Bone",      "palette": "bone",    "type": "manrope",    "density": "compact", "mode": "light"},
    "midnight":  {"label": "Midnight",  "palette": "slate",   "type": "inter",      "density": "compact", "mode": "dark"},
}
DEFAULT_APPEARANCE = {"preset": "calm", "palette": "stone", "type": "inter", "density": "compact", "mode": "light"}

PREFS_DIR = PROJECT_ROOT / ".context" / "user-preferences"
_UID_RE = re.compile(r"^[0-9a-f]{32}$")


def _wt_uid() -> str:
    """Stable per-browser UID from the signed session cookie (tamper-proof via
    app.secret_key). Created lazily; constrained to 32 hex chars."""
    uid = session.get("wt_uid")
    if not uid or not _UID_RE.match(str(uid)):
        uid = uuid.uuid4().hex
        session["wt_uid"] = uid
    return uid


def _prefs_path(uid: str):
    """Path to a user's prefs file. uid MUST already match _UID_RE — guard here
    too so a forged/legacy session value can never escape PREFS_DIR (T-1988 sec)."""
    if not _UID_RE.match(str(uid)):
        raise ValueError("invalid uid")
    return PREFS_DIR / f"{uid}.yaml"


def _sanitise_appearance(raw: dict) -> dict:
    """Whitelist every field against the known axis sets. Unknown values fall
    back to the default — nothing untrusted reaches the YAML or an HTML attr."""
    out = dict(DEFAULT_APPEARANCE)
    preset = raw.get("preset")
    if preset in PRESETS:
        out.update({k: PRESETS[preset][k] for k in ("palette", "type", "density", "mode")})
        out["preset"] = preset
    else:
        out["preset"] = "custom"
    if raw.get("palette") in PALETTES:
        out["palette"] = raw["palette"]
    if raw.get("type") in TYPES:
        out["type"] = raw["type"]
    if raw.get("density") in DENSITIES:
        out["density"] = raw["density"]
    if raw.get("mode") in MODES:
        out["mode"] = raw["mode"]
    return out


def _load_appearance() -> dict:
    """Read the current user's appearance, defaulting cleanly. Never raises."""
    try:
        path = _prefs_path(_wt_uid())
    except Exception:
        return dict(DEFAULT_APPEARANCE)
    if path.exists():
        try:
            data = yaml.safe_load(path.read_text()) or {}
            return _sanitise_appearance({**DEFAULT_APPEARANCE, **(data.get("appearance") or {})})
        except Exception:
            return dict(DEFAULT_APPEARANCE)
    return dict(DEFAULT_APPEARANCE)


def _save_appearance(appearance: dict) -> dict:
    """Persist a sanitised appearance for the current user. Returns what was saved."""
    clean = _sanitise_appearance(appearance)
    path = _prefs_path(_wt_uid())
    PREFS_DIR.mkdir(parents=True, exist_ok=True)
    path.write_text(yaml.dump({"appearance": clean}, default_flow_style=False))
    return clean


@bp.app_context_processor
def inject_appearance():
    """Make wt_appearance available to every template (base.html <html> tag)."""
    try:
        return {"wt_appearance": _load_appearance()}
    except Exception:
        return {"wt_appearance": dict(DEFAULT_APPEARANCE)}

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

    # T-722: Notification status
    notify_config_path = PROJECT_ROOT / ".context" / "notify-config.yaml"
    notify_enabled = False
    if notify_config_path.exists():
        try:
            nc = yaml.safe_load(notify_config_path.read_text()) or {}
            notify_enabled = nc.get("enabled", False)
        except Exception:
            pass
    from pathlib import Path as _P
    dispatcher_path = "/opt/150-skills-manager/skills/alerts/alert_dispatcher.py"
    dispatcher_available = _P(dispatcher_path).exists()

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
        ollama_host=settings.get("ollama_host", Config.OLLAMA_HOST),
        notify_enabled=notify_enabled,
        dispatcher_available=dispatcher_available,
    )


@bp.route("/settings/save", methods=["POST"])
def save_settings():
    """Save settings via htmx."""
    from web.llm import get_manager

    provider = request.form.get("provider", "ollama")
    primary_model = request.form.get("primary_model", "").strip()
    fallback_model = request.form.get("fallback_model", "").strip()
    ollama_host = request.form.get("ollama_host", "").strip()

    manager = get_manager()

    # Update Ollama host if changed (T-390)
    if ollama_host and provider == "ollama":
        from web.llm.ollama_provider import OllamaProvider

        current = manager.get("ollama")
        if not current or getattr(current, "_host", "") != ollama_host:
            new_provider = OllamaProvider(host=ollama_host)
            manager.register(new_provider)  # replaces existing
            Config.OLLAMA_HOST = ollama_host
            log.info("Ollama host updated to %s", ollama_host)

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
    if ollama_host:
        settings["ollama_host"] = ollama_host
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

    fmt = request.args.get("format", "options")
    manager = get_manager()
    models = manager.active.list_models()

    if fmt == "datalist":
        # T-390: Return datalist options for autocomplete
        if not models:
            return Response("")
        options = [f'<option value="{m.id}">' for m in models]
        return Response("\n".join(options))

    if not models:
        return Response("<option value=''>No models available</option>")

    options = []
    for m in models:
        options.append(f'<option value="{m.id}">{m.id}</option>')
    return Response("\n".join(options))


# ── arc-007 S1 (T-1988): /settings/appearance ───────────────────────────────
@bp.route("/settings/appearance")
def appearance_page():
    """Render the appearance picker — 6 presets + per-axis foundation controls."""
    return render_page(
        "appearance.html",
        page_title="Appearance",
        active_endpoint="settings.appearance_page",
        presets=PRESETS,
        palettes=PALETTES,
        types=TYPES,
        densities=DENSITIES,
        modes=MODES,
        appearance=_load_appearance(),
    )


@bp.route("/settings/appearance/save", methods=["POST"])
def save_appearance():
    """Persist the chosen appearance for this browser (signed-cookie UID)."""
    raw = {
        "preset": request.form.get("preset", "").strip(),
        "palette": request.form.get("palette", "").strip(),
        "type": request.form.get("type", "").strip(),
        "density": request.form.get("density", "").strip(),
        "mode": request.form.get("mode", "").strip(),
    }
    saved = _save_appearance(raw)
    return jsonify({"ok": True, "appearance": saved})
