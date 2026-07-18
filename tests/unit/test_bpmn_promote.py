"""Unit tests for `fw bpmn promote` (tools/bpmn_promote.py, T-2542).

Covers the write-out promotion invariants:
  - manifest round-trip (reads exactly what bpmn_to_tasks.write_proposals emits)
  - reconcile keyed on (uid, source_bpmn_sha): new / unchanged / changed / orphan
  - un-overridable owner:human + captured via the gated writer (create args)
  - provenance stamped as-is (832 IW-2 contract §3b), idempotently
  - dry-run writes nothing

Hermetic: the .tasks/ scan is pointed at a tmp dir (TASKS_DIR); the gated write
(`fw task create`) is monkeypatched so tests never touch the real repo .tasks/ or
shell out. One separate integration check exercises the real gate manually (see the
task's ## Verification), not here.
"""
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))

import bpmn_promote  # noqa: E402
import bpmn_to_tasks  # noqa: E402

FIXTURE = os.path.join(REPO_ROOT, "tests", "fixtures", "bpmn", "two-lane-sample.bpmn")


def _stage(tmp_path):
    """Compile the two-lane fixture into a tmp stage dir; return (stage_dir, manifests)."""
    stage = str(tmp_path / "staged")
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    bpmn_to_tasks.write_proposals(skeletons, FIXTURE, stage_dir=stage)
    return stage, bpmn_promote.load_manifests(stage)


def _write_task(tasks_active, tid, uid, sha, status="captured", ticked=False):
    """Write a minimal promoted task file carrying an aef_provenance block."""
    os.makedirs(tasks_active, exist_ok=True)
    ac = "- [x] done" if ticked else "- [ ] todo"
    text = (
        "---\n"
        f"id: {tid}\n"
        'name: "x"\n'
        "owner: human\n"
        "workflow_type: build\n"
        f"status: {status}\n"
        "aef_provenance:\n"
        f"  uid: {uid}\n"
        "  source_diagram: two-lane-sample.bpmn\n"
        f"  source_bpmn_sha: {sha}\n"
        "  promoted_at: 2026-01-01T00:00:00Z\n"
        "---\n\n## Acceptance Criteria\n\n### Agent\n"
        f"{ac}\n"
    )
    with open(os.path.join(tasks_active, f"{tid}.md"), "w", encoding="utf-8") as fh:
        fh.write(text)


# ── manifest round-trip ──────────────────────────────────────────────────────


def test_manifest_roundtrip(tmp_path):
    stage, manifests = _stage(tmp_path)
    assert len(manifests) == 1
    m = manifests[0]
    assert m["diagram"] == "two-lane-sample.bpmn"
    assert m["proposals"], "expected at least one staged proposal"
    for uid, entry in m["proposals"].items():
        assert "name" in entry and "sha" in entry and "workflow_type" in entry
        assert len(entry["sha"]) == 16  # _content_sha short hash


def test_load_manifests_missing_dir_is_empty():
    assert bpmn_promote.load_manifests("/nonexistent/stage/dir") == []


# ── reconcile states ─────────────────────────────────────────────────────────


def test_reconcile_new(tmp_path):
    _, manifests = _stage(tmp_path)
    actions = bpmn_promote.reconcile(manifests, existing={}, only_uid=None)
    assert actions and all(a["action"] == bpmn_promote.NEW for a in actions)


def test_reconcile_unchanged(tmp_path):
    _, manifests = _stage(tmp_path)
    uid = next(iter(manifests[0]["proposals"]))
    sha = manifests[0]["proposals"][uid]["sha"]
    existing = {uid: {"tid": "T-900", "path": "p", "status": "captured", "sha": sha, "human_touched": False}}
    actions = bpmn_promote.reconcile(manifests, existing, only_uid=uid)
    assert [a["action"] for a in actions] == [bpmn_promote.UNCHANGED]


def test_reconcile_changed_untouched_refresh(tmp_path):
    _, manifests = _stage(tmp_path)
    uid = next(iter(manifests[0]["proposals"]))
    existing = {uid: {"tid": "T-900", "path": "p", "status": "captured", "sha": "deadbeefdeadbeef", "human_touched": False}}
    actions = bpmn_promote.reconcile(manifests, existing, only_uid=uid)
    assert [a["action"] for a in actions] == [bpmn_promote.CHANGED_REFRESH]


def test_reconcile_changed_touched_refuse(tmp_path):
    _, manifests = _stage(tmp_path)
    uid = next(iter(manifests[0]["proposals"]))
    existing = {uid: {"tid": "T-900", "path": "p", "status": "started-work", "sha": "deadbeefdeadbeef", "human_touched": True}}
    actions = bpmn_promote.reconcile(manifests, existing, only_uid=uid)
    assert [a["action"] for a in actions] == [bpmn_promote.CHANGED_REFUSE]


def test_reconcile_orphan_only_in_all_sweep(tmp_path):
    _, manifests = _stage(tmp_path)
    existing = {"n_ghost": {"tid": "T-901", "path": "p", "status": "captured", "sha": "x", "human_touched": False}}
    # all-sweep flags the orphan
    acts_all = bpmn_promote.reconcile(manifests, existing, only_uid=None)
    assert any(a["action"] == bpmn_promote.ORPHAN and a["uid"] == "n_ghost" for a in acts_all)
    # single-uid promote of a real uid never flags orphans (can't see the full set)
    real_uid = next(iter(manifests[0]["proposals"]))
    acts_one = bpmn_promote.reconcile(manifests, existing, only_uid=real_uid)
    assert not any(a["action"] == bpmn_promote.ORPHAN for a in acts_one)


# ── scan_existing rebuilds the uid↔T-ID cache from frontmatter ───────────────


def test_scan_existing_reads_provenance(tmp_path, monkeypatch):
    tasks_root = tmp_path / "tasks"
    monkeypatch.setenv("TASKS_DIR", str(tasks_root))
    _write_task(str(tasks_root / "active"), "T-500", "n_alpha", "aaaabbbbccccdddd", status="captured")
    _write_task(str(tasks_root / "active"), "T-501", "n_beta", "1111222233334444", status="started-work")
    found = bpmn_promote.scan_existing()
    assert found["n_alpha"]["tid"] == "T-500"
    assert found["n_alpha"]["sha"] == "aaaabbbbccccdddd"
    assert found["n_alpha"]["human_touched"] is False
    assert found["n_beta"]["human_touched"] is True  # started-work


def test_scan_existing_ticked_ac_is_touched(tmp_path, monkeypatch):
    tasks_root = tmp_path / "tasks"
    monkeypatch.setenv("TASKS_DIR", str(tasks_root))
    _write_task(str(tasks_root / "active"), "T-502", "n_gamma", "5555666677778888", status="captured", ticked=True)
    found = bpmn_promote.scan_existing()
    assert found["n_gamma"]["human_touched"] is True  # ticked AC despite captured


# ── provenance stamping ──────────────────────────────────────────────────────


def test_stamp_provenance_idempotent(tmp_path):
    p = tmp_path / "T-600.md"
    p.write_text("---\nid: T-600\nowner: human\nstatus: captured\n---\n\nbody\n", encoding="utf-8")
    bpmn_promote.stamp_provenance(str(p), "n_x", "d.bpmn", "abc123")
    bpmn_promote.stamp_provenance(str(p), "n_x", "d.bpmn", "abc123")
    text = p.read_text(encoding="utf-8")
    assert text.count("aef_provenance:") == 1  # idempotent — one block only
    # block sits inside frontmatter (before the 2nd fence)
    second_fence = text.index("---", text.index("---") + 3)
    assert text.index("aef_provenance:") < second_fence
    assert "uid: n_x" in text and "source_bpmn_sha: abc123" in text


# ── write path: gated create + provenance, and dry-run writes nothing ────────


def test_apply_new_creates_via_gate_and_stamps(tmp_path, monkeypatch):
    _, manifests = _stage(tmp_path)
    actions = bpmn_promote.reconcile(manifests, existing={}, only_uid=None)

    created_files = []

    def fake_create(entry):
        tid = f"T-70{len(created_files)}"
        fpath = str(tmp_path / f"{tid}.md")
        with open(fpath, "w", encoding="utf-8") as fh:
            fh.write("---\nid: %s\nowner: human\nstatus: captured\n---\n\nbody\n" % tid)
        created_files.append(fpath)
        return tid, fpath

    monkeypatch.setattr(bpmn_promote, "create_via_gate", fake_create)
    bpmn_promote.apply_actions(actions, write=True)

    assert created_files, "expected NEW actions to create files"
    for fpath in created_files:
        txt = open(fpath, encoding="utf-8").read()
        assert "aef_provenance:" in txt  # provenance stamped after the gated create


def test_dry_run_never_calls_gate(tmp_path, monkeypatch):
    _, manifests = _stage(tmp_path)
    actions = bpmn_promote.reconcile(manifests, existing={}, only_uid=None)

    def boom(entry):
        raise AssertionError("create_via_gate must NOT be called in dry-run")

    monkeypatch.setattr(bpmn_promote, "create_via_gate", boom)
    lines = bpmn_promote.apply_actions(actions, write=False)
    assert lines and all("would-create" in ln for ln in lines)


def test_create_via_gate_forces_owner_human_captured(monkeypatch):
    """The gate delegation hard-codes --owner human and never passes --start."""
    captured = {}

    class FakeProc:
        returncode = 0
        stdout = "ID:       T-999\nFile:     /tmp/T-999.md\n"
        stderr = ""

    def fake_run(cmd, capture_output, text):
        captured["cmd"] = cmd
        return FakeProc()

    monkeypatch.setattr(bpmn_promote.subprocess, "run", fake_run)
    tid, fpath = bpmn_promote.create_via_gate(
        {"name": "attacker owner:agent", "workflow_type": "build", "horizon": "now", "owner": "agent"}
    )
    assert tid == "T-999" and fpath == "/tmp/T-999.md"
    cmd = captured["cmd"]
    # owner is forced to human regardless of entry content; --start is never present
    assert "--owner" in cmd and cmd[cmd.index("--owner") + 1] == "human"
    assert "--start" not in cmd
