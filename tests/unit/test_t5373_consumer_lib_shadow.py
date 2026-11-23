"""T-5373: framework python imports the framework's own ``lib`` from a consumer
root that ships its own regular ``lib/__init__.py``.

Origin: skills-manager (C-010, their T-489). ``fw inception decide`` recorded the
decision, then died in update-task.sh check_inception_scope_trace with
``ModuleNotFoundError: No module named 'lib.inception_decisions'``. The framework
``lib/`` was a namespace package (no ``__init__.py``), and Python prefers a
regular package over a namespace portion whatever the sys.path order, so the
consumer's ``lib`` won even with the framework root at sys.path[0].

Every case runs from the root of a temp consumer that has a decoy regular
``lib`` package, which is the shape no earlier fixture had.
"""
import os
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
UPDATE_TASK = ROOT / "agents" / "task-create" / "update-task.sh"
FW = ROOT / "bin" / "fw"


@pytest.fixture
def consumer(tmp_path):
    c = tmp_path / "consumer"
    (c / "lib").mkdir(parents=True)
    (c / "lib" / "__init__.py").write_text("CONSUMER_DECOY = True\n")
    (c / "lib" / "helpers.py").write_text("X = 1\n")
    (c / ".tasks" / "active").mkdir(parents=True)
    return c


def _env(consumer):
    env = dict(os.environ)
    env.pop("PYTHONPATH", None)
    env["PROJECT_ROOT"] = str(consumer)
    env["FRAMEWORK_ROOT"] = str(ROOT)
    return env


def _heredoc(text, opener, terminator):
    """Body of the heredoc whose opening line contains ``opener``."""
    start = text.index(opener)
    body_start = text.index("\n", start) + 1
    end = text.index("\n" + terminator + "\n", body_start)
    return text[body_start:end]


def _logical_line(text, marker):
    """The shell logical line (backslash continuations joined) containing marker."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if marker in line:
            j = i
            while j > 0 and lines[j - 1].rstrip().endswith("\\"):
                j -= 1
            out = []
            k = j
            while True:
                out.append(lines[k].rstrip().rstrip("\\"))
                if not lines[k].rstrip().endswith("\\"):
                    break
                k += 1
            return " ".join(out).strip()
    raise AssertionError(f"marker not found: {marker}")


def test_framework_lib_is_a_regular_package():
    assert (ROOT / "lib" / "__init__.py").is_file()


def test_inception_scope_trace_python_imports_framework_lib(consumer):
    """The reported crash: update-task.sh check_inception_scope_trace (stdin)."""
    src = UPDATE_TASK.read_text()
    fn = src[src.index("check_inception_scope_trace() {"):]
    body = _heredoc(fn, "py_output=$(python3 - ", "PYEOF")
    task = consumer / ".tasks" / "active" / "T-001-x.md"
    task.write_text(
        "---\nid: T-001\nworkflow_type: inception\ninception_decisions:\n"
        "  - id: ship-it\n    text: ship the thing\n    ships_in: lib/helpers.py\n"
        "---\n# T-001\n"
    )
    r = subprocess.run(
        ["python3", "-", str(task), str(consumer), str(ROOT)],
        input=body, text=True, capture_output=True, cwd=consumer,
        env=_env(consumer), timeout=60,
    )
    assert "ModuleNotFoundError" not in r.stderr, r.stderr
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip().startswith("OK"), (r.stdout, r.stderr)


@pytest.mark.parametrize("marker, var", [
    ("import lib.govd_policy as p", "_pp_state"),
    ("import lib.govd_sandbox as s", "_sb_state"),
])
def test_fw_doctor_dash_c_helpers_import_framework_lib(consumer, marker, var):
    """bin/fw doctor `python3 -c` probes: 'err' means the import failed."""
    line = _logical_line(FW.read_text(), marker)
    assert line.startswith(var + "=$(")
    script = (
        f'FRAMEWORK_ROOT="{ROOT}"; PROJECT_ROOT="{consumer}"; '
        f'_pp_src="{consumer}/policy/proxy-policy.yaml"; '
        f'_sb_src="{consumer}/policy/sandbox-profile.yaml"; '
        f'{line}; echo "$' + var + '"'
    )
    r = subprocess.run(["bash", "-c", script], text=True, capture_output=True,
                       cwd=consumer, env=_env(consumer), timeout=60)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() and r.stdout.strip() != "err", (r.stdout, r.stderr)


def test_l387_advisory_heredoc_finds_framework_static_scan(consumer):
    """update-task.sh started-work advisory: it used to locate lib/reviewer by
    walking up from the CWD, so in a consumer it silently found nothing."""
    src = UPDATE_TASK.read_text()
    marker = "_l387_findings=$(python3 - "
    opener_line = next(l for l in src.splitlines() if marker in l)
    body = _heredoc(src[src.index(marker):], marker, "PY")
    # Replace the advisory's own logic after the import with a probe.
    probe = body.split("try:\n    from lib.reviewer import static_scan as ss", 1)[0]
    probe += ("from lib.reviewer import static_scan as ss\n"
              "print(ss.__file__)\n")
    m = re.search(r'python3 - (.*?) 2>', opener_line)
    assert m, opener_line
    args = m.group(1).split()
    env = _env(consumer)
    env["TASK_FILE"] = str(consumer / "x.md")
    argv = [subprocess.run(["bash", "-c", f'echo {a}'], text=True,
                           capture_output=True, env=dict(env, FRAMEWORK_ROOT=str(ROOT))
                           ).stdout.strip() for a in args]
    r = subprocess.run(["python3", "-", *argv], input=probe, text=True,
                       capture_output=True, cwd=consumer, env=env, timeout=60)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == str(ROOT / "lib" / "reviewer" / "static_scan.py"), (
        r.stdout, r.stderr)


def test_run_module_launcher_beats_cwd_lib(consumer):
    """`python3 -m lib.X` puts the CWD first; the launcher puts the framework root first."""
    r = subprocess.run(
        ["python3", str(ROOT / "lib" / "run_module.py"), "lib.unclosable_misfiled",
         "scan", "--facts"],
        text=True, capture_output=True, cwd=consumer, env=_env(consumer), timeout=60,
    )
    assert "ModuleNotFoundError" not in r.stderr, r.stderr
    assert r.returncode == 0, r.stderr


SHELL_FILES = [p for d in ("agents", "lib", "bin") for p in (ROOT / d).rglob("*")
               if p.is_file() and p.suffix in ("", ".sh") and "node_modules" not in p.parts
               and "__pycache__" not in p.parts]


def test_no_shell_runs_python_dash_m_lib_from_the_caller_cwd():
    """Prevention: every `python3 -m lib.X` in shell must run with the framework
    root as CWD (cd "$FRAMEWORK_ROOT"), otherwise use lib/run_module.py."""
    bad = []
    for p in SHELL_FILES:
        try:
            lines = p.read_text().splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for i, line in enumerate(lines):
            if not re.search(r'python3?"?\s+-m\s+lib\.', line) or line.lstrip().startswith("#"):
                continue
            window = "\n".join(lines[max(0, i - 3):i + 1])
            if 'cd "$FRAMEWORK_ROOT"' in window:
                continue
            bad.append(f"{p.relative_to(ROOT)}:{i + 1}")
    assert not bad, "python3 -m lib.* from caller CWD:\n" + "\n".join(bad)
