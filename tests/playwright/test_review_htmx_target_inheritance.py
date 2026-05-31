"""T-2135: regression net for the htmx-target-inheritance class.

Four bugs in the last fortnight shared one shape — a wrapper sets
``hx-target="#X"`` (typically ``#content`` for the bounce-back fix); a
descendant form/anchor with ``hx-post``/``hx-get``/etc. inherits the target;
if ``#X`` doesn't exist in the rendered DOM (standalone template — no
base.html → no ``#content``), htmx fires ``htmx:targetError`` and aborts the
request before any user-visible feedback or CSRF wiring runs.

Origin incidents:

* **T-2112** — /approvals "Review" click bounce-back (wrapper inherited target
  swapped into the polling div).
* **T-2113** — cockpit Recent Activity task links → same bounce-back class.
* **T-2114** — review.html Reload-page link + markdown-rendered URLs →
  introduced the wrapper-reset ``<div hx-target="#content">`` pattern.
* **T-2134** — review.html ac-check form silently no-opped because the form
  inherited ``#content`` (absent in the standalone template); htmx aborted
  the POST pre-configRequest, so CSRF never ran. Captured as L-450.

This test pins the contract structurally: on /review/<id> (the canonical
standalone-template surface), every interactive descendant must have a
resolvable ``hx-target`` — either declared on the element itself, OR
inherited from an ancestor whose target value resolves to a DOM-present
id selector. Wrapper elements with no own request trigger are fine even
when their hx-target points at a missing id (htmx only consults
hx-target when *the wrapper itself* dispatches a request).

Same regression-net shape as T-2042 + T-2048 (unbounded page height) and
T-2120 (htmx-toast extraction): a structural pin that fails the moment a
future edit drops the explicit override or re-introduces the inheritance
trap.
"""

import urllib.request

from bs4 import BeautifulSoup

TEST_URL = "http://localhost:3099"
# T-2134 is a partial-complete arc-007 task we know exists in active/ at
# filing time; its /review surface exercises both the wrapper-reset
# (`<div hx-target="#content">` from T-2114) and the explicit override
# (`<form hx-target="this">` from T-2134) — the two halves of the contract
# this test guards.
SAMPLE_TASK_ID = "T-2134"

# htmx request-triggering attributes. An element carrying any of these
# dispatches an htmx request and therefore needs a resolvable hx-target.
REQUEST_TRIGGER_ATTRS = ("hx-post", "hx-get", "hx-put", "hx-delete", "hx-patch")


def _fetch_review_html(task_id: str) -> str:
    """Fetch /review/<id> HTML via the conftest-managed Watchtower server."""
    with urllib.request.urlopen(f"{TEST_URL}/review/{task_id}", timeout=15) as r:
        return r.read().decode("utf-8", errors="replace")


def _effective_target(element):
    """Walk ancestors (including self) and return the nearest hx-target.

    Returns (target_value, source_element) or (None, None) if no hx-target
    inherits — in which case htmx defaults to the triggering element itself,
    which always resolves.
    """
    node = element
    while node is not None and getattr(node, "name", None) is not None:
        if node.has_attr("hx-target"):
            return node["hx-target"], node
        node = node.parent
    return None, None


def _target_always_resolves(target_value: str) -> bool:
    """Return True for hx-target values that don't depend on a DOM id.

    The contract we're checking is specifically the ``#some-id`` selector
    case (the T-2112..T-2134 class). Relative targets (``this``, ``closest``,
    ``find``, ``next``, ``previous``) and class selectors are out of scope
    for v1; htmx's failure mode on those is different from targetError-abort.
    """
    if target_value in ("this",):
        return True
    if target_value.startswith(("closest ", "find ", "next ", "previous ")):
        return True
    # Class / tag / attribute selectors: htmx resolves these via document.query;
    # missing-match yields a different failure mode (silent no-swap), not the
    # pre-configRequest abort the L-450 class describes.
    if not target_value.startswith("#"):
        return True
    return False


def test_review_no_unresolvable_hx_target(page):
    """Every interactive descendant on /review/<id> has a resolvable hx-target.

    Uses ``page`` only to keep the test inside the Playwright collection (one
    server-startup shared across all tests in the file). The actual analysis
    is static DOM via bs4 — no browser interaction needed; the contract is a
    property of the rendered HTML, independent of JS execution.
    """
    html = _fetch_review_html(SAMPLE_TASK_ID)
    soup = BeautifulSoup(html, "html.parser")

    # Collect every id present in the rendered DOM. The hx-target ``#X``
    # selector resolves iff ``X`` is in this set.
    present_ids = {el["id"] for el in soup.find_all(id=True)}

    # Find every element that dispatches an htmx request.
    interactive = [
        el
        for el in soup.find_all(True)
        if any(el.has_attr(a) for a in REQUEST_TRIGGER_ATTRS)
    ]
    assert interactive, (
        f"/review/{SAMPLE_TASK_ID} returned no htmx-interactive elements; "
        "either the route changed shape or the fixture task lost its "
        "ac-check / polling forms — investigate before relaxing this assert."
    )

    failures = []
    for el in interactive:
        target_value, source = _effective_target(el)
        if target_value is None:
            # No hx-target anywhere — htmx targets the triggering element.
            continue
        if _target_always_resolves(target_value):
            continue
        # target_value starts with '#'
        target_id = target_value.lstrip("#")
        if target_id in present_ids:
            continue
        failures.append(
            {
                "element": el.name,
                "hx_attr": next(a for a in REQUEST_TRIGGER_ATTRS if el.has_attr(a)),
                "hx_path": el.get(next(a for a in REQUEST_TRIGGER_ATTRS if el.has_attr(a))),
                "inherited_target": target_value,
                "target_from_self": source is el,
                "source_element": source.name if source is not None else None,
            }
        )

    assert not failures, (
        "/review/<id> has interactive elements whose hx-target inherits an "
        "id that does NOT exist in the rendered DOM — htmx will fire "
        "htmx:targetError and abort the request pre-configRequest "
        f"(L-450, T-2112..T-2134 class). Failures: {failures}"
    )


def test_ac_check_form_has_explicit_hx_target_this(page):
    """The ac-check form must carry ``hx-target=\"this\"`` — T-2134 fix pin.

    A regression here is the exact bug T-2134 fixed: the form inherits the
    wrapper-reset ``#content`` (T-2114), htmx fires targetError on the
    standalone review.html template (no #content), and the checkbox click
    silently no-ops. This complements test_review_no_unresolvable_hx_target
    above: the former proves the form has its own override; this one names
    the contract explicitly so a maintainer reading the test sees exactly
    what shape protects against L-450.
    """
    html = _fetch_review_html(SAMPLE_TASK_ID)
    soup = BeautifulSoup(html, "html.parser")
    ac_check_forms = soup.select("form.ac-check")
    assert ac_check_forms, (
        f"/review/{SAMPLE_TASK_ID} has no form.ac-check — the AC fragment is "
        "missing or the class name changed. Investigate before relaxing this "
        "assert; the contract this test pins depends on form.ac-check existing."
    )
    for form in ac_check_forms:
        assert form.get("hx-target") == "this", (
            "form.ac-check on /review/<id> must declare hx-target=\"this\" "
            "(T-2134 fix). Without it, the form inherits the wrapper-reset "
            "hx-target=\"#content\" (T-2114) and aborts pre-configRequest in "
            "the standalone review.html template — L-450. Current form: "
            f"{form.attrs}"
        )
