"""Reviewer override mechanism (T-1443 v1.4).

Bounded-time per-(task, pattern, ac_index?) waivers. Suppresses known
false-positive findings without losing the audit trail.

Antifragile properties:
- TTL forces re-evaluation; overrides cannot drift to permanent.
- Suppressions emit feedback-stream events; nothing is silently hidden.
- Overrides can only suppress findings, never fabricate them → fail-closed.

Storage: `.context/working/reviewer-overrides.yaml` (per-project working memory).
"""

from __future__ import annotations

import os
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

DEFAULT_TTL_DAYS = 90
SCHEMA_VERSION = 1


@dataclass
class Override:
    id: str
    task_id: str
    pattern_id: str
    ac_index: int | None  # None = wildcard, matches any AC for this (task, pattern)
    reason: str
    expires_at: str       # ISO 8601 UTC
    added_by: str
    added_at: str

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "task_id": self.task_id,
            "pattern_id": self.pattern_id,
            "ac_index": self.ac_index,
            "reason": self.reason,
            "expires_at": self.expires_at,
            "added_by": self.added_by,
            "added_at": self.added_at,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "Override":
        return cls(
            id=d["id"],
            task_id=d["task_id"],
            pattern_id=d["pattern_id"],
            ac_index=d.get("ac_index"),
            reason=d.get("reason", ""),
            expires_at=d["expires_at"],
            added_by=d.get("added_by", "unknown"),
            added_at=d.get("added_at", ""),
        )

    def is_expired(self, now: datetime | None = None) -> bool:
        now = now or datetime.now(timezone.utc)
        try:
            exp = datetime.fromisoformat(self.expires_at.replace("Z", "+00:00"))
        except ValueError:
            return True  # malformed → treat as expired (fail-closed)
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        return now > exp

    def days_remaining(self, now: datetime | None = None) -> int:
        now = now or datetime.now(timezone.utc)
        try:
            exp = datetime.fromisoformat(self.expires_at.replace("Z", "+00:00"))
        except ValueError:
            return -1
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        return (exp - now).days


def _store_path(project_root: Path | None = None) -> Path:
    root = project_root or Path(os.environ.get("PROJECT_ROOT") or os.getcwd())
    return root / ".context" / "working" / "reviewer-overrides.yaml"


def load_overrides(path: Path | None = None) -> list[Override]:
    p = path or _store_path()
    if not p.exists():
        return []
    try:
        data = yaml.safe_load(p.read_text()) or {}
    except yaml.YAMLError:
        return []
    raw = data.get("overrides", [])
    overrides: list[Override] = []
    for entry in raw:
        try:
            overrides.append(Override.from_dict(entry))
        except (KeyError, TypeError):
            continue  # skip malformed entries (fail-soft load)
    return overrides


def save_overrides(overrides: list[Override], path: Path | None = None) -> None:
    p = path or _store_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": SCHEMA_VERSION,
        "overrides": [o.to_dict() for o in overrides],
    }
    tmp = p.with_suffix(".yaml.tmp")
    tmp.write_text(yaml.safe_dump(payload, sort_keys=False))
    tmp.replace(p)


def is_overridden(
    overrides: list[Override],
    task_id: str,
    pattern_id: str,
    ac_index: int | None,
    now: datetime | None = None,
) -> Override | None:
    """Return the matching active override, or None.

    Match rule: (task_id, pattern_id) must match exactly. ac_index in the
    override:
      - None → wildcard, matches any finding (including verification-level)
      - int  → must equal the finding's ac_index exactly
    Expired overrides do not match.
    """
    now = now or datetime.now(timezone.utc)
    for o in overrides:
        if o.task_id != task_id or o.pattern_id != pattern_id:
            continue
        if o.ac_index is not None and o.ac_index != ac_index:
            continue
        if o.is_expired(now):
            continue
        return o
    return None


def prune_expired(overrides: list[Override], now: datetime | None = None) -> tuple[list[Override], list[Override]]:
    """Return (kept, dropped). Pure — does not write."""
    now = now or datetime.now(timezone.utc)
    kept = [o for o in overrides if not o.is_expired(now)]
    dropped = [o for o in overrides if o.is_expired(now)]
    return kept, dropped


def find_expired(overrides: list[Override], now: datetime | None = None) -> list[Override]:
    now = now or datetime.now(timezone.utc)
    return [o for o in overrides if o.is_expired(now)]


def add_override(
    task_id: str,
    pattern_id: str,
    reason: str,
    ac_index: int | None = None,
    ttl_days: int = DEFAULT_TTL_DAYS,
    added_by: str | None = None,
    path: Path | None = None,
    now: datetime | None = None,
) -> Override:
    now = now or datetime.now(timezone.utc)
    expires = now + timedelta(days=ttl_days)
    o = Override(
        id=f"OV-{uuid.uuid4().hex[:8]}",
        task_id=task_id,
        pattern_id=pattern_id,
        ac_index=ac_index,
        reason=reason,
        expires_at=expires.strftime("%Y-%m-%dT%H:%M:%SZ"),
        added_by=added_by or os.environ.get("USER", "unknown"),
        added_at=now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    )
    existing = load_overrides(path)
    existing.append(o)
    save_overrides(existing, path)
    return o


def remove_override(override_id: str, path: Path | None = None) -> bool:
    existing = load_overrides(path)
    new = [o for o in existing if o.id != override_id]
    if len(new) == len(existing):
        return False
    save_overrides(new, path)
    return True
