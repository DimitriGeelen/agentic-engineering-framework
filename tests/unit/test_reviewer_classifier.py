"""Unit tests for lib/reviewer/classifier.py (T-1483 v1.5)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer.classifier import Category, classify, classify_block, worst_case  # noqa: E402


def test_read_only_test_command():
    assert classify("test -f bin/fw") == Category.READ_ONLY


def test_read_only_grep():
    assert classify("grep -q 'expected' file.md") == Category.READ_ONLY


def test_read_only_python_yaml_parse():
    assert classify("python3 -c \"import yaml; yaml.safe_load(open('a.yaml'))\"") == Category.READ_ONLY


def test_read_only_bash_n():
    assert classify("bash -n agents/foo/foo.sh") == Category.READ_ONLY


def test_read_only_pytest():
    assert classify("python3 -m pytest tests/unit/ -q") == Category.READ_ONLY


def test_read_only_git_log():
    assert classify("git log --oneline -5") == Category.READ_ONLY


def test_state_touching_fw_audit():
    assert classify("bin/fw audit") == Category.STATE_TOUCHING


def test_state_touching_redirect():
    assert classify("echo hi > /tmp/foo") == Category.STATE_TOUCHING


def test_state_touching_git_commit():
    assert classify("git commit -m 'msg'") == Category.STATE_TOUCHING


def test_state_touching_mkdir():
    assert classify("mkdir /tmp/work") == Category.STATE_TOUCHING


def test_state_touching_rm():
    assert classify("rm -f stale.lock") == Category.STATE_TOUCHING


def test_network_curl():
    assert classify("curl -sf http://localhost:3000/") == Category.NETWORK_DEPENDENT


def test_network_https_url():
    assert classify("python3 fetch.py 'https://example.com/x'") == Category.NETWORK_DEPENDENT


def test_network_wins_over_state():
    # curl + redirect: network is more restrictive
    assert classify("curl -sf url > out") == Category.NETWORK_DEPENDENT


def test_time_dependent_date():
    assert classify("FOO=$(date +%s)") == Category.TIME_DEPENDENT


def test_time_dependent_sleep():
    assert classify("sleep 5") == Category.TIME_DEPENDENT


def test_unclassified_arbitrary():
    assert classify("./scripts/some-novel-thing.sh") == Category.UNCLASSIFIED


def test_comment_line_treated_as_read_only():
    # comments are no-ops
    assert classify("# this is a comment") == Category.READ_ONLY


def test_empty_line_treated_as_read_only():
    assert classify("") == Category.READ_ONLY
    assert classify("   ") == Category.READ_ONLY


def test_classify_block_groups_by_category():
    text = """test -f a.txt
curl http://x
bin/fw audit
sleep 1"""
    out = classify_block(text)
    assert any("test -f" in l for l in out[Category.READ_ONLY])
    assert any("curl" in l for l in out[Category.NETWORK_DEPENDENT])
    assert any("audit" in l for l in out[Category.STATE_TOUCHING])
    assert any("sleep" in l for l in out[Category.TIME_DEPENDENT])


def test_classify_block_skips_comments():
    text = """# comment
test -f a.txt"""
    out = classify_block(text)
    assert len(out[Category.READ_ONLY]) == 1
    assert "test -f" in out[Category.READ_ONLY][0]


def test_worst_case_picks_network():
    text = """test -f a.txt
curl http://x"""
    assert worst_case(text) == Category.NETWORK_DEPENDENT


def test_worst_case_picks_state_over_read_only():
    text = """test -f a.txt
bin/fw audit"""
    assert worst_case(text) == Category.STATE_TOUCHING


def test_worst_case_pure_read_only():
    text = """test -f a.txt
grep foo bar.txt"""
    assert worst_case(text) == Category.READ_ONLY


def test_worst_case_empty():
    assert worst_case("") == Category.READ_ONLY
