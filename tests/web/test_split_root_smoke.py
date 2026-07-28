"""T-2650 (OBS-097, 832's split-root CI-smoke proposal): boot the Watchtower
app with PROJECT_ROOT != FRAMEWORK_ROOT and hit every parameterless GET route.

The class this guards: framework-owned assets resolved via PROJECT_ROOT are
invisible bugs in the framework repo (roots coincide) but break split-root
consumers — G-004 shipped a dead /review queue to a consumer because the
failing path structurally cannot fire where the code is developed (siblings:
OBS-096, T-1633). T-2645/T-2648/T-2649 fixed instances and added grep-lints;
this test is the behavioral guard that catches shapes the lints can't (e.g.
the core.py relative_to class fires only at request time).

Isolation: the app is imported and exercised in a SUBPROCESS with the
PROJECT_ROOT env var pointing at a synthetic consumer skeleton. In-process
reload of web.shared under a foreign root is the OBS-094 tarpit (module-level
constants leak into every later test) — subprocess sidesteps it entirely.

Known limit (deliberate, layered with the T-2648 grep-lint): sys.path is
process-global, so ONE blueprint inserting the correct FRAMEWORK_ROOT/lib
masks a sibling that regressed to PROJECT_ROOT/lib — this smoke only reds
when the whole class regresses (verified: all three G-004 sites broken →
/review/T-9999 fails with ModuleNotFoundError: dispatch_pause; any one fixed
→ green). Single-site regressions are the grep-lint's job; request-time
shapes the lint can't see (relative_to crashes, subprocess paths, template
resolution) are this smoke's job.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]

# Runs inside the subprocess. Prints one JSON line: {"failures": [...], "routes": N}.
_SMOKE_SCRIPT = r"""
import json, sys, warnings
warnings.filterwarnings("ignore")

from web.app import create_app

app = create_app()
app.config["TESTING"] = True
client = app.test_client()

failures = []
routes = 0
for rule in sorted(app.url_map.iter_rules(), key=lambda r: str(r)):
    if rule.arguments:            # parameterized routes need sample data — out of scope
        continue
    if "GET" not in (rule.methods or set()):
        continue
    if rule.endpoint == "static":
        continue
    routes += 1
    try:
        resp = client.get(rule.rule)
        if resp.status_code >= 500:
            failures.append({"route": rule.rule, "status": resp.status_code})
    except Exception as exc:      # noqa: BLE001 — any unhandled exception is a finding
        failures.append({"route": rule.rule, "error": f"{type(exc).__name__}: {exc}"})

# Curated parameterized probes: the parameterless sweep misses lazy imports
# inside route handlers — the ORIGINAL G-004 hid exactly there
# (dispatch_pause imported inside /review/<task_id>'s handler, so the crash
# never fires on any parameterless route). T-9999 is seeded by the harness
# so these render real content, not an early 404.
for probe in ("/review/T-9999", "/tasks/T-9999", "/inception/T-9999"):
    routes += 1
    try:
        resp = client.get(probe)
        if resp.status_code >= 500:
            failures.append({"route": probe, "status": resp.status_code})
    except Exception as exc:  # noqa: BLE001
        failures.append({"route": probe, "error": f"{type(exc).__name__}: {exc}"})

print(json.dumps({"failures": failures, "routes": routes}))
"""


def _make_consumer_skeleton(root: Path) -> None:
    """Minimal consumer project: governance dirs + .framework.yaml, no framework
    source at the root — the split-root shape fw init/vendor produces."""
    for d in (
        ".tasks/active", ".tasks/completed", ".tasks/templates",
        ".context/working", ".context/handovers", ".context/episodic",
        ".context/audits", ".context/arcs", "docs/reports",
    ):
        (root / d).mkdir(parents=True)
    (root / ".framework.yaml").write_text(
        "project_name: split-root-smoke\nversion: 1.0.0\nprovider: claude\n"
    )
    # Sample task so the parameterized probes render full pages (an early 404
    # would skip the lazy-import code paths the probes exist to exercise).
    (root / ".tasks/active/T-9999-smoke.md").write_text(
        "---\n"
        "id: T-9999\n"
        'name: "split-root smoke task"\n'
        "description: smoke\n"
        "status: started-work\n"
        "workflow_type: build\n"
        "horizon: now\n"
        "owner: human\n"
        "created: 2026-07-28T00:00:00Z\n"
        "last_update: 2026-07-28T00:00:00Z\n"
        "---\n\n"
        "# T-9999: split-root smoke task\n\n"
        "## Acceptance Criteria\n\n"
        "### Agent\n- [x] exists\n\n"
        "### Human\n- [ ] [REVIEW] renders\n\n"
        "## Recommendation\n\n"
        "**Recommendation:** GO\n**Rationale:** smoke fixture\n"
    )


def _run_smoke(project_root: Path) -> dict:
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(project_root)
    # No FRAMEWORK_ROOT in env: web.shared derives it from its own file
    # location (APP_DIR.parent), which is exactly the split-root contract.
    env.pop("FRAMEWORK_ROOT", None)
    env["PYTHONPATH"] = str(FRAMEWORK_ROOT)
    proc = subprocess.run(
        [sys.executable, "-c", _SMOKE_SCRIPT],
        capture_output=True, text=True, timeout=300,
        cwd=str(FRAMEWORK_ROOT), env=env,
    )
    assert proc.returncode == 0, (
        "split-root app boot crashed (import-time failure — the G-004 shape):\n"
        f"stderr:\n{proc.stderr[-3000:]}"
    )
    return json.loads(proc.stdout.strip().splitlines()[-1])


def test_split_root_parameterless_routes_do_not_500(tmp_path):
    consumer = tmp_path / "consumer"
    consumer.mkdir()
    _make_consumer_skeleton(consumer)

    result = _run_smoke(consumer)

    assert result["routes"] > 30, (
        f"smoke swept only {result['routes']} routes — url_map iteration broke?"
    )
    assert not result["failures"], (
        "routes failing under split roots (PROJECT_ROOT != FRAMEWORK_ROOT) — "
        "OBS-097 class, see T-2645/T-2648/T-2649 for fix patterns:\n"
        + json.dumps(result["failures"], indent=2)
    )
