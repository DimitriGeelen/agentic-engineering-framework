"""T-3251 — the /pending Resolve button must send a CSRF token.

Reported by a peer project running the same vendored Watchtower: the button
"could not resolve" for anyone. The page has always carried
`<meta name="csrf-token">` (base.html), so a test that only asked whether the
page *mentions* a token would have been green throughout the bug's life. What
was missing is that the fetch never *sent* it — and since the POST carries a
JSON body there is no `_csrf_token` form field either, so the header is the
only route csrf_protect (web/app.py) will accept.

The sharpest symptom, and the one that identifies the mechanism rather than the
outcome: a POST for an id that does not exist returned 403 rather than 404.
CSRF fires before the lookup, so no click ever reached the handler.

Leg 1 is the control. Without it, leg 2 could pass on a route that has no CSRF
protection at all, which is a different system with the same green.
"""

import re
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
TEMPLATES = FRAMEWORK_ROOT / "web" / "templates"
MISSING_ID = "U-999-does-not-exist"
RESOLVE_URL = f"/api/v1/pending/{MISSING_ID}/resolve"


def _client():
    from web.app import app

    app.config["TESTING"] = True
    client = app.test_client()
    client.get("/health")
    with client.session_transaction() as sess:
        sess.setdefault("_csrf_token", "test-csrf-token")
        token = sess["_csrf_token"]
    return client, token


def test_resolve_without_token_is_rejected_before_the_lookup():
    """CONTROL: no token → 403, and 403 even for an id that does not exist.

    The id is deliberately absent. A 404 here would mean the route reached its
    lookup, i.e. CSRF is not gating it, and leg 2 below would then prove nothing.
    """
    client, _ = _client()
    resp = client.post(RESOLVE_URL, json={"note": "probe"})
    assert resp.status_code == 403, (
        f"expected the CSRF layer to reject an untokened POST, got "
        f"{resp.status_code}. If this is 404 the route is no longer CSRF-gated "
        f"and the next test is vacuous."
    )


def test_resolve_with_header_token_reaches_the_handler():
    """The header is the working route: with it, the request gets as far as the

    lookup and fails on the missing id (404) rather than on CSRF (403)."""
    client, token = _client()
    resp = client.post(RESOLVE_URL, json={"note": "probe"},
                       headers={"X-CSRF-Token": token})
    assert resp.status_code != 403, (
        "the X-CSRF-Token header was not accepted — the button cannot work by "
        "any route, since its JSON body carries no _csrf_token form field"
    )
    assert resp.status_code == 404, (
        f"expected 404 for a nonexistent id once CSRF is satisfied, got "
        f"{resp.status_code}"
    )


def _strip_js_comments(text: str) -> str:
    """Remove // and /* */ comments.

    Written after this test's own negative control caught it: with the fix
    reverted, the assertion still passed because the COMMENT explaining the fix
    mentioned X-CSRF-Token. A check satisfied by prose about the mechanism,
    rather than by the mechanism, is the same false green this task is about.
    """
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"(?m)^\s*//.*$", "", text)


def test_rendered_pending_page_sends_the_token_it_carries():
    """Asserted on the RENDERED page, not on the template file.

    Carrying the token and sending it are different properties, and only the
    second one was ever broken."""
    client, _ = _client()
    page = client.get("/pending").get_data(as_text=True)
    assert 'name="csrf-token"' in page, "the page does not carry a token to send"
    assert "X-CSRF-Token" in _strip_js_comments(page), (
        "the rendered /pending page carries a CSRF token but never sends one — "
        "this is the T-3251 defect exactly"
    )


def test_no_state_changing_template_fetch_omits_a_csrf_token():
    """Corpus scan (AC3): the count is the assertion.

    A new template that POSTs without a token reddens this against a stated
    number rather than against nobody's memory. Both accepted routes count:
    the X-CSRF-Token header, or a _csrf_token field in a form body.
    """
    offenders = []
    checked = 0
    for path in sorted(TEMPLATES.glob("*.html")):
        text = path.read_text()
        for m in re.finditer(r"fetch\(", text):
            window = text[max(0, m.start() - 400):m.start() + 600]
            if not re.search(r"method\s*:\s*['\"](POST|PUT|PATCH|DELETE)", window):
                continue
            checked += 1
            window = _strip_js_comments(window)
            if "X-CSRF-Token" in window or "_csrf_token" in window:
                continue
            offenders.append(f"{path.name}:{text[:m.start()].count(chr(10)) + 1}")

    assert checked >= 6, (
        f"only {checked} state-changing template fetches found; the scan has "
        f"stopped seeing its subject (it found 6 at T-3251)"
    )
    assert not offenders, (
        "state-changing fetch() with no CSRF token by either accepted route: "
        + ", ".join(offenders)
    )
