"""Session dataclass — provider-neutral terminal session descriptor (T-967).

Matches the schema defined in docs/reports/T-962-v7-orchestrator-design.md §3.2.
"""

import os
import random
import string
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional


def _generate_id() -> str:
    """Generate a session ID in S-YYYY-MMDD-XXXX format."""
    now = datetime.now(timezone.utc)
    suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=4))
    return f"S-{now.strftime('%Y-%m%d')}-{suffix}"


@dataclass
class ProviderInfo:
    """Provider identification."""

    name: str  # "local", "claude", "ollama", "openai", "gemini", "custom"
    model: Optional[str] = None
    endpoint: Optional[str] = None
    version: Optional[str] = None

    def to_dict(self) -> dict:
        d = {"name": self.name}
        if self.model:
            d["model"] = self.model
        if self.endpoint:
            d["endpoint"] = self.endpoint
        if self.version:
            d["version"] = self.version
        return d

    @classmethod
    def from_dict(cls, d: dict) -> "ProviderInfo":
        return cls(
            name=d.get("name", "local"),
            model=d.get("model"),
            endpoint=d.get("endpoint"),
            version=d.get("version"),
        )


@dataclass
class Capabilities:
    """What a session can do."""

    mode: str = "read-write"  # read-only, read-write, inject-only, observe-only
    file_edit: bool = True
    tool_use: bool = False
    streaming: bool = True
    context_window: Optional[int] = None
    persistent_thread: bool = False

    def to_dict(self) -> dict:
        return {
            "mode": self.mode,
            "file_edit": self.file_edit,
            "tool_use": self.tool_use,
            "streaming": self.streaming,
            "context_window": self.context_window,
            "persistent_thread": self.persistent_thread,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "Capabilities":
        return cls(**{k: v for k, v in d.items() if k in cls.__dataclass_fields__})


@dataclass
class CostInfo:
    """Token usage tracking (tokens only, never dollars)."""

    input_tokens: int = 0
    output_tokens: int = 0
    cache_read_tokens: int = 0
    cache_write_tokens: int = 0
    total_tokens: int = 0
    model: Optional[str] = None

    def to_dict(self) -> dict:
        d = {
            "input_tokens": self.input_tokens,
            "output_tokens": self.output_tokens,
            "cache_read_tokens": self.cache_read_tokens,
            "cache_write_tokens": self.cache_write_tokens,
            "total_tokens": self.total_tokens,
        }
        if self.model:
            d["model"] = self.model
        return d

    @classmethod
    def from_dict(cls, d: dict) -> "CostInfo":
        return cls(**{k: v for k, v in d.items() if k in cls.__dataclass_fields__})


@dataclass
class ProcessInfo:
    """OS-level process tracking."""

    pid: Optional[int] = None
    fd: Optional[int] = None
    tty: Optional[str] = None
    termlink_session: Optional[str] = None
    websocket_id: Optional[str] = None

    def to_dict(self) -> dict:
        d = {}
        if self.pid is not None:
            d["pid"] = self.pid
        if self.tty:
            d["tty"] = self.tty
        if self.termlink_session:
            d["termlink_session"] = self.termlink_session
        if self.websocket_id:
            d["websocket_id"] = self.websocket_id
        return d

    @classmethod
    def from_dict(cls, d: dict) -> "ProcessInfo":
        return cls(**{k: v for k, v in d.items() if k in cls.__dataclass_fields__})


# Valid session statuses (lifecycle state machine)
VALID_STATUSES = {"spawning", "active", "idle", "paused", "completed", "failed", "killed"}
# Valid session types
VALID_TYPES = {"shell", "agent", "repl"}
# Valid termination reasons
VALID_TERMINATION_REASONS = {
    None, "user_close", "task_complete", "timeout",
    "budget_exhausted", "error", "killed",
}


@dataclass
class Session:
    """Provider-neutral terminal session descriptor.

    Matches the JSON schema in T-962 v7 §3.2.
    """

    id: str = field(default_factory=_generate_id)
    type: str = "shell"  # shell, agent, repl
    provider: ProviderInfo = field(default_factory=lambda: ProviderInfo(name="local"))
    status: str = "spawning"
    task: Optional[str] = None  # T-XXX reference
    tags: list = field(default_factory=list)
    capabilities: Capabilities = field(default_factory=Capabilities)
    cost: CostInfo = field(default_factory=CostInfo)
    process: ProcessInfo = field(default_factory=ProcessInfo)
    created: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    last_activity: Optional[str] = None
    finished: Optional[str] = None
    exit_code: Optional[int] = None
    termination_reason: Optional[str] = None
    prompt: Optional[str] = None
    result_path: Optional[str] = None
    parent_session: Optional[str] = None
    profile: Optional[str] = None  # Profile name used to create this session

    def to_dict(self) -> dict:
        """Serialize to dict for YAML persistence."""
        d = {
            "id": self.id,
            "type": self.type,
            "provider": self.provider.to_dict(),
            "status": self.status,
            "created": self.created,
        }
        if self.task:
            d["task"] = self.task
        if self.tags:
            d["tags"] = self.tags
        d["capabilities"] = self.capabilities.to_dict()
        if any(v for v in [self.cost.input_tokens, self.cost.output_tokens,
                           self.cost.cache_read_tokens, self.cost.total_tokens]):
            d["cost"] = self.cost.to_dict()
        if self.process.pid is not None or self.process.termlink_session:
            d["process"] = self.process.to_dict()
        if self.last_activity:
            d["last_activity"] = self.last_activity
        if self.finished:
            d["finished"] = self.finished
        if self.exit_code is not None:
            d["exit_code"] = self.exit_code
        if self.termination_reason:
            d["termination_reason"] = self.termination_reason
        if self.prompt:
            d["prompt"] = self.prompt
        if self.result_path:
            d["result_path"] = self.result_path
        if self.parent_session:
            d["parent_session"] = self.parent_session
        if self.profile:
            d["profile"] = self.profile
        return d

    @classmethod
    def from_dict(cls, d: dict) -> "Session":
        """Deserialize from dict (YAML load)."""
        provider = ProviderInfo.from_dict(d.get("provider", {"name": "local"}))
        capabilities = Capabilities.from_dict(d.get("capabilities", {}))
        cost = CostInfo.from_dict(d.get("cost", {}))
        process = ProcessInfo.from_dict(d.get("process", {}))
        return cls(
            id=d.get("id", _generate_id()),
            type=d.get("type", "shell"),
            provider=provider,
            status=d.get("status", "spawning"),
            task=d.get("task"),
            tags=d.get("tags", []),
            capabilities=capabilities,
            cost=cost,
            process=process,
            created=d.get("created", datetime.now(timezone.utc).isoformat()),
            last_activity=d.get("last_activity"),
            finished=d.get("finished"),
            exit_code=d.get("exit_code"),
            termination_reason=d.get("termination_reason"),
            prompt=d.get("prompt"),
            result_path=d.get("result_path"),
            parent_session=d.get("parent_session"),
            profile=d.get("profile"),
        )

    def touch_activity(self):
        """Update last_activity to now."""
        self.last_activity = datetime.now(timezone.utc).isoformat()

    def finish(self, reason: str = "user_close", exit_code: int = 0):
        """Mark session as finished."""
        self.status = "completed" if exit_code == 0 else "failed"
        self.finished = datetime.now(timezone.utc).isoformat()
        self.exit_code = exit_code
        self.termination_reason = reason
