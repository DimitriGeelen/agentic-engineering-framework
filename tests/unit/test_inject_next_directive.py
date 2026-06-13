"""T-2364/T-2365 (T-2158 S2+S3) — unit tests for inject-next-directive.py.

Covers:
  S2 AC#1 — helper reads .next-directive.yaml and emits "## Next Directive" section
  S2 AC#2 — iteration counter increments across invocations + persists to state file
  S2 AC#3 — refuse-to-inject when iteration > max_iterations OR expires_at passed
  S2 AC#4 — no-directive / no-state degrades silently (empty stdout, exit 0)
  S3 AC#1 — .context/working/.continuous-mode.yaml unified config + state schema
  S3 AC#2 — default-disabled means no behavior when enabled: false
  S3 AC#3 — --source compact resets current_iteration to 0 before increment
  S3 AC#5 — conservative defaults seeded by helper / fw config get
"""

import importlib.util
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).resolve().parents[2]
HELPER = PROJECT_ROOT / "agents" / "context" / "inject-next-directive.py"


def _load_helper():
    spec = importlib.util.spec_from_file_location("inject_next_directive", HELPER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _file_layout(tmp_path):
    working = tmp_path / ".context" / "working"
    working.mkdir(parents=True)
    return working


def _write_directive(working, **overrides):
    payload = {
        "directive": "continue T-XXXX",
        "filed_by": "operator",
        "filed_at": "2026-06-13T09:15:00Z",
        "expires_at": "2026-06-14T09:00:00Z",
        "iteration": 0,
        "max_iterations": 5,
        "tier_ceiling": 1,
    }
    payload.update(overrides)
    (working / ".next-directive.yaml").write_text(yaml.safe_dump(payload))


def _write_cmode(working, **overrides):
    """Seed .continuous-mode.yaml with enabled-by-default for S2-style tests
    that pre-date the S3 disable-by-default rule."""
    payload = {
        "enabled": True,
        "max_iterations": 10,
        "tier_ceiling": 1,
        "expires_after_seconds": 86400,
        "current_iteration": 0,
    }
    payload.update(overrides)
    (working / ".continuous-mode.yaml").write_text(yaml.safe_dump(payload))


def _run_subprocess(tmp_path, now=None, source=None):
    args = [sys.executable, str(HELPER), "--project-root", str(tmp_path)]
    if now:
        args += ["--now", now]
    if source:
        args += ["--source", source]
    result = subprocess.run(args, capture_output=True, text=True)
    return result.stdout, result.returncode


# ─── S3 AC#2: default-disabled is the default ────────────────────────────────

def test_disabled_continuous_mode_is_silent_even_with_directive(tmp_path):
    """When .continuous-mode.yaml is absent or has enabled: false, helper
    emits nothing — backward compat with all pre-S3 sessions."""
    working = _file_layout(tmp_path)
    _write_directive(working)
    # No .continuous-mode.yaml at all
    stdout, rc = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert rc == 0
    assert stdout == ""


def test_explicit_disabled_short_circuits(tmp_path):
    working = _file_layout(tmp_path)
    _write_directive(working)
    _write_cmode(working, enabled=False)
    stdout, rc = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert rc == 0
    assert stdout == ""


# ─── S2 AC#4 baseline: degrade-to-no-op paths (continuous-mode ENABLED) ─────

def test_no_directive_file_is_silent_no_op(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working)
    stdout, rc = _run_subprocess(tmp_path)
    assert rc == 0
    assert stdout == ""


def test_directive_file_empty_directive_field_is_silent(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working)
    (working / ".next-directive.yaml").write_text("directive: ''\nfiled_by: self\n")
    stdout, rc = _run_subprocess(tmp_path)
    assert rc == 0
    assert stdout == ""


def test_directive_file_missing_directive_field_is_silent(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working)
    (working / ".next-directive.yaml").write_text("filed_by: self\n")
    stdout, rc = _run_subprocess(tmp_path)
    assert rc == 0
    assert stdout == ""


def test_malformed_yaml_is_silent_no_op(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working)
    (working / ".next-directive.yaml").write_text("not: [valid: yaml")
    stdout, rc = _run_subprocess(tmp_path)
    assert rc == 0
    assert stdout == ""


# ─── S2 AC#1: helper emits "## Next Directive" section ─────────────────────

def test_first_resume_emits_next_directive_section(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working, max_iterations=5)
    _write_directive(working, directive="extend post-compact-resume.sh", max_iterations=5)
    stdout, rc = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert rc == 0
    assert stdout.startswith("## Next Directive (iteration 1/5, tier_ceiling 1)")
    assert "extend post-compact-resume.sh" in stdout
    assert "Filed by: operator at 2026-06-13T09:15:00Z" in stdout
    assert "LOOP TERMINATED" not in stdout
    # T-2365 AC#1 schema: state file written at unified path
    assert (working / ".continuous-mode.yaml").is_file()


def test_section_renders_max_iter_unset_as_infinity(tmp_path):
    working = _file_layout(tmp_path)
    # Both config and directive unset → ∞
    _write_cmode(working, max_iterations=None)
    _write_directive(working, max_iterations=None)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert "iteration 1/∞" in stdout


def test_section_renders_tier_ceiling_unset(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working, tier_ceiling=None)
    _write_directive(working, tier_ceiling=None)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert "tier_ceiling unset" in stdout


# ─── S2 AC#2: iteration counter increments + persists ──────────────────────

def test_iteration_counter_increments_across_invocations(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working, max_iterations=5)
    _write_directive(working, max_iterations=5)
    stdout1, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    stdout2, _ = _run_subprocess(tmp_path, now="2026-06-13T11:00:00Z")
    stdout3, _ = _run_subprocess(tmp_path, now="2026-06-13T12:00:00Z")
    assert "iteration 1/5" in stdout1
    assert "iteration 2/5" in stdout2
    assert "iteration 3/5" in stdout3


def test_state_file_persists_after_first_resume(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working)
    _write_directive(working, directive="hello world")
    _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    state_file = working / ".continuous-mode.yaml"
    assert state_file.is_file()
    state = yaml.safe_load(state_file.read_text())
    assert state["current_iteration"] == 1
    assert state["last_resumed_at"] == "2026-06-13T10:00:00Z"
    assert state["last_directive_seen"] == "hello world"
    assert state["last_terminated_reason"] == ""
    # S3 schema fields preserved
    assert state["enabled"] is True
    assert state["max_iterations"] == 10
    assert state["tier_ceiling"] == 1


def test_state_file_carries_iteration_across_calls(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working)
    _write_directive(working)
    _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    _run_subprocess(tmp_path, now="2026-06-13T11:00:00Z")
    state = yaml.safe_load((working / ".continuous-mode.yaml").read_text())
    assert state["current_iteration"] == 2


# ─── S2 AC#3: refuse-to-inject on cap or expiry ────────────────────────────

def test_loop_terminated_when_iteration_exceeds_cap(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working, max_iterations=2)
    _write_directive(working, max_iterations=2)
    out1, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    out2, _ = _run_subprocess(tmp_path, now="2026-06-13T10:30:00Z")
    out3, _ = _run_subprocess(tmp_path, now="2026-06-13T11:00:00Z")
    assert "iteration 1/2" in out1
    assert "iteration 2/2" in out2
    assert "LOOP TERMINATED" in out3
    assert "iteration 3 exceeds max_iterations 2" in out3


def test_loop_terminated_when_expires_at_passed(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working)
    _write_directive(working, expires_at="2026-06-12T00:00:00Z")
    stdout, rc = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert rc == 0
    assert "LOOP TERMINATED" in stdout
    assert "2026-06-12T00:00:00Z passed" in stdout


def test_loop_terminated_state_records_reason(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working, max_iterations=0)
    _write_directive(working, max_iterations=0)
    _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    state = yaml.safe_load((working / ".continuous-mode.yaml").read_text())
    assert state["current_iteration"] == 1
    assert "exceeds max_iterations 0" in state["last_terminated_reason"]


def test_no_cap_no_expiry_runs_forever(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working, max_iterations=None, expires_after_seconds=None)
    _write_directive(working, max_iterations=None, expires_at=None)
    for i in range(1, 11):
        out, _ = _run_subprocess(tmp_path, now=f"2026-06-13T{i:02d}:00:00Z")
        assert "LOOP TERMINATED" not in out
        assert f"iteration {i}/∞" in out


# ─── S3 AC#3: --source compact resets current_iteration ────────────────────

def test_source_compact_resets_iteration_counter(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working, current_iteration=4, max_iterations=5)
    _write_directive(working, max_iterations=5)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z", source="compact")
    # 4 → reset to 0 → +1 = 1
    assert "iteration 1/5" in stdout
    state = yaml.safe_load((working / ".continuous-mode.yaml").read_text())
    assert state["current_iteration"] == 1
    assert state["last_source"] == "compact"


def test_source_resume_advances_iteration_counter(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working, current_iteration=3, max_iterations=5)
    _write_directive(working, max_iterations=5)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z", source="resume")
    # 3 → +1 = 4 (no reset)
    assert "iteration 4/5" in stdout


def test_source_default_is_resume(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working, current_iteration=3, max_iterations=5)
    _write_directive(working, max_iterations=5)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")  # no --source
    assert "iteration 4/5" in stdout


# ─── S3 AC#5: config-fallback expires_after_seconds + cap precedence ───────

def test_config_expires_after_seconds_triggers_termination(tmp_path):
    """When the directive has no explicit expires_at, the config's
    expires_after_seconds + the directive's filed_at compute an effective
    expiry. A clock past that expiry → LOOP TERMINATED."""
    working = _file_layout(tmp_path)
    _write_cmode(working, expires_after_seconds=3600)  # 1 hour cap
    _write_directive(working, expires_at=None, filed_at="2026-06-13T09:00:00Z")
    # 2 hours after filed_at → past expiry
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T11:00:00Z")
    assert "LOOP TERMINATED" in stdout
    assert "2026-06-13T10:00:00Z passed" in stdout  # filed_at + 3600s


def test_directive_max_iterations_overrides_config(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working, max_iterations=10)
    _write_directive(working, max_iterations=2)  # tighter override
    out1, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    out2, _ = _run_subprocess(tmp_path, now="2026-06-13T10:30:00Z")
    out3, _ = _run_subprocess(tmp_path, now="2026-06-13T11:00:00Z")
    assert "iteration 1/2" in out1
    assert "iteration 2/2" in out2
    assert "LOOP TERMINATED" in out3


# ─── Programmatic API tests ────────────────────────────────────────────────

def test_evaluate_returns_empty_section_when_disabled():
    mod = _load_helper()
    now = datetime(2026, 6, 13, 10, 0, tzinfo=timezone.utc)
    _, section = mod.evaluate(
        {"directive": "do X"}, {"enabled": False}, now
    )
    assert section == ""


def test_evaluate_returns_empty_section_when_directive_missing():
    mod = _load_helper()
    now = datetime(2026, 6, 13, 10, 0, tzinfo=timezone.utc)
    _, section = mod.evaluate(
        {"filed_by": "self"}, {"enabled": True}, now
    )
    assert section == ""


def test_evaluate_advances_iteration():
    mod = _load_helper()
    now = datetime(2026, 6, 13, 10, 0, tzinfo=timezone.utc)
    state, section = mod.evaluate(
        {"directive": "do X", "max_iterations": 5},
        {"enabled": True, "current_iteration": 3},
        now,
    )
    assert state["current_iteration"] == 4
    assert "iteration 4/5" in section


def test_evaluate_handles_malformed_iteration_state():
    mod = _load_helper()
    now = datetime(2026, 6, 13, 10, 0, tzinfo=timezone.utc)
    state, section = mod.evaluate(
        {"directive": "do X"},
        {"enabled": True, "current_iteration": "not-a-number"},
        now,
    )
    assert state["current_iteration"] == 1
    assert "iteration 1/" in section


def test_evaluate_source_compact_clears_then_increments():
    mod = _load_helper()
    now = datetime(2026, 6, 13, 10, 0, tzinfo=timezone.utc)
    state, section = mod.evaluate(
        {"directive": "do X"},
        {"enabled": True, "current_iteration": 7, "max_iterations": 10},
        now,
        source="compact",
    )
    assert state["current_iteration"] == 1
    assert "iteration 1/10" in section
    assert state["last_source"] == "compact"


def test_evaluate_config_defaults_seeded_on_empty_state():
    """When state_data is empty, evaluate fills in CONFIG_DEFAULTS — including
    enabled: False (so an unseeded session never accidentally goes live)."""
    mod = _load_helper()
    now = datetime(2026, 6, 13, 10, 0, tzinfo=timezone.utc)
    state, section = mod.evaluate(
        {"directive": "do X"}, {}, now
    )
    # enabled defaults False → no section
    assert section == ""
    # But the new_state still carries the defaults
    assert state["enabled"] is False
    assert state["max_iterations"] == 10
    assert state["tier_ceiling"] == 1
    assert state["expires_after_seconds"] == 86400


def test_parse_iso8601_accepts_z_suffix():
    mod = _load_helper()
    dt = mod.parse_iso8601("2026-06-14T09:00:00Z")
    assert dt is not None
    assert dt.tzinfo is timezone.utc
    assert dt.year == 2026


def test_parse_iso8601_accepts_datetime_passthrough():
    mod = _load_helper()
    dt = datetime(2026, 6, 14, 9, 0, tzinfo=timezone.utc)
    assert mod.parse_iso8601(dt) is dt


def test_format_iso8601_normalises_datetime_to_z_suffix():
    mod = _load_helper()
    dt = datetime(2026, 6, 14, 9, 0, tzinfo=timezone.utc)
    assert mod.format_iso8601(dt) == "2026-06-14T09:00:00Z"
    naive = datetime(2026, 6, 14, 9, 0)
    assert mod.format_iso8601(naive) == "2026-06-14T09:00:00Z"
    assert mod.format_iso8601("2026-06-14T09:00:00Z") == "2026-06-14T09:00:00Z"
    assert mod.format_iso8601(None) == "unset"
    assert mod.format_iso8601("") == "unset"


def test_loop_terminated_message_normalises_datetime_expiry(tmp_path):
    working = _file_layout(tmp_path)
    _write_cmode(working)
    payload = """directive: do X
filed_by: operator
filed_at: 2026-06-13T09:15:00Z
expires_at: 2026-06-12T00:00:00Z
max_iterations: 5
"""
    (working / ".next-directive.yaml").write_text(payload)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert "LOOP TERMINATED" in stdout
    assert "2026-06-12T00:00:00Z passed" in stdout
    assert "2026-06-12 00:00:00+00:00" not in stdout


def test_parse_iso8601_returns_none_on_garbage():
    mod = _load_helper()
    assert mod.parse_iso8601("not-a-date") is None
    assert mod.parse_iso8601("") is None
    assert mod.parse_iso8601(None) is None


# ─── Legacy state migration ─────────────────────────────────────────────────

def test_legacy_state_file_migrates_to_unified(tmp_path):
    """When pre-S3 `.continuous-mode-state.yaml` exists and unified file is
    absent, the legacy iteration counter migrates into the new file. Legacy
    file is removed after the migration."""
    working = _file_layout(tmp_path)
    # Pre-S3 file
    legacy = working / ".continuous-mode-state.yaml"
    legacy.write_text(yaml.safe_dump({
        "iteration": 3,
        "last_resumed_at": "2026-06-13T08:00:00Z",
        "last_directive_seen": "old-directive",
        "last_terminated_reason": "",
    }))
    # No directive → migration runs but no injection
    stdout, rc = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert rc == 0
    assert stdout == ""
    # Unified file exists with migrated iteration
    unified = working / ".continuous-mode.yaml"
    assert unified.is_file()
    state = yaml.safe_load(unified.read_text())
    assert state["current_iteration"] == 3
    assert state["last_resumed_at"] == "2026-06-13T08:00:00Z"
    # Migration keeps enabled=False until operator opts in
    assert state["enabled"] is False
    # Legacy file removed
    assert not legacy.is_file()


# ─── S5 (T-2367): bounded-autonomy ceiling — blast-radius vs tier_ceiling ─────


def _write_task(tmp_path, task_id, blast_radius=None, proposed_blast=None):
    """Seed .tasks/active/<task_id>-slug.md with a cost_estimate frontmatter.
    blast_radius → confirmed cost_estimate; proposed_blast → cost_estimate_proposed."""
    tasks = tmp_path / ".tasks" / "active"
    tasks.mkdir(parents=True, exist_ok=True)
    fm = {"id": task_id}
    if blast_radius is not None:
        fm["cost_estimate"] = {"blast_radius": blast_radius, "tier": 2, "effort": 4}
    if proposed_blast is not None:
        fm["cost_estimate_proposed"] = [
            {"ts": "2026-06-13T00:00:00Z",
             "cost_estimate": {"blast_radius": proposed_blast, "tier": 1, "effort": 2}}
        ]
    (tasks / f"{task_id}-slug.md").write_text("---\n" + yaml.safe_dump(fm) + "---\n# body\n")


def test_blast_radius_over_ceiling_refuses_and_freezes_counter(tmp_path):
    """AC#2/#5b: planned task blast-radius > tier_ceiling → operator-continuation
    notice, iteration counter frozen (not advanced)."""
    working = _file_layout(tmp_path)
    _write_cmode(working, tier_ceiling=1, current_iteration=1)
    _write_directive(working, directive="continue T-9001 big task", next_task="T-9001",
                     max_iterations=10)
    _write_task(tmp_path, "T-9001", blast_radius=3)
    stdout, rc = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert rc == 0
    assert "TIER CEILING EXCEEDED" in stdout
    assert "T-9001" in stdout and "blast-radius **3**" in stdout
    state = yaml.safe_load((working / ".continuous-mode.yaml").read_text())
    assert state["current_iteration"] == 1  # frozen, not advanced to 2
    assert "tier ceiling exceeded" in state["last_terminated_reason"]


def test_blast_radius_within_ceiling_continues(tmp_path):
    """AC#5a: planned task blast-radius <= tier_ceiling → normal directive,
    counter advances."""
    working = _file_layout(tmp_path)
    _write_cmode(working, tier_ceiling=1, current_iteration=1)
    _write_directive(working, directive="continue T-9002 small task", next_task="T-9002",
                     max_iterations=10)
    _write_task(tmp_path, "T-9002", blast_radius=1)
    stdout, rc = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert rc == 0
    assert "TIER CEILING EXCEEDED" not in stdout
    assert "## Next Directive (iteration 2/" in stdout
    state = yaml.safe_load((working / ".continuous-mode.yaml").read_text())
    assert state["current_iteration"] == 2


def test_proposed_cost_estimate_used_when_confirmed_absent(tmp_path):
    """Resolver falls back to cost_estimate_proposed[].cost_estimate.blast_radius."""
    working = _file_layout(tmp_path)
    _write_cmode(working, tier_ceiling=1, current_iteration=1)
    _write_directive(working, directive="continue T-9003", next_task="T-9003",
                     max_iterations=10)
    _write_task(tmp_path, "T-9003", proposed_blast=5)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert "TIER CEILING EXCEEDED" in stdout
    assert "blast-radius **5**" in stdout


def test_next_task_field_takes_precedence_over_prose_ref(tmp_path):
    """next_task: wins over the first T-NNNN in prose (prose names a low-blast
    completed task first, but next_task points at the high-blast planned one)."""
    working = _file_layout(tmp_path)
    _write_cmode(working, tier_ceiling=1, current_iteration=1)
    _write_directive(working,
                     directive="T-9004 done. Now continue T-9005 (the real next).",
                     next_task="T-9005", max_iterations=10)
    _write_task(tmp_path, "T-9004", blast_radius=0)
    _write_task(tmp_path, "T-9005", blast_radius=4)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert "TIER CEILING EXCEEDED" in stdout
    assert "T-9005" in stdout


def test_first_prose_task_ref_used_when_next_task_absent(tmp_path):
    """No next_task: → first T-NNNN in prose is the planned action."""
    working = _file_layout(tmp_path)
    _write_cmode(working, tier_ceiling=1, current_iteration=1)
    _write_directive(working, directive="continue T-9006 then T-9007", max_iterations=10)
    _write_task(tmp_path, "T-9006", blast_radius=9)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert "TIER CEILING EXCEEDED" in stdout
    assert "T-9006" in stdout


def test_unresolvable_blast_radius_proceeds(tmp_path):
    """AC#4: task ref present but no cost_estimate frontmatter → no ceiling
    breach (cannot assess) → directive proceeds normally."""
    working = _file_layout(tmp_path)
    _write_cmode(working, tier_ceiling=1, current_iteration=1)
    _write_directive(working, directive="continue T-9008", next_task="T-9008",
                     max_iterations=10)
    _write_task(tmp_path, "T-9008")  # no cost_estimate at all
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert "TIER CEILING EXCEEDED" not in stdout
    assert "## Next Directive (iteration 2/" in stdout


def test_no_task_reference_proceeds(tmp_path):
    """AC#5c-adjacent: directive with no T-NNNN reference → no ceiling check,
    directive proceeds (zero ceiling overhead)."""
    working = _file_layout(tmp_path)
    _write_cmode(working, tier_ceiling=1, current_iteration=1)
    _write_directive(working, directive="refactor the widget styles", max_iterations=10)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert "TIER CEILING EXCEEDED" not in stdout
    assert "## Next Directive (iteration 2/" in stdout
