"""T-2917: Unit tests for lib/worker_identity.py.

Pinned behaviors:
- mechanism_from_origin maps the resolver's dispatch-origin taxonomy to a
  short, readable mechanism name (no two distinct origins collapse to the
  same mechanism unless they should — systemd units all share the
  "resolver-loop" family, everything else fans out).
- worker_git_env never produces an identity that could be mistaken for an
  operator's own git config (no bare name, no arbitrary email domain).
- the email always carries a recoverable 8-char dispatch_id prefix.
"""

from __future__ import annotations

import sys
from pathlib import Path

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))

import worker_identity as wi  # noqa: E402


def test_mechanism_resolver_loop_service():
    assert wi.mechanism_from_origin("systemd:resolver-loop.service") == "resolver-loop"


def test_mechanism_other_systemd_unit_distinguishable():
    m = wi.mechanism_from_origin("systemd:some-other-unit.service")
    assert m != "resolver-loop"
    assert "some-other-unit.service" in m


def test_mechanism_interactive():
    assert wi.mechanism_from_origin("interactive:S-2026-01") == "resolver-manual"


def test_mechanism_cli():
    assert wi.mechanism_from_origin("cli:foo") == "resolver-cli"


def test_mechanism_unknown_and_empty_never_none():
    assert wi.mechanism_from_origin("unknown") == "resolver"
    assert wi.mechanism_from_origin("") == "resolver"


def test_worker_git_env_shape():
    env = wi.worker_git_env("resolver-loop", "abc123456789")
    assert set(env) == {
        "GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL",
        "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL",
    }
    assert env["GIT_AUTHOR_NAME"] == "fw worker (resolver-loop)"
    assert env["GIT_AUTHOR_EMAIL"] == "dispatch+abc12345@aef.local"
    assert env["GIT_AUTHOR_NAME"] == env["GIT_COMMITTER_NAME"]
    assert env["GIT_AUTHOR_EMAIL"] == env["GIT_COMMITTER_EMAIL"]


def test_worker_git_env_dispatch_id_recoverable():
    env = wi.worker_git_env("termlink-dispatch", "deadbeef-1234-5678-9abc-def012345678")
    local_part = env["GIT_AUTHOR_EMAIL"].split("@", 1)[0]
    assert local_part == "dispatch+deadbeef"


def test_worker_git_env_missing_dispatch_id_still_distinct():
    env = wi.worker_git_env("resolver-loop", "")
    assert env["GIT_AUTHOR_EMAIL"] == "dispatch+unknown@aef.local"


def test_worker_git_env_different_mechanisms_produce_different_names():
    env_a = wi.worker_git_env("resolver-loop", "abc123456789")
    env_b = wi.worker_git_env("termlink-dispatch", "abc123456789")
    assert env_a["GIT_AUTHOR_NAME"] != env_b["GIT_AUTHOR_NAME"]
