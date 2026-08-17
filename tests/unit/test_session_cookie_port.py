"""T-3065: the session cookie is named for the port actually being served.

The defect these tests pin is not "the name is wrong". T-2278 shipped a correct
name for the environment path and a six-line comment asserting per-port scoping
was in place; what it never covered was the `--port` flag, which is parsed into a
local and handed to `run()` without touching `Config.PORT`. So the case that
matters here is the flag case, and a suite that only exercises FW_PORT would have
been green against the broken code — which is the same thing as no suite (L-616).

Reported upstream by 832-Workflow-designer (agent-chat-arc thread
`aef-upstream-findings-2026-08-16`, item 3), who measured two instances on one
host both emitting `fw_session_3000`.
"""

import subprocess
import sys
from pathlib import Path

FW_ROOT = Path(__file__).resolve().parents[2]


def _cookie_name_for(argv, env_port=None):
    """Resolve the cookie name the way a real start-up does, in a clean process.

    A subprocess is load-bearing rather than fussy: `Config.PORT` is a class
    attribute evaluated at import, and `web.app` builds a module-level `app` at
    import too. Both are therefore one-shot per interpreter — an in-process test
    would read whatever the first import happened to bake in, and would keep
    passing after a regression reintroduced exactly that coupling.
    """
    code = (
        "import sys; sys.argv = %r\n"
        "from web import app as m\n"
        "import argparse\n"
        "p = argparse.ArgumentParser()\n"
        "p.add_argument('--port', '-p', type=int, default=m.Config.PORT)\n"
        "a, _ = p.parse_known_args()\n"
        # Mirror main()'s ordering: build-time default, then flag override.
        "m.apply_session_cookie_name(m.app, a.port)\n"
        "print(m.app.config['SESSION_COOKIE_NAME'])\n"
    ) % (argv,)

    env = {"PATH": "/usr/bin:/bin", "HOME": str(FW_ROOT)}
    if env_port is not None:
        env["FW_PORT"] = str(env_port)

    r = subprocess.run(
        [sys.executable, "-c", code],
        cwd=FW_ROOT, capture_output=True, text=True, env=env, timeout=120,
    )
    assert r.returncode == 0, f"start-up failed:\n{r.stderr[-2000:]}"
    return r.stdout.strip().splitlines()[-1]


def test_flag_port_wins_over_the_env_default():
    """The regression itself: --port 3012 must not emit fw_session_3000."""
    assert _cookie_name_for(["web/app.py", "--port", "3012"]) == "fw_session_3012"


def test_flag_port_wins_even_when_fw_port_disagrees():
    """Both sources present and different — the served port is the one that counts.

    This is 832's measured configuration: FW_PORT pointing at one instance while
    the flag starts another.
    """
    name = _cookie_name_for(["web/app.py", "--port", "3012"], env_port=3000)
    assert name == "fw_session_3012"


def test_env_port_still_names_the_cookie_when_no_flag_is_given():
    assert _cookie_name_for(["web/app.py"], env_port=3007) == "fw_session_3007"


def test_default_is_unchanged_with_neither_source():
    assert _cookie_name_for(["web/app.py"]) == "fw_session_3000"


def test_main_actually_applies_the_resolved_port():
    """The join, which the tests above cannot reach.

    Everything above exercises the helper and mirrors `main()`'s ordering; none of
    it would notice if `main()` stopped calling the helper, because none of it
    runs `main()` (that would mean binding a socket). Driving the real path is out
    of proportion, so the wiring is asserted at the source — the same shape used
    for the push-state consumer checks in t3063_push_state.bats, and named as a
    weaker assertion rather than dressed up as an end-to-end one.

    This is the leg T-2278 was missing: a correct helper wired nowhere reads
    exactly like a correct helper wired everywhere.
    """
    src = (FW_ROOT / "web" / "app.py").read_text()
    body = src.split("def main():", 1)
    assert len(body) == 2, "main() not found — this test's premise is stale"
    body = body[1]

    assert "apply_session_cookie_name(app, port)" in body, (
        "main() resolves --port but never re-scopes the cookie slot; the name "
        "stays at FW_PORT-or-3000 (the T-3065 defect)"
    )
    # Ordering matters: applying before `port = args.port` would re-apply the
    # very default it is meant to override.
    assert body.index("port = args.port") < body.index(
        "apply_session_cookie_name(app, port)"
    ), "cookie name applied before the flag is resolved"


def test_two_instances_on_one_host_do_not_share_a_slot():
    """The property the guard exists for, stated as a property rather than a value.

    T-2278's comment claims distinct instances get distinct slots. Asserting that
    directly means the test still fails if some future refactor makes the names
    equal again by a route nobody anticipated.
    """
    a = _cookie_name_for(["web/app.py", "--port", "3012"], env_port=3000)
    b = _cookie_name_for(["web/app.py"], env_port=3000)
    assert a != b, f"both instances occupy {a!r} — the collision T-2278 forbids"
