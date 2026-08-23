"""T-3124: the /file/<path> route must not say a file "does not exist" when it does.

Pre-T-3124 both aborts in `file_viewer` rendered the same 404 body — "The
requested page does not exist." — so a tracked, on-disk file whose directory
is simply absent from VIEWABLE_DIR_PREFIXES was reported as missing. 1221 of
2011 tracked files under docs/ were in that state. The status code was never
the problem; the sentence was, because a false answer reads as answered and
sends the reader hunting for a file instead of at the allowlist.

The fix has a hard security boundary: existence is disclosed only for
GIT-TRACKED paths, so the route cannot be used as an existence oracle for
arbitrary filesystem paths (.env, keys, scratch output). These tests pin:
  - tracked + unservable  -> distinct body naming VIEWABLE_DIR_PREFIXES
  - tracked + servable    -> 200, unchanged
  - untracked + on disk   -> plain "does not exist", presence not revealed
  - absent                -> plain "does not exist", unchanged
  - `..` traversal        -> 404 and never reaches the disclosure branch
"""
from __future__ import annotations

import subprocess

import pytest

from web.app import app

# The route resolves paths against the PROJECT_ROOT bound into docs.py at
# import time — use that exact object, not web.shared's live attribute, which
# reload-based tests elsewhere can leave dangling at a tmp dir.
from web.blueprints.docs import PROJECT_ROOT as ROUTE_ROOT
from web.shared import is_viewable_path

NOT_EXIST = "does not exist"
ALLOWLIST = "VIEWABLE_DIR_PREFIXES"


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def _body(resp) -> str:
    return resp.get_data(as_text=True)


def _tracked_unservable_path() -> str:
    """A git-tracked file that exists on disk but is outside the allowlist."""
    out = subprocess.run(
        ["git", "ls-files", "--", "docs/"],
        cwd=str(ROUTE_ROOT),
        capture_output=True,
        text=True,
    )
    for rel in out.stdout.splitlines():
        if not rel or is_viewable_path(rel):
            continue
        if (ROUTE_ROOT / rel).is_file():
            return rel
    pytest.skip("no tracked-but-unservable file available in this checkout")


def _tracked_servable_path() -> str:
    """A git-tracked file that exists on disk and IS inside the allowlist.

    Deliberately NOT docs.py or shared.py: those contain the very strings this
    module asserts on, so serving them would make the negative assertions in
    the servable case self-referential and meaningless.
    """
    out = subprocess.run(
        ["git", "ls-files", "--", "lib/"],
        cwd=str(ROUTE_ROOT),
        capture_output=True,
        text=True,
    )
    for rel in out.stdout.splitlines():
        if not rel or not is_viewable_path(rel):
            continue
        path = ROUTE_ROOT / rel
        if not path.is_file():
            continue
        try:
            text = path.read_text()
        except (OSError, UnicodeDecodeError):
            continue
        if ALLOWLIST in text or NOT_EXIST in text:
            continue
        return rel
    pytest.skip("no clean tracked-and-servable file available in this checkout")


# ---- a) tracked + NOT servable -------------------------------------------

def test_tracked_unservable_file_says_it_exists(client):
    rel = _tracked_unservable_path()
    resp = client.get(f"/file/{rel}")
    body = _body(resp)

    assert resp.status_code == 404, "status stays 404 — the fix is the message"
    assert NOT_EXIST not in body, (
        f"/file/{rel} still claims the file does not exist, but it is tracked "
        f"and present at {ROUTE_ROOT / rel}"
    )
    assert ALLOWLIST in body, "body must name the allowlist as the thing to change"
    assert rel in body, "body must name the file it is talking about"


# ---- b) tracked + servable (no regression) --------------------------------

def test_tracked_servable_file_still_renders(client):
    rel = _tracked_servable_path()
    resp = client.get(f"/file/{rel}")

    assert resp.status_code == 200
    body = _body(resp)
    assert NOT_EXIST not in body
    assert "not served by the file viewer" not in body
    assert (ROUTE_ROOT / rel).name in body, "expected the file itself to render"


# ---- c) untracked + on disk (the security boundary) -----------------------

def test_untracked_file_on_disk_is_not_disclosed(client, tmp_path):
    """An untracked file that happens to exist keeps the plain not-found body.

    docs/ (bare) is not in VIEWABLE_DIR_PREFIXES, so this lands in exactly the
    branch that would otherwise disclose. It must not.
    """
    probe = ROUTE_ROOT / "docs" / "t3124-untracked-probe.md"
    probe.write_text("secret scratch content\n")
    try:
        assert probe.is_file()
        rel = "docs/t3124-untracked-probe.md"
        assert (
            subprocess.run(
                ["git", "ls-files", "--error-unmatch", "--", f":(literal){rel}"],
                cwd=str(ROUTE_ROOT),
                capture_output=True,
            ).returncode
            != 0
        ), "probe must be untracked for this test to mean anything"

        resp = client.get(f"/file/{rel}")
        body = _body(resp)

        assert resp.status_code == 404
        assert NOT_EXIST in body, "untracked paths keep the plain not-found body"
        assert ALLOWLIST not in body, "must not hint that the path is real"
        assert "secret scratch content" not in body
    finally:
        probe.unlink(missing_ok=True)


# ---- d) genuinely absent (unchanged) --------------------------------------

def test_absent_path_is_unchanged(client):
    for rel in (
        "docs/t3124-no-such-file.md",              # absent, unservable dir
        "lib/t3124_no_such_file_anywhere.py",      # absent, servable dir
    ):
        resp = client.get(f"/file/{rel}")
        body = _body(resp)
        assert resp.status_code == 404, rel
        assert NOT_EXIST in body, rel
        assert ALLOWLIST not in body, rel


# ---- traversal must never reach the disclosure branch ---------------------

def test_traversal_is_refused_before_disclosure(client):
    for attempt in (
        "/file/../../etc/passwd",
        "/file/lib/../../etc/passwd",
        "/file/docs/../docs/adr/0001-orchestration-model-pin-enforcement.md",
        "/file/%2e%2e/%2e%2e/etc/passwd",
    ):
        resp = client.get(attempt)
        body = _body(resp)
        assert resp.status_code in (301, 308, 404), attempt
        if resp.status_code == 404:
            assert ALLOWLIST not in body, f"traversal reached the new branch: {attempt}"
            assert "is present in the repository" not in body, attempt
