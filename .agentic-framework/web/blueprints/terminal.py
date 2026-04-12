"""Terminal blueprint — interactive web terminal for Watchtower (T-964, T-966, T-967)."""

import json
import subprocess

from flask import Blueprint, jsonify, request

from web.shared import render_page
from web.terminal.adapters.local_shell import LocalShellAdapter
from web.terminal.adapters.claude_code import ClaudeCodeAdapter
from web.terminal.profiles import load_profiles, profile_to_config, profile_provider, profile_type
from web.terminal.registry import SessionRegistry
from web.terminal.session import Session, ProviderInfo, Capabilities, ProcessInfo

bp = Blueprint("terminal", __name__)

# Singleton registry and adapter map (initialized on first use)
_registry = None
_adapters = {}


def _get_registry():
    global _registry
    if _registry is None:
        _registry = SessionRegistry()
    return _registry


def _get_adapter(provider_name: str):
    global _adapters
    if not _adapters:
        local = LocalShellAdapter()
        claude = ClaudeCodeAdapter()
        _adapters = {local.name: local, claude.name: claude}
    return _adapters.get(provider_name)


@bp.route("/terminal")
def terminal_page():
    """Render the interactive terminal page."""
    return render_page(
        "terminal.html",
        page_title="Terminal",
        profiles=load_profiles(),
    )


# --- Session CRUD API (T-967) ---


@bp.route("/api/sessions", methods=["GET"])
def list_sessions():
    """List all sessions, optionally filtered."""
    registry = _get_registry()
    provider = request.args.get("provider")
    status = request.args.get("status")
    task = request.args.get("task")
    tag = request.args.get("tag")
    session_type = request.args.get("type")

    if any([provider, status, task, tag, session_type]):
        sessions = registry.query(
            provider=provider, status=status, task=task,
            tag=tag, session_type=session_type,
        )
    else:
        sessions = registry.list_all()
    return jsonify([s.to_dict() for s in sessions])


@bp.route("/api/sessions", methods=["POST"])
def create_session():
    """Create a new session from a profile or raw config."""
    data = request.get_json(silent=True) or {}
    profile_id = data.get("profile", "local-bash")
    task_ref = data.get("task")

    # Resolve provider and config from profile
    provider_name = data.get("provider", profile_provider(profile_id))
    session_type = data.get("type", profile_type(profile_id))
    config = profile_to_config(profile_id)
    config.update(data.get("config", {}))

    adapter = _get_adapter(provider_name)
    if not adapter:
        return jsonify({"error": f"Unknown provider: {provider_name}"}), 400

    # Create session record
    session = Session(
        type=session_type,
        provider=ProviderInfo(name=provider_name, model=config.get("model")),
        status="spawning",
        task=task_ref,
        capabilities=Capabilities.from_dict(adapter.capabilities()),
        profile=profile_id,
        prompt=config.get("prompt"),
    )

    # Spawn the process
    try:
        handle = adapter.spawn(config)
        session.process = ProcessInfo(pid=handle.get("pid"), fd=handle.get("fd"))
        session.status = "active"
        session.touch_activity()
    except Exception as e:
        session.status = "failed"
        session.termination_reason = "error"
        registry = _get_registry()
        registry.create(session)
        return jsonify({"error": str(e), "session": session.to_dict()}), 500

    registry = _get_registry()
    registry.create(session)
    return jsonify(session.to_dict()), 201


@bp.route("/api/sessions/<session_id>", methods=["GET"])
def get_session(session_id):
    """Get a single session by ID."""
    registry = _get_registry()
    session = registry.get(session_id)
    if not session:
        return jsonify({"error": "Session not found"}), 404
    return jsonify(session.to_dict())


@bp.route("/api/sessions/<session_id>", methods=["DELETE"])
def delete_session(session_id):
    """Kill and remove a session."""
    registry = _get_registry()
    session = registry.get(session_id)
    if not session:
        return jsonify({"error": "Session not found"}), 404

    # Kill the process if still running
    if session.process.pid and session.status in ("active", "idle", "paused"):
        adapter = _get_adapter(session.provider.name)
        if adapter and session.process.fd is not None:
            adapter.kill({"pid": session.process.pid, "fd": session.process.fd})
        session.finish(reason="killed", exit_code=-1)
        registry.update(session)

    registry.delete(session_id)
    return jsonify({"deleted": session_id})


@bp.route("/api/sessions/profiles", methods=["GET"])
def list_profiles():
    """List available session profiles."""
    return jsonify(load_profiles())


# --- TermLink sessions (T-966, preserved) ---


@bp.route("/api/termlink/sessions")
def termlink_sessions():
    """List active TermLink sessions for attachment (T-966)."""
    try:
        result = subprocess.run(
            ["termlink", "list", "--json"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            data = json.loads(result.stdout)
            sessions = data.get("sessions", []) if isinstance(data, dict) else data
            return jsonify([{
                "id": s.get("id", ""),
                "name": s.get("display_name", s.get("name", "")),
                "state": s.get("state", "unknown"),
                "tags": s.get("tags", []),
                "pid": s.get("pid"),
            } for s in sessions if isinstance(s, dict)])
    except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError):
        pass
    return jsonify([])
