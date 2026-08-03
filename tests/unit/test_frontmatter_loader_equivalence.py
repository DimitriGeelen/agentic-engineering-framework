"""T-2774: the fast YAML loader must parse identically to the pure-Python one.

`web/shared.py:parse_frontmatter` uses `yaml.CSafeLoader` (libyaml) when the C
extension is compiled into the installed PyYAML, falling back to `yaml.SafeLoader`
otherwise. That swap took the 2,761-task corpus scan from 9.82s to 1.12s.

Speed is only safe if the two loaders agree. They resolve implicit scalar types
through different code paths, and this project is already on record (L-495) for
PyYAML mangling unquoted ISO-8601 `Z` timestamps — a class where "it parsed" and
"it parsed correctly" differ silently. If a future PyYAML upgrade drifts the two
apart, frontmatter would start deserialising differently depending on whether the
host happens to have libyaml, which is the kind of environment-dependent
divergence that shows up as an unreproducible bug months later.

Two layers:

  1. `TRICKY` — hand-written scalars covering the implicit-resolution classes
     where the loaders could plausibly disagree. Always runs, including in a
     fresh consumer project whose `.tasks/` is nearly empty. This is the part
     that keeps the test meaningful where the corpus sweep has nothing to chew.
  2. The live-corpus sweep — every real frontmatter block in `.tasks/`. Catches
     shapes nobody thought to write a fixture for. Skips (not passes) when no
     corpus exists, so an empty run is never mistaken for a clean one.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).resolve().parents[2]
_FM = re.compile(r"^---\s*\n(.*?)\n---\n?(.*)", re.DOTALL)

# Skip the whole module when the installed PyYAML has no C extension: there is
# no second loader to compare against, and parse_frontmatter has already fallen
# back to SafeLoader, so there is nothing this test could assert.
pytestmark = pytest.mark.skipif(
    not hasattr(yaml, "CSafeLoader"),
    reason="PyYAML built without libyaml — parse_frontmatter falls back to SafeLoader",
)


# Implicit-type resolution classes. Each is a frontmatter body; the point is not
# that any particular value is *correct* (PyYAML's timestamp coercion is its own
# problem, see L-495) but that both loaders produce the *same* wrong-or-right
# thing, so behaviour cannot depend on which loader the host provides.
TRICKY = {
    "iso8601_z": "last_update: 2026-08-03T18:27:14Z\n",
    "iso8601_offset": "created: 2026-08-03T18:27:14+02:00\n",
    "date_only": "created: 2026-08-03\n",
    "quoted_timestamp": 'last_update: "2026-08-03T18:27:14Z"\n',
    "sexagesimal_like": "version: 1:30\nport: 22:00\n",
    "bools_yaml11": "a: yes\nb: no\nc: on\nd: off\ne: true\nf: false\n",
    "nulls": "a: null\nb: ~\nc:\n",
    "numbers": "a: 0o777\nb: 0x1F\nc: 1_000\nd: .inf\ne: .nan\nf: 1e3\ng: 007\n",
    "strings_that_look_typed": 'id: T-2774\nname: "3.10"\nver: 3.10\n',
    "empty_and_ws": "a: ''\nb: '  '\nc: |\n  block\n  scalar\n",
    "nested": "bvp_scores:\n  D1: 5\n  D2: 0\ntags:\n  - arc:foo\n  - bar\n",
    "unicode": 'name: "arc-006 · value-prioritisation — em—dash"\n',
    "merge_key_ish": "a: &anchor {x: 1}\nb: *anchor\n",
}


def _both(block: str):
    """Parse `block` under each loader, returning (safe_result, c_result).

    A YAMLError is captured as a marker string rather than raised: the loaders
    must also agree about *which* documents are rejected, not only about the
    values they accept.
    """
    out = []
    for loader in (yaml.SafeLoader, yaml.CSafeLoader):
        try:
            out.append(yaml.load(block, Loader=loader))
        except yaml.YAMLError as exc:
            out.append(f"__YAMLError__:{type(exc).__name__}")
    return out[0], out[1]


@pytest.mark.parametrize("case", sorted(TRICKY))
def test_tricky_scalars_parse_identically(case):
    """Implicit-type resolution must not depend on which loader is installed."""
    safe, fast = _both(TRICKY[case])
    assert repr(safe) == repr(fast), (
        f"loader divergence on {case!r}:\n"
        f"  SafeLoader  -> {safe!r}\n"
        f"  CSafeLoader -> {fast!r}\n"
        "parse_frontmatter would deserialise this differently depending on "
        "whether the host's PyYAML was built with libyaml."
    )


def _corpus_blocks():
    tasks = PROJECT_ROOT / ".tasks"
    blocks = []
    for sub in ("active", "completed"):
        d = tasks / sub
        if not d.is_dir():
            continue
        for f in sorted(d.glob("T-*.md")):
            try:
                text = f.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            m = _FM.match(text)
            if m:
                blocks.append((f, m.group(1)))
    return blocks


def test_live_corpus_parses_identically_under_both_loaders():
    """Every real frontmatter block must parse the same under both loaders.

    This is the layer that catches shapes no fixture anticipated. It sweeps the
    whole corpus rather than sampling: a sample that happens to miss the one
    divergent file reports clean, which is the failure mode the test exists to
    prevent.
    """
    blocks = _corpus_blocks()
    if not blocks:
        pytest.skip("no task corpus in this project — TRICKY cases still cover the classes")

    divergent = []
    for path, block in blocks:
        safe, fast = _both(block)
        if repr(safe) != repr(fast):
            divergent.append((path.name, safe, fast))

    assert not divergent, (
        f"{len(divergent)} of {len(blocks)} frontmatter blocks parse differently "
        f"under SafeLoader vs CSafeLoader:\n"
        + "\n".join(f"  {n}\n    safe={s!r}\n    fast={f!r}" for n, s, f in divergent[:5])
    )


def test_parse_frontmatter_uses_the_fast_loader_when_available():
    """The production helper must actually be wired to the C loader.

    Without this, the equivalence tests above would keep passing while
    `parse_frontmatter` quietly reverted to the slow loader — green, and 8.8x
    slower, with nothing to say so.
    """
    from web.shared import _YAML_LOADER

    assert _YAML_LOADER is yaml.CSafeLoader, (
        f"parse_frontmatter is wired to {_YAML_LOADER!r}, expected yaml.CSafeLoader "
        "(libyaml is available in this environment)"
    )
