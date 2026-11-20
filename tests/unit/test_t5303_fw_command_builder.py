#!/usr/bin/env python3
"""T-5303 — one builder for printed fw commands (rule: T-5302 GO).

Shell (lib/paths.sh _fw_cmd / _emit_user_command), Python (lib/fw_command.py)
and Watchtower's `fw_cmd` template global must print identical text, on a
framework-repo fixture and on a vendored fixture, args with spaces and quotes
included. Also: `fw doctor`'s PATH-fw kind check (router / old shim / other /
absent).
"""
import html
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import fw_command  # noqa: E402

ARGS = [
    "doctor",
    "task review T-1",
    "inception decide T-1 go --rationale 'two words'",
    'git commit -m "T-1: it\'s done"',
    "",
]


def _framework_fixture(tmp: Path) -> Path:
    root = tmp / "fw repo"  # a space in the root: it must be quoted identically
    (root / "bin").mkdir(parents=True)
    (root / "FRAMEWORK.md").write_text("# fw\n")
    (root / "bin" / "fw").write_text("#!/bin/sh\n")
    return root


def _vendored_fixture(tmp: Path) -> Path:
    root = tmp / "consumer's project"  # a quote in the root
    (root / ".agentic-framework" / "bin").mkdir(parents=True)
    (root / ".agentic-framework" / "bin" / "fw").write_text("#!/bin/sh\n")
    return root


SHELL_LIBS = ["lib/paths.sh", "lib/fw-command.sh"]  # T-5304: paths.sh sources fw-command.sh


def _shell(root: Path, func: str, *args: str, lib: str = "lib/paths.sh") -> str:
    script = f'. "{ROOT}/{lib}" >/dev/null 2>&1; PROJECT_ROOT="$1"; shift; {func} "$@"'
    env = dict(os.environ, PROJECT_ROOT=str(root), FRAMEWORK_ROOT=str(ROOT))
    r = subprocess.run(["bash", "-c", script, "_", str(root), *args],
                       capture_output=True, text=True, env=env, check=True)
    return r.stdout.rstrip("\n")


def _template_global(root: Path, args: str) -> tuple[str, str]:
    """(global's return value, rendered-and-unescaped) as web/app.py registers it."""
    from jinja2 import Environment
    env = Environment(autoescape=True)
    env.globals["fw_cmd"] = lambda a="": fw_command.user_command(a, str(root))
    rendered = env.from_string("{{ fw_cmd(a) }}").render(a=args)
    return env.globals["fw_cmd"](args), html.unescape(rendered)


@pytest.mark.parametrize("lib", SHELL_LIBS)
@pytest.mark.parametrize("kind", ["framework", "vendored"])
@pytest.mark.parametrize("args", ARGS)
def test_shell_python_template_parity(tmp_path, kind, args, lib):
    root = (_framework_fixture if kind == "framework" else _vendored_fixture)(tmp_path)
    expected_fw = "bin/fw" if kind == "framework" else ".agentic-framework/bin/fw"

    assert fw_command.fw_path(root) == expected_fw
    assert _shell(root, "_fw_cmd", lib=lib) == expected_fw

    py = fw_command.user_command(args, root)
    sh = (_shell(root, "_emit_user_command", args, lib=lib) if args
          else _shell(root, "_emit_user_command", lib=lib))
    assert _shell(root, "_emit_user_command_in", str(root), args, lib=lib) == sh
    tg, rendered = _template_global(root, args)
    assert py == sh == tg == rendered

    assert py.startswith("cd '")  # both fixture roots need quoting
    assert py.endswith(f"{expected_fw} {args}" if args else expected_fw)
    assert " fw " not in f" {py.split(' && ', 1)[1]} ".replace(expected_fw, "")


def test_fw_command_lib_is_side_effect_free(tmp_path):
    """T-5304: bin/fw sources lib/fw-command.sh before anything is resolved, so
    sourcing it must define functions only: no output, no exports, no variables
    beyond its load guard, PROJECT_ROOT/FRAMEWORK_ROOT untouched."""
    script = (
        'unset PROJECT_ROOT FRAMEWORK_ROOT; set -u; '
        'before_env="$(env | sort)"; before_vars="$(compgen -v | sort)"; '
        f'out="$(. "{ROOT}/lib/fw-command.sh"; echo x)"; '
        f'. "{ROOT}/lib/fw-command.sh"; '
        '[ "$out" = x ] || { echo "OUTPUT:$out"; exit 1; }; '
        '[ "$(env | sort)" = "$before_env" ] || { echo ENV; exit 1; }; '
        'extra="$(comm -13 <(echo "$before_vars") <(compgen -v | sort) | grep -vx -e before_vars -e before_env -e out)"; '
        '[ "$extra" = _FW_COMMAND_LOADED ] || { echo "VARS:$extra"; exit 1; }; '
        'declare -F _fw_cmd _fw_quote_word _emit_user_command _emit_user_command_in >/dev/null; '
        'echo ok'
    )
    r = subprocess.run(["bash", "-c", script], capture_output=True, text=True,
                       env={"PATH": os.environ["PATH"], "HOME": str(tmp_path)}, cwd=tmp_path)
    assert r.stdout.strip() == "ok", r.stdout + r.stderr


def test_bin_fw_sources_the_builder():
    src = (ROOT / "bin" / "fw").read_text()
    assert 'source "$FW_LIB_DIR/fw-command.sh"' in src
    assert "_fw_cmd()" not in (ROOT / "lib" / "paths.sh").read_text()


def test_printed_root_round_trips_through_the_shell(tmp_path):
    root = _vendored_fixture(tmp_path)
    cmd = fw_command.user_command("x", root).split(" && ")[0]
    r = subprocess.run(["bash", "-c", f"{cmd} && pwd"], capture_output=True, text=True, check=True)
    assert r.stdout.strip() == str(root)


def test_never_bare_fw_even_when_fw_is_on_path(tmp_path):
    """Before T-5303 _fw_cmd returned bare `fw` whenever any fw was on PATH."""
    root = _vendored_fixture(tmp_path)
    bindir = tmp_path / "pathbin"
    bindir.mkdir()
    (bindir / "fw").write_text("#!/bin/sh\n")
    (bindir / "fw").chmod(0o755)
    script = (f'. "{ROOT}/lib/paths.sh" >/dev/null 2>&1; PATH="{bindir}:$PATH"; '
              f'PROJECT_ROOT="{root}"; _fw_cmd')
    r = subprocess.run(["bash", "-c", script], capture_output=True, text=True,
                       env=dict(os.environ, PROJECT_ROOT=str(root)), check=True)
    assert r.stdout.strip() == ".agentic-framework/bin/fw"


def test_the_framework_repo_itself():
    assert fw_command.fw_path(ROOT) == "bin/fw"
    assert fw_command.user_command("doctor", ROOT) == f"cd {ROOT} && bin/fw doctor"


def test_python_copies_use_the_module(tmp_path, monkeypatch):
    from lib import delegation_cli
    root = _vendored_fixture(tmp_path)
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    assert delegation_cli._fw() == ".agentic-framework/bin/fw"
    src = (ROOT / "web" / "designer_registry.py").read_text()
    assert "from lib.fw_command import fw_path" in src
    app_src = (ROOT / "web" / "app.py").read_text()
    assert 'app.jinja_env.globals["fw_cmd"]' in app_src


# ── fw doctor: which fw is on PATH ──────────────────────────────────────────

def _doctor(tmp_path, fw_body):
    bindir = tmp_path / "bin-on-path"
    bindir.mkdir(exist_ok=True)
    if fw_body is not None:
        (bindir / "fw").write_text(fw_body)
        (bindir / "fw").chmod(0o755)
    script = f'. "{ROOT}/lib/fw-path-check.sh"; fw_doctor_path_fw'
    # PATH holds only the fixture (a host may have a real fw in /usr/bin); the
    # check uses bash builtins, so it needs nothing else on PATH.
    env = dict(os.environ, PATH=str(bindir), FRAMEWORK_ROOT=str(ROOT), HOME=str(tmp_path))
    r = subprocess.run(["/bin/bash", "-c", script], capture_output=True, text=True, env=env)
    return r.returncode, r.stdout


def test_doctor_router(tmp_path):
    rc, out = _doctor(tmp_path, "#!/bin/bash\n# fw-router — the `fw` entry point on PATH (T-2793)\n")
    assert rc == 0 and "OK" in out and "router" in out


def test_doctor_old_shim_warns_with_refresh(tmp_path):
    rc, out = _doctor(tmp_path, "#!/bin/bash\n# fw-shim — Project-detecting wrapper\n")
    assert rc == 1 and "WARN" in out and "old fw-shim" in out
    assert f'cp "{ROOT}/bin/fw-router"' in out and "install.sh" in out


def test_doctor_other_is_info_only(tmp_path):
    rc, out = _doctor(tmp_path, "#!/bin/sh\necho something else\n")
    assert rc == 0 and "INFO" in out and "neither" in out


def test_doctor_absent_warns(tmp_path):
    rc, out = _doctor(tmp_path, None)
    assert rc == 1 and "No fw on PATH" in out and "install.sh" in out


def test_doctor_skips_a_project_copy_first_on_path(tmp_path):
    """A session started inside the repo has its bin/ first on PATH; that copy is
    not the host's entry point."""
    router_dir = tmp_path / "local-bin"
    router_dir.mkdir()
    (router_dir / "fw").write_text("#!/bin/bash\n# fw-router — x\n")
    (router_dir / "fw").chmod(0o755)
    script = f'. "{ROOT}/lib/fw-path-check.sh"; fw_doctor_path_fw'
    env = dict(os.environ, PATH=f"{ROOT}/bin:{router_dir}", FRAMEWORK_ROOT=str(ROOT))
    r = subprocess.run(["/bin/bash", "-c", script], capture_output=True, text=True, env=env)
    assert r.returncode == 0 and str(router_dir / "fw") in r.stdout


def test_doctor_wires_the_check():
    src = (ROOT / "bin" / "fw").read_text()
    assert "fw_doctor_path_fw || warnings=$((warnings + 1))" in src
