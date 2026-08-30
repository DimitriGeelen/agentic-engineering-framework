"""T-3224 — guard for `_parse_ac_body`'s Steps/Expected/If-not marker handling.

Three legs, matching the task's ACs:

* CLASS 2 — a canonical ``**Steps:**`` whose step text sits on the SAME line kept
  that text (the old branch did ``current_content = []`` and threw the rest away,
  while the Expected/If-not branches both seeded from ``rest``).
* CLASS 1 — a heading carrying a suffix before the closing ``:**``
  (``**Steps (Route A — manual):**``, ``**If not visible:**``) is recognised as a
  field start instead of being swallowed into the preceding field.
* NO-WIDENING — every AC body in the live ``.tasks/active`` corpus that parsed
  correctly before parses *identically* after. Asserted against a frozen copy of
  the pre-fix parser (``_prefix_parse_ac_body`` below), over all bodies, not a
  spot-check. The frozen copy was verified byte-identical to the real pre-fix
  implementation over 2,446 corpus AC bodies at capture time (T-3224 Updates).
"""

import pathlib
import re
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from web.blueprints.tasks import (  # noqa: E402
    _parse_ac_body,
    _parse_acceptance_criteria,
    _render_md_block,
    _render_md_inline,
)


# ---------------------------------------------------------------------------
# Frozen pre-fix implementation — copied verbatim from web/blueprints/tasks.py
# at the commit before T-3224. Do NOT "fix" it; its whole job is to be the
# baseline the no-widening leg compares against.
# ---------------------------------------------------------------------------
def _prefix_parse_ac_body(body):
    steps = []
    expected = ''
    if_not = ''
    if not body:
        return steps, expected, if_not

    lines = body.split('\n')
    current_field = None
    current_content = []

    for line in lines:
        stripped = line.strip()
        if stripped.startswith('**Steps:**'):
            current_field = 'steps'
            current_content = []
            continue
        elif stripped.startswith('**Expected:**'):
            if current_field == 'steps':
                steps = [s for s in current_content if s.strip()]
            current_field = 'expected'
            rest = stripped[len('**Expected:**'):].strip()
            current_content = [rest] if rest else []
            continue
        elif stripped.startswith('**If not:**'):
            if current_field == 'steps':
                steps = [s for s in current_content if s.strip()]
            elif current_field == 'expected':
                expected = '\n'.join(current_content).strip()
            current_field = 'if_not'
            rest = stripped[len('**If not:**'):].strip()
            current_content = [rest] if rest else []
            continue
        if current_field:
            current_content.append(stripped)

    if current_field == 'steps':
        steps = [s for s in current_content if s.strip()]
    elif current_field == 'expected':
        expected = '\n'.join(current_content).strip()
    elif current_field == 'if_not':
        if_not = '\n'.join(current_content).strip()

    steps = [re.sub(r'^\d+\.\s*', '', s) for s in steps]

    steps = [_render_md_inline(s) for s in steps]
    expected = _render_md_block(expected)
    if_not = _render_md_block(if_not)

    return steps, expected, if_not


# --- defect predicates, applied per AC body -------------------------------
_ANY_MARKER = re.compile(r'^\*\*(Steps|Expected|If not)')
_CANONICAL = re.compile(r'^\*\*(Steps|Expected|If not):\*\*')
_STEPS_SAME_LINE = re.compile(r'^\*\*Steps:\*\*\s*\S')


def _defect_class(body):
    """Return the set of defect classes present in an AC body ('c1' / 'c2')."""
    found = set()
    for raw in body.split('\n'):
        line = raw.strip()
        if _ANY_MARKER.match(line) and not _CANONICAL.match(line):
            found.add('c1')
        if _STEPS_SAME_LINE.match(line):
            found.add('c2')
    return found


def _corpus_bodies():
    """(task_file, ac_index, body) for every AC body under .tasks/active."""
    for path in sorted((ROOT / '.tasks' / 'active').glob('*.md')):
        text = path.read_text(encoding='utf-8', errors='replace')
        for idx, ac in enumerate(_parse_acceptance_criteria(text)):
            yield path.name, idx, ac['body']


# ---------------------------------------------------------------------------
# CLASS 2 — same-line step text after a canonical heading
# ---------------------------------------------------------------------------
def test_class2_same_line_steps_text_is_kept():
    body = (
        '**Steps:** 1. Run `bin/fw bvp driver --propose` 2. Open the approvals page\n'
        '**Expected:** the proposal card appears\n'
        '**If not:** check the JSONL reader\n'
    )
    steps, expected, if_not = _parse_ac_body(body)
    assert steps, 'same-line Steps text was dropped — CLASS 2 regression'
    assert 'bvp driver --propose' in ' '.join(steps)
    assert 'Open the approvals page' in ' '.join(steps)
    # siblings unchanged
    assert 'the proposal card appears' in expected
    assert 'check the JSONL reader' in if_not
    # and the pre-fix parser really did drop it (the defect is real)
    assert _prefix_parse_ac_body(body)[0] == []


def test_class2_mixed_same_line_and_following_lines():
    body = (
        '**Steps:** 1. First step on the heading line\n'
        '2. Second step on its own line\n'
        '**Expected:** ok\n'
    )
    steps, _, _ = _parse_ac_body(body)
    joined = ' '.join(steps)
    assert 'First step on the heading line' in joined
    assert 'Second step on its own line' in joined


# ---------------------------------------------------------------------------
# CLASS 1 — heading with a suffix before the closing `:**`
# ---------------------------------------------------------------------------
def test_class1_suffixed_steps_heading_is_a_field_start():
    body = (
        '**Steps (Route A — manual, simplest):**\n'
        '1. Open the dashboard\n'
        '2. Paste the hub secret\n'
        '**Expected:** the dashboard refreshes\n'
    )
    steps, expected, _ = _parse_ac_body(body)
    joined = ' '.join(steps)
    assert 'Open the dashboard' in joined, 'suffixed Steps heading not recognised — CLASS 1'
    assert 'Paste the hub secret' in joined
    # the qualifier is kept as a label — it is what distinguishes two Steps blocks
    assert 'Route A' in joined
    assert 'the dashboard refreshes' in expected
    # pre-fix: the block was swallowed (no field open → dropped outright)
    assert _prefix_parse_ac_body(body)[0] == []


@pytest.mark.parametrize('heading,marker', [
    ('**Steps (Route B — automated, T-1055):**', 'steps'),
    ('**Steps (one-line, copy-pasteable from project root):**', 'steps'),
    ('**Expected (per README "What It Shows"):**', 'expected'),
    ('**If not visible:**', 'if_not'),
])
def test_class1_applies_to_all_three_markers(heading, marker):
    """The suffix tolerance is not Steps-only — the siblings share the limit."""
    body = f'{heading}\nCONTENT-SENTINEL\n'
    steps, expected, if_not = _parse_ac_body(body)
    got = {'steps': ' '.join(steps), 'expected': expected, 'if_not': if_not}
    assert 'CONTENT-SENTINEL' in got[marker], f'{heading} not recognised as a {marker} start'
    for other in got:
        if other != marker:
            assert 'CONTENT-SENTINEL' not in got[other]


def test_suffixed_heading_precedence_flushes_previous_field():
    """A suffixed heading after another field ends that field rather than joining it."""
    body = (
        '**Steps:**\n'
        '1. do the thing\n'
        '**If not visible:** re-run the collector\n'
    )
    steps, _, if_not = _parse_ac_body(body)
    assert 'do the thing' in ' '.join(steps)
    assert 're-run the collector' in if_not
    assert 're-run the collector' not in ' '.join(steps)


def test_two_route_blocks_both_render():
    """T-1624's shape: one AC offering two routes keeps both, labelled."""
    body = (
        '**Steps (Route A — manual, simplest):**\n'
        '1. ssh to the host\n'
        '**Expected:** PASS for route A\n'
        '\n'
        '**Steps (Route B — automated, T-1055):**\n'
        '1. run the reauth command\n'
        '**Expected:** PASS for route B\n'
        '**If not:** capture the new failure class\n'
    )
    steps, expected, if_not = _parse_ac_body(body)
    joined = ' '.join(steps)
    for fragment in ('Route A', 'ssh to the host', 'Route B', 'run the reauth command'):
        assert fragment in joined, f'{fragment!r} lost — the second block overwrote the first'
    assert 'PASS for route A' in expected and 'PASS for route B' in expected
    assert 'capture the new failure class' in if_not


def test_inline_bold_after_marker_is_not_mistaken_for_the_heading():
    """The suffix excludes `*`, so later inline bold cannot close the heading."""
    body = '**Expected:** all **panels** visible, no console errors\n'
    _, expected, _ = _parse_ac_body(body)
    assert 'panels' in expected
    assert 'visible, no console errors' in expected


def test_empty_body_returns_empty_fields():
    assert _parse_ac_body('') == ([], '', '')
    assert _parse_ac_body(None) == ([], '', '')


# ---------------------------------------------------------------------------
# NO-WIDENING — full active corpus, pre-fix vs post-fix
# ---------------------------------------------------------------------------
def test_no_widening_over_active_corpus():
    """Every AC body without a defect-class marker parses identically to pre-fix."""
    compared = 0
    diffs = []
    for name, idx, body in _corpus_bodies():
        if _defect_class(body):
            continue
        compared += 1
        if _parse_ac_body(body) != _prefix_parse_ac_body(body):
            diffs.append(f'{name} AC#{idx}')
    assert compared > 1000, f'corpus sweep collected only {compared} AC bodies — did collection break?'
    assert not diffs, f'{len(diffs)} unaffected AC bodies changed: {diffs[:10]}'


def test_defect_class_bodies_exist_and_all_changed():
    """The corpus really carries both classes, and the fix moves every one of them."""
    defective = [(n, i, b) for n, i, b in _corpus_bodies() if _defect_class(b)]
    assert defective, 'no defect-class AC body in the corpus — the sweep has nothing to prove'
    unchanged = [
        f'{n} AC#{i}' for n, i, b in defective
        if _parse_ac_body(b) == _prefix_parse_ac_body(b)
    ]
    assert not unchanged, f'defect-class bodies still parse as pre-fix: {unchanged}'
    classes = set().union(*(_defect_class(b) for _, _, b in defective))
    assert classes == {'c1', 'c2'}, f'corpus covers only {classes}'
