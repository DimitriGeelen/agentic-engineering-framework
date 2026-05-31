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


# ─────────────────────────────────────────────────────────────────────────────
# T-2139 V1 keystone — homework-pattern detection + --enforce mode + class-aware
# block messages. Pinned by T-2138 GO decision (Candidate E + B + Q3-both).
# ─────────────────────────────────────────────────────────────────────────────


def _body_with_homework(workflow="build"):
    return f"""---
id: T-9999
workflow_type: {workflow}
---
## Acceptance Criteria
### Human
- [ ] [REVIEW] open the pages
  **Steps:**
  1. Open these (URL from `bin/fw watchtower url`):
     - `/`
     - `/bvp`
"""


def _body_clean(workflow="build"):
    return f"""---
id: T-9999
workflow_type: {workflow}
---
## Acceptance Criteria
### Human
- [ ] [REVIEW] open the pages
  **Steps:**
  1. Open http://192.168.10.107:3000/ in browser
  2. Open http://192.168.10.107:3000/bvp in browser
"""


def test_detect_homework_url_from_pattern():
    body = _body_with_homework()
    findings = V.detect_homework_patterns(body)
    assert any("URL from bin/fw watchtower url" in msg for _, msg in findings), findings


def test_detect_homework_base_from_pattern():
    body = """## Acceptance Criteria
### Human
- [ ] open page
  **Steps:**
  1. Open (base from `bin/fw watchtower url`)/foo
"""
    findings = V.detect_homework_patterns(body)
    assert any("base from bin/fw watchtower url" in msg for _, msg in findings), findings


def test_detect_homework_watchtower_url_from_pattern():
    body = """## Acceptance Criteria
### Human
- [ ] open page
  **Steps:**
  1. Open each (Watchtower URL from cli output): /foo
"""
    findings = V.detect_homework_patterns(body)
    assert any("(Watchtower URL from" in msg for _, msg in findings), findings


def test_detect_bare_path_bullets_in_steps():
    body = _body_with_homework()
    findings = V.detect_homework_patterns(body)
    # `/bvp` should be flagged; the literal `URL from ...` pattern is also flagged.
    bare = [m for _, m in findings if "bare-path bullet" in m]
    assert any("/bvp" in m for m in bare), findings


def test_bare_path_bullet_with_http_prefix_passes():
    body = """## Acceptance Criteria
### Human
- [ ] open page
  **Steps:**
  1. Open these:
     - http://192.168.10.107:3000/foo
"""
    findings = V.detect_homework_patterns(body)
    assert not any("bare-path bullet" in m for _, m in findings), findings


def test_clean_task_has_no_homework():
    findings = V.detect_homework_patterns(_body_clean())
    assert findings == []


def test_detect_workflow_type_inception():
    assert V.detect_workflow_type(_body_with_homework("inception")) == "inception"


def test_detect_workflow_type_default_build():
    assert V.detect_workflow_type("(no frontmatter)") == "build"


def test_class_aware_hint_inception():
    hint = V.class_aware_handoff_hint("inception", "T-2138")
    assert "inception" in hint.lower()
    assert "/inception/T-2138" in hint
    assert "/review/T-2138" in hint  # contrasts with the other class


def test_class_aware_hint_build():
    hint = V.class_aware_handoff_hint("build", "T-2109")
    assert "/review/T-2109" in hint


def test_main_advisory_mode_returns_zero_even_with_homework(tmp_path):
    task = tmp_path / "T-9999-x.md"
    task.write_text(_body_with_homework(), encoding="utf-8")
    rc = V.main([str(task), BASE])  # no --enforce
    assert rc == 0


def test_main_enforce_mode_blocks_on_homework(tmp_path):
    task = tmp_path / "T-9999-x.md"
    task.write_text(_body_with_homework(), encoding="utf-8")
    rc = V.main([str(task), BASE, "--enforce"])
    assert rc == 2, f"expected block (exit 2), got {rc}"


def test_main_enforce_mode_passes_clean_task(tmp_path):
    task = tmp_path / "T-9999-x.md"
    task.write_text(_body_clean(), encoding="utf-8")
    rc = V.main([str(task), BASE, "--enforce"])
    assert rc == 0


def test_main_enforce_bypassed_by_env_var(tmp_path, monkeypatch):
    task = tmp_path / "T-9999-x.md"
    task.write_text(_body_with_homework(), encoding="utf-8")
    monkeypatch.setenv("FW_ALLOW_REVIEW_LINK_HOMEWORK", "1")
    rc = V.main([str(task), BASE, "--enforce"])
    assert rc == 0


def test_main_inception_block_message_names_inception_class(tmp_path, capsys):
    task = tmp_path / "T-9999-x.md"
    task.write_text(_body_with_homework("inception"), encoding="utf-8")
    rc = V.main([str(task), BASE, "--enforce"])
    captured = capsys.readouterr()
    assert rc == 2
    assert "inception" in captured.err.lower()
    assert "/inception/T-9999" in captured.err


def test_main_build_block_message_names_review_class(tmp_path, capsys):
    task = tmp_path / "T-9999-x.md"
    task.write_text(_body_with_homework("build"), encoding="utf-8")
    rc = V.main([str(task), BASE, "--enforce"])
    captured = capsys.readouterr()
    assert rc == 2
    assert "/review/T-9999" in captured.err


# ─────────────────────────────────────────────────────────────────────────────
# T-2139 self-trap fix — fenced code blocks are documentation, not instructions
# ─────────────────────────────────────────────────────────────────────────────


def test_homework_in_fenced_code_block_is_not_flagged():
    """An AC may quote the anti-pattern inside ```...``` to document it —
    that's the example block-message, not real homework. Detector must skip."""
    body = """## Acceptance Criteria
### Human
- [ ] [REVIEW] confirm block message reads coaching
  **Steps:** read the captured example below and tick each clause.

  ```
  ✗ Review-link check — BLOCK — review-handoff homework:
      homework pattern in Steps: `URL from bin/fw watchtower url`
      bare-path bullet in Steps (no http:// prefix): - `/bvp`
  ```

  Confirm the rendering names the class.
"""
    findings = V.detect_homework_patterns(body)
    assert findings == [], f"fenced code block should be ignored, got {findings}"


def test_homework_outside_fenced_code_block_still_flagged():
    """Sanity: the fenced-code carve-out doesn't break detection of real homework
    OUTSIDE the fence."""
    body = """## Acceptance Criteria
### Human
- [ ] [REVIEW] open the page
  **Steps:**
  1. Use the URL from `bin/fw watchtower url`/foo

  ```
  example documentation: URL from bin/fw watchtower url is the anti-pattern
  ```

  2. Done.
"""
    findings = V.detect_homework_patterns(body)
    # The Step on line 1 (outside fence) is still flagged; the fence-quoted one is not.
    assert any("URL from bin/fw watchtower url" in msg for _, msg in findings), findings
    # Only one finding for this pattern (not two — fence stripped).
    url_from_count = sum(
        1 for _, msg in findings if "URL from bin/fw watchtower url" in msg
    )
    assert url_from_count == 1, f"expected 1 finding, got {url_from_count}: {findings}"
