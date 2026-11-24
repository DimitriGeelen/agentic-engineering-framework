"""T-5189: shared contract 3 — validator codes <-> runtime refusal reason_codes.

Checks docs/research/executable-workflow/contracts/v2/validator-refusal-mapping.{yaml,md}
against the two sources they map: contracts v2 refusal.schema.json (reason_code enum) and
832's vendored validator named by the mapping's sources.validator.path (every code it emits).
The path is read from the mapping, so a designer re-pin is one mapping edit (path, version, sha256).
"""
import ast
import hashlib
import json
import pathlib
import re

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
V2 = ROOT / "docs/research/executable-workflow/contracts/v2"
SCHEMA = V2 / "refusal.schema.json"
MAP_YAML = V2 / "validator-refusal-mapping.yaml"
VALIDATOR = ROOT / yaml.safe_load(MAP_YAML.read_text())["sources"]["validator"]["path"]
MAP_MD = V2 / "validator-refusal-mapping.md"
CODE_RE = re.compile(r"[EWI]-[A-Z0-9][A-Z0-9-]*")


def _reason_codes():
    return json.loads(SCHEMA.read_text())["properties"]["reason_code"]["enum"]


def _validator_codes():
    """Every code the validator can emit: string literals passed to err/warn/info or Finding()."""
    tree = ast.parse(VALIDATOR.read_text())
    codes = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        f = node.func
        if isinstance(f, ast.Attribute) and f.attr in ("err", "warn", "info"):
            arg = node.args[0] if node.args else None
        elif isinstance(f, ast.Name) and f.id == "Finding":
            arg = node.args[1] if len(node.args) > 1 else None
        else:
            continue
        if arg is None:
            continue
        if isinstance(arg, ast.Name) and arg.id == "rule":
            continue  # the err/warn/info helpers forwarding their own parameter
        assert isinstance(arg, ast.Constant) and isinstance(arg.value, str), (
            "line %d emits a non-literal code; the mapping cannot enumerate it" % node.lineno)
        assert CODE_RE.fullmatch(arg.value), arg.value
        codes.add(arg.value)
    return codes


def _mapping():
    return yaml.safe_load(MAP_YAML.read_text())


def _md_table(title):
    """First-column codes of the markdown table under the '## <title>' heading."""
    text = MAP_MD.read_text()
    section = text.split("## " + title, 1)[1].split("\n## ", 1)[0]
    rows = []
    for line in section.splitlines():
        m = re.match(r"\| `([^`]+)`( \*)? \| (.*) \|$", line)
        if m:
            cells = m.group(3).split(" | ")
            rows.append((m.group(1), cells))
    return rows


def _codes_in(cell):
    return sorted(re.findall(r"`([^`]+)`", cell))


def test_source_shas_match():
    src = _mapping()["sources"]
    assert hashlib.sha256(SCHEMA.read_bytes()).hexdigest() == src["refusal_schema"]["sha256"]
    assert hashlib.sha256(VALIDATOR.read_bytes()).hexdigest() == src["validator"]["sha256"]


def test_every_reason_code_exactly_once():
    enum = _reason_codes()
    assert len(enum) == len(set(enum))
    assert set(_mapping()["reason_codes"]) == set(enum)
    md = [c for c, _ in _md_table("Table A")]
    assert sorted(md) == sorted(enum), "Table A must list each reason_code exactly once"


def test_every_validator_code_exactly_once():
    emitted = _validator_codes()
    assert emitted, "no codes found: extraction is broken"
    assert any(c.startswith("E-") for c in emitted) and any(c.startswith("W-") for c in emitted)
    assert set(_mapping()["validator_codes"]) == emitted
    md = [c for c, _ in _md_table("Table B")]
    assert sorted(md) == sorted(emitted), "Table B must list each validator code exactly once"


def test_yaml_cross_references_agree():
    m = _mapping()
    rc, vc = m["reason_codes"], m["validator_codes"]
    for code, row in rc.items():
        assert row["runtime_only"] == (not row["prevented_by"]), code
        assert row["why"].strip(), code
        for v in row["prevented_by"]:
            assert v in vc and code in vc[v]["prevents"], (code, v)
    for code, row in vc.items():
        assert row["design_only"] == (not row["prevents"]), code
        assert row["rule"].strip(), code
        for r in row["prevents"]:
            assert r in rc and code in rc[r]["prevented_by"], (code, r)


def test_markdown_tables_agree_with_yaml():
    m = _mapping()
    for code, cells in _md_table("Table A"):
        row = m["reason_codes"][code]
        prevented = cells[1]
        if row["runtime_only"]:
            assert prevented == "runtime-only", code
        else:
            assert _codes_in(prevented) == sorted(row["prevented_by"]), code
    for code, cells in _md_table("Table B"):
        row = m["validator_codes"][code]
        prevents = cells[1]
        if row["design_only"]:
            assert prevents == "design-only", code
        else:
            assert _codes_in(prevents) == sorted(row["prevents"]), code


def test_inferred_marks_agree():
    m = _mapping()
    for title, key in (("Table A", "reason_codes"), ("Table B", "validator_codes")):
        text = MAP_MD.read_text().split("## " + title, 1)[1].split("\n## ", 1)[0]
        for code, row in m[key].items():
            starred = ("| `%s` * |" % code) in text
            assert starred == bool(row["inferred"]), (title, code)


def test_mapping_is_not_in_frozen_manifest():
    manifest = (V2 / "MANIFEST.yaml").read_text()
    assert "validator-refusal-mapping" not in manifest
