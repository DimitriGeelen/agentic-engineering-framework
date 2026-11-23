"""T-5370 — Mistral Vibe (`vibe`) as a fourth isolated review seat.

Hermetic: no vibe binary is launched. Checks the registry entry, the isolation argv that
`fw review isolated-run` builds from it, the tool markers, and that the `vibe` worker kind is
listed in every place a harness kind must be (parity with opencode).
"""
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib import review_cost, review_isolation as ri, verdict_ledger as vl  # noqa: E402
from lib.reviewer import probe_vision  # noqa: E402

TERMLINK = ROOT / "agents" / "termlink" / "termlink.sh"


def _reg() -> dict:
    return {b["id"]: b for b in yaml.safe_load((ROOT / "policy" / "review-backends.yaml").read_text())["backends"]}


def _run_sh() -> str:
    src = TERMLINK.read_text()
    start = src.index("cat > \"$wdir/run.sh\" <<'RUNEOF'\n") + len("cat > \"$wdir/run.sh\" <<'RUNEOF'\n")
    return src[start:src.index("\nRUNEOF\n", start)] + "\n"


def test_registry_entry_is_internal_subscription_cli_login():
    b = _reg()["mistral-vibe"]
    assert (b["cost_class"], b["harness_class"], b["approval_required"], b["cost_estimate_method"]) == \
        ("internal", "subscription", False, "unmetered")
    assert b["vendor"] == "mistral" and b["worker_kind"] == "vibe"
    assert b["credential"]["source"] == "cli-login" and b["credential"]["note"]
    assert b["binary"] == "/root/.local/bin/vibe"
    assert "mistral-vibe" in {x["id"] for x in review_cost.load_registry()}   # validator accepts it


def test_isolation_argv_is_headless_tools_off_one_turn_untrusted():
    b = _reg()["mistral-vibe"]
    argv, env = ri.seat_command(b, binary="/x/vibe", seat_dir=Path("/s/seat"), conf_dir=Path("/s/conf"),
                                prompt="PROMPT {seat_dir}", write_config=False)
    assert argv == ["/x/vibe", "--workdir", "/s/seat", "--agent", "plan", "--enabled-tools", "__no_tool__",
                    "--max-turns", "1", "--output", "streaming", "-p", "PROMPT {seat_dir}"]
    assert "--trust" not in argv and "--auto-approve" not in argv and "--yolo" not in argv
    # exactly one --enabled-tools, naming no real vibe tool (headless: all others disabled)
    i = argv.index("--enabled-tools")
    assert argv.count("--enabled-tools") == 1 and not argv[i + 1].startswith(("file_system", "bash", "read"))
    assert b["isolation"]["stdin"] == "closed"
    assert set(env) <= set(ri.ENV_KEEP)          # nothing extra handed to the seat


def test_tool_markers_flag_a_tool_event_and_not_a_plain_answer():
    b = _reg()["mistral-vibe"]
    attempt = json.dumps({"type": "effect", "title": "file_system.read_file",
                          "detail": {"toolName": "file_system.read_file"},
                          "state": {"status": "failed", "display": {"message": "Tool execution denied by approval policy"}}})
    answer = json.dumps({"type": "message", "role": "assistant",
                         "content": [{"type": "text", "text": "VERDICT: green"}]})
    assert ri.tool_use(b, attempt)
    assert ri.tool_use(b, answer) == []


def test_vibe_is_a_harness_kind_everywhere_a_kind_is_listed():
    src = TERMLINK.read_text()
    km = re.search(r'^DISPATCH_WORKER_KINDS="([^"]*)"', src, re.M)
    assert km
    kinds = km.group(1).split()
    assert "vibe" in kinds
    # every registry worker_kind is dispatchable
    assert {b["worker_kind"] for b in _reg().values() if b.get("worker_kind")} <= set(kinds)
    assert re.search(r'""\|claude\|ollama-loop\|codex\|opencode\|antigravity\|vibe\) : ;;', src)
    assert src.count("        codex|opencode|antigravity|vibe)\n") == 2
    run = _run_sh()
    m = re.search(r'case "\$WORKER_KIND" in ([a-z|-]+)\) HARNESS=1 ;; esac', run)
    assert m and set(m.group(1).split("|")) == set(vl.HARNESS_KINDS)
    assert "vibe" in vl.HARNESS_KINDS and "vibe" in vl.WORKTREE_CONFIG
    assert set(probe_vision.HARNESS_KINDS) == set(vl.HARNESS_KINDS)
    # the launch arm: export workdir, read-only agent, not trusted, JSONL out
    arm_m = re.search(r'\n            vibe\)\n(.*?)\n                ;;\n', run, re.S)
    assert arm_m
    arm = "\n".join(ln for ln in arm_m.group(1).splitlines() if not ln.lstrip().startswith("#"))
    assert '--workdir "$TREE" --agent plan --output streaming -p "$PROMPT_TEXT" < /dev/null' in arm
    assert "--trust" not in arm and "--auto-approve" not in arm


def _normaliser() -> str:
    run = _run_sh()
    start = run.index("python3 - \"$WDIR\" \"$WORKER_KIND\" <<'PYEOF'")
    body = run[run.index("\n", start) + 1:run.index("\nPYEOF\n", start)]
    return body


def test_run_sh_normalises_vibe_stream_to_result_md(tmp_path):
    events = [
        {"type": "message", "role": "user", "content": [{"type": "text", "text": "the brief"}], "sessionId": "s-1"},
        {"type": "reasoning", "text": "thinking"},
        {"type": "message", "role": "assistant", "content": [{"type": "text", "text": "VERDICT: green\nWHY: ok"}]},
    ]
    (tmp_path / "result.jsonl").write_text("".join(json.dumps(e) + "\n" for e in events))
    script = tmp_path / "norm.py"
    script.write_text(_normaliser())
    r = subprocess.run([sys.executable, "-I", str(script), str(tmp_path), "vibe"], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert (tmp_path / "result.md").read_text() == "VERDICT: green\nWHY: ok\n"
    assert vl._worker_session(tmp_path) == "s-1"


def test_probe_vision_has_a_vibe_launch_and_reads_its_answer(tmp_path):
    argv, _env = probe_vision.launch_argv("vibe", "/x/vibe", "P", tmp_path)
    assert argv == ["/x/vibe", "--workdir", str(tmp_path), "--agent", "plan", "--output", "streaming", "-p", "P"]
    out = json.dumps({"type": "message", "role": "assistant", "content": [{"type": "text", "text": "SEEN: red"}]})
    assert probe_vision._answer_text("vibe", out + "\n", tmp_path) == "SEEN: red"
