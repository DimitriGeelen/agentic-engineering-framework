"""T-4402: GET /api/lens-definition serves the one lens file (tools/corpus_lenses.yaml)
in the shape designer 0.25.0 reads (T-1241).

Before T-4402 the route did not exist: the designer's loadLensDefinition() got a
404, set _lensDef = null, and the lens select offered only "All".

The vocabulary checks read the VENDORED designer rather than a copied list, so a
lens naming a field, section or decoration the designer does not know fails here.
"""

import re

import pytest
import yaml

import web.blueprints.designer_api as designer_api
from web.shared import FRAMEWORK_ROOT

# T-4732: the pinned build, read from the pin so a re-pin does not orphan this test.
DESIGNER = FRAMEWORK_ROOT / yaml.safe_load(
    (FRAMEWORK_ROOT / "policy" / "designer-pin.yaml").read_text())["vendored_path"]


@pytest.fixture()
def client():
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


@pytest.fixture(scope="module")
def designer_src():
    return DESIGNER.read_text()


def _vocab(src):
    block = re.search(r"const AEF_FIELDS = \{(.*?)\n\};", src, re.S).group(1)
    fields = set(re.findall(r"'([A-Za-z]+)'", re.sub(r"//[^\n]*", "", block)))
    fields |= set(re.findall(r"lensField\('([^']+)'\)", src))
    return {
        "fields": fields,
        "sections": set(re.findall(r"lensSection\('([^']+)'\)", src)),
        "canvas": set(re.findall(r"lensDeco\('([^']+)'\)", src)),
        # BPMN-section field labels: field('Name', …), selectField('Lane', …), and the
        # hand-built label divs (`xLabel.textContent = 'Display ID'`).
        "bpmn": set(re.findall(r"sBpmn\.appendChild\((?:field|selectField)\('([^']+)'", src))
        | set(re.findall(r"field\('(Slug)'", src))
        | set(re.findall(r"(?:displayLabel|uidLabel)\.textContent = '([^']+)'", src)),
    }


def _resolve(defn, name, seen=None):
    """Port of the designer's _lensResolve (0.25.0, line ~7040)."""
    lens = defn["lenses"].get(name)
    if not lens:
        return None
    seen = seen or set()
    if name in seen:
        return None
    seen.add(name)
    parent = _resolve(defn, lens["extends"], seen) if lens.get("extends") else None
    u = lambda k: list(dict.fromkeys(((parent or {}).get(k) or []) + (lens.get(k) or [])))
    return {k: u(k) for k in ("fields", "bpmn", "sections", "canvas")}


def _designer_accepts(resp):
    """Port of loadLensDefinition + renderLensSelect: returns the select options."""
    d = resp.get_json(silent=True)
    defn = d["definition"] if (resp.status_code == 200 and d and d.get("ok")
                                and d.get("definition") and d["definition"].get("lenses")) else None
    if not defn:
        return ["all"]
    order = defn["order"] if isinstance(defn.get("order"), list) else list(defn["lenses"])
    return [n for n in order if defn["lenses"].get(n)] + ["all"]


def test_endpoint_serves_definition(client):
    r = client.get("/api/lens-definition")
    assert r.status_code == 200
    d = r.get_json()
    assert d["ok"] is True
    assert d["definition"]["order"] == ["business", "logical", "technical"]


def test_designer_parser_offers_four_lenses(client):
    assert _designer_accepts(client.get("/api/lens-definition")) == [
        "business", "logical", "technical", "all"]


def test_every_lens_resolves_and_widens(client):
    defn = client.get("/api/lens-definition").get_json()["definition"]
    b, l, t = (_resolve(defn, n) for n in ("business", "logical", "technical"))
    for k in ("fields", "bpmn", "sections", "canvas"):
        assert set(b[k]) <= set(l[k]) <= set(t[k])
    assert "owner" in b["fields"] and "fabricRef" not in b["fields"]
    assert "fabricRef" in t["fields"]


def test_every_name_exists_in_designer_vocabulary(client, designer_src):
    vocab = _vocab(designer_src)
    # Guard the extractor itself, so an empty vocabulary cannot pass vacuously.
    assert {"owner", "authority", "fabricRef", "note"} <= vocab["fields"]
    assert {"BPMN", "Extensions", "I/O contract"} <= vocab["sections"]
    assert {"ids", "findings", "authority"} <= vocab["canvas"]
    assert {"Name", "Lane", "Slug", "Display ID", "UID"} <= vocab["bpmn"]
    defn = client.get("/api/lens-definition").get_json()["definition"]
    for name, lens in defn["lenses"].items():
        for k in ("fields", "bpmn", "sections", "canvas"):
            unknown = set(lens.get(k, [])) - vocab[k]
            assert not unknown, f"lens {name}.{k} names {sorted(unknown)} unknown to designer 0.25.0"


def test_invalid_definition_is_refused(client, monkeypatch, tmp_path):
    bad = tmp_path / "lenses.yaml"
    bad.write_text("order: [a]\nlenses:\n  a: {extends: a, fields: []}\n")
    monkeypatch.setattr(designer_api, "_LENS_FILE", bad)
    r = client.get("/api/lens-definition")
    assert r.status_code == 500 and r.get_json()["ok"] is False
    assert _designer_accepts(r) == ["all"]   # designer falls back to All


def test_missing_definition_is_refused(client, monkeypatch, tmp_path):
    monkeypatch.setattr(designer_api, "_LENS_FILE", tmp_path / "absent.yaml")
    r = client.get("/api/lens-definition")
    assert r.get_json()["ok"] is False
