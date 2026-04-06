"""SessionRegistry — CRUD + persistence for terminal sessions (T-967).

Stores session records as YAML files in .context/sessions/.
Design: docs/reports/T-962-v7-orchestrator-design.md §4.2 L3.
"""

import logging
import os
from typing import List, Optional

import yaml

from web.terminal.session import Session

logger = logging.getLogger(__name__)


class SessionRegistry:
    """Session CRUD with YAML file persistence."""

    def __init__(self, sessions_dir: Optional[str] = None):
        if sessions_dir:
            self._dir = sessions_dir
        else:
            project_root = os.environ.get(
                "PROJECT_ROOT",
                os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            )
            self._dir = os.path.join(project_root, ".context", "sessions")
        os.makedirs(self._dir, exist_ok=True)
        # In-memory cache of active sessions (pid/fd are not persisted across restarts)
        self._active: dict[str, Session] = {}

    def _yaml_path(self, session_id: str) -> str:
        return os.path.join(self._dir, f"{session_id}.yaml")

    def create(self, session: Session) -> Session:
        """Register a new session."""
        self._active[session.id] = session
        self._persist(session)
        logger.info("Registered session %s (provider=%s)", session.id, session.provider.name)
        return session

    def get(self, session_id: str) -> Optional[Session]:
        """Get a session by ID (memory first, then disk)."""
        if session_id in self._active:
            return self._active[session_id]
        return self._load(session_id)

    def update(self, session: Session) -> Session:
        """Update session state."""
        self._active[session.id] = session
        self._persist(session)
        return session

    def delete(self, session_id: str) -> bool:
        """Remove a session from the registry."""
        self._active.pop(session_id, None)
        path = self._yaml_path(session_id)
        if os.path.exists(path):
            os.remove(path)
            logger.info("Deleted session record %s", session_id)
            return True
        return False

    def list_all(self) -> List[Session]:
        """List all sessions (active in memory + completed on disk)."""
        sessions = dict(self._active)
        # Also load any persisted sessions not in memory
        if os.path.isdir(self._dir):
            for fname in os.listdir(self._dir):
                if fname.endswith(".yaml"):
                    sid = fname[:-5]
                    if sid not in sessions:
                        s = self._load(sid)
                        if s:
                            sessions[sid] = s
        return sorted(sessions.values(), key=lambda s: s.created, reverse=True)

    def query(
        self,
        provider: Optional[str] = None,
        status: Optional[str] = None,
        task: Optional[str] = None,
        tag: Optional[str] = None,
        session_type: Optional[str] = None,
    ) -> List[Session]:
        """Filter sessions by criteria."""
        results = []
        for session in self.list_all():
            if provider and session.provider.name != provider:
                continue
            if status and session.status != status:
                continue
            if task and session.task != task:
                continue
            if tag and tag not in session.tags:
                continue
            if session_type and session.type != session_type:
                continue
            results.append(session)
        return results

    def active_sessions(self) -> List[Session]:
        """List sessions that are currently running (in memory with pid)."""
        return [
            s for s in self._active.values()
            if s.status in ("spawning", "active", "idle", "paused")
        ]

    def cleanup_dead(self) -> int:
        """Remove sessions whose processes have died. Returns count cleaned."""
        cleaned = 0
        for sid, session in list(self._active.items()):
            if session.process.pid and session.status in ("active", "idle"):
                try:
                    os.kill(session.process.pid, 0)
                except OSError:
                    session.finish(reason="error", exit_code=-1)
                    self._persist(session)
                    del self._active[sid]
                    cleaned += 1
                    logger.info("Cleaned dead session %s (pid=%d)", sid, session.process.pid)
        return cleaned

    def _persist(self, session: Session) -> None:
        """Write session to YAML file."""
        path = self._yaml_path(session.id)
        try:
            with open(path, "w") as f:
                yaml.dump(session.to_dict(), f, default_flow_style=False, sort_keys=False)
        except OSError as e:
            logger.warning("Failed to persist session %s: %s", session.id, e)

    def _load(self, session_id: str) -> Optional[Session]:
        """Load session from YAML file."""
        path = self._yaml_path(session_id)
        if not os.path.exists(path):
            return None
        try:
            with open(path) as f:
                data = yaml.safe_load(f)
            if data:
                return Session.from_dict(data)
        except (yaml.YAMLError, OSError) as e:
            logger.warning("Failed to load session %s: %s", session_id, e)
        return None
