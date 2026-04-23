"""Fleet blueprint — operational dashboard for termlink fleet health (T-1103, T-1107)."""

import json
import os
import subprocess

from flask import Blueprint, jsonify, request

from web.shared import render_page

bp = Blueprint("fleet", __name__)


def _find_termlink():
    """Find the termlink binary, checking common locations."""
    import shutil
    # Try PATH first
    found = shutil.which("termlink")
    if found:
        return found
    # Check common install locations
    for path in ["/root/.cargo/bin/termlink", "/usr/local/bin/termlink"]:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return "termlink"  # fallback to PATH


def _get_fleet_status():
    """Run termlink fleet status --json and return parsed result."""
    try:
        binary = _find_termlink()
        # Ensure HOME and PATH are set so termlink can find hubs.toml and libs
        env = os.environ.copy()
        env.setdefault("HOME", "/root")
        # Add cargo bin to PATH for subprocess
        cargo_bin = os.path.expanduser("~/.cargo/bin")
        if cargo_bin not in env.get("PATH", ""):
            env["PATH"] = cargo_bin + ":" + env.get("PATH", "/usr/bin")
        result = subprocess.run(
            [binary, "fleet", "status", "--json", "--verbose", "--timeout", "5"],
            capture_output=True, text=True, timeout=30, env=env,
        )
        if result.stdout.strip():
            return json.loads(result.stdout)
        # If stdout is empty, check stderr for clues
        if result.stderr.strip():
            return {
                "ok": False, "fleet": [], "actions": [],
                "summary": {"total": 0, "up": 0, "down": 0, "auth_fail": 0},
                "error": result.stderr.strip()[:200],
            }
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError) as e:
        return {
            "ok": False, "fleet": [], "actions": [],
            "summary": {"total": 0, "up": 0, "down": 0, "auth_fail": 0},
            "error": str(e)[:200],
        }
    return {
        "ok": False, "fleet": [], "actions": [],
        "summary": {"total": 0, "up": 0, "down": 0, "auth_fail": 0},
        "error": "Could not run termlink fleet status",
    }


@bp.route("/fleet")
def fleet_dashboard():
    """Render the fleet operational dashboard."""
    data = _get_fleet_status()
    return render_page(
        "fleet.html",
        page_title="Fleet",
        fleet_data=data,
        fleet_entries=data.get("fleet", []),
        summary=data.get("summary", {}),
        actions=data.get("actions", []),
        is_healthy=data.get("ok", False),
    )


@bp.route("/api/fleet/status")
def fleet_status_api():
    """JSON API endpoint for fleet status (used by auto-refresh)."""
    return jsonify(_get_fleet_status())


def _run_net_test(profile=None, timeout_secs=5):
    """Run termlink net test --json and return parsed result.

    T-1107: Shells out to the CLI so we get the exact same layered diagnostic
    the operator would see from the terminal. Profile=None tests all hubs.
    """
    try:
        binary = _find_termlink()
        env = os.environ.copy()
        env.setdefault("HOME", "/root")
        cargo_bin = os.path.expanduser("~/.cargo/bin")
        if cargo_bin not in env.get("PATH", ""):
            env["PATH"] = cargo_bin + ":" + env.get("PATH", "/usr/bin")
        args = [binary, "net", "test", "--json", "--timeout", str(timeout_secs)]
        if profile:
            args += ["--profile", profile]
        result = subprocess.run(
            args, capture_output=True, text=True, timeout=60, env=env,
        )
        if result.stdout.strip():
            return json.loads(result.stdout)
        if result.stderr.strip():
            return {
                "ok": False, "hubs": [],
                "summary": {"total": 0, "healthy": 0, "degraded": 0, "unreachable": 0},
                "error": result.stderr.strip()[:300],
            }
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError) as e:
        return {
            "ok": False, "hubs": [],
            "summary": {"total": 0, "healthy": 0, "degraded": 0, "unreachable": 0},
            "error": str(e)[:300],
        }
    return {
        "ok": False, "hubs": [],
        "summary": {"total": 0, "healthy": 0, "degraded": 0, "unreachable": 0},
        "error": "Could not run termlink net test",
    }


@bp.route("/api/fleet/net-test")
def fleet_net_test_api():
    """T-1107: Layered connectivity diagnostic for hubs.

    Query params:
      profile: optional hub profile name to filter to a single hub
      timeout: per-layer timeout in seconds (default 5, max 30)
    """
    profile = request.args.get("profile")
    try:
        timeout_secs = min(int(request.args.get("timeout", "5")), 30)
    except ValueError:
        timeout_secs = 5
    if profile and not _is_safe_profile_name(profile):
        return jsonify({
            "ok": False, "hubs": [],
            "error": "invalid profile name (alphanumeric, dash, underscore only)",
        }), 400
    return jsonify(_run_net_test(profile=profile, timeout_secs=timeout_secs))


def _is_safe_profile_name(name):
    """Reject anything that could smuggle shell metacharacters through the args list.

    subprocess.run(args=[...]) does not use a shell, but extra defence here costs
    nothing and makes the endpoint obviously safe to review.
    """
    if not name or len(name) > 64:
        return False
    return all(c.isalnum() or c in "-_" for c in name)
