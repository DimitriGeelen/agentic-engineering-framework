"""T-4043 (GitHub #90): /file/ and /docs/generated/ show the title once, and the
component-docs / Fabric links appear only where they apply."""

import re

import pytest

import web.blueprints.docs as docs
import web.blueprints.fabric as fabric
import web.shared as shared


@pytest.fixture()
def client(monkeypatch, tmp_path):
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "titled.md").write_text("# My Title\n\nbody text\n")
    (tmp_path / "docs" / "carded.md").write_text("# Carded\n\nbody\n")
    (tmp_path / "docs" / "plain.md").write_text("just text, no heading\n")
    gen = tmp_path / "gen"
    gen.mkdir()
    (gen / "comp-x.md").write_text("# Comp X\n\nbody\n")
    comps = tmp_path / "components"
    comps.mkdir()
    (comps / "carded-card.yaml").write_text(
        "id: carded-card\nname: carded-card\nlocation: docs/carded.md\n")
    monkeypatch.setattr(docs, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(docs, "GENERATED_DIR", gen)
    monkeypatch.setattr(fabric, "COMP_DIR", str(comps))
    monkeypatch.setattr(fabric, "_comp_cache", {"mtime": 0, "data": []})
    monkeypatch.setattr(shared, "is_viewable_path", lambda p: True)
    monkeypatch.setattr(docs, "is_viewable_path", lambda p: True)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


def _h1s(html):
    return re.findall(r"<h1[^>]*>.*?</h1>", html, re.S)


def test_file_markdown_has_single_h1(client):
    r = client.get("/file/docs/titled.md")
    assert r.status_code == 200
    h1s = [h for h in _h1s(r.get_data(as_text=True)) if "My Title" in h]
    assert len(h1s) == 1
    assert "body text" in r.get_data(as_text=True)


def test_generated_doc_has_single_h1_and_back_link(client):
    html = client.get("/docs/generated/comp-x").get_data(as_text=True)
    assert len([h for h in _h1s(html) if "Comp X" in h]) == 1
    assert "Back to Component Docs" in html
    assert "/fabric/component/comp-x" in html


def test_file_without_card_has_no_fabric_or_component_links(client):
    html = client.get("/file/docs/titled.md").get_data(as_text=True)
    assert "/fabric/component/" not in html
    assert "Back to Component Docs" not in html


def test_file_with_card_links_to_it(client):
    html = client.get("/file/docs/carded.md").get_data(as_text=True)
    assert "/fabric/component/carded-card" in html
    assert "Back to Component Docs" not in html


def test_headingless_file_keeps_filename_title_and_body(client):
    html = client.get("/file/docs/plain.md").get_data(as_text=True)
    assert any("plain.md" in h for h in _h1s(html))
    assert "just text, no heading" in html
