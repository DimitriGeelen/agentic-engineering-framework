"""T-5198: `inception_handoff_blockers` runs in-process, and agrees with the shell.

Before: every cold call ran `bash -c '. lib/inception-readiness.sh; inception_handoff_blockers F'`
(~47 subprocesses, ~5-6 s on a cold /approvals). Now `web.shared._handoff_blockers_from_text`
transcribes the shell predicate. The shell function stays the one definition other callers use,
so these tests pin the two together:

  * fixtures covering each rule and its edge cases, compared with the shell's own output;
  * every task file in the live corpus that mentions inception, compared the same way;
  * the cache: no subprocess at all, a warm call does not re-read, and every edit to the
    only input (the task file) is seen — cached == uncached after each.
"""

import glob
import os
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
os.environ.setdefault("PROJECT_ROOT", str(ROOT))

from web import shared  # noqa: E402

_SHELL = ('. "$1/lib/inception-readiness.sh" || exit 3; '
          '. "$1/lib/task-audit.sh" 2>/dev/null || true; shift; '
          'for f in "$@"; do printf "@@FILE %s\\n" "$f"; inception_handoff_blockers "$f"; done')


def _shell(paths):
    """The shell predicate's answer for each path, parsed as the old caller parsed it."""
    r = subprocess.run(["bash", "-c", _SHELL, "_", str(ROOT), *map(str, paths)],
                       capture_output=True, text=True, errors="surrogateescape")
    assert r.returncode == 0, r.stderr
    out, cur = {}, None
    for line in r.stdout.split("\n"):
        if line.startswith("@@FILE "):
            cur = line[7:]
            out[cur] = []
            continue
        parts = line.split("\t")
        if cur and len(parts) >= 2 and parts[0]:
            out[cur].append({"kind": parts[0], "detail": parts[1],
                             "fix": parts[2] if len(parts) > 2 else ""})
    return out


def _py(path):
    return shared._handoff_blockers_from_text(
        Path(path).read_bytes().decode("utf-8", errors="surrogateescape"))


FM = "---\nid: T-9001\nname: x\nworkflow_type: {wf}\nstatus: started-work\n---\n\n# T-9001\n\n"
REC_OK = "## Recommendation\n\n**Recommendation:** GO\n\n**Rationale:** because\n"

CASES = {
    "build-task": FM.format(wf="build") + "## Recommendation\n",
    "ready": FM.format(wf="inception") + "## Open Questions\n\n- **IW-1: q**\n  disposition: answered\n  rationale: r\n\n" + REC_OK,
    "no-oq-section": FM.format(wf="inception") + REC_OK,
    "no-rec-section": FM.format(wf="inception") + "## Problem\n\nx\n",
    "rec-template-only": FM.format(wf="inception") + "## Recommendation\n\n<!-- **Recommendation:** GO -->\n\n**Recommendation:**\n",
    "rec-bulleted-emphasis": FM.format(wf="inception") + "## Recommendation\n\n- **Recommendation:** **NO-GO**\n",
    "rec-star-bullet": FM.format(wf="inception") + "## Recommendation\n* **Recommendation:** *DEFER*\n",
    "rec-in-later-section-only": FM.format(wf="inception") + "## Recommendation\n\n### Sub\n**Recommendation:** GO\n",
    "rec-after-closing-comment": FM.format(wf="inception") + "## Recommendation\n<!-- a\nb -->\n**Recommendation:** GO\n",
    "rec-same-line-comment": FM.format(wf="inception") + "## Recommendation\n<!-- c --> **Recommendation:** GO\n",
    "rec-duplicate-heading": FM.format(wf="inception") + "## Recommendation\n\n## Recommendation\n**Recommendation:** GO\n",
    "rec-heading-trailing-space": FM.format(wf="inception") + "## Recommendation   \n**Recommendation:** GO\n",
    "rec-verdict-digit": FM.format(wf="inception") + "## Recommendation\n**Recommendation:** 1\n",
    "undisposed-mixed": FM.format(wf="inception") + (
        "## Open Questions\n\n"
        "disposition: answered\n"               # before any marker: ignored
        "- **IW-1: first**\n  disposition: deferred\n"
        "- IW-2: second\n  rationale: r\n"
        "### IW-3 third\n  disposition: dissolved\n  rationale: x\n"
        "- Q-4 legacy\n"
        "- Q5 legacy no dash\n  disposition: maybe\n  rationale:\n"
        "  see IW-9 in prose, not a marker\n"
        "- **IW-6: disposition: answered rationale: on the marker line**\n"
        "\n## Next\n- **IW-7: outside the section**\n") + REC_OK,
    "oq-two-sections": FM.format(wf="inception") + "## Open Questions\n- **IW-1: a**\n## Other\n- **IW-2: b**\n## Open Questions (cont)\n- **IW-3: c**\n  disposition: answered\n  rationale: y\n" + REC_OK,
    "rationale-space-only": FM.format(wf="inception") + "## Open Questions\n- **IW-1: a**\n  disposition: answered\n  rationale: \n" + REC_OK,
    "wf-quoted": FM.format(wf='"inception"') + "## Open Questions\n- **IW-1: a**\n" + REC_OK,
    "wf-no-space": FM.replace("workflow_type: {wf}", "workflow_type:inception") + "## Open Questions\n- **IW-1: a**\n",
    "wf-comment": FM.format(wf="inception  # note") + "## Open Questions\n- **IW-1: a**\n",
    "wf-inceptionx": FM.format(wf="inceptionx") + "## Open Questions\n- **IW-1: a**\n",
    "crlf": (FM.format(wf="inception") + "## Open Questions\n- **IW-1: a**\n  disposition: answered\n  rationale: r\n" + REC_OK).replace("\n", "\r\n"),
    "no-trailing-newline": FM.format(wf="inception") + "## Recommendation\n**Recommendation:** GO",
    "non-utf8": (FM.format(wf="inception") + "## Open Questions\n- **IW-1: caf\xe9**\n" + REC_OK).encode("latin-1"),
    "empty": "",
}


@pytest.fixture
def fixtures(tmp_path):
    paths = {}
    for name, body in CASES.items():
        p = tmp_path / f"T-9001-{name}.md"
        if isinstance(body, bytes):
            p.write_bytes(body)
        else:
            p.write_bytes(body.encode("utf-8"))
        paths[name] = p
    return paths


def test_fixtures_match_the_shell_predicate(fixtures):
    shell = _shell(fixtures.values())
    for name, p in fixtures.items():
        assert _py(p) == shell[str(p)], name
    # The fixtures exercise both kinds and the ready case, not only "no output".
    kinds = {b["kind"] for p in fixtures.values() for b in shell[str(p)]}
    assert kinds == {"undisposed-question", "empty-recommendation"}
    assert shell[str(fixtures["ready"])] == []
    assert len(shell[str(fixtures["undisposed-mixed"])]) >= 4


def test_every_inception_in_the_corpus_matches_the_shell():
    files = sorted(f for d in ("active", "completed")
                   for f in glob.glob(str(ROOT / ".tasks" / d / "T-*.md"))
                   if b"inception" in Path(f).read_bytes())
    assert len(files) > 100
    shell = _shell(files)
    mismatches = [f for f in files if _py(f) != shell[f]]
    assert mismatches == []
    assert any(shell[f] for f in files)  # the comparison saw blockers, not only []


def test_missing_and_directory_paths_are_not_inceptions(tmp_path):
    assert shared.inception_handoff_blockers(tmp_path / "nope.md") == []
    assert shared.inception_handoff_blockers(tmp_path) == []


def test_unreadable_file_fails_closed(tmp_path, monkeypatch):
    p = tmp_path / "T-9001-x.md"
    p.write_text(CASES["ready"])
    shared._HANDOFF_BLOCKERS_CACHE.clear()

    def _boom(self):
        raise PermissionError("denied")
    monkeypatch.setattr(Path, "read_bytes", _boom)
    out = shared.inception_handoff_blockers(p)
    assert [b["kind"] for b in out] == ["check-failed"]


def test_no_subprocess_and_warm_call_does_not_reread(fixtures, monkeypatch):
    shared._HANDOFF_BLOCKERS_CACHE.clear()
    spawned = []
    real_popen = subprocess.Popen.__init__

    def _count(self, *a, **kw):
        spawned.append(a[0] if a else kw.get("args"))
        return real_popen(self, *a, **kw)
    monkeypatch.setattr(subprocess.Popen, "__init__", _count)
    reads = []
    real_read = Path.read_bytes
    monkeypatch.setattr(Path, "read_bytes", lambda self: reads.append(self) or real_read(self))

    first = {n: shared.inception_handoff_blockers(p) for n, p in fixtures.items()}
    cold_reads = len(reads)
    again = {n: shared.inception_handoff_blockers(p) for n, p in fixtures.items()}
    assert spawned == []
    assert cold_reads == len(fixtures)
    assert len(reads) == cold_reads          # warm: nothing re-read
    assert again == first


def test_cached_equals_uncached_after_each_edit(fixtures):
    shared._HANDOFF_BLOCKERS_CACHE.clear()
    p = fixtures["undisposed-mixed"]
    shared.inception_handoff_blockers(p)      # warm the cache
    edits = [
        lambda t: t.replace("- Q-4 legacy\n", "- Q-4 legacy\n  disposition: answered\n  rationale: z\n"),
        lambda t: t.replace("**Recommendation:** GO", "**Recommendation:**"),
        lambda t: t.replace("workflow_type: inception", "workflow_type: build"),
        lambda t: t.replace("workflow_type: build", "workflow_type: inception") + "\n",
    ]
    st = p.stat()
    for i, edit in enumerate(edits):
        p.write_text(edit(p.read_text()))
        if i == 0:
            # same mtime, different size: the size half of the key must catch it
            os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
        cached = shared.inception_handoff_blockers(p)
        assert cached == _py(p) == _shell([p])[str(p)], i


def test_returned_lists_are_copies(fixtures):
    shared._HANDOFF_BLOCKERS_CACHE.clear()
    p = fixtures["no-rec-section"]
    a = shared.inception_handoff_blockers(p)
    a[0]["kind"] = "mutated"
    a.append({})
    assert shared.inception_handoff_blockers(p) == _py(p)


def test_transcription_digest_is_current():
    """Fails when the shell rule changes: update `_handoff_blockers_from_text`, re-run the
    parity tests above, then set `_HB_TRANSCRIBED_DIGEST` to the new value."""
    shared._HB_RULE_STATE.clear()
    state = shared._handoff_rule_state()
    assert state is not None and state[1] is True


def test_a_changed_shell_rule_falls_back_to_the_shell(fixtures, monkeypatch):
    monkeypatch.setattr(shared, "_HB_TRANSCRIBED_DIGEST", "0" * 64)
    shared._HB_RULE_STATE.clear()
    shared._HANDOFF_BLOCKERS_CACHE.clear()
    calls = []
    real = shared._handoff_blockers_via_shell
    monkeypatch.setattr(shared, "_handoff_blockers_via_shell",
                        lambda p: calls.append(p) or real(p))
    p = fixtures["undisposed-mixed"]
    assert shared.inception_handoff_blockers(p) == _shell([p])[str(p)]
    assert calls == [p]
    shared._HB_RULE_STATE.clear()
    shared._HANDOFF_BLOCKERS_CACHE.clear()


def test_missing_shell_rule_fails_closed(fixtures, monkeypatch, tmp_path):
    monkeypatch.setattr(shared, "FRAMEWORK_ROOT", tmp_path / "nowhere")
    shared._HANDOFF_BLOCKERS_CACHE.clear()
    out = shared.inception_handoff_blockers(fixtures["ready"])
    assert [b["kind"] for b in out] == ["check-failed"]
    assert fixtures["ready"].as_posix() not in shared._HANDOFF_BLOCKERS_CACHE
