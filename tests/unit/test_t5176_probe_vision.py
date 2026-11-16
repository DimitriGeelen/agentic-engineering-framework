"""T-5176: fw reviewer probe-vision — graded, recorded, launched in the review form, no ledger
or registry writes. The seat launch is stubbed; the real probe is run by hand (T-5175)."""
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.reviewer import probe_vision as pv  # noqa: E402

GOOD = f"CARDS: 8\nTITLE: \"{pv.DEFAULT_TITLE}\"\nMECHANISM: view_image\n"


@pytest.fixture()
def project(tmp_path):
    img = tmp_path / pv.DEFAULT_IMAGE
    img.parent.mkdir(parents=True)
    img.write_bytes(b"\x89PNG fake")
    (tmp_path / "policy").mkdir()
    (tmp_path / "policy/review-backends.yaml").write_text("UNCHANGED\n")
    return tmp_path


def _launcher(stdout, rc=0, seen=None):
    def go(argv, env_extra, cwd, timeout):
        if seen is not None:
            seen.update(argv=argv, env=env_extra, files=sorted(p.name for p in Path(cwd).iterdir()))
        return rc, stdout, ""
    return go


@pytest.mark.parametrize("text,want", [
    (GOOD, "sees"),
    ("CARDS: CANNOT VIEW\nTITLE: CANNOT VIEW\nMECHANISM: model has no image input\n", "cannot-view"),
    (f"CARDS: 7\nTITLE: {pv.DEFAULT_TITLE}\nMECHANISM: read\n", "wrong"),
    ("CARDS: 8\nTITLE: Onboarding: something else\nMECHANISM: read\n", "wrong"),
    ("I could not start.", "no-answer"),
])
def test_grading(text, want):
    assert pv.grade(text, pv.DEFAULT_COUNT, pv.DEFAULT_TITLE, 0)[0] == want


def test_run_records_and_suggests(project):
    seen = {}
    rec = pv.run_probe("antigravity", root=project, binary="/bin/agy",
                       launcher=_launcher(GOOD, seen=seen))
    assert rec["grade"] == "sees" and rec["suggested_vision"] == "true"
    assert seen["files"] == ["probe.png"]                        # only the screenshot
    assert seen["argv"][:5] == ["/usr/bin/sudo", "-n", "-u", pv.ANTIGRAVITY_USER, "-H"]
    assert "--sandbox" in seen["argv"] and "--mode" in seen["argv"]
    lines = (project / pv.RECORD).read_text().splitlines()
    assert len(lines) == 1 and json.loads(lines[0])["kind"] == "antigravity"


def test_never_touches_ledger_or_registry(project):
    pv.run_probe("codex", root=project, binary="/bin/codex", launcher=_launcher(GOOD))
    assert (project / "policy/review-backends.yaml").read_text() == "UNCHANGED\n"
    assert not (project / ".context/reviews/verdicts.jsonl").exists()


def test_codex_and_opencode_forms(project, tmp_path):
    argv, env = pv.launch_argv("codex", "/bin/codex", "p", tmp_path)
    assert argv[1:4] == ["exec", "-s", "read-only"] and "--ephemeral" in argv
    argv, env = pv.launch_argv("opencode", "/bin/oc", "p", tmp_path)
    assert "--agent" in argv and env == {"OPENCODE_DISABLE_PROJECT_CONFIG": "1"}


def test_non_harness_kind_refused(project):
    with pytest.raises(ValueError):
        pv.run_probe("claude", root=project, binary="/bin/claude", launcher=_launcher(GOOD))


def test_failed_launch_is_no_answer_with_error(project):
    rec = pv.run_probe("opencode", root=project, binary="/bin/oc",
                       launcher=lambda *a: (1, "", "auth expired"))
    assert rec["grade"] == "no-answer" and rec["suggested_vision"] == "unknown"
    assert "auth expired" in rec["answer"]["error"]


def test_opencode_json_events_are_read(project):
    events = "\n".join(json.dumps({"type": "text", "part": {"text": t}}) for t in GOOD.splitlines())
    rec = pv.run_probe("opencode", root=project, binary="/bin/oc", launcher=_launcher(events))
    assert rec["grade"] == "sees"
