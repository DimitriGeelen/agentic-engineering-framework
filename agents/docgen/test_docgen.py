"""Tests for the component reference doc generator (T-387)."""

import os
import tempfile

import yaml

from agents.docgen.generate_component import generate_doc


def _make_card(tmp, name="test-component", **overrides):
    """Create a minimal fabric card YAML and return its path."""
    card = {
        "id": name,
        "name": name.replace("-", " ").title(),
        "type": "script",
        "subsystem": "test",
        "location": "bin/test.sh",
        "purpose": "A test component for unit testing",
        "tags": ["test", "ci"],
        "depends_on": [],
        "depended_by": [],
    }
    card.update(overrides)
    path = os.path.join(tmp, f"{name}.yaml")
    with open(path, "w") as f:
        yaml.safe_dump(card, f)
    return path


def test_generate_doc_creates_markdown():
    """generate_doc produces a .md file with expected sections."""
    with tempfile.TemporaryDirectory() as tmp:
        card_path = _make_card(tmp)
        out_dir = os.path.join(tmp, "output")
        os.makedirs(out_dir)
        result = generate_doc(card_path, tmp, out_dir)
        assert result == "test-component"
        md_path = os.path.join(out_dir, "test-component.md")
        assert os.path.isfile(md_path)
        content = open(md_path).read()
        assert "# Test Component" in content
        assert "A test component for unit testing" in content
        assert "`test`" in content  # tags rendered


def test_generate_doc_with_dependencies():
    """Dependencies render as markdown tables."""
    with tempfile.TemporaryDirectory() as tmp:
        card_path = _make_card(
            tmp,
            depends_on=[{"target": "other-component", "type": "uses"}],
            depended_by=[{"target": "consumer", "type": "used_by"}],
        )
        out_dir = os.path.join(tmp, "output")
        os.makedirs(out_dir)
        generate_doc(card_path, tmp, out_dir)
        content = open(os.path.join(out_dir, "test-component.md")).read()
        assert "## Dependencies" in content
        assert "other-component" in content
        assert "## Used By" in content
        assert "consumer" in content


def test_generate_doc_empty_card_returns_none():
    """An empty YAML file returns None."""
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "empty.yaml")
        with open(path, "w") as f:
            f.write("")
        out_dir = os.path.join(tmp, "output")
        os.makedirs(out_dir)
        assert generate_doc(path, tmp, out_dir) is None


def test_generate_doc_with_docs_field():
    """docs field renders Documentation section."""
    with tempfile.TemporaryDirectory() as tmp:
        card_path = _make_card(
            tmp,
            docs=[{"title": "Guide", "path": "/docs/guide.md", "type": "guide"}],
        )
        out_dir = os.path.join(tmp, "output")
        os.makedirs(out_dir)
        generate_doc(card_path, tmp, out_dir)
        content = open(os.path.join(out_dir, "test-component.md")).read()
        assert "## Documentation" in content
        assert "Guide" in content


def test_generate_doc_against_real_fabric():
    """generate_doc works with a real fabric card (integration test)."""
    import glob as _glob

    fw_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    cards = sorted(_glob.glob(os.path.join(fw_root, ".fabric", "components", "*.yaml")))
    assert len(cards) > 0, "No fabric cards found — is .fabric/components/ populated?"

    with tempfile.TemporaryDirectory() as out_dir:
        # Generate doc for the first card
        result = generate_doc(cards[0], fw_root, out_dir)
        assert result is not None
        md_path = os.path.join(out_dir, f"{result}.md")
        assert os.path.isfile(md_path)
        content = open(md_path).read()
        assert content.startswith("#")
        assert len(content) > 100
