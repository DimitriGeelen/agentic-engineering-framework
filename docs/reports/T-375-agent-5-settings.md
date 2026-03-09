# Settings Page Design — Watchtower

## 1. Nav Placement

Add a gear icon to the right side of the nav bar, between Docs and Search:

```
[Logo] Watchtower | Work v | Knowledge v | Architecture v | Govern v | ··· | Docs | [gear] | [search]
```

Implementation in `base.html`, after the `nav-docs` `<li>` and before `nav-search`:

```html
<li class="nav-settings">
    <a href="{{ url_for('settings.settings_page') }}" title="Settings"
       {% if active_endpoint == 'settings.settings_page' %}aria-current="page"{% endif %}
       hx-target="#content" hx-swap="innerHTML" hx-push-url="true">
        <svg viewBox="0 0 24 24" aria-hidden="true" style="width:1rem;height:1rem;stroke:currentColor;stroke-width:2;fill:none;">
            <circle cx="12" cy="12" r="3"></circle>
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
        </svg>
    </a>
</li>
```

Add matching CSS in base.html `<style>`:

```css
nav.site-nav .nav-settings a {
    display: flex; align-items: center;
    padding: 0.4rem 0.6rem;
    text-decoration: none;
    color: var(--pico-color);
    border-radius: var(--pico-border-radius);
    font-size: 0.925rem;
}
nav.site-nav .nav-settings a:hover {
    background: var(--pico-primary-focus);
}
```

---

## 2. Page Layout: Single Scrollable Page with Sections

**Recommendation: Single scrollable page with `<article>` cards per section (NOT tabs).**

Rationale:
- Consistent with existing Watchtower pages (metrics, enforcement, quality all use card-based sections)
- Pico CSS has no built-in tab component — building one adds JS complexity for marginal UX gain
- Settings are few enough (~10 fields) that a single page is scannable
- htmx form submission works naturally per-section without tab-state management

Sections:
1. **LLM Engine** — Engine selector + engine-specific config
2. **Models** — Model selection per role (primary, fallback, embedding, reranker)
3. **Search** — Default search mode, thinking mode toggle
4. **Connection** — Timeouts, host URLs

---

## 3. ASCII Wireframe

### State A: Local/Ollama Selected (default)

```
┌─────────────────────────────────────────────────────────┐
│ Settings                                                │
│ Configure Watchtower's LLM engine and search behavior.  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ┌─── LLM Engine ──────────────────────────────────────┐ │
│ │                                                     │ │
│ │  Engine                                             │ │
│ │  (●) Local (Ollama)    ( ) Cloud (OpenRouter)       │ │
│ │                                                     │ │
│ │  Ollama Host                                        │ │
│ │  ┌──────────────────────────────────────────┐       │ │
│ │  │ http://192.168.10.107:11434              │       │ │
│ │  └──────────────────────────────────────────┘       │ │
│ │                                                     │ │
│ │  Timeout (seconds)                                  │ │
│ │  ┌───────┐                                          │ │
│ │  │ 120   │                                          │ │
│ │  └───────┘                                          │ │
│ │                                                     │ │
│ │  Connection     [Test Connection]                    │ │
│ │  ✓ Connected — 3 models available                   │ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─── Models ──────────────────────────────────────────┐ │
│ │                                                     │ │
│ │  Primary Model          Fallback Model              │ │
│ │  ┌──────────────v─┐     ┌──────────────v─┐          │ │
│ │  │ qwen3:14b      │     │ dolphin-llama3 │          │ │
│ │  └────────────────┘     └────────────────┘          │ │
│ │                                                     │ │
│ │  Embedding Model        Reranker Model              │ │
│ │  ┌──────────────v─┐     ┌──────────────v─┐          │ │
│ │  │ nomic-embed... │     │ dengcao/Qwen3..│          │ │
│ │  └────────────────┘     └────────────────┘          │ │
│ │                                                     │ │
│ │  [Refresh Models]  (fetches from Ollama)            │ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─── Search ──────────────────────────────────────────┐ │
│ │                                                     │ │
│ │  Default Search Mode                                │ │
│ │  ┌──────────────v─┐                                 │ │
│ │  │ Keyword (BM25) │                                 │ │
│ │  └────────────────┘                                 │ │
│ │                                                     │ │
│ │  Thinking Mode                                      │ │
│ │  [■] Enable thinking mode for Ask Q&A               │ │
│ │  <small>Uses /think prefix — slower but better      │ │
│ │  reasoning. Requires model support.</small>          │ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│  ┌─────────────┐                                       │
│  │ Save Changes│                                       │
│  └─────────────┘                                       │
│                                                         │
│  <small>Settings override defaults but are             │
│  overridden by environment variables.</small>           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### State B: Cloud/OpenRouter Selected

```
┌─── LLM Engine ──────────────────────────────────────────┐
│                                                         │
│  Engine                                                 │
│  ( ) Local (Ollama)    (●) Cloud (OpenRouter)           │
│                                                         │
│  API Key                                                │
│  ┌──────────────────────────────────────┐  [Show/Hide]  │
│  │ ●●●●●●●●●●●●●●●●●●●●●●●●●●●●sk-4f2e│               │
│  └──────────────────────────────────────┘               │
│  <small>Stored locally. Never sent to Watchtower       │
│  server — passed directly to OpenRouter API.</small>    │
│                                                         │
│  Connection     [Test Connection]                       │
│  ✓ Valid key — 200+ models available                    │
│                                                         │
└─────────────────────────────────────────────────────────┘

┌─── Models ──────────────────────────────────────────────┐
│                                                         │
│  Primary Model                                          │
│  ┌────────────────────────────────────v─┐               │
│  │ anthropic/claude-3.5-sonnet          │               │
│  ├──────────────────────────────────────┤               │
│  │ anthropic/claude-3.5-sonnet          │               │
│  │ openai/gpt-4o                        │               │
│  │ google/gemini-pro-1.5                │               │
│  │ meta-llama/llama-3.1-70b            │               │
│  │ ...                                  │               │
│  └──────────────────────────────────────┘               │
│                                                         │
│  <small>Embedding and reranker models not available     │
│  via OpenRouter. Semantic search requires Ollama.</small>│
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 4. Config Persistence

**Recommendation: YAML file at `{PROJECT_ROOT}/.context/settings.yaml` (gitignored)**

Rationale:
- Consistent with existing `.context/` convention (working memory, project memory all use YAML)
- YAML is human-readable and editable (framework convention)
- `.context/` is already in `.gitignore` — API keys stay local
- No new dependency (no SQLite for this — overkill for ~10 fields)
- JSON would work but YAML is the framework's lingua franca

### File Format

```yaml
# Watchtower settings — managed via /settings UI
# These override defaults but environment variables override these.
# Precedence: env var > settings.yaml > Config defaults

engine: ollama  # ollama | openrouter

ollama:
  host: "http://192.168.10.107:11434"
  timeout: 120

openrouter:
  api_key: "sk-or-v1-..."  # stored in plaintext — file is gitignored

models:
  primary: "qwen3:14b"
  fallback: "dolphin-llama3:8b"
  embedding: "nomic-embed-text-v2-moe"
  reranker: "dengcao/Qwen3-Reranker-0.6B"

search:
  default_mode: "keyword"  # keyword | semantic | hybrid
  thinking_enabled: false
```

### Precedence Chain

```
1. Environment variable (FW_PRIMARY_MODEL, OLLAMA_HOST, etc.)
2. settings.yaml value
3. Config class default
```

Implementation: Modify `web/config.py` to load settings.yaml at startup:

```python
class Config:
    _settings = _load_settings()  # load from .context/settings.yaml

    @staticmethod
    def _load_settings():
        path = _PROJECT_ROOT / ".context" / "settings.yaml"
        if path.exists():
            with open(path) as f:
                return yaml.safe_load(f) or {}
        return {}

    # Precedence: env > settings > default
    OLLAMA_HOST = os.environ.get("OLLAMA_HOST") or _settings.get("ollama", {}).get("host") or "http://localhost:11434"
    # ... etc for each field
```

### Hot Reload

Settings changes should take effect without restart:
- The settings blueprint saves to YAML on POST
- A module-level `reload_settings()` function re-reads the file
- Called after successful save
- Blueprint routes that need current config read from the reloaded values

---

## 5. Engine Selector Interaction Flow

### Radio Button Selection (htmx-powered)

```html
<fieldset>
    <legend>Engine</legend>
    <label>
        <input type="radio" name="engine" value="ollama"
               {% if engine == 'ollama' %}checked{% endif %}
               hx-get="/settings/engine-fields?engine=ollama"
               hx-target="#engine-fields"
               hx-swap="innerHTML">
        Local (Ollama)
    </label>
    <label>
        <input type="radio" name="engine" value="openrouter"
               {% if engine == 'openrouter' %}checked{% endif %}
               hx-get="/settings/engine-fields?engine=openrouter"
               hx-target="#engine-fields"
               hx-swap="innerHTML">
        Cloud (OpenRouter)
    </label>
</fieldset>
<div id="engine-fields">
    {% include "_settings_ollama_fields.html" if engine == 'ollama' else "_settings_openrouter_fields.html" %}
</div>
```

### Test Connection Flow

```
User clicks [Test Connection]
  → htmx POST /settings/test-connection { engine, host/api_key }
  → Server tries:
       Ollama: ollama.list() against specified host
       OpenRouter: GET https://openrouter.ai/api/v1/models with API key header
  → Returns HTML fragment:
       Success: ✓ Connected — N models available (green)
       Failure: ✗ Connection failed: <error> (red)
  → htmx swaps into #connection-status span
```

### Model Dropdown Population

For Ollama:
```
Page load or [Refresh Models] click
  → htmx GET /settings/models?engine=ollama
  → Server: ollama.list() → extract model names
  → Returns <option> elements
  → htmx swaps into <select> elements
```

For OpenRouter:
```
After successful API key test
  → htmx GET /settings/models?engine=openrouter&api_key=...
  → Server: GET https://openrouter.ai/api/v1/models
  → Returns <option> elements grouped by provider
  → htmx swaps into <select> elements
```

### API Key Input

```html
<div style="display:flex; gap:0.5rem; align-items:end;">
    <input type="password" id="api-key" name="openrouter_api_key"
           value="{{ masked_key }}" placeholder="sk-or-v1-..."
           style="flex:1; font-family:monospace;">
    <button type="button" onclick="toggleKeyVisibility()" class="outline secondary"
            style="white-space:nowrap;">Show</button>
</div>
<small>Last 4 chars shown when saved. Full key stored locally in .context/settings.yaml</small>
```

Toggle JS:
```javascript
function toggleKeyVisibility() {
    var input = document.getElementById('api-key');
    var btn = event.target;
    if (input.type === 'password') {
        input.type = 'text';
        btn.textContent = 'Hide';
    } else {
        input.type = 'password';
        btn.textContent = 'Show';
    }
}
```

---

## 6. Flask Implementation Outline

### New Blueprint: `web/blueprints/settings.py`

```python
"""Settings blueprint — user-configurable Watchtower settings."""

import yaml
from flask import Blueprint, request, jsonify
from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("settings", __name__, url_prefix="/settings")

SETTINGS_PATH = PROJECT_ROOT / ".context" / "settings.yaml"

def _load_settings():
    """Load settings from YAML, return dict with defaults."""
    defaults = {
        "engine": "ollama",
        "ollama": {"host": "http://localhost:11434", "timeout": 120},
        "openrouter": {"api_key": ""},
        "models": {
            "primary": "qwen3:14b",
            "fallback": "dolphin-llama3:8b",
            "embedding": "nomic-embed-text-v2-moe",
            "reranker": "dengcao/Qwen3-Reranker-0.6B",
        },
        "search": {"default_mode": "keyword", "thinking_enabled": False},
    }
    if SETTINGS_PATH.exists():
        with open(SETTINGS_PATH) as f:
            saved = yaml.safe_load(f) or {}
        # Deep merge saved into defaults
        _deep_merge(defaults, saved)
    return defaults

def _save_settings(settings):
    """Write settings to YAML file."""
    SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(SETTINGS_PATH, "w") as f:
        yaml.dump(settings, f, default_flow_style=False, sort_keys=False)

def _mask_key(key):
    """Mask API key, showing only last 4 characters."""
    if not key or len(key) < 8:
        return ""
    return "●" * (len(key) - 4) + key[-4:]


@bp.route("/")
def settings_page():
    """Render the settings page."""
    settings = _load_settings()
    # Check which values are env-overridden
    env_overrides = _detect_env_overrides()
    return render_page(
        "settings.html",
        page_title="Settings",
        settings=settings,
        masked_key=_mask_key(settings.get("openrouter", {}).get("api_key", "")),
        env_overrides=env_overrides,
    )


@bp.route("/save", methods=["POST"])
def save_settings():
    """Save settings from form POST."""
    settings = _load_settings()
    # Update from form data
    settings["engine"] = request.form.get("engine", "ollama")
    settings["ollama"]["host"] = request.form.get("ollama_host", settings["ollama"]["host"])
    settings["ollama"]["timeout"] = int(request.form.get("ollama_timeout", 120))
    # Only update API key if a new one was provided (not the masked placeholder)
    new_key = request.form.get("openrouter_api_key", "")
    if new_key and not new_key.startswith("●"):
        settings["openrouter"]["api_key"] = new_key
    settings["models"]["primary"] = request.form.get("model_primary", settings["models"]["primary"])
    settings["models"]["fallback"] = request.form.get("model_fallback", settings["models"]["fallback"])
    settings["models"]["embedding"] = request.form.get("model_embedding", settings["models"]["embedding"])
    settings["models"]["reranker"] = request.form.get("model_reranker", settings["models"]["reranker"])
    settings["search"]["default_mode"] = request.form.get("search_mode", "keyword")
    settings["search"]["thinking_enabled"] = request.form.get("thinking_enabled") == "on"

    _save_settings(settings)
    _reload_runtime_config(settings)

    # Return toast-triggering response for htmx
    return '<div hx-swap-oob="true" id="save-status">Settings saved successfully.</div>', 200


@bp.route("/test-connection", methods=["POST"])
def test_connection():
    """Test connection to the selected engine."""
    engine = request.form.get("engine", "ollama")
    if engine == "ollama":
        host = request.form.get("host", "http://localhost:11434")
        return _test_ollama(host)
    elif engine == "openrouter":
        api_key = request.form.get("api_key", "")
        return _test_openrouter(api_key)
    return '<span style="color:#c62828;">Unknown engine</span>'


@bp.route("/engine-fields")
def engine_fields():
    """Return engine-specific form fields (htmx partial)."""
    engine = request.args.get("engine", "ollama")
    settings = _load_settings()
    if engine == "openrouter":
        return render_template("_settings_openrouter_fields.html",
                               settings=settings,
                               masked_key=_mask_key(settings["openrouter"]["api_key"]))
    return render_template("_settings_ollama_fields.html", settings=settings)


@bp.route("/models")
def list_models():
    """Fetch available models from the selected engine."""
    engine = request.args.get("engine", "ollama")
    if engine == "ollama":
        return _fetch_ollama_models()
    elif engine == "openrouter":
        return _fetch_openrouter_models()
    return "<option>No models</option>"
```

### Routes Summary

| Method | Route                    | Purpose                              | Response        |
|--------|--------------------------|--------------------------------------|-----------------|
| GET    | /settings/               | Render settings page                 | Full page/htmx  |
| POST   | /settings/save           | Save settings to YAML                | htmx fragment   |
| POST   | /settings/test-connection| Test engine connectivity             | HTML fragment    |
| GET    | /settings/engine-fields  | Swap engine-specific fields          | HTML fragment    |
| GET    | /settings/models         | Fetch available models from engine   | `<option>` list  |

### Template: `web/templates/settings.html`

Structure following existing page pattern:

```html
<div class="page-header">
    <h1>{{ page_title }}</h1>
    <p>Configure Watchtower's LLM engine, models, and search behavior.</p>
</div>

<form hx-post="{{ url_for('settings.save_settings') }}"
      hx-swap="none" hx-on::after-request="showToast('Settings saved', 'success')">

    <!-- Section 1: LLM Engine -->
    <article>
        <header><strong>LLM Engine</strong></header>
        <!-- Engine radio buttons with hx-get for field swapping -->
        <!-- #engine-fields div with conditional Ollama/OpenRouter inputs -->
        <!-- Test Connection button + status -->
    </article>

    <!-- Section 2: Models -->
    <article>
        <header><strong>Models</strong></header>
        <!-- 2x2 grid of model dropdowns -->
        <!-- Refresh Models button -->
    </article>

    <!-- Section 3: Search -->
    <article>
        <header><strong>Search Preferences</strong></header>
        <!-- Default mode select -->
        <!-- Thinking mode checkbox -->
    </article>

    <!-- Env override notice -->
    {% if env_overrides %}
    <small style="color: var(--pico-muted-color);">
        Some settings are overridden by environment variables:
        {{ env_overrides | join(', ') }}. These cannot be changed here.
    </small>
    {% endif %}

    <button type="submit">Save Changes</button>
    <div id="save-status"></div>
</form>
```

### Partial Templates

- `_settings_ollama_fields.html` — Ollama host input, timeout input
- `_settings_openrouter_fields.html` — API key input with show/hide, masked display

### Registration in `app.py`

Add to the blueprint registration section:

```python
from web.blueprints.settings import bp as settings_bp
app.register_blueprint(settings_bp)
```

---

## 7. Environment Variable Override Detection

Show a lock icon or disabled state for fields that are env-overridden:

```python
def _detect_env_overrides():
    """Return list of setting names overridden by env vars."""
    overrides = []
    env_map = {
        "OLLAMA_HOST": "Ollama Host",
        "FW_PRIMARY_MODEL": "Primary Model",
        "FW_FALLBACK_MODEL": "Fallback Model",
        "FW_EMBEDDING_MODEL": "Embedding Model",
        "FW_RERANKER_MODEL": "Reranker Model",
        "FW_OLLAMA_TIMEOUT": "Timeout",
    }
    for var, label in env_map.items():
        if os.environ.get(var):
            overrides.append(label)
    return overrides
```

In the template, env-overridden fields get `disabled` + a lock tooltip:

```html
{% if "Primary Model" in env_overrides %}
<select disabled title="Overridden by FW_PRIMARY_MODEL env var">
    <option>{{ settings.models.primary }} (env)</option>
</select>
{% else %}
<select name="model_primary">...</select>
{% endif %}
```

---

## 8. Runtime Config Reload

After saving, update the running Flask app's config without restart:

```python
def _reload_runtime_config(settings):
    """Update runtime config from saved settings."""
    from flask import current_app
    from web.config import Config

    # Only override if no env var set
    if not os.environ.get("OLLAMA_HOST"):
        Config.OLLAMA_HOST = settings["ollama"]["host"]
    if not os.environ.get("FW_PRIMARY_MODEL"):
        Config.PRIMARY_MODEL = settings["models"]["primary"]
    # ... etc

    # Update ollama client host
    import ollama
    ollama_host = os.environ.get("OLLAMA_HOST") or settings["ollama"]["host"]
    # ollama library reads OLLAMA_HOST from env; for runtime override,
    # set it in process env
    os.environ["OLLAMA_HOST"] = ollama_host
```

---

## 9. Security Considerations

1. **API key storage**: Plaintext in `.context/settings.yaml` which is gitignored. Acceptable for local dev tool. Add a comment in the file warning about this.

2. **API key in POST**: Sent over localhost HTTP, acceptable for local dev. In production (Traefik with HTTPS), encrypted in transit.

3. **CSRF**: All POST endpoints are protected by existing CSRF middleware in `app.py`. htmx sends `X-CSRF-Token` header automatically via the existing `htmx:configRequest` listener in base.html.

4. **API key never in URL**: Test connection uses POST body, not query params. Model fetch for OpenRouter should also use POST or store the key server-side after save.

5. **Masked display**: When rendering saved key, show `●●●●●●sk-4f2e`. When POSTing, skip masked values (don't overwrite real key with dots).

---

## 10. Implementation Order

1. **Config persistence** — `_load_settings()`, `_save_settings()`, settings.yaml format
2. **Blueprint skeleton** — `/settings/` GET route, basic template with all sections
3. **Engine selector** — Radio buttons + htmx field swap
4. **Save endpoint** — POST handler, toast feedback
5. **Test connection** — Ollama test, OpenRouter test
6. **Model dropdowns** — Dynamic population from engines
7. **Env override detection** — Lock/disable overridden fields
8. **Runtime reload** — Config hot-reload after save
9. **Nav integration** — Gear icon in base.html
10. **Config.py integration** — Make Config class read from settings.yaml as fallback

---

## 11. Files to Create/Modify

### New Files
- `web/blueprints/settings.py` — Settings blueprint
- `web/templates/settings.html` — Main settings page
- `web/templates/_settings_ollama_fields.html` — Ollama engine fields partial
- `web/templates/_settings_openrouter_fields.html` — OpenRouter engine fields partial

### Modified Files
- `web/app.py` — Register settings blueprint
- `web/templates/base.html` — Add gear icon to nav
- `web/config.py` — Add settings.yaml loading as fallback
- `web/shared.py` — No changes needed (settings not in nav groups — it's a utility page)

### Generated Files (runtime)
- `.context/settings.yaml` — User settings (gitignored, created on first save)
