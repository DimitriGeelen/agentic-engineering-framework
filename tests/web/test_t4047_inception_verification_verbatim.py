"""T-4047 (GitHub #94): /inception/<id> shows the `## Verification` card verbatim.

The block is shell commands and `#` comments, not Markdown. Rendered through
_md, a comment becomes an <h1>, and `*` or `_` inside a command becomes
emphasis, so the operator reads something other than what the completion gate
runs. The card must hold the exact text in a <pre>, HTML-escaped and unformatted.
"""
from __future__ import annotations

import html
import re

import pytest

import web.blueprints.inception as inception

VERIFICATION = """# Toolchain hint: *.vbproj/*.csproj/*.xaml -> dotnet build
# out_of_scope and yaml.safe_load are checked below
python3 -c "import yaml; yaml.safe_load(open('policy/x.yaml'))"
grep -q out_of_scope docs/reports/T-9950.md
echo "*.csproj _x_"
"""

TASK = """---
id: T-9950
name: "verbatim probe"
status: started-work
workflow_type: inception
owner: human
---

# T-9950

## Problem Statement

A probe.

## Verification

{verification}
"""


@pytest.fixture()
def client(tmp_path, monkeypatch):
    d = tmp_path / ".tasks" / "active"
    d.mkdir(parents=True)
    (d / "T-9950-probe.md").write_text(
        TASK.format(verification=VERIFICATION), encoding="utf-8")
    monkeypatch.setattr(inception, "PROJECT_ROOT", tmp_path)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


def _verification_card(page):
    m = re.search(
        r"<header>Verification</header>\s*(<pre[^>]*>.*?</pre>|<div class=\"section-content\">.*?</div>)\s*</article>",
        page, re.S)
    assert m, "Verification card not rendered"
    return m.group(1)


def test_verification_card_holds_verbatim_pre(client):
    page = client.get("/inception/T-9950").get_data(as_text=True)
    card = _verification_card(page)
    pre = re.fullmatch(r"<pre[^>]*>(.*?)</pre>", card, re.S)
    assert pre, "Verification is not in a <pre>"
    assert html.unescape(pre.group(1)).strip() == VERIFICATION.strip()


def test_verification_card_has_no_markdown_artifacts(client):
    card = _verification_card(client.get("/inception/T-9950").get_data(as_text=True))
    assert "<h1" not in card
    assert "<em>" not in card
    assert "<strong>" not in card


def test_verification_comments_stay_text(client):
    card = _verification_card(client.get("/inception/T-9950").get_data(as_text=True))
    text = html.unescape(card)
    assert "# Toolchain hint: *.vbproj/*.csproj/*.xaml -> dotnet build" in text
    assert "yaml.safe_load" in text
    assert "out_of_scope" in text
