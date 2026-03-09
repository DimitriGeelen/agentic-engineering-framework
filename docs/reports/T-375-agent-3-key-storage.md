# API Key Storage Research for Watchtower

## Context Summary

- **App**: Flask web UI (Watchtower), single-user developer tool
- **Production**: systemd service on LXC 170 (Ubuntu), gunicorn on :5050/:5051
- **Dev**: localhost:3000 via `fw serve`
- **Current config**: `web/config.py` reads `os.environ` for all settings
- **Already installed**: `cryptography` (41.0.7), `python-dotenv` (1.1.1)
- **NOT installed**: `keyring`
- **Git protection**: `.gitignore` exists but minimal (no `.env` rule currently)
- **requirements.txt**: flask, gunicorn, pyyaml, ruamel.yaml, markdown2, bleach, ollama, sqlite-vec, tantivy
- **machine-id available**: `/etc/machine-id` exists (tested: `c1db32d067464686a530ef500a648293`)
- **Fernet verified working**: encrypt/decrypt roundtrip confirmed with PBKDF2 key derivation from machine-id

---

## Option Comparison

| Criterion | A: keyring | B: Fernet encrypted file | C: .env + dotenv | D: SQLite encrypted | E: Hybrid (env + Fernet) |
|-----------|-----------|-------------------------|-------------------|---------------------|--------------------------|
| **Git safety** | Excellent (no file) | Good (encrypted file safe to commit, but gitignore anyway) | Moderate (relies on .gitignore) | Good (encrypted values) | Good |
| **Headless server** | Problematic (needs dbus + gnome-keyring daemon) | Excellent (pure Python) | Excellent | Excellent | Excellent |
| **systemd compat** | Uncertain (dbus session issues) | Excellent | Excellent | Excellent | Excellent |
| **Web UI settable** | Complex (subprocess + dbus) | Simple (read/write file) | No (requires restart) | Simple (SQL insert) | Partial |
| **New dependencies** | keyring + gnome-keyring-daemon | None (cryptography already installed) | None (python-dotenv already installed) | None (sqlite3 built-in) | None |
| **Complexity** | High (OS integration, backend selection, dbus) | Low-Medium | Very Low | Medium | Medium |
| **Key management** | OS handles it | Need to derive/store encryption key | N/A (plaintext) | Need to derive/store encryption key | Mixed |
| **Portability** | Poor (backend varies by OS) | Excellent | Excellent | Excellent | Excellent |
| **Encryption at rest** | Yes (OS keychain) | Yes (AES-128-CBC + HMAC) | No (plaintext) | Yes (Fernet per-value) | Partial |

---

## Detailed Analysis

### Option A: Python `keyring` — NOT RECOMMENDED

**Why it fails our use case:**

1. **Headless Linux is the hard case.** On a headless Ubuntu LXC:
   - No GNOME desktop → no gnome-keyring daemon running
   - Need to install `gnome-keyring` package + configure dbus session
   - systemd services don't have a user dbus session by default
   - GNOME Keyring 46+ can run without X11, but still needs dbus socket activation configured
   - The `keyrings.alt` package provides a plaintext fallback — which defeats the purpose

2. **Dependency weight:** `keyring` pulls in `jaraco.classes`, `jaraco.context`, `jaraco.functools`, `importlib-metadata` on older Python, plus the OS-level `gnome-keyring` or `libsecret` packages.

3. **Web UI integration:** Calling `keyring.set_password()` from a Flask route that runs under gunicorn requires the gunicorn worker to have access to the dbus session — fragile setup.

4. **Portability:** Different backends per OS (macOS Keychain, Windows Credential Locker, Linux SecretService). Testing and debugging varies per platform.

**Verdict:** Over-engineered for a single-user developer tool. The complexity-to-security ratio is terrible for our threat model.

### Option B: Fernet Encrypted File — RECOMMENDED

**How it works:**

1. Derive a Fernet encryption key from `/etc/machine-id` using PBKDF2-HMAC-SHA256 (600K iterations)
2. Store encrypted API keys in `.context/secrets/api-keys.enc` (a JSON blob, encrypted as a whole)
3. The file is machine-bound: copying it to another machine won't decrypt it
4. Already tested: roundtrip encrypt/decrypt works with current `cryptography` package

**Key derivation (tested and working):**
```python
import hashlib, base64
from cryptography.fernet import Fernet

def _derive_key() -> bytes:
    """Derive Fernet key from machine-id (deterministic, no stored key)."""
    machine_id = open("/etc/machine-id").read().strip()
    dk = hashlib.pbkdf2_hmac(
        "sha256",
        machine_id.encode(),
        b"watchtower-secrets-v1",  # application-specific salt
        600_000,  # OWASP 2024 minimum for PBKDF2-SHA256
        dklen=32,
    )
    return base64.urlsafe_b64encode(dk)
```

**Pros:**
- Zero new dependencies (cryptography 41.0.7 already installed)
- Works perfectly on headless Linux, in systemd services, in containers
- Machine-bound: encrypted file is useless if exfiltrated without machine-id
- Simple implementation (~80 lines of Python)
- Easy to set from web UI (just encrypt and write)
- Deterministic key: no key file to manage, lose, or backup

**Cons:**
- `/etc/machine-id` is readable by any user on the system (but attacker needs both the machine-id AND the encrypted file AND knowledge of the salt/iteration count)
- If the machine-id changes (LXC recreation, migration), keys are lost → need to re-enter
- Not suitable for multi-machine deployment (each machine derives its own key)

**Security properties against our threat model:**
- ✅ Git commit protection: encrypted file is gibberish, AND gitignored
- ✅ Casual file access: need machine-id + knowledge of derivation to decrypt
- ✅ Headless server: pure Python, no OS services needed
- ✅ systemd service: works identically in any process context

### Option C: .env + python-dotenv — ADEQUATE BUT LIMITED

**Current state:** python-dotenv is installed but not used in config.py. Config reads raw `os.environ`.

**Pros:**
- Simplest possible approach
- Well-understood pattern
- Already have python-dotenv installed

**Cons:**
- Plaintext on disk (anyone who can read the file has the keys)
- Cannot be set from web UI without restarting the app
- Relies entirely on `.gitignore` for git safety (single point of failure)
- No encryption at rest

**Verdict:** Fine for non-sensitive config (model names, ports). Not appropriate for API keys that cost money if leaked.

### Option D: SQLite Encrypted Store

**Pros:**
- Could reuse existing sqlite-vec database infrastructure
- SQL queries for key management
- Fernet encryption per-value before storage

**Cons:**
- SQLite database files are binary blobs in git (not .gitignored by default)
- Need to either gitignore the secrets db or mix secrets with other data
- More moving parts than a simple encrypted file
- The sqlite-vec database is for embeddings, not config — mixing concerns

**Verdict:** Over-engineered. A separate secrets.db adds complexity without benefit over Option B.

### Option E: Hybrid (env vars for deployment + Fernet for UI-set keys)

**This is Option B with a graceful fallback:**

1. Check environment variable first: `OPENROUTER_API_KEY` (set via systemd unit file)
2. If not in env, check encrypted file: `.context/secrets/api-keys.enc`
3. Web UI writes to the encrypted file
4. Environment variables take precedence (ops can override without touching the UI)

**This is the recommended approach** — it's Option B with the added benefit that existing env-var-based deployments don't break.

---

## RECOMMENDATION: Option E (Hybrid)

Implement Option B (Fernet encrypted file) with env-var fallback, creating the recommended approach (Option E).

### Architecture

```
┌──────────────────┐     ┌──────────────────────┐
│ Settings Page    │     │ systemd env vars     │
│ (web UI)         │     │ (EnvironmentFile=)   │
│                  │     │                      │
│  Set/view keys   │     │  OPENROUTER_API_KEY  │
│        │         │     │        │             │
│        ▼         │     │        ▼             │
│  Fernet encrypt  │     │  os.environ lookup   │
│        │         │     │        │             │
└────────┼─────────┘     └────────┼─────────────┘
         │                        │
         ▼                        │
  .context/secrets/               │
  api-keys.enc                    │
  (encrypted JSON)                │
         │                        │
         ▼                        ▼
  ┌──────────────────────────────────────┐
  │         get_api_key("openrouter")    │
  │  1. Check os.environ (takes priority)│
  │  2. Check encrypted file             │
  │  3. Return None if neither set       │
  └──────────────────────────────────────┘
```

### Implementation Sketch

#### 1. New module: `web/secrets_store.py` (~80 lines)

```python
"""
Encrypted API key storage for Watchtower.

Keys are encrypted with Fernet using a key derived from /etc/machine-id.
Storage file: .context/secrets/api-keys.enc
Environment variables take precedence over stored keys.
"""

import base64
import hashlib
import json
import os
from pathlib import Path
from cryptography.fernet import Fernet, InvalidToken

_SALT = b"watchtower-secrets-v1"
_ITERATIONS = 600_000
_SECRETS_DIR = Path(__file__).resolve().parent.parent / ".context" / "secrets"
_SECRETS_FILE = _SECRETS_DIR / "api-keys.enc"

# Map of key names to environment variable names
_ENV_MAP = {
    "openrouter": "OPENROUTER_API_KEY",
    "openai": "OPENAI_API_KEY",
}


def _derive_key() -> bytes:
    """Derive Fernet key from machine-id."""
    try:
        machine_id = Path("/etc/machine-id").read_text().strip()
    except FileNotFoundError:
        # macOS fallback: use IOPlatformUUID
        import subprocess
        result = subprocess.run(
            ["ioreg", "-rd1", "-c", "IOPlatformExpertDevice"],
            capture_output=True, text=True
        )
        for line in result.stdout.splitlines():
            if "IOPlatformUUID" in line:
                machine_id = line.split('"')[-2]
                break
        else:
            raise RuntimeError("Cannot determine machine identity")

    dk = hashlib.pbkdf2_hmac("sha256", machine_id.encode(), _SALT, _ITERATIONS, dklen=32)
    return base64.urlsafe_b64encode(dk)


def _get_fernet() -> Fernet:
    return Fernet(_derive_key())


def _load_store() -> dict:
    """Load and decrypt the key store. Returns empty dict if not found."""
    if not _SECRETS_FILE.exists():
        return {}
    try:
        encrypted = _SECRETS_FILE.read_bytes()
        decrypted = _get_fernet().decrypt(encrypted)
        return json.loads(decrypted)
    except (InvalidToken, json.JSONDecodeError):
        return {}


def _save_store(data: dict) -> None:
    """Encrypt and save the key store."""
    _SECRETS_DIR.mkdir(parents=True, exist_ok=True)
    plaintext = json.dumps(data).encode()
    encrypted = _get_fernet().encrypt(plaintext)
    _SECRETS_FILE.write_bytes(encrypted)
    # Restrict permissions (owner read/write only)
    _SECRETS_FILE.chmod(0o600)


def get_api_key(name: str) -> str | None:
    """Get an API key. Environment variable takes precedence."""
    env_var = _ENV_MAP.get(name)
    if env_var:
        env_val = os.environ.get(env_var)
        if env_val:
            return env_val
    store = _load_store()
    return store.get(name)


def set_api_key(name: str, value: str) -> None:
    """Store an API key (encrypted)."""
    store = _load_store()
    store[name] = value
    _save_store(store)


def delete_api_key(name: str) -> None:
    """Remove an API key from the store."""
    store = _load_store()
    store.pop(name, None)
    _save_store(store)


def list_configured_keys() -> dict[str, str]:
    """Return dict of {name: source} for all configured keys.

    source is 'env' or 'stored'. Values are NOT returned.
    """
    result = {}
    store = _load_store()
    for name in _ENV_MAP:
        env_var = _ENV_MAP[name]
        if os.environ.get(env_var):
            result[name] = "env"
        elif name in store:
            result[name] = "stored"
    # Also include any stored keys not in _ENV_MAP
    for name in store:
        if name not in result:
            result[name] = "stored"
    return result


def mask_key(key: str) -> str:
    """Return masked version of a key for display: sk-...last4"""
    if len(key) <= 8:
        return "****"
    return key[:3] + "..." + key[-4:]
```

#### 2. New blueprint: `web/blueprints/settings.py`

Routes:
- `GET /settings` — Show settings page with configured key status
- `POST /settings/api-keys` — Set/update an API key
- `DELETE /settings/api-keys/<name>` — Remove a stored key
- `POST /settings/api-keys/test` — Test an API key (make a minimal API call)

The settings page would show:
- For each provider (OpenRouter, OpenAI):
  - Status: "Set (from environment)", "Set (stored)", or "Not configured"
  - If set: masked key display (sk-...last4)
  - Input field to set/update
  - Delete button (only for stored keys, not env vars)
  - Test button

#### 3. Git protection

Add to `.gitignore`:
```
# Encrypted secrets (machine-bound, but defense in depth)
.context/secrets/
```

Add to `.context/secrets/.gitignore` (belt AND suspenders):
```
*
!.gitignore
```

#### 4. Settings page template: `web/templates/settings.html`

```html
<h2>API Keys</h2>
<p>Keys set via environment variables take precedence over stored keys.</p>

{% for provider in providers %}
<article>
  <h3>{{ provider.display_name }}</h3>
  <p>
    Status:
    {% if provider.source == 'env' %}
      <mark>Set (environment variable: {{ provider.env_var }})</mark>
    {% elif provider.source == 'stored' %}
      <mark>Set (encrypted storage)</mark> — {{ provider.masked }}
      <button hx-delete="/settings/api-keys/{{ provider.name }}"
              hx-confirm="Remove this key?">Remove</button>
    {% else %}
      <span class="secondary">Not configured</span>
    {% endif %}
  </p>

  {% if provider.source != 'env' %}
  <form hx-post="/settings/api-keys" hx-swap="innerHTML" hx-target="#result-{{ provider.name }}">
    <input type="hidden" name="_csrf_token" value="{{ csrf_token() }}">
    <input type="hidden" name="provider" value="{{ provider.name }}">
    <input type="password" name="api_key" placeholder="Enter API key" required>
    <button type="submit">Save</button>
  </form>
  {% endif %}

  {% if provider.source %}
  <button hx-post="/settings/api-keys/test"
          hx-vals='{"provider": "{{ provider.name }}", "_csrf_token": "{{ csrf_token() }}"}'>
    Test Connection
  </button>
  {% endif %}
  <div id="result-{{ provider.name }}"></div>
</article>
{% endfor %}
```

#### 5. Config integration

In `web/config.py`, add a method to retrieve API keys:

```python
# Add to Config class or as module-level helper
@staticmethod
def get_llm_api_key(provider: str) -> str | None:
    from web.secrets_store import get_api_key
    return get_api_key(provider)
```

#### 6. Migration path

1. **Existing env-var deployments continue to work** — env vars take precedence
2. **systemd services** can use `EnvironmentFile=/etc/watchtower/env` for ops-managed keys
3. **Web UI** provides a second path for setting keys (useful for dev, useful when ops isn't involved)
4. **No migration needed** — the encrypted store starts empty, env vars keep working

For production (LXC 170), the recommended flow:
- Create `/etc/watchtower/env` with `OPENROUTER_API_KEY=sk-or-...`
- Reference in systemd unit: `EnvironmentFile=/etc/watchtower/env`
- Or: use the Watchtower settings page to store keys in the encrypted file

### File changes summary

| File | Action | Purpose |
|------|--------|---------|
| `web/secrets_store.py` | Create | Core encrypted storage module (~80 lines) |
| `web/blueprints/settings.py` | Create | Settings page blueprint (~60 lines) |
| `web/templates/settings.html` | Create | Settings page template (~50 lines) |
| `web/app.py` | Edit | Register settings blueprint |
| `web/shared.py` | Edit | Add Settings to NAV_ITEMS |
| `web/config.py` | Edit | Add `get_llm_api_key()` helper |
| `.gitignore` | Edit | Add `.context/secrets/` |
| `web/requirements.txt` | No change | cryptography already installed as transitive dep |

### Security notes

1. **machine-id stability**: In an LXC container, `/etc/machine-id` is set at container creation and persists across reboots. It only changes if the container is destroyed and recreated. This is acceptable — API key re-entry is a minor inconvenience in a rare event.

2. **PBKDF2 iterations**: 600,000 iterations of PBKDF2-HMAC-SHA256 is the OWASP 2024 recommendation. Key derivation takes ~0.3s on modern hardware — acceptable since it only happens on key get/set, not on every request. For performance, the Fernet instance could be cached at module level.

3. **File permissions**: The encrypted file is created with `0o600` (owner read/write only). Combined with encryption, this provides two layers against casual access.

4. **No key file to manage**: The encryption key is deterministically derived from machine-id. There is no separate key file to lose, back up, or accidentally commit. The trade-off is that if someone has root access AND knows the derivation scheme, they can decrypt — but our threat model explicitly excludes sophisticated root-level attackers.

5. **Salt uniqueness**: The salt `watchtower-secrets-v1` is application-specific. If the scheme ever needs to change, bump to `v2` and re-encrypt.

### Performance consideration

The `_derive_key()` function runs PBKDF2 with 600K iterations. This takes ~200-400ms. Options:
- **Cache at module level**: Derive once at import time (simple, ~zero ongoing cost)
- **Cache per-request**: Derive once per request cycle (Flask `g` object)
- **Recommended**: Cache at module level with lazy initialization

```python
_cached_fernet: Fernet | None = None

def _get_fernet() -> Fernet:
    global _cached_fernet
    if _cached_fernet is None:
        _cached_fernet = Fernet(_derive_key())
    return _cached_fernet
```

### macOS development compatibility

For developers on macOS (no `/etc/machine-id`):
- Use `ioreg -rd1 -c IOPlatformExpertDevice` to get IOPlatformUUID
- Or use `platform.node()` as fallback (less stable but works everywhere)
- The implementation sketch above includes a macOS fallback

### What about docker/container portability?

If Watchtower ever runs in Docker:
- Mount machine-id from host: `-v /etc/machine-id:/etc/machine-id:ro`
- Or set a `FW_SECRET_SALT` env var as the identity anchor instead of machine-id
- The key derivation function can be extended with a `FW_MACHINE_IDENTITY` env var override

---

## Sources

- [keyring PyPI](https://pypi.org/project/keyring/)
- [keyring documentation](https://keyring.readthedocs.io/)
- [GNOME Keyring Daemon Without X](https://copyprogramming.com/howto/use-of-gnome-keyring-daemon-without-x)
- [keyrings.alt PyPI](https://pypi.org/project/keyrings.alt/)
- [Fernet documentation (cryptography)](https://cryptography.io/en/latest/fernet/)
- [Apache Airflow Fernet secrets](https://airflow.apache.org/docs/apache-airflow/stable/security/secrets/fernet.html)
- [Fernet encryption GeeksforGeeks](https://www.geeksforgeeks.org/python/fernet-symmetric-encryption-using-cryptography-module-in-python/)
