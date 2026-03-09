"""Encrypted API key storage for Watchtower.

Machine-bound Fernet encryption using /etc/machine-id as key derivation input.
Keys are stored encrypted at .context/secrets/api-keys.enc.
Environment variables take precedence over stored keys.

T-378: Fernet encrypted API key storage.
"""

import base64
import hashlib
import json
import logging
import os
from pathlib import Path

from cryptography.fernet import Fernet, InvalidToken

from web.shared import PROJECT_ROOT

log = logging.getLogger(__name__)

SECRETS_DIR = PROJECT_ROOT / ".context" / "secrets"
KEYS_FILE = SECRETS_DIR / "api-keys.enc"

# Map of key names to their environment variable overrides
ENV_OVERRIDES = {
    "openrouter": "OPENROUTER_API_KEY",
    "openai": "OPENAI_API_KEY",
}


def _derive_key() -> bytes:
    """Derive a Fernet key from /etc/machine-id.

    Uses PBKDF2-HMAC-SHA256 with 600K iterations.
    Machine-bound: the encrypted file is useless without this machine's ID.
    """
    try:
        machine_id = Path("/etc/machine-id").read_text().strip()
    except FileNotFoundError:
        # Fallback for systems without machine-id (macOS, etc.)
        import uuid
        machine_id = str(uuid.getnode())

    dk = hashlib.pbkdf2_hmac(
        "sha256",
        machine_id.encode(),
        b"watchtower-secrets-v1",
        600_000,
        dklen=32,
    )
    return base64.urlsafe_b64encode(dk)


def _get_fernet() -> Fernet:
    """Get a Fernet instance with the derived key."""
    return Fernet(_derive_key())


def _load_store() -> dict:
    """Load and decrypt the key store. Returns empty dict if missing/invalid."""
    if not KEYS_FILE.exists():
        return {}
    try:
        encrypted = KEYS_FILE.read_bytes()
        f = _get_fernet()
        decrypted = f.decrypt(encrypted)
        return json.loads(decrypted)
    except (InvalidToken, json.JSONDecodeError, Exception) as e:
        log.warning("Failed to decrypt key store: %s", e)
        return {}


def _save_store(store: dict) -> None:
    """Encrypt and save the key store."""
    SECRETS_DIR.mkdir(parents=True, exist_ok=True)
    f = _get_fernet()
    plaintext = json.dumps(store).encode()
    encrypted = f.encrypt(plaintext)
    KEYS_FILE.write_bytes(encrypted)


def get_api_key(name: str) -> str | None:
    """Get an API key by name.

    Checks environment variable first, then encrypted store.
    Returns None if not configured.
    """
    # Environment variable takes precedence
    env_var = ENV_OVERRIDES.get(name, f"FW_{name.upper()}_API_KEY")
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
    log.info("Stored API key: %s", name)


def delete_api_key(name: str) -> bool:
    """Delete an API key. Returns True if it existed."""
    store = _load_store()
    if name not in store:
        return False
    del store[name]
    _save_store(store)
    log.info("Deleted API key: %s", name)
    return True


def list_configured_keys() -> list[dict]:
    """List all configured API keys with their sources.

    Returns list of dicts with: name, source ('env' | 'encrypted'), masked_value.
    Never returns the actual key value.
    """
    result = []
    store = _load_store()

    # Check all known key names
    all_names = set(list(ENV_OVERRIDES.keys()) + list(store.keys()))

    for name in sorted(all_names):
        env_var = ENV_OVERRIDES.get(name, f"FW_{name.upper()}_API_KEY")
        env_val = os.environ.get(env_var)

        if env_val:
            result.append({
                "name": name,
                "source": "env",
                "env_var": env_var,
                "masked": _mask(env_val),
            })
        elif name in store:
            result.append({
                "name": name,
                "source": "encrypted",
                "masked": _mask(store[name]),
            })

    return result


def _mask(value: str) -> str:
    """Mask an API key for display: show first 4 and last 4 chars."""
    if len(value) <= 8:
        return "****"
    return f"{value[:4]}...{value[-4:]}"
