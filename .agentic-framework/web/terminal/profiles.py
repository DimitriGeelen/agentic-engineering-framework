"""Session profile loader — named presets for terminal sessions (T-967).

Reads web/terminal/profiles.yaml and returns profile configurations
for the terminal page's session creation UI.
"""

import os
from typing import Optional

import yaml


_PROFILES_PATH = os.path.join(os.path.dirname(__file__), "profiles.yaml")
_cache: Optional[dict] = None


def load_profiles(path: Optional[str] = None) -> dict:
    """Load session profiles from YAML.

    Returns:
        dict mapping profile ID to profile config.
    """
    global _cache
    target = path or _PROFILES_PATH
    if _cache is not None and path is None:
        return _cache
    with open(target) as f:
        data = yaml.safe_load(f)
    profiles = data.get("profiles", {})
    if path is None:
        _cache = profiles
    return profiles


def get_profile(profile_id: str) -> Optional[dict]:
    """Get a single profile by ID."""
    profiles = load_profiles()
    return profiles.get(profile_id)


def profile_to_config(profile_id: str) -> dict:
    """Convert a profile to adapter spawn config.

    Returns:
        dict suitable for passing to SessionAdapter.spawn().
    """
    profile = get_profile(profile_id)
    if not profile:
        return {}
    config = dict(profile.get("config", {}))
    provider = profile.get("provider", {})
    if provider.get("model"):
        config["model"] = provider["model"]
    return config


def profile_provider(profile_id: str) -> str:
    """Get the provider name for a profile."""
    profile = get_profile(profile_id)
    if not profile:
        return "local"
    return profile.get("provider", {}).get("name", "local")


def profile_type(profile_id: str) -> str:
    """Get the session type for a profile."""
    profile = get_profile(profile_id)
    if not profile:
        return "shell"
    return profile.get("type", "shell")


def invalidate_cache():
    """Clear the profile cache (for testing or hot-reload)."""
    global _cache
    _cache = None
