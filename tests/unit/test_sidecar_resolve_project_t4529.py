"""T-4529: a same-hub project must be resolvable as a bare `--to`.

Origin: 0909-boot-into-timeshift-snapshots (their G-002/T-1003) could post, but
others' sends and `--in-reply-to` replies to it (the reply address is the bare
sender name) were refused as "not resolvable". `circuit._PROJECT_ID_RE` was
`^\\d{3}-`, so a four-digit fleet id only passed as a sibling directory of the
sender, and a project outside the numbering had no hub evidence at all. The
hub is a fake runner; nothing reaches a real hub.
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_sidecar_orphan_circuit_t4418 import (  # noqa: E402,F401  (fixture import)
    OWN, _row, _runner, env)

from lib.sidecar import circuit  # noqa: E402

NOW = int(time.time() * 1000)


@pytest.mark.parametrize("name", ["0909-boot-into-timeshift-snapshots", "1409-sprind",
                                  "010-termlink"])
def test_three_and_four_digit_fleet_ids_are_projects(env, name):
    assert circuit.is_project_id(name)                 # no sibling dir in tmp_path


@pytest.mark.parametrize("name", ["w4531", "e2e-ab947312-responder", "reviewer-T-3433-ab12",
                                  "t3433-circuit-addr", "12345-too-many-digits"])
def test_agent_names_are_not_projects(env, name):
    assert not circuit.is_project_id(name)


def test_four_digit_project_resolves_on_our_hub(env):
    where = env.resolve("0909-boot-into-timeshift-snapshots", runner=_runner([]))
    assert where["circuit"] == f"{OWN}/0909-boot-into-timeshift-snapshots"
    assert where["hub"] is None


def test_unnumbered_name_with_a_fetched_inbox_is_refused_at_auto(env):
    """T-5427: a recent fetch (a peek counts) is no evidence; refusal names --level project."""
    rows = [_row(f"inbox:{OWN}/claude-shared", count=4, write=NOW - 60_000, fetch=NOW - 1000)]
    with pytest.raises(env.AddressError) as e:
        env.resolve("claude-shared", runner=_runner(rows))
    assert "--level project" in str(e.value)


def test_unnumbered_project_resolves_with_level_project(env):
    where = env.resolve("claude-shared", level="project", runner=_runner([]))
    assert where["circuit"] == f"{OWN}/claude-shared"


def test_proxmox_nickname_with_a_peeked_inbox_is_refused(env):
    """T-5427 witness: the address three consults went to, with a fresh fetch on the hub."""
    rows = [_row(f"inbox:{OWN}/proxmox-ring20-management", count=43, write=NOW - 60_000,
                 fetch=NOW - 1000)]
    with pytest.raises(env.AddressError):
        env.resolve("proxmox-ring20-management", runner=_runner(rows))


def test_unnumbered_name_with_a_never_read_inbox_is_still_refused(env):
    rows = [_row(f"inbox:{OWN}/ring20-manager", count=3, write=NOW - 60_000, unread=NOW - 60_000)]
    with pytest.raises(env.AddressError):
        env.resolve("ring20-manager", runner=_runner(rows))
