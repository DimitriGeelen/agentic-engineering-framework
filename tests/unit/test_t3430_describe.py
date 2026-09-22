r"""T-3430 — the fabric card deriver: what a file says about itself, or a refusal.

Every fixture is built in tmp_path. Per L-599 these tests never assert against
the live `.fabric/` corpus or live counts — those move under the test for
reasons that have nothing to do with the derivation rules under test.

The property that matters most is the negative one: a file that describes
itself nowhere must produce None, not a plausible sentence. A near-miss written
into `purpose` is indistinguishable from a real description once it is on the
card, so the refusal path gets as much coverage as the success paths.
"""

import importlib.util
import os
import sys
import textwrap

import pytest
import yaml

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_DESCRIBE_PATH = os.path.join(_REPO_ROOT, "agents", "fabric", "lib", "describe.py")


def _load():
    spec = importlib.util.spec_from_file_location("fabric_describe_under_test", _DESCRIBE_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


describe = _load()


def _write(root, rel, content):
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content).lstrip("\n"))
    return path


# ---------------------------------------------------------------------------
# Tier 1 — the file's own header
# ---------------------------------------------------------------------------

def test_python_module_docstring(tmp_path):
    _write(tmp_path, "lib/thing.py", '''
        #!/usr/bin/env python3
        """Resolve a dispatch envelope into a runnable worker prompt.

        Longer explanation in a second paragraph that must not be included.
        """
        import os
    ''')
    text, source = describe.derive_purpose("lib/thing.py", project_root=str(tmp_path))
    assert source == "docstring"
    assert text == "Resolve a dispatch envelope into a runnable worker prompt."


def test_python_falls_back_to_hash_header_when_no_docstring(tmp_path):
    _write(tmp_path, "tools/probe.py", '''
        #!/usr/bin/env python3
        # Probe the cron registry for entries that were never generated.
        import sys
    ''')
    text, source = describe.derive_purpose("tools/probe.py", project_root=str(tmp_path))
    assert source == "header-comment"
    assert text.startswith("Probe the cron registry")


def test_bash_header_block(tmp_path):
    _write(tmp_path, "agents/audit/audit.sh", '''
        #!/bin/bash
        # Audit Agent - compliance checking across structure, tasks and controls
        # Implements: fw audit

        set -euo pipefail
    ''')
    text, source = describe.derive_purpose("agents/audit/audit.sh", project_root=str(tmp_path))
    assert source == "header-comment"
    assert "compliance checking" in text
    # The block ends at the blank line — code below it never leaks into purpose.
    assert "set -euo" not in text


def test_markdown_first_paragraph(tmp_path):
    _write(tmp_path, "docs/reports/note.md", '''
        ---
        title: something
        ---

        # T-1234: A Heading

        The first real paragraph explains what this document argues.

        A second paragraph that must not appear.
    ''')
    text, source = describe.derive_purpose("docs/reports/note.md", project_root=str(tmp_path))
    assert source == "markdown"
    assert text == "The first real paragraph explains what this document argues."


def test_markdown_falls_back_to_heading_when_there_is_no_paragraph(tmp_path):
    _write(tmp_path, "docs/reports/stub.md", "# Cron registry drift runbook\n")
    text, source = describe.derive_purpose("docs/reports/stub.md", project_root=str(tmp_path))
    assert source == "markdown"
    assert text == "Cron registry drift runbook"


def test_yaml_hash_header(tmp_path):
    _write(tmp_path, ".context/project/learnings.yaml", '''
        # Project Learnings - knowledge gained during development
        # Added via: fw context add-learning

        learnings: []
    ''')
    text, source = describe.derive_purpose(".context/project/learnings.yaml",
                                           project_root=str(tmp_path))
    assert source == "header-comment"
    assert "knowledge gained during development" in text


def test_shebang_and_directive_lines_are_not_the_description(tmp_path):
    _write(tmp_path, "lib/noisy.sh", '''
        #!/bin/bash
        # shellcheck disable=SC2086
        # SPDX-License-Identifier: MIT
        # ──────────────────────────────
        # Rotate the fleet certificates across every registered node.
    ''')
    text, _ = describe.derive_purpose("lib/noisy.sh", project_root=str(tmp_path))
    assert text == "Rotate the fleet certificates across every registered node."


# ---------------------------------------------------------------------------
# Tier 2 — the originating task
# ---------------------------------------------------------------------------

def test_task_title_fallback(tmp_path):
    _write(tmp_path, "web/static/css/style.css", "body { margin: 0; }\n")
    _write(tmp_path, ".tasks/active/T-4242-restyle.md", '''
        ---
        id: T-4242
        name: "Restyle the Watchtower task list so long titles wrap instead of clipping"
        status: started-work
        ---

        # body
    ''')
    text, source = describe.derive_purpose(
        "web/static/css/style.css", created_by="T-4242", project_root=str(tmp_path))
    assert source == "task-title"
    assert text.startswith("Restyle the Watchtower task list")


def test_task_report_fallback_when_no_task_file(tmp_path):
    _write(tmp_path, "web/static/css/style.css", "body { margin: 0; }\n")
    _write(tmp_path, "docs/reports/T-4243-restyle-rca.md",
           "# Why the task list clipped long titles\n")
    text, source = describe.derive_purpose(
        "web/static/css/style.css", created_by="T-4243", project_root=str(tmp_path))
    assert source == "task-report"
    assert text == "Why the task list clipped long titles"


def test_header_wins_over_task_title(tmp_path):
    _write(tmp_path, "lib/thing.sh", "#!/bin/bash\n# Rotate the audit lock every hour.\n")
    _write(tmp_path, ".tasks/active/T-4242-restyle.md",
           '---\nid: T-4242\nname: "Some unrelated task title"\n---\n')
    text, source = describe.derive_purpose(
        "lib/thing.sh", created_by="T-4242", project_root=str(tmp_path))
    assert source == "header-comment"
    assert "Rotate the audit lock" in text


# ---------------------------------------------------------------------------
# Tier 3 — the refusal
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("rel,content", [
    ("web/static/css/style.css", "body { margin: 0; }\n"),
    ("web/templates/page.html", "<div>hello</div>\n"),
    ("lib/bare.sh", "#!/bin/bash\nset -euo pipefail\necho hi\n"),
    ("lib/empty.py", ""),
    ("lib/todo.py", '"""TODO: write this."""\n'),
    ("lib/tiny.sh", "# x\n"),
])
def test_refuses_when_the_file_describes_itself_nowhere(tmp_path, rel, content):
    _write(tmp_path, rel, content)
    assert describe.derive_purpose(rel, project_root=str(tmp_path)) is None


def test_refusal_is_not_rescued_by_a_missing_task(tmp_path):
    _write(tmp_path, "lib/bare.sh", "#!/bin/bash\necho hi\n")
    assert describe.derive_purpose(
        "lib/bare.sh", created_by="T-9999", project_root=str(tmp_path)) is None


def test_long_header_is_trimmed_not_dumped(tmp_path):
    body = " ".join(["word"] * 300)
    _write(tmp_path, "lib/long.py", f'"""{body}"""\n')
    text, _ = describe.derive_purpose("lib/long.py", project_root=str(tmp_path))
    assert len(text) <= describe.MAX_PURPOSE


# ---------------------------------------------------------------------------
# Subsystem routing
# ---------------------------------------------------------------------------

def _subsystems(tmp_path, mapping):
    data = {"subsystems": [{"id": k, "name": k, "paths": v} for k, v in mapping.items()]}
    path = tmp_path / ".fabric" / "subsystems.yaml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(yaml.safe_dump(data))


def test_subsystem_longest_pattern_wins_regardless_of_declaration_order(tmp_path):
    _subsystems(tmp_path, {"tests": ["tests/*"], "tests-playwright": ["tests/playwright/*"]})
    root = str(tmp_path)
    assert describe.derive_subsystem("tests/unit/a.bats", root) == "tests"
    assert describe.derive_subsystem("tests/playwright/a.py", root) == "tests-playwright"


def test_subsystem_matches_dotted_directories(tmp_path):
    # Regression: str.lstrip("./") strips CHARACTERS, so ".fabric/x" became
    # "fabric/x" and no ".fabric/*" rule could ever match.
    _subsystems(tmp_path, {"component-fabric": [".fabric/*"]})
    assert describe.derive_subsystem(".fabric/watch-patterns.yaml", str(tmp_path)) \
        == "component-fabric"


def test_subsystem_returns_none_when_no_rule_matches(tmp_path):
    _subsystems(tmp_path, {"tests": ["tests/*"]})
    assert describe.derive_subsystem("vendor/designer/x.py", str(tmp_path)) is None


def test_subsystem_accepts_absolute_paths(tmp_path):
    _subsystems(tmp_path, {"tests": ["tests/*"]})
    abs_path = str(tmp_path / "tests" / "unit" / "a.bats")
    assert describe.derive_subsystem(abs_path, str(tmp_path)) == "tests"


# ---------------------------------------------------------------------------
# Card-level behaviour: fill placeholders only
# ---------------------------------------------------------------------------

def test_placeholder_detection():
    assert describe.is_placeholder_purpose(describe.PLACEHOLDER_PURPOSE)
    assert describe.is_placeholder_purpose("")
    assert describe.is_placeholder_purpose(None)
    assert not describe.is_placeholder_purpose("Resolves dispatch envelopes.")
    assert describe.is_placeholder_subsystem("unknown")
    assert not describe.is_placeholder_subsystem("watchtower")


def test_describe_card_fills_placeholders(tmp_path):
    _subsystems(tmp_path, {"tests": ["tests/*"]})
    _write(tmp_path, "tests/unit/a.bats", "#!/usr/bin/env bats\n# Pin the cron registry drift check.\n")
    card = {"location": "tests/unit/a.bats",
            "purpose": describe.PLACEHOLDER_PURPOSE, "subsystem": "unknown"}
    updates, refusal = describe.describe_card(card, str(tmp_path))
    assert refusal is None
    assert updates["purpose_source"] == "header-comment"
    assert updates["subsystem"] == "tests"
    assert "cron registry drift" in updates["purpose"]


def test_describe_card_never_overwrites_a_human_sentence(tmp_path):
    _subsystems(tmp_path, {"tests": ["tests/*"]})
    _write(tmp_path, "tests/unit/a.bats", "# Pin the cron registry drift check.\n")
    card = {"location": "tests/unit/a.bats",
            "purpose": "A sentence a human wrote and meant.", "subsystem": "audit"}
    updates, refusal = describe.describe_card(card, str(tmp_path))
    assert updates == {}
    assert refusal is None


def test_describe_card_reports_the_refusal(tmp_path):
    _subsystems(tmp_path, {"watchtower": ["web/*"]})
    _write(tmp_path, "web/static/css/style.css", "body{}\n")
    card = {"location": "web/static/css/style.css",
            "purpose": describe.PLACEHOLDER_PURPOSE, "subsystem": "unknown"}
    updates, refusal = describe.describe_card(card, str(tmp_path))
    assert "describes itself nowhere" in refusal
    assert "purpose" not in updates
    # The subsystem is still routed — a refusal on one field does not block the other.
    assert updates["subsystem"] == "watchtower"


def test_describe_card_skips_url_locations(tmp_path):
    card = {"location": "https://example.com/service",
            "purpose": describe.PLACEHOLDER_PURPOSE, "subsystem": "unknown"}
    updates, refusal = describe.describe_card(card, str(tmp_path))
    assert updates == {} and refusal is None


def test_edge_count():
    assert describe.card_edge_count({"depends_on": [{"a": 1}], "depended_by": []}) == 1
    assert describe.card_edge_count({"depends_on": None, "depended_by": None}) == 0


# ---------------------------------------------------------------------------
# The bash bridge
# ---------------------------------------------------------------------------

def test_emit_shell_roundtrip(tmp_path, capsys):
    import base64
    _subsystems(tmp_path, {"framework-core": ["lib/*"]})
    _write(tmp_path, "lib/thing.sh", "#!/bin/bash\n# Rotate the fleet certificates.\n")
    os.environ["PROJECT_ROOT"] = str(tmp_path)
    try:
        rc = describe.main(["--emit-shell", "lib/thing.sh"])
    finally:
        del os.environ["PROJECT_ROOT"]
    assert rc == 0
    out = dict(line.split("=", 1) for line in capsys.readouterr().out.splitlines())
    assert base64.b64decode(out["FW_PURPOSE_B64"]).decode() == "Rotate the fleet certificates."
    assert out["FW_PURPOSE_SOURCE"] == "header-comment"
    assert out["FW_SUBSYSTEM"] == "framework-core"


def test_emit_shell_emits_empty_fields_on_refusal(tmp_path, capsys):
    _subsystems(tmp_path, {"framework-core": ["lib/*"]})
    _write(tmp_path, "lib/bare.sh", "#!/bin/bash\necho hi\n")
    os.environ["PROJECT_ROOT"] = str(tmp_path)
    try:
        describe.main(["--emit-shell", "lib/bare.sh"])
    finally:
        del os.environ["PROJECT_ROOT"]
    out = dict(line.split("=", 1) for line in capsys.readouterr().out.splitlines())
    assert out["FW_PURPOSE_B64"] == ""
    assert out["FW_SUBSYSTEM"] == "framework-core"
