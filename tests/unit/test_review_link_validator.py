"""T-2050 — unit tests for lib/review_link_validator.py.

The validator extracts internal Watchtower URLs from a task's ## Recommendation
and ### Human AC Steps and WARNs on any path that doesn't resolve against the
app's route table. These tests pin the core contract WITHOUT a running server or
Flask: known_routes and the HTTP-probe function are injected.

Contract (the canonical bug is /appearance 404 vs the real /settings/appearance):
  - good parameterless path (in known_routes)        → ok
  - bad path (not in known_routes, probe 404)         → warn
  - parameterised path (not in routes, probe 200)     → ok
  - server unreachable (probe None)                   → advisory
  - external URL (different host)                      → ignored (out of scope)
  - main() always returns 0 (advisory — never blocks)
"""

import importlib.util
import os

BASE = "http://192.168.10.107:3000"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _load():
    path = os.path.join(ROOT, "lib", "review_link_validator.py")
    spec = importlib.util.spec_from_file_location("review_link_validator", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


V = _load()


# --- URL extraction ---------------------------------------------------------

def test_extract_internal_paths_skips_external():
    body = """
## Recommendation
- See http://192.168.10.107:3000/review/T-2050
- External: https://example.com/should-be-ignored
"""
    paths = V.extract_internal_paths(body, BASE)
    assert "/review/T-2050" in paths
    assert "/should-be-ignored" not in paths
    assert all("example.com" not in p for p in paths)


def test_extract_from_recommendation_and_human_steps():
    body = """
## Recommendation
- Evidence: http://192.168.10.107:3000/settings/appearance

## Acceptance Criteria
### Agent
- [ ] something
### Human
- [ ] [REVIEW] open the page
  **Steps:**
  1. Open http://192.168.10.107:3000/approvals
"""
    paths = V.extract_internal_paths(body, BASE)
    assert "/settings/appearance" in paths
    assert "/approvals" in paths


def test_extract_handles_markdown_and_backtick_wrapping():
    body = """
## Recommendation
- [link](http://192.168.10.107:3000/tasks) and `http://192.168.10.107:3000/fabric`.
"""
    paths = V.extract_internal_paths(body, BASE)
    assert "/tasks" in paths
    assert "/fabric" in paths


# --- path classification (injected routes + probe) --------------------------

def test_good_parameterless_path_is_ok():
    known = {"/settings/appearance", "/approvals", "/tasks"}
    level, _ = V.classify_path("/settings/appearance", BASE, known, _probe_never_called)
    assert level == "ok"


def test_bad_path_warns():
    # The canonical bug: /appearance is not a route; probe returns 404.
    known = {"/settings/appearance"}
    level, msg = V.classify_path("/appearance", BASE, known, lambda url: 404)
    assert level == "warn"
    assert "404" in msg


def test_parameterised_path_probe_ok():
    # /review/T-2050 is not in the parameterless set; probe says 200.
    known = {"/approvals"}
    level, _ = V.classify_path("/review/T-2050", BASE, known, lambda url: 200)
    assert level == "ok"


def test_unreachable_server_is_advisory():
    known = {"/approvals"}
    level, msg = V.classify_path("/review/T-2050", BASE, known, lambda url: None)
    assert level == "advisory"
    assert "verify manually" in msg


def test_known_routes_none_falls_back_to_probe():
    # Flask/app unavailable → known_routes is None → everything probed.
    level, _ = V.classify_path("/settings/appearance", BASE, None, lambda url: 200)
    assert level == "ok"


# --- end-to-end validate() with a temp task file ----------------------------

def test_validate_end_to_end(tmp_path):
    task = tmp_path / "T-9999-x.md"
    task.write_text(
        """## Recommendation
- good: http://192.168.10.107:3000/settings/appearance
- bad:  http://192.168.10.107:3000/appearance
- external: https://example.com/ignored
""",
        encoding="utf-8",
    )
    known = {"/settings/appearance"}

    def probe(url):
        return 404 if url.endswith("/appearance") else 200

    results = V.validate(str(task), BASE, known_routes=known, probe_fn=probe)
    levels = {msg.split(" ")[0]: lvl for lvl, msg in results}
    assert levels.get("/settings/appearance") == "ok"
    assert levels.get("/appearance") == "warn"
    # external URL never appears
    assert all("example.com" not in msg for _, msg in results)


def test_main_always_returns_zero(tmp_path, capsys):
    task = tmp_path / "T-9999-x.md"
    task.write_text(
        "## Recommendation\n- bad: http://192.168.10.107:3000/appearance\n",
        encoding="utf-8",
    )
    # No injection → main uses real loaders; even if they fail it must return 0.
    rc = V.main([str(task), BASE])
    assert rc == 0


def _probe_never_called(url):  # guard: ok-by-route should not probe
    raise AssertionError(f"probe should not be called for a known route ({url})")
