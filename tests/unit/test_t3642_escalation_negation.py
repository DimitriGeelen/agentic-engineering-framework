"""T-3642 — destructive-action escalation: negated guarantees and first-match-only.

Port of 055-agentic-fleet-cockpit's finding (framework:pickup offset 219, their
T-304 / commit 9bb44ca), re-derived against our code. Drives the REAL
evaluate_escalations against the REAL policy file and asserts both directions:
a safety guarantee no longer escalates, and genuine destructive language still
does — including the cross-sentence trap 055 hit with a plain lookback window.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


@pytest.fixture(scope="module")
def esc() -> dict:
    return ss.load_catalogue(ROOT / "policy" / "escalation-patterns.yaml")


def _destructive(esc, ac: str = "", verif: str = ""):
    trig = ss.evaluate_escalations(ac, verif, {}, esc)
    return [t for t in trig if t.trigger_id == "destructive-action"]


# ── the false positive ──


def test_negated_guarantee_does_not_escalate(esc):
    ac = "- [ ] Running it with no arguments can never destroy anything."
    assert _destructive(esc, ac=ac) == []


def test_negated_production_guarantee_does_not_escalate(esc):
    ac = "- [ ] The cleanup must not wipe production data under any flag."
    assert _destructive(esc, ac=ac) == []


def test_vague_verb_without_production_object_does_not_escalate(esc):
    ac = "- [ ] On eviction the cache layer will destroy stale entries."
    assert _destructive(esc, ac=ac) == []


# ── first-match-only ──


def test_later_genuine_hit_is_reported_not_the_harmless_early_one(esc):
    ac = (
        "- [ ] Running it with no arguments can never destroy anything.\n"
        "- [ ] Step 3 will wipe the production database before re-seeding."
    )
    hits = _destructive(esc, ac=ac)
    assert len(hits) == 1
    assert "wipe" in hits[0].matched.lower()


# ── fail-open guards (the direction that must keep firing) ──


def test_negation_in_previous_sentence_does_not_suppress_next(esc):
    ac = "- [ ] This step must never be skipped. Wipe the production database first."
    hits = _destructive(esc, ac=ac)
    assert len(hits) == 1
    assert "wipe" in hits[0].matched.lower()


@pytest.mark.parametrize(
    "ac",
    [
        "- [ ] Agent will force-push the rewritten branch",
        "- [ ] Do a hard reset of the staging tree",
        "- [ ] drop-table users after migration",
        "- [ ] We never force-push, except here: force-push the fix",
        "- [ ] Purge production caches nightly",
        "- [ ] Destroy the live tenant records older than 90 days",
        "- [ ] wipe customer data on request",
    ],
)
def test_genuine_destructive_ac_still_fires(esc, ac):
    assert len(_destructive(esc, ac=ac)) == 1


def test_unconditional_ac_forms_fire_even_when_negated(esc):
    # force-push / hard-reset / drop-table name the operation itself; they are
    # not subject to the negation exclusion.
    assert len(_destructive(esc, ac="- [ ] never force-push to master")) == 1


@pytest.mark.parametrize(
    "verif",
    [
        "rm -rf build/",
        "psql -c 'DROP TABLE users'",
        "git push --force origin x",
        "git reset --hard HEAD~1",
    ],
)
def test_verification_forms_unchanged(esc, verif):
    assert len(_destructive(esc, verif=verif)) == 1


# ── exclude_pattern semantics on a synthetic catalogue ──


def _cat(exclude):
    m = {"kind": "ac_text", "pattern": r"\bzap\b"}
    if exclude is not None:
        m["exclude_pattern"] = exclude
    return {"triggers": [{"id": "t", "name": "t", "severity": "high", "match": [m]}]}


def test_exclude_pattern_skips_and_continues():
    trig = ss.evaluate_escalations("never zap it. zap it now", "", {}, _cat(r"\bnever\b"))
    assert len(trig) == 1


def test_exclude_pattern_alone_suppresses():
    assert ss.evaluate_escalations("never zap it", "", {}, _cat(r"\bnever\b")) == []


def test_unparseable_exclude_pattern_fails_loud_not_open():
    trig = ss.evaluate_escalations("never zap it", "", {}, _cat(r"(unclosed"))
    assert len(trig) == 1
