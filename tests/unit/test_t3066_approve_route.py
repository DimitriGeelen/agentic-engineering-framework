"""T-3066: the Watchtower approve route, driven end-to-end against a scratch register.

The sibling bats (`tests/unit/t3066_driver_drop_identity.bats`) proves the CLI
guard and asserts the *source-level* join — that every route building a
`driver --add` also passes `--drop-name`. That join test is necessary (a guard
wired to one leg is the L-399 producer/consumer split) but it reads the source,
not the behaviour: it would pass if the route passed the flag and Flask returned
500 before reaching it.

This file closes that gap by POSTing to the real endpoint through Flask's test
client and asserting the register afterwards. Three cases, which are the three
things an operator can click:

  1. the proposal's referent has changed hands  → refused, nothing written
  2. the proposal predates `drop_name` (legacy) → refused, nothing written
  3. the referent is unchanged                  → applied, at-cap drop included

Isolation: PROJECT_ROOT, POLICY_PATH and PROPOSALS_PATH are pointed at a tmp_path
and `bin` is symlinked so the route's `subprocess.run(["bin/fw", ...], cwd=...)`
resolves the real CLI. Nothing here can touch policy/value-drivers.yaml or the
live proposals queue — which matters more than usual, because the thing under
test deletes drivers.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT))

CSRF = "t3066-approve-route-token"

POLICY = """\
protected_drivers:
  - {id: D1, name: Antifragility, weight: 9, protected: true}
free_drivers:
  - {id: F1, name: V_DIFFERENT, weight: 7, protected: false, rationale: "occupies the recycled slot F1 — nobody proposed dropping this one"}
  - {id: F2, name: V_BETA, weight: 4, protected: false, rationale: "scratch seed row whose referent never moves during these tests"}
"""

PROPOSALS = [
    # Filed when F1 meant V_ALPHA. V_ALPHA has since left and F1 was reallocated.
    {"id": "P-aa11bb22", "ts": "2026-08-17T10:00:00Z", "state": "pending",
     "name": "V_NEW", "weight": 6,
     "rationale": "filed while F1 denoted V_ALPHA; the slot has since changed hands",
     "drop": "F1", "drop_name": "V_ALPHA", "task": None, "author": "agent:test"},
    # Pre-T-3066 shape: a slot with no record of what was in it.
    {"id": "P-cc33dd44", "ts": "2026-08-17T10:01:00Z", "state": "pending",
     "name": "V_LEGACY", "weight": 5,
     "rationale": "a pre-T-3066 row: records the slot but never recorded the name",
     "drop": "F1", "task": None, "author": "agent:test"},
    # Nothing moved — must still work, or the guard has made the cap unusable.
    {"id": "P-ee55ff66", "ts": "2026-08-17T10:02:00Z", "state": "pending",
     "name": "V_OK", "weight": 3,
     "rationale": "a proposal whose referent has not moved at all, so it must still work",
     "drop": "F2", "drop_name": "V_BETA", "task": None, "author": "agent:test"},
]


@pytest.fixture
def scratch(tmp_path, monkeypatch):
    """A throwaway project the approve route can mutate freely."""
    (tmp_path / "policy").mkdir()
    (tmp_path / ".context").mkdir()
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".framework.yaml").touch()
    # `cwd=PROJECT_ROOT` + argv[0] "bin/fw" means the scratch root needs a bin/.
    (tmp_path / "bin").symlink_to(FRAMEWORK_ROOT / "bin")
    (tmp_path / "policy" / "value-drivers.yaml").write_text(POLICY)
    (tmp_path / ".context" / "bvp-driver-proposals.jsonl").write_text(
        "".join(json.dumps(p) + "\n" for p in PROPOSALS))

    # bin/fw validates an inherited PROJECT_ROOT (T-2391) rather than trusting
    # it; the .framework.yaml + .tasks/ above are what make the scratch pass.
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    return tmp_path


@pytest.fixture
def client(scratch, monkeypatch):
    from web.app import create_app
    import web.blueprints.bvp as m

    monkeypatch.setattr(m, "PROJECT_ROOT", scratch)
    monkeypatch.setattr(m, "POLICY_PATH", scratch / "policy" / "value-drivers.yaml")
    monkeypatch.setattr(m, "PROPOSALS_PATH",
                        scratch / ".context" / "bvp-driver-proposals.jsonl")

    app = create_app()
    c = app.test_client()
    with c.session_transaction() as sess:
        sess["_csrf_token"] = CSRF          # web/app.py:131 csrf_protect
    return c


def _driver_names(scratch) -> list[str]:
    import yaml
    policy = yaml.safe_load((scratch / "policy" / "value-drivers.yaml").read_text())
    return [d["name"] for d in (policy.get("free_drivers") or [])]


def _approve(client, pid):
    return client.post(f"/api/bvp/driver/approve?id={pid}",
                       headers={"X-CSRF-Token": CSRF})


def test_recycled_slot_is_refused_and_nothing_changes(client, scratch):
    """The reported defect, at the surface the operator actually clicks."""
    before = _driver_names(scratch)
    r = _approve(client, "P-aa11bb22")

    assert r.status_code == 400, r.get_data(as_text=True)[:400]
    body = r.get_data(as_text=True)
    # BOTH sides named, in the body the operator actually receives. This route
    # surfaces `err.splitlines()[0]` and discards the rest, so asserting only
    # the proposed name would have passed against a message that never tells
    # the operator what the slot now holds — the one fact the decision turns
    # on. That was true of the first version of this fix; this pair of asserts
    # is what caught it.
    assert "V_ALPHA" in body, "refusal does not name what was proposed"
    assert "V_DIFFERENT" in body, "refusal does not name what the slot holds now"
    assert "T-3066" in body

    # Fail-safe: no deletion AND no addition. A partial apply here is a
    # silently corrupted Sovereignty boundary.
    assert _driver_names(scratch) == before
    assert "V_DIFFERENT" in _driver_names(scratch)
    assert "V_NEW" not in _driver_names(scratch)


def test_legacy_row_without_drop_name_is_refused(client, scratch):
    """100 append-only rows predate `drop_name`; theirs is an unreadable intent.

    Resolving the slot at approval time would be the defect, so the route
    refuses and says what to do instead.
    """
    before = _driver_names(scratch)
    r = _approve(client, "P-cc33dd44")

    assert r.status_code == 409, r.get_data(as_text=True)[:400]
    body = r.get_data(as_text=True)
    assert "re-file" in body.lower()
    assert _driver_names(scratch) == before


def test_unchanged_referent_still_applies(client, scratch):
    """The guard must not make add-one-drop-one unusable (AC4)."""
    r = _approve(client, "P-ee55ff66")
    assert r.status_code == 200, r.get_data(as_text=True)[:400]

    names = _driver_names(scratch)
    assert "V_OK" in names          # added
    assert "V_BETA" not in names    # dropped, as proposed

    # The success line names the driver, not just the slot — "dropped F2" alone
    # is true of two different deletions once the slot is recycled.
    assert "V_BETA" in json.loads(r.get_data(as_text=True))["message"]


def test_approve_route_reaches_the_cli_at_all(client, scratch):
    """Positive control (L-616).

    Every assertion above is about a refusal or a state change downstream of a
    subprocess call. If the route were 500-ing before it ever ran `bin/fw`, the
    two refusal tests would still pass — a 400/409 for the wrong reason and an
    unchanged register are exactly what a broken harness produces. This test
    fails loudly in that case, because it needs the CLI's own stdout.
    """
    r = _approve(client, "P-ee55ff66")
    assert r.status_code == 200
    assert "M1 add-one-drop-one" in json.loads(r.get_data(as_text=True))["message"]
