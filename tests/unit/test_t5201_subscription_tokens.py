"""T-5201 (T-5190 S2): every dispatch and review cost row names its subscription; a dispatch
records the token counts its result reports.

* meta.json `subscription` at launch: the assigned id (host-specific beats kind-only),
  "unassigned", or "unknown" + one stderr warning when the registry is unreadable/invalid —
  and the dispatch still goes ahead.
* meta.json `tokens` at completion: only the counts the result reports (no zero-fill), and no
  key at all when the result reports none.
* review cost rows carry `subscription`; existing rows are untouched and the readers accept
  rows with and without it.

Drives the REAL `termlink.sh dispatch` and run.sh with a stub `termlink` and a stub `claude`
(same sandbox shape as t4674_dispatch_target_path.bats). Fixture registries live in temp
project dirs; policy/subscriptions.yaml is never touched.
"""
from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "lib"))

import dispatch_tokens  # noqa: E402
import subscriptions  # noqa: E402

TL = ROOT / "agents" / "termlink" / "termlink.sh"
HOST = socket.gethostname()

REGISTRY = f"""subscriptions:
- id: claude-a
  harness: claude
  description: first claude seat
- id: claude-b
  harness: claude
  description: second claude seat
assignments:
- kind: claude
  subscription: claude-a
- kind: claude
  host: {HOST}
  subscription: claude-b
"""

KIND_ONLY = """subscriptions:
- id: claude-a
  harness: claude
  description: first claude seat
assignments:
- kind: claude
  subscription: claude-a
"""

NO_CLAUDE = """subscriptions:
- id: glm
  harness: glm
  description: coding plan
assignments:
- kind: opencode
  subscription: glm
"""

INVALID = """subscriptions:
- id: Not_An_Id
  harness: nope
assignments: []
"""

MODEL_USAGE_RESULT = {"type": "result", "subtype": "success", "result": "done",
                      "modelUsage": {"m1": {"inputTokens": 10, "outputTokens": 7,
                                            "cacheReadInputTokens": 100},
                                     "m2": {"inputTokens": 5, "outputTokens": 3}}}


def _project(tmp: Path, registry: str | None) -> Path:
    p = tmp / "proj"
    (p / "policy").mkdir(parents=True)
    (p / ".agentic-framework").symlink_to(ROOT)
    if registry is not None:
        (p / "policy" / "subscriptions.yaml").write_text(registry)
    return p


def _stubs(tmp: Path, result_line: dict | None) -> Path:
    stub = tmp / "stub"
    stub.mkdir()
    (stub / "termlink").write_text(f"""#!/bin/bash
case "$1" in
    pty) [ "$2" = inject ] && {{ setsid bash -c "$4" > "{tmp}/inject.out" 2>&1 < /dev/null 3>&- 4>&- & }} ;;
    --version) echo "termlink stub" ;;
esac
exit 0
""")
    line = json.dumps(result_line) if result_line is not None else ""
    (stub / "claude").write_text("#!/bin/bash\n" + (f"echo '{line}'\n" if line else "") + "exit 0\n")
    for f in ("termlink", "claude"):
        (stub / f).chmod(0o755)
    return stub


def _dispatch(tmp: Path, proj: Path, stub: Path, name: str) -> tuple[subprocess.CompletedProcess, Path]:
    dd = tmp / "dispatch"
    dd.mkdir(exist_ok=True)
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE", "PROJECT_ROOT")}
    env.update(PATH=f"{stub}:{os.environ['PATH']}", PROJECT_ROOT=str(proj),
               FW_DISPATCH_DIR=str(dd), FW_AGENT_SCOPE="0")
    r = subprocess.run(["bash", str(TL), "dispatch", "--task", "T-5201", "--name", name,
                        "--project", str(proj), "--prompt", "noop"],
                       cwd=proj, env=env, capture_output=True, text=True, timeout=120,
                       stdin=subprocess.DEVNULL)
    return r, dd / name


def _meta(w: Path) -> dict:
    return json.loads((w / "meta.json").read_text())


def _wait_done(w: Path) -> dict:
    for _ in range(300):
        try:
            m = _meta(w)
        except (OSError, ValueError):
            m = {}
        if m.get("status") in ("done", "failed") and "close_state" in m:
            return m
        time.sleep(0.2)
    raise AssertionError(f"worker never finished: {_meta(w)}\n" +
                         ((w / "stderr.log").read_text() if (w / "stderr.log").exists() else ""))


# ── record_id (unit) ─────────────────────────────────────────────────────────

def test_record_id_host_specific_beats_kind_only(tmp_path):
    f = tmp_path / "s.yaml"
    f.write_text(REGISTRY)
    assert subscriptions.record_id("claude", HOST, f) == ("claude-b", "")
    assert subscriptions.record_id("claude", "other-host", f) == ("claude-a", "")
    assert subscriptions.record_id("codex", HOST, f) == ("unassigned", "")


def test_record_id_invalid_or_unreadable_is_unknown_with_warning(tmp_path):
    f = tmp_path / "s.yaml"
    f.write_text(INVALID)
    sid, warn = subscriptions.record_id("claude", HOST, f)
    assert sid == "unknown" and warn.startswith("WARNING:") and "\n" not in warn
    f.write_text("subscriptions: [unclosed\n")
    assert subscriptions.record_id("claude", HOST, f)[0] == "unknown"
    # Unreadable for any reason (here: not UTF-8) is the same answer, never an exception.
    f.write_bytes(b"\xff\xfe\x00garbage")
    assert subscriptions.record_id("claude", HOST, f)[0] == "unknown"


# ── reported_counts (unit) ───────────────────────────────────────────────────

def test_reported_counts_sum_only_what_is_reported(tmp_path):
    s = tmp_path / "result.jsonl"
    s.write_text('{"type":"assistant"}\n' + json.dumps(MODEL_USAGE_RESULT) + "\n")
    assert dispatch_tokens.reported_counts(s) == {"input": 15, "output": 10, "cache_read": 100}


def test_reported_counts_flat_ollama_loop_result(tmp_path):
    s = tmp_path / "result.jsonl"
    s.write_text(json.dumps({"type": "result", "result": "x", "input_tokens": 4, "output_tokens": 2}) + "\n")
    assert dispatch_tokens.reported_counts(s) == {"input": 4, "output": 2}


@pytest.mark.parametrize("body", ["", '{"type":"assistant"}\n', '{"type":"result","result":"x"}\n'])
def test_reported_counts_none_when_nothing_reported(tmp_path, body):
    s = tmp_path / "result.jsonl"
    s.write_text(body)
    assert dispatch_tokens.reported_counts(s) is None
    assert dispatch_tokens.reported_counts(tmp_path / "absent.jsonl") is None


# ── dispatch end to end ──────────────────────────────────────────────────────

def test_dispatch_records_assigned_subscription_and_reported_tokens(tmp_path):
    proj = _project(tmp_path, REGISTRY)
    r, w = _dispatch(tmp_path, proj, _stubs(tmp_path, MODEL_USAGE_RESULT), "t5201-a")
    assert r.returncode == 0, r.stdout + r.stderr
    assert _meta(w)["subscription"] == "claude-b"
    m = _wait_done(w)
    assert m["subscription"] == "claude-b"
    assert m["tokens"] == {"input": 15, "output": 10, "cache_read": 100}  # no cache_creation: 0
    assert HOST not in json.dumps({k: m[k] for k in ("subscription", "tokens")})


def test_dispatch_kind_only_and_unassigned(tmp_path):
    proj = _project(tmp_path, KIND_ONLY)
    r, w = _dispatch(tmp_path, proj, _stubs(tmp_path, MODEL_USAGE_RESULT), "t5201-k")
    assert r.returncode == 0, r.stdout + r.stderr
    assert _meta(w)["subscription"] == "claude-a"
    _wait_done(w)
    (proj / "policy" / "subscriptions.yaml").write_text(NO_CLAUDE)
    r, w = _dispatch(tmp_path, proj, tmp_path / "stub", "t5201-u")
    assert r.returncode == 0, r.stdout + r.stderr
    assert _meta(w)["subscription"] == "unassigned"
    assert "WARNING: subscription" not in r.stderr
    _wait_done(w)


def test_dispatch_with_invalid_registry_records_unknown_and_continues(tmp_path):
    proj = _project(tmp_path, INVALID)
    r, w = _dispatch(tmp_path, proj, _stubs(tmp_path, None), "t5201-i")
    assert r.returncode == 0, r.stdout + r.stderr
    assert _meta(w)["subscription"] == "unknown"
    assert r.stderr.count("WARNING: subscription registry") == 1, r.stderr
    m = _wait_done(w)
    assert "tokens" not in m, m   # the stub result reported nothing: no tokens key, not zeros


# ── review cost ledger ───────────────────────────────────────────────────────

def _rc(proj: Path, *args: str) -> subprocess.CompletedProcess:
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    env["PROJECT_ROOT"] = str(proj)
    return subprocess.run([sys.executable, str(ROOT / "lib" / "review_cost.py"), *args],
                          cwd=proj, env=env, capture_output=True, text=True, timeout=60)


def _backend_kind(kind: str) -> str:
    import yaml
    reg = yaml.safe_load((ROOT / "policy" / "review-backends.yaml").read_text())
    items = reg.get("backends") if isinstance(reg, dict) else reg
    for b in items:
        if b.get("worker_kind") == kind and not b.get("approval_required"):
            return b["id"]
    pytest.skip(f"no internal backend with worker_kind {kind}")


@pytest.mark.parametrize("registry,expect,warns", [(REGISTRY, "claude-b", False),
                                                   (NO_CLAUDE, "unassigned", False),
                                                   (INVALID, "unknown", True)])
def test_cost_row_carries_subscription_and_old_rows_untouched(tmp_path, registry, expect, warns):
    proj = _project(tmp_path, registry)
    (proj / "policy" / "review-backends.yaml").write_text((ROOT / "policy" / "review-backends.yaml").read_text())
    ledger = proj / ".context" / "costs" / "reviews.jsonl"
    ledger.parent.mkdir(parents=True)
    old = json.dumps({"ts": "2026-11-01T00:00:00Z", "task": "T-1", "backend": "x", "class": "internal",
                      "purpose": "old", "tokens": None, "cost_amount": None, "metering": "unmetered",
                      "proposal_id": None, "evidence": None}) + "\n"
    ledger.write_text(old)
    backend = _backend_kind("claude")
    r = _rc(proj, "cost", "log", "--task", "T-5201", "--backend", backend, "--purpose", "code-review")
    assert r.returncode == 0, r.stdout + r.stderr
    lines = ledger.read_text().splitlines(keepends=True)
    assert lines[0] == old                    # the existing row is byte-identical
    row = json.loads(lines[1])
    assert row["subscription"] == expect
    assert ("WARNING: subscription registry" in r.stderr) is warns
    # readers accept rows with and without the field
    rep = _rc(proj, "cost", "report")
    assert rep.returncode == 0, rep.stdout + rep.stderr
    sys.path.insert(0, str(ROOT / "lib"))
    import review_cost
    recs, bad = review_cost.read_jsonl(ledger)
    assert len(recs) == 2 and not bad


def test_cost_row_for_backend_without_worker_kind_is_unassigned():
    import review_cost
    assert review_cost._subscription_for({"id": "x"}) == "unassigned"
