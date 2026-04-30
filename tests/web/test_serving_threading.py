"""Pin Watchtower's serving layer to threaded request handling.

T-1614 (T-1611-A regression prevention): T-1612 fixed local Watchtower
saturation by adding `threaded=True` to `web/app.py:app.run(...)`. Single-
threaded Werkzeug serialised concurrent requests through one worker; under
realistic browser load (auto-refresh + htmx polls), localhost curls timed
out behind queued LAN requests.

This test freezes the fix at the source level. If a future refactor
silently drops `threaded=True` (or reintroduces `threaded=False`), the
test fails and points at T-1612 / T-1611 for context.

Source-level (AST) freeze rather than a subprocess+curl smoke because:
  1. Subprocess tests are heavy and flaky in CI (port races, startup time).
  2. T-1612 already verified runtime behaviour (3 concurrent localhost
     curls return 200 in <1s post-fix vs 10s timeout pre-fix).
  3. The regression class is "developer drops a kwarg" — exactly what
     a static check catches.
"""

import ast
from pathlib import Path

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
APP_PY = FRAMEWORK_ROOT / "web" / "app.py"


def _parse_app_py() -> ast.Module:
    return ast.parse(APP_PY.read_text())


def _find_calls(tree: ast.Module, qualified_name: str) -> list[ast.Call]:
    """Find all Call nodes whose func matches the qualified name (e.g. 'app.run' or 'socketio.run')."""
    target_obj, target_attr = qualified_name.split(".", 1)
    calls = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        if isinstance(func, ast.Attribute) and func.attr == target_attr:
            value = func.value
            if isinstance(value, ast.Name) and value.id == target_obj:
                calls.append(node)
    return calls


def _has_kwarg(call: ast.Call, name: str) -> ast.keyword | None:
    for kw in call.keywords:
        if kw.arg == name:
            return kw
    return None


def test_app_run_passes_threaded_true():
    """app.run(...) must include threaded=True (T-1612)."""
    tree = _parse_app_py()
    app_run_calls = _find_calls(tree, "app.run")
    assert app_run_calls, "no app.run(...) call found in web/app.py — refactor changed the serving entry?"
    for call in app_run_calls:
        kw = _has_kwarg(call, "threaded")
        assert kw is not None, (
            f"app.run() at line {call.lineno} missing threaded= kwarg. "
            "T-1612 set threaded=True to prevent saturation. Do not drop it."
        )
        assert isinstance(kw.value, ast.Constant) and kw.value.value is True, (
            f"app.run() at line {call.lineno}: threaded must be the literal True. "
            "T-1612 / T-1611 explain the saturation root cause."
        )


def test_app_py_does_not_set_threaded_false():
    """Defensive: no threaded=False anywhere in web/app.py."""
    src = APP_PY.read_text()
    assert "threaded=False" not in src, (
        "web/app.py contains threaded=False — this disables concurrent "
        "request handling and re-introduces the T-1612 saturation regression."
    )


def test_socketio_run_call_present():
    """The socketio.run(...) branch must remain — Flask-SocketIO is the active path
    when SocketIO is registered. Threading async_mode is the default when neither
    eventlet nor gevent is installed (verified T-1611 Spike 2). If a future change
    swaps SocketIO transport, T-1611 inception should be revisited."""
    tree = _parse_app_py()
    sio_calls = _find_calls(tree, "socketio.run")
    assert sio_calls, (
        "no socketio.run(...) call in web/app.py — if SocketIO was removed, "
        "T-1611 inception (Werkzeug vs gunicorn) should be reopened."
    )
