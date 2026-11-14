"""T-5136: the /search tag cloud parses episodic YAML with libyaml's C loader.

The cold tag cloud parses every episodic file (4,180 on 2026-11-14): 21.6 s in pure Python,
2.3 s with CSafeLoader, the same tags. That cold pass is the first /search after a restart.
"""
import sys
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from web import search_utils  # noqa: E402

EPISODIC = """\
task_id: T-9999
summary: |
  a block scalar, then a list
tags: [watchtower, perf, "quoted tag", 42]
metrics:
  git_mining: ok
"""


def test_tags_match_the_pure_python_parse(tmp_path):
    f = tmp_path / "T-9999.yaml"
    f.write_text(EPISODIC)
    want = [str(t) for t in yaml.safe_load(EPISODIC)["tags"]]
    assert search_utils._parse_tags_from_path(f) == want


def test_uses_the_c_loader_when_present(tmp_path, monkeypatch):
    if not getattr(yaml, "__with_libyaml__", False):
        pytest.skip("libyaml not built into this PyYAML")
    f = tmp_path / "T-9999.yaml"
    f.write_text(EPISODIC)
    seen = []
    real = yaml.load

    def spy(stream, Loader):
        seen.append(Loader)
        return real(stream, Loader=Loader)

    monkeypatch.setattr(yaml, "load", spy)
    search_utils._parse_tags_from_path(f)
    assert seen == [yaml.CSafeLoader]


def test_bad_yaml_still_gives_no_tags(tmp_path):
    f = tmp_path / "T-9998.yaml"
    f.write_text("tags: [unclosed\n")
    assert search_utils._parse_tags_from_path(f) == []
