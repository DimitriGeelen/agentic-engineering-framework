"""T-4490 (T-4466 GO, operator 2026-10-20): GREEN-DEGRADED panel closes.

A rung-5 panel whose ONLY missing seats are provably UNAVAILABLE — dispatched, started and completed
by the signed runtime with no verdict at all — closes a REVIEWER-JUDGES criterion green-degraded
when at least two seats of distinct vendors judged green and none dissented. One test per
condition, including every refusal:

  1. every missing seat UNAVAILABLE with a recorded reason (never not-evaluated, never unproven)
  2. >= 2 distinct vendors green on the same reviewed revision; no amber/red
  3. GREEN-DEGRADED on the criterion, in the applied log, WARNed by audit
  4. never for tier-0-or-bypass / act-in-the-world / sovereignty criteria
  5. project opt-out REVIEW_GREEN_DEGRADED (default on; anything but 1/true/yes/on is off)
  6. per-ISO-week count in audit

Runs through the real run.sh with stub harness binaries (fixtures from t3582_harness_kinds_test).
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import delegation  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
import _review_runtime as rt  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (T-4205: autouse)
import t3582_harness_kinds_test as hk  # noqa: E402
from t3580_judge_cli_test import NOCAP, TID, repo  # noqa: E402,F401
from t3582_harness_kinds_test import hrepo_hi  # noqa: E402,F401

KV = {"claude": "anthropic", "codex": "openai", "opencode": "zai"}

#: Prepended to a stub harness: STUB_MODE=dead is a seat that cannot reach a verdict (a provider
#: error, exit 1, nothing printed that parses as a verdict) — the T-4457 shape.
_DEAD = ('import os as _o, sys as _s, json as _j\n'
         'if _o.environ.get("STUB_MODE") == "dead":\n'
         '    print(_j.dumps({"type": "error", "error": {"name": "ProviderError", '
         '"data": {"message": "provider unavailable"}}}))\n'
         '    _s.exit(1)\n')


@pytest.fixture()
def panel_repo(hrepo_hi):
    """hrepo_hi (rung 5: claude, codex, opencode) whose codex and opencode stubs can die."""
    d = hk._stub_dir(hrepo_hi)
    for k in ("codex", "opencode"):
        body = (d / k).read_text()
        shebang, rest = body.split("\n", 1)
        (d / k).write_text(f"{shebang}\n{_DEAD}{rest}")
    return hrepo_hi


def _crit(root):
    ctx = vl._task_ctx(root, TID)
    return ctx, next(x for x in vl.human_criteria(ctx.text) if x.index == 1)


def _panel(root, modes: dict[str, str], monkeypatch, *, reassign=False, unregistered=(),
           unstarted=()):
    """Run the rung-5 judge. `modes[kind]` is the stub verdict (or `dead`). A kind in
    `unregistered` is handed back with no registration at all; one in `unstarted` is registered
    but run.sh never starts it."""
    rt.unbound_spend(monkeypatch)
    seen = []

    class _Stop(Exception):
        pass

    def stop(_w):
        raise _Stop()

    def dispatcher(*, task_id, brief, root, name, vendor, revision="", run_id="", seat=""):
        did = f"{name}-{len(seen) + 1:012x}"
        seen.append({"did": did, "kind": vendor})
        if vendor in unregistered:
            return did
        try:
            hk._launch(root, did=did, kind=vendor, brief=brief, revision=revision, run_id=run_id,
                       seat=seat, mode=modes.get(vendor, "green"),
                       before_run=stop if vendor in unstarted else None)
        except _Stop:
            pass
        return did

    fn = judge_cli.judge_with_reassign if reassign else judge_cli.judge
    res = fn(TID, root, dispatcher=dispatcher, capture=NOCAP, worker_kinds=set(KV),
             kind_vendors=dict(KV))
    return res, seen


# ── condition 1 + 2: the close itself ────────────────────────────────────────────────────────

class TestGreenDegradedCloses:
    def test_two_vendors_green_and_one_unavailable_seat_close_green_degraded(self, panel_repo, monkeypatch):
        res, seen = _panel(panel_repo, {"codex": "dead"}, monkeypatch, reassign=True)
        # the unavailable seat does not stop the panel: the third seat still sits
        assert [s["kind"] for s in seen] == ["claude", "codex", "opencode"], seen
        assert res["outcomes"] == {1: vl.GREEN}, res.get("why")
        assert res["reassigned"] == [], res["reassigned"]           # closed, not re-run
        assert res["why"][1].startswith("GREEN-DEGRADED: "), res["why"]
        ctx, crit = _crit(panel_repo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is not None, why
        deg = vl.green_degraded_of(ctx, crit, good)
        assert "unavailable: " in deg and "exit 1, no verdict" in deg, deg
        assert "[anthropic]" in deg and "[zai]" in deg, deg

    def test_the_unavailable_seat_is_proven_by_its_signed_completion(self, panel_repo, monkeypatch):
        _res, seen = _panel(panel_repo, {"codex": "dead"}, monkeypatch)
        did = next(s["did"] for s in seen if s["kind"] == "codex")
        comps = vl._completions_for(panel_repo, did)
        assert len(comps) == 1 and comps[0]["verdicts"] == [] and comps[0]["exit_code"] == 1
        assert not [r for r in vl._read(vl.VERDICTS, panel_repo) if r.get("dispatch_id") == did]

    def test_control_a_whole_green_panel_is_not_degraded(self, panel_repo, monkeypatch):
        res, _seen = _panel(panel_repo, {}, monkeypatch)
        assert res["outcomes"] == {1: vl.GREEN}
        ctx, crit = _crit(panel_repo)
        good, _ = vl.satisfying_verdict(ctx, crit)
        assert good is not None and vl.green_degraded_of(ctx, crit, good) == ""


# ── condition 1: every missing seat must be PROVABLY unavailable ─────────────────────────────

class TestMissingSeatMustBeUnavailable:
    def test_refused_when_the_other_missing_seat_is_not_evaluated(self, panel_repo, monkeypatch):
        res, _ = _panel(panel_repo, {"codex": "dead", "opencode": "not-evaluated"}, monkeypatch)
        assert res["outcomes"][1] != vl.GREEN, res
        ctx, crit = _crit(panel_repo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and "never a not-evaluated" in why, why

    def test_refused_when_the_seat_was_never_registered(self, panel_repo, monkeypatch):
        res, _ = _panel(panel_repo, {}, monkeypatch, unregistered=("codex",))
        assert res["outcomes"][1] != vl.GREEN, res
        ctx, crit = _crit(panel_repo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and "not provably unavailable" in why and "never dispatched" in why, why

    def test_refused_when_the_seat_was_registered_but_never_started(self, panel_repo, monkeypatch):
        res, _ = _panel(panel_repo, {}, monkeypatch, unstarted=("codex",))
        assert res["outcomes"][1] != vl.GREEN, res
        ctx, crit = _crit(panel_repo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and "never ran" in why, why

    def test_refused_when_the_seat_has_two_completions(self, panel_repo, monkeypatch):
        _res, seen = _panel(panel_repo, {"codex": "dead"}, monkeypatch)
        did = next(s["did"] for s in seen if s["kind"] == "codex")
        comp = vl._completions_for(panel_repo, did)[0]
        with (panel_repo / vl.COMPLETIONS).open("a") as fh:
            fh.write(json.dumps(comp) + "\n")
        ctx, crit = _crit(panel_repo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and "2 runtime completion(s)" in why, why


# ── condition 2: >= 2 distinct vendors green; no dissent ─────────────────────────────────────

class TestGreensAndDissent:
    def test_refused_on_a_single_green(self, panel_repo, monkeypatch):
        res, seen = _panel(panel_repo, {"codex": "dead", "opencode": "dead"}, monkeypatch)
        assert [s["kind"] for s in seen] == ["claude", "codex", "opencode"]
        assert res["outcomes"][1] != vl.GREEN, res
        ctx, crit = _crit(panel_repo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and "1 green seat(s) across 1 vendor(s)" in why, why

    def test_refused_when_the_two_greens_are_one_vendor(self, panel_repo, monkeypatch):
        # Re-commit the fixture registry so codex maps to claude's vendor.
        reg = hk._registry({k: hk._stub_dir(panel_repo) / k for k in hk._STUBS})
        rt.commit_registry(panel_repo, reg.replace("vendor: openai", "vendor: anthropic"))
        res, _ = _panel(panel_repo, {"opencode": "dead"}, monkeypatch)
        assert res["outcomes"][1] != vl.GREEN, res
        ctx, crit = _crit(panel_repo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and "2 green seat(s) across 1 vendor(s)" in why, why

    def test_refused_when_a_seat_dissents(self, panel_repo, monkeypatch):
        res, seen = _panel(panel_repo, {"codex": "dead", "opencode": "amber"}, monkeypatch)
        assert res["outcomes"][1] == "amber", res
        ctx, crit = _crit(panel_repo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and "'amber'" in why, why


# ── condition 4: never an operator-only criterion ────────────────────────────────────────────

class TestCarveOuts:
    @pytest.mark.parametrize("cls", list(delegation.CARVE_OUTS))
    def test_refused_for_every_operator_only_class(self, panel_repo, monkeypatch, cls):
        _panel(panel_repo, {"codex": "dead"}, monkeypatch)
        monkeypatch.setattr(vl._Ctx, "classify", lambda self, c: delegation.Classification(
            cls, delegation.OPERATOR_ONLY, "test"))
        ctx, crit = _crit(panel_repo)
        # Outer layer: a reviewer verdict on an operator-only criterion is invalid anyway.
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and "not-reviewer-judged" in why, why
        # The degraded path's own check, with the row validator out of the way.
        monkeypatch.setattr(vl, "_fault", lambda *a, **k: None)
        mine = [r for r, _i in ctx.ledger.entries() if r.get("task") == TID and r.get("ac") == 1]
        last = next(r for r in reversed(mine) if r["outcome"] == vl.GREEN)
        fault, deg = vl._panel_state(ctx, crit, last, mine)
        assert deg == {} and f"a {cls} criterion never closes green-degraded" in fault, fault


# ── condition 5: the project opt-out ─────────────────────────────────────────────────────────

class TestOptOut:
    @pytest.mark.parametrize("value,on", [("1", True), ("true", True), ("0", False),
                                          ("off", False), ("maybe", False)])
    def test_only_an_explicit_truthy_value_keeps_it_on(self, tmp_path, monkeypatch, value, on):
        monkeypatch.setenv("FW_REVIEW_GREEN_DEGRADED", value)
        assert vl.green_degraded_enabled(tmp_path) is on

    def test_default_is_on(self, tmp_path, monkeypatch):
        monkeypatch.delenv("FW_REVIEW_GREEN_DEGRADED", raising=False)
        assert vl.green_degraded_enabled(tmp_path) is True

    def test_opted_out_the_panel_stops_and_refuses_as_before(self, panel_repo, monkeypatch):
        monkeypatch.setenv("FW_REVIEW_GREEN_DEGRADED", "0")
        res, seen = _panel(panel_repo, {"codex": "dead"}, monkeypatch)
        assert [s["kind"] for s in seen] == ["claude", "codex"], seen     # stops, as T-3852
        assert res["outcomes"][1] != vl.GREEN, res
        ctx, crit = _crit(panel_repo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and why.startswith("panel-incomplete: required seat"), why
        assert "provably" not in why, why

    def test_registered_in_config_sh_and_the_watchtower_config_page(self):
        assert '"REVIEW_GREEN_DEGRADED|1|' in (_HERE / "lib/config.sh").read_text()
        assert '("REVIEW_GREEN_DEGRADED", "1",' in (_HERE / "web/blueprints/config.py").read_text()


# ── condition 3 + 6: on the criterion, WARNed and counted per ISO week ───────────────────────

class TestDisclosure:
    def test_apply_writes_green_degraded_on_the_criterion_and_audit_warns(self, panel_repo, monkeypatch):
        _panel(panel_repo, {"codex": "dead"}, monkeypatch)
        out = vl.apply(TID, panel_repo)
        assert out["ticked"] and out["ticked"][0]["green_degraded"], out
        text = vl._task_ctx(panel_repo, TID).text
        ann = next(ln for ln in text.splitlines() if ln.lstrip().startswith("**Reviewer verdict:**"))
        assert "GREEN-DEGRADED: run " in ann and "unavailable: " in ann, ann
        assert vl.provenance_mismatches(panel_repo, TID, text) == []
        lines = vl.green_degraded_lines(panel_repo)
        assert any(ln.startswith(f"WARN green-degraded: {TID} AC#1 ") for ln in lines), lines
        assert any(ln.startswith("WARN green-degraded weekly: ") and ln.endswith(" 1")
                   for ln in lines), lines
        p = subprocess.run([sys.executable, str(_HERE / "lib/verdict_ledger.py"), "audit"],
                           cwd=panel_repo, env={**__import__("os").environ,
                                                "PROJECT_ROOT": str(panel_repo)},
                           capture_output=True, text=True)
        assert "WARN green-degraded: " in p.stdout and "WARN green-degraded weekly: " in p.stdout, p.stdout

    def test_weekly_count_groups_by_iso_week_and_counts_each_close_once(self, tmp_path):
        rows = [
            {"ts": "2026-10-19T10:00:00Z", "task": "T-1", "kind": "verdict-apply",
             "ticked": [{"ac": 1, "verdict_id": "V-a", "green_degraded": "x"}]},
            # the same close recited later is one close, not two
            {"ts": "2026-10-20T10:00:00Z", "task": "T-1", "kind": "verdict-recite",
             "recited": [{"ac": 1, "verdict_id": "V-a", "green_degraded": "x"}]},
            {"ts": "2026-10-25T10:00:00Z", "task": "T-2", "kind": "verdict-apply",
             "ticked": [{"ac": 2, "verdict_id": "V-b", "green_degraded": "y"}]},
            {"ts": "2026-10-26T10:00:00Z", "task": "T-3", "kind": "verdict-apply",
             "ticked": [{"ac": 1, "verdict_id": "V-c", "green_degraded": "z"},
                        {"ac": 2, "verdict_id": "V-d"}]},          # a whole panel: not counted
        ]
        (tmp_path / vl.APPLIED).parent.mkdir(parents=True)
        (tmp_path / vl.APPLIED).write_text("".join(json.dumps(r) + "\n" for r in rows))
        lines = vl.green_degraded_lines(tmp_path)
        assert [ln for ln in lines if "weekly" in ln] == [
            "WARN green-degraded weekly: 2026-W43 2", "WARN green-degraded weekly: 2026-W44 1"], lines
        assert len([ln for ln in lines if "weekly" not in ln]) == 3
