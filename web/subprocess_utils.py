"""Consistent subprocess execution for Watchtower blueprints (T-417).

Provides run_git_command() and run_fw_command() with standardized
timeouts, encoding, and error handling. Replaces ad-hoc subprocess.run
calls scattered across blueprints.
"""
from __future__ import annotations


import logging
import os
import subprocess

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT

log = logging.getLogger(__name__)


def run_git_command(args: list[str], *, timeout: int = 10) -> tuple[str, bool]:
    """Run a git command against PROJECT_ROOT.

    Returns (stdout, ok). Errors are caught and logged.
    """
    try:
        result = subprocess.run(
            ["git", "-C", str(PROJECT_ROOT)] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return result.stdout.strip(), result.returncode == 0
    except subprocess.TimeoutExpired:
        log.warning("git %s timed out after %ds", " ".join(args[:3]), timeout)
        return "", False
    except Exception as exc:
        log.warning("git %s failed: %s", " ".join(args[:3]), exc)
        return "", False


def run_fw_command(args: list[str], *, timeout: int = 30) -> tuple[str, str, bool]:
    """Run a fw CLI command.

    Returns (stdout, stderr, ok). Errors are caught and logged.
    """
    try:
        result = subprocess.run(
            [str(FRAMEWORK_ROOT / "bin" / "fw")] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode == 0
    except subprocess.TimeoutExpired:
        log.warning("fw %s timed out after %ds", " ".join(args[:3]), timeout)
        return "", "Command timed out", False
    except Exception as exc:
        log.warning("fw %s failed: %s", " ".join(args[:3]), exc)
        return "", str(exc), False
