r"""T-3430 — `fw fabric enrich --describe`: fill the placeholders, never overwrite.

Driven end-to-end through the CLI (subprocess + a tmp PROJECT_ROOT) rather than
by calling apply_describe() directly, because the flags are half the contract:
--describe is on by default, --no-describe turns it off, --dry-run must write
nothing, and the refusal count has to reach stdout. Per L-599 nothing here
touches the live .fabric/ corpus.
"""

import os
import subprocess
import sys
import textwrap

import pytest
import yaml

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_ENRICH = os.path.join(_REPO_ROOT, "agents", "fabric", "lib", "enrich.py")
PLACEHOLDER = "TODO: describe what this component does"


@pytest.fixture
def project(tmp_path):
    """A tiny project: two described files, one that describes itself nowhere."""
    (tmp_path / ".fabric" / "components").mkdir(parents=True)
    (tmp_path / "lib").mkdir()
    (tmp_path / "web" / "templates").mkdir(parents=True)

    (tmp_path / ".fabric" / "subsystems.yaml").write_text(yaml.safe_dump({
        "subsystems": [
            {"id": "framework-core", "name": "core", "paths": ["lib/*"]},
            {"id": "watchtower", "name": "wt", "paths": ["web/*"]},
        ]
    }))

    (tmp_path / "lib" / "rotate.sh").write_text(
        "#!/bin/bash\n# Rotate the fleet certificates across every node.\n")
    (tmp_path / "lib" / "keep.sh").write_text(
        "#!/bin/bash\n# A header the deriver would happily use.\n")
    (tmp_path / "web" / "templates" / "page.html").write_text("<div>hi</div>\n")

    def card(slug, loc, purpose=PLACEHOLDER, subsystem="unknown", **extra):
        data = {"id": loc, "name": slug, "location": loc,
                "purpose": purpose, "subsystem": subsystem}
        data.update(extra)
        (tmp_path / ".fabric" / "components" / f"{slug}.yaml").write_text(
            yaml.safe_dump(data, sort_keys=False))

    card("lib-rotate", "lib/rotate.sh")
    card("lib-keep", "lib/keep.sh",
         purpose="A sentence a human wrote and meant.", subsystem="audit")
    card("web-page", "web/templates/page.html")
    return tmp_path


def run_enrich(project, *args):
    env = dict(os.environ, PROJECT_ROOT=str(project))
    return subprocess.run([sys.executable, _ENRICH, *args],
                          capture_output=True, text=True, env=env, cwd=str(project))


def load(project, slug):
    return yaml.safe_load(
        (project / ".fabric" / "components" / f"{slug}.yaml").read_text())


def test_describe_is_on_by_default(project):
    res = run_enrich(project)
    assert res.returncode == 0, res.stderr
    assert "=== Describe pass ===" in res.stdout
    assert load(project, "lib-rotate")["purpose"].startswith("Rotate the fleet")


def test_no_describe_skips_the_pass_entirely(project):
    res = run_enrich(project, "--no-describe")
    assert res.returncode == 0, res.stderr
    assert "=== Describe pass ===" not in res.stdout
    assert load(project, "lib-rotate")["purpose"] == PLACEHOLDER


def test_writes_purpose_source(project):
    run_enrich(project, "--describe-only")
    card = load(project, "lib-rotate")
    assert card["purpose_source"] == "header-comment"
    assert card["subsystem"] == "framework-core"


def test_never_overwrites_a_human_sentence(project):
    run_enrich(project, "--describe-only")
    card = load(project, "lib-keep")
    assert card["purpose"] == "A sentence a human wrote and meant."
    assert card["subsystem"] == "audit"
    assert "purpose_source" not in card


def test_refusal_is_counted_and_listed(project):
    res = run_enrich(project, "--describe-only")
    assert "described 1, refused 1" in res.stdout
    assert "web/templates/page.html: describes itself nowhere" in res.stdout
    # The refused card keeps its placeholder rather than acquiring a guess.
    assert load(project, "web-page")["purpose"] == PLACEHOLDER


def test_a_refused_purpose_does_not_block_the_subsystem(project):
    run_enrich(project, "--describe-only")
    assert load(project, "web-page")["subsystem"] == "watchtower"


def test_dry_run_writes_nothing(project):
    before = (project / ".fabric" / "components" / "lib-rotate.yaml").read_text()
    res = run_enrich(project, "--describe-only", "--dry-run")
    assert "described 1, refused 1" in res.stdout
    assert (project / ".fabric" / "components" / "lib-rotate.yaml").read_text() == before


def test_rerun_is_idempotent(project):
    run_enrich(project, "--describe-only")
    first = (project / ".fabric" / "components" / "lib-rotate.yaml").read_text()
    res = run_enrich(project, "--describe-only")
    assert "described 0, refused 1" in res.stdout
    assert (project / ".fabric" / "components" / "lib-rotate.yaml").read_text() == first


def test_unrouted_subsystems_are_named(project, tmp_path):
    (project / "vendor").mkdir()
    (project / "vendor" / "thing.py").write_text('"""A vendored thing."""\n')
    (project / ".fabric" / "components" / "vendor-thing.yaml").write_text(yaml.safe_dump(
        {"id": "vendor/thing.py", "name": "thing", "location": "vendor/thing.py",
         "purpose": PLACEHOLDER, "subsystem": "unknown"}, sort_keys=False))
    res = run_enrich(project, "--describe-only")
    assert "unrouted subsystem: 1" in res.stdout
    assert "vendor/thing.py" in res.stdout
    assert load(project, "vendor-thing")["subsystem"] == "unknown"


def test_long_python_module_keeps_its_docstring(project):
    """Regression: a 64 KB read cap made ast.parse fail on every long module,
    so each one was reported as describing itself nowhere."""
    filler = "\n".join(f"# padding line {i}" for i in range(4000))
    (project / "lib" / "big.py").write_text(
        '"""A long module that still says what it does."""\n' + filler + "\n")
    (project / ".fabric" / "components" / "lib-big.yaml").write_text(yaml.safe_dump(
        {"id": "lib/big.py", "name": "big", "location": "lib/big.py",
         "purpose": PLACEHOLDER, "subsystem": "unknown"}, sort_keys=False))
    assert (project / "lib" / "big.py").stat().st_size > 64 * 1024
    run_enrich(project, "--describe-only")
    card = load(project, "lib-big")
    assert card["purpose"] == "A long module that still says what it does."
    assert card["purpose_source"] == "docstring"


def test_describe_does_not_disturb_edge_enrichment(project):
    """--describe runs before edges; the edge summary is still emitted."""
    res = run_enrich(project)
    assert "=== Summary ===" in res.stdout
    assert "Forward edges:" in res.stdout
