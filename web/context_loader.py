"""Centralized context file loading for Watchtower blueprints (T-416).

Replaces duplicated YAML loading blocks across discovery.py, core.py,
metrics.py, and risks.py. Uses shared.load_yaml() internally for
consistent error collection (T-403: R-018, R-024).
"""

from web.shared import PROJECT_ROOT, load_yaml

_PROJECT_DIR = PROJECT_ROOT / ".context" / "project"


def load_learnings() -> list:
    """Load learnings list from learnings.yaml."""
    data = load_yaml(_PROJECT_DIR / "learnings.yaml", label="learnings")
    return data.get("learnings", [])


def load_patterns() -> dict:
    """Load patterns.yaml as dict.

    Callers extract specific types: failure_patterns, success_patterns,
    antifragile_patterns, workflow_patterns.
    """
    return load_yaml(_PROJECT_DIR / "patterns.yaml", label="patterns")


def load_decisions() -> list:
    """Load decisions list from decisions.yaml."""
    data = load_yaml(_PROJECT_DIR / "decisions.yaml", label="decisions")
    return data.get("decisions", [])


def load_practices() -> list:
    """Load practices list from practices.yaml."""
    data = load_yaml(_PROJECT_DIR / "practices.yaml", label="practices")
    return data.get("practices", [])


def load_concerns() -> list:
    """Load concerns list with gaps.yaml fallback (T-397 migration)."""
    path = _PROJECT_DIR / "concerns.yaml"
    if not path.exists():
        path = _PROJECT_DIR / "gaps.yaml"
    data = load_yaml(path, label="concerns")
    return data.get("concerns", data.get("gaps", []))


def load_directives() -> list:
    """Load directives list from directives.yaml."""
    data = load_yaml(_PROJECT_DIR / "directives.yaml", label="directives")
    return data.get("directives", [])
