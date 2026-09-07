"""T-3313 (arc-020 S7): tests for the durable provision audit trail.

Spec: docs/reports/T-3287-identity-taxonomy-circuit-model.md (D5 bound 4 —
every auto-provision logged, unconditionally).

Covers: the six-field row schema, append-only growth across runs, deny (S5)
and halted (S6) decisions landing in the file, malformed-line tolerance on
read, and the CLI the `fw provisions` verb calls.
"""

from __future__ import annotations

import json
import subprocess
import sys
from dataclasses import replace
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

from lib.aef_address import AEFAddress, parse, serialize  # noqa: E402
from lib.aef_provision_log import (  # noqa: E402
    append_row,
    default_log_path,
    format_rows,
    jsonl_sink,
    main,
    read_rows,
)
from lib.aef_resolve import DENIED, HALTED, PROVISIONED, provision  # noqa: E402

CIRCUIT = (
    "aef::host=host107.ring20.lan::hub=H-1"
    "::project={project}::session=S-8f3c::@reviewer::"
)


def circuit(project: str) -> AEFAddress:
    return parse(CIRCUIT.format(project=project))


def probe_knowing(*existing: AEFAddress):
    known = {serialize(a) for a in existing}
    return lambda addr: serialize(addr) in known


def make_provisioners():
    """Stub provisioners for every level; session mints a fresh id (D1)."""

    def make(level):
        def prov(intended: AEFAddress) -> AEFAddress | None:
            if level == "session" and intended.session is None:
                return replace(intended, session="S-fresh")
            return None

        return prov

    return {lvl: make(lvl) for lvl in ("hub", "project", "session", "agent")}


def provision_to(log_path: Path, tmp_path: Path, **kwargs):
    """One provisioned run wired to the JSONL sink; project dir exists."""
    proj = tmp_path / "proj"
    proj.mkdir(exist_ok=True)
    target = circuit(str(proj))
    found = AEFAddress(host=target.host, hub=target.hub)
    return provision(
        target,
        probe_knowing(found),
        make_provisioners(),
        audit_sink=jsonl_sink(log_path),
        **kwargs,
    )


# ── AC 1: every auto-provision event appends a schema-complete JSONL row ─


def test_provision_run_appends_schema_complete_rows(tmp_path):
    log = tmp_path / ".context" / "provisions.jsonl"  # parent created by sink
    result = provision_to(log, tmp_path)
    assert result.outcome == PROVISIONED
    rows = [json.loads(l) for l in log.read_text().splitlines()]
    assert len(rows) == len(result.audit)  # one durable row per decision
    for row in rows:
        assert set(row) == {"ts", "address", "level", "outcome", "actor", "detail"}
        assert row["ts"].endswith("Z")  # ISO8601 UTC
        assert row["outcome"] == "allow"
        assert row["actor"] == "aef-resolve"
        assert row["address"].startswith("aef::")


def test_append_only_two_runs_accumulate(tmp_path):
    log = tmp_path / "provisions.jsonl"
    provision_to(log, tmp_path)
    first = len(log.read_text().splitlines())
    assert first > 0
    provision_to(log, tmp_path)
    assert len(log.read_text().splitlines()) == first * 2  # nothing rewritten


def test_actor_override_lands_in_row(tmp_path):
    log = tmp_path / "provisions.jsonl"
    append_row(
        {"level": "hub", "address": "aef::host=h::hub=H-1::", "decision": "allow"},
        path=log,
        actor="governor-v1",
    )
    assert read_rows(log)[0]["actor"] == "governor-v1"


# ── AC 3: deny (S5) and halted (S6) decisions are logged too ─────────────


def test_denied_admission_is_logged(tmp_path):
    log = tmp_path / "provisions.jsonl"
    result = provision_to(log, tmp_path, admission=lambda level, intended: False)
    assert result.outcome == DENIED
    rows = read_rows(log)
    assert rows  # the deny landed durably
    assert rows[-1]["outcome"] == "deny"


def test_missing_path_halt_is_logged(tmp_path):
    log = tmp_path / "provisions.jsonl"
    target = circuit(str(tmp_path / "not-on-disk"))
    found = AEFAddress(host=target.host, hub=target.hub)
    result = provision(
        target, probe_knowing(found), make_provisioners(),
        audit_sink=jsonl_sink(log),
    )
    assert result.outcome == HALTED
    rows = read_rows(log)
    assert len(rows) == 1
    assert rows[0]["outcome"] == "halted"
    assert rows[0]["level"] == "project"
    assert "S6" in rows[0]["detail"]


# ── reading: malformed tolerance, tail, missing file ─────────────────────


def test_read_skips_malformed_lines(tmp_path):
    log = tmp_path / "provisions.jsonl"
    append_row({"level": "hub", "address": "a", "decision": "allow"}, path=log)
    with open(log, "a") as fh:
        fh.write("{torn write, not json\n")
        fh.write("[1, 2, 3]\n")  # valid json, not a row object
    append_row({"level": "agent", "address": "b", "decision": "allow"}, path=log)
    rows = read_rows(log)
    assert [r["level"] for r in rows] == ["hub", "agent"]


def test_read_missing_file_and_tail(tmp_path):
    assert read_rows(tmp_path / "absent.jsonl") == []
    log = tmp_path / "provisions.jsonl"
    for i in range(5):
        append_row({"level": "agent", "address": f"a{i}", "decision": "allow"}, path=log)
    assert [r["address"] for r in read_rows(log, tail=2)] == ["a3", "a4"]


def test_default_log_path_honours_project_root(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    assert default_log_path() == tmp_path / ".context" / "provisions.jsonl"


# ── AC 2: the readable surface (`fw provisions` → this module's CLI) ─────


def test_cli_main_renders_rows(tmp_path, capsys):
    log = tmp_path / "provisions.jsonl"
    append_row(
        {"level": "session", "address": "aef::host=h::", "decision": "deny",
         "reason": "governor said no"},
        path=log,
    )
    assert main(["--tail", "1", "--path", str(log)]) == 0
    out = capsys.readouterr().out
    assert "deny" in out and "governor said no" in out
    assert format_rows(read_rows(log)).count("\n") == 0  # one line per row


def test_cli_main_empty_trail_is_exit_zero(tmp_path, capsys):
    assert main(["--path", str(tmp_path / "absent.jsonl")]) == 0
    assert "No provision audit rows yet" in capsys.readouterr().out


def test_fw_provisions_verb_smoke():
    """`bash bin/fw provisions --tail 1` is read-only and exits 0 whether or
    not the trail exists yet (the verb the operator actually types)."""
    proc = subprocess.run(
        ["bash", str(REPO_ROOT / "bin" / "fw"), "provisions", "--tail", "1"],
        cwd=REPO_ROOT, capture_output=True, text=True, timeout=60,
    )
    assert proc.returncode == 0, proc.stderr
    assert "provision" in proc.stdout.lower()
