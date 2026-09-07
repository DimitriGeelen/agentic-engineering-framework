"""T-3311 (arc-020 S5): tests for the environmental governor v1.

Spec: docs/reports/T-3287-identity-taxonomy-circuit-model.md (D5 bound 2).
Covers: allow under threshold, defer in the busy band, deny when drowning,
FW_PROVISION_LOAD_MAX threshold resolution (including bad-value fallback,
logged), deny/defer logging (never silent), per-core normalization, fresh
sampling via callable load1, and the seam-compat leg — the governor plugged
into aef_resolve.provision()'s admission seam blocks provisioning.

Every test injects load1= — nothing here ever reads the live host's load.
"""

from __future__ import annotations

import sys
from dataclasses import replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.aef_address import AEFAddress, parse, serialize  # noqa: E402
from lib.aef_governor import (  # noqa: E402
    ALLOW,
    DEFAULT_LOAD_MAX,
    DEFER,
    DENY,
    admission_check,
    as_admission,
    load_threshold,
)
from lib.aef_resolve import DENIED, PROVISIONED, provision  # noqa: E402


def check(load1, cores=4, threshold=0.8, log=None):
    sink = log if log is not None else (lambda line: None)
    return admission_check(
        {"level": "session"},
        load1=load1,
        cpu_count=cores,
        threshold=threshold,
        log=sink,
    )


# ── decision bands ───────────────────────────────────────────────────────


def test_allow_under_threshold():
    # 2.0 over 4 cores -> 0.5/core, under 0.8
    assert check(load1=2.0) == ALLOW


def test_defer_in_busy_band():
    # 4.0 over 4 cores -> 1.0/core: >= 0.8, < 1.6
    assert check(load1=4.0) == DEFER


def test_deny_when_drowning():
    # load-62-shaped: 62 over 16 cores -> ~3.9/core, way past 2x threshold
    assert check(load1=62.0, cores=16) == DENY


def test_normalization_is_per_core():
    # Same absolute load, more cores -> more headroom -> allow
    assert check(load1=4.0, cores=4) == DEFER
    assert check(load1=4.0, cores=8) == ALLOW


def test_load1_callable_sampled_per_check():
    samples = iter([1.0, 8.0])
    fresh = lambda: next(samples)  # noqa: E731
    assert check(load1=fresh) == ALLOW
    assert check(load1=fresh) == DENY


# ── threshold configuration (FW_PROVISION_LOAD_MAX) ──────────────────────


def test_env_threshold_respected(monkeypatch):
    monkeypatch.setenv("FW_PROVISION_LOAD_MAX", "0.4")
    # 0.5/core allows at the 0.8 default but defers at 0.4
    assert check(load1=2.0, threshold=None) == DEFER


def test_default_threshold_when_env_unset(monkeypatch):
    monkeypatch.delenv("FW_PROVISION_LOAD_MAX", raising=False)
    assert load_threshold() == DEFAULT_LOAD_MAX
    assert check(load1=2.0, threshold=None) == ALLOW


def test_bad_env_threshold_falls_back_and_logs(monkeypatch):
    lines: list[str] = []
    monkeypatch.setenv("FW_PROVISION_LOAD_MAX", "not-a-number")
    assert load_threshold(log=lines.append) == DEFAULT_LOAD_MAX
    monkeypatch.setenv("FW_PROVISION_LOAD_MAX", "-1")
    assert load_threshold(log=lines.append) == DEFAULT_LOAD_MAX
    assert len(lines) == 2 and all("FW_PROVISION_LOAD_MAX" in ln for ln in lines)


# ── deny/defer are logged, never silent ──────────────────────────────────


def test_deny_is_logged_with_context():
    lines: list[str] = []
    assert check(load1=62.0, cores=16, log=lines.append) == DENY
    assert len(lines) == 1
    assert "deny" in lines[0] and "session" in lines[0]


def test_defer_is_logged_allow_is_not():
    lines: list[str] = []
    assert check(load1=4.0, log=lines.append) == DEFER
    assert len(lines) == 1 and "defer" in lines[0]
    lines.clear()
    assert check(load1=1.0, log=lines.append) == ALLOW
    assert lines == []


def test_deny_logs_to_stderr_by_default(capsys):
    decision = admission_check(
        {"level": "session"}, load1=62.0, cpu_count=16, threshold=0.8
    )
    assert decision == DENY
    err = capsys.readouterr().err
    assert "aef-governor" in err and "deny" in err


# ── seam-compat: governor plugged into aef_resolve.provision ─────────────


def make_provisioners():
    def make(level):
        def prov(intended: AEFAddress) -> AEFAddress | None:
            if level == "session" and intended.session is None:
                return replace(intended, session="S-fresh")
            return None

        return prov

    return {lvl: make(lvl) for lvl in ("hub", "project", "session", "agent")}


def probe_knowing(*existing: AEFAddress):
    known = {serialize(a) for a in existing}
    return lambda addr: serialize(addr) in known


def seam_target(tmp_path):
    proj = tmp_path / "proj"
    proj.mkdir()
    target = parse(
        "aef::host=host107.ring20.lan::hub=H-1"
        f"::project={proj}::session=S-8f3c::@reviewer::"
    )
    found = AEFAddress(host=target.host, hub=target.hub)
    return target, found


def test_seam_governor_deny_blocks_provisioning(tmp_path):
    target, found = seam_target(tmp_path)
    lines: list[str] = []
    admission = as_admission(
        load1=62.0, cpu_count=16, threshold=0.8, log=lines.append
    )
    result = provision(
        target, probe_knowing(found), make_provisioners(), admission=admission
    )
    assert result.outcome == DENIED
    assert result.materialized == ()
    # the governor logged the deny AND the ladder's own audit row recorded it
    assert lines and "deny" in lines[0]
    assert any(r["decision"] == "deny" for r in result.audit)


def test_seam_governor_allows_under_threshold(tmp_path):
    target, found = seam_target(tmp_path)
    admission = as_admission(
        load1=1.0, cpu_count=16, threshold=0.8, log=lambda line: None
    )
    result = provision(
        target, probe_knowing(found), make_provisioners(), admission=admission
    )
    assert result.outcome == PROVISIONED
