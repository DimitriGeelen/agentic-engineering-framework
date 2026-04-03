"""
Unit tests for web/blueprints/costs.py — token usage dashboard.

Tests: _fmt_tokens, _parse_session, _load_all_sessions, /costs route.

Run: pytest web/test_costs.py -v
"""

import json
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from web.blueprints.costs import _fmt_tokens, _parse_session, _load_all_sessions
from web.app import app


# ── Fixtures ────────────────────────────────────────────────────


@pytest.fixture
def client():
    """Flask test client with testing config."""
    app.config["TESTING"] = True
    app.config["SECRET_KEY"] = "test-secret-key"
    with app.test_client() as c:
        yield c


@pytest.fixture
def jsonl_dir(tmp_path):
    """Create a temp directory with a sample JSONL transcript."""
    session_file = tmp_path / "abc12345-test-session.jsonl"
    lines = [
        json.dumps({"type": "system", "timestamp": "2026-04-01T10:00:00Z",
                     "message": {"role": "system", "content": "init"}}),
        json.dumps({"type": "assistant", "timestamp": "2026-04-01T10:01:00Z",
                     "message": {"role": "assistant", "model": "claude-sonnet-4-20250514",
                                 "usage": {"input_tokens": 1000,
                                           "cache_read_input_tokens": 5000,
                                           "cache_creation_input_tokens": 200,
                                           "output_tokens": 300},
                                 "content": "response 1"}}),
        json.dumps({"type": "assistant", "timestamp": "2026-04-01T10:02:00Z",
                     "message": {"role": "assistant", "model": "claude-sonnet-4-20250514",
                                 "usage": {"input_tokens": 800,
                                           "cache_read_input_tokens": 4000,
                                           "cache_creation_input_tokens": 100,
                                           "output_tokens": 250},
                                 "content": "response 2"}}),
    ]
    session_file.write_text("\n".join(lines) + "\n")
    return tmp_path


# ── _fmt_tokens ────────────────────────────────────────────────


class TestFmtTokens:
    """Token formatting with K/M/B suffixes."""

    def test_small_number(self):
        assert _fmt_tokens(42) == "42"

    def test_zero(self):
        assert _fmt_tokens(0) == "0"

    def test_thousands(self):
        assert _fmt_tokens(1500) == "1.5K"

    def test_millions(self):
        assert _fmt_tokens(2_500_000) == "2.5M"

    def test_billions(self):
        assert _fmt_tokens(1_200_000_000) == "1.2B"

    def test_boundary_1000(self):
        assert _fmt_tokens(1000) == "1.0K"

    def test_boundary_1M(self):
        assert _fmt_tokens(1_000_000) == "1.0M"

    def test_boundary_1B(self):
        assert _fmt_tokens(1_000_000_000) == "1.0B"


# ── _parse_session ─────────────────────────────────────────────


class TestParseSession:
    """Parsing a single JSONL transcript file."""

    def test_basic_parsing(self, jsonl_dir):
        filepath = str(jsonl_dir / "abc12345-test-session.jsonl")
        stats = _parse_session(filepath)

        assert stats["turns"] == 2
        assert stats["input_tokens"] == 1800  # 1000 + 800
        assert stats["cache_read"] == 9000  # 5000 + 4000
        assert stats["cache_create"] == 300  # 200 + 100
        assert stats["output_tokens"] == 550  # 300 + 250
        assert stats["total"] == 1800 + 9000 + 300 + 550

    def test_session_id(self, jsonl_dir):
        filepath = str(jsonl_dir / "abc12345-test-session.jsonl")
        stats = _parse_session(filepath)
        assert stats["id"] == "abc12345"
        assert stats["id_full"] == "abc12345-test-session"

    def test_timestamps(self, jsonl_dir):
        filepath = str(jsonl_dir / "abc12345-test-session.jsonl")
        stats = _parse_session(filepath)
        assert stats["first_ts"] == "2026-04-01T10:00:00Z"
        assert stats["last_ts"] == "2026-04-01T10:02:00Z"

    def test_model_extraction(self, jsonl_dir):
        filepath = str(jsonl_dir / "abc12345-test-session.jsonl")
        stats = _parse_session(filepath)
        assert "claude-sonnet" in stats["model"]

    def test_malformed_json_skipped(self, tmp_path):
        filepath = tmp_path / "bad.jsonl"
        filepath.write_text("not json\n{also not}\n")
        stats = _parse_session(str(filepath))
        assert stats["turns"] == 0
        assert stats["total"] == 0

    def test_synthetic_model_skipped(self, tmp_path):
        filepath = tmp_path / "synth.jsonl"
        lines = [
            json.dumps({"type": "assistant", "timestamp": "2026-04-01T10:00:00Z",
                         "message": {"role": "assistant", "model": "<synthetic>",
                                     "usage": {"input_tokens": 999,
                                               "cache_read_input_tokens": 999,
                                               "cache_creation_input_tokens": 999,
                                               "output_tokens": 999},
                                     "content": "synthetic"}}),
            json.dumps({"type": "assistant", "timestamp": "2026-04-01T10:01:00Z",
                         "message": {"role": "assistant", "model": "claude-sonnet-4-20250514",
                                     "usage": {"input_tokens": 100,
                                               "cache_read_input_tokens": 0,
                                               "cache_creation_input_tokens": 0,
                                               "output_tokens": 50},
                                     "content": "real"}}),
        ]
        filepath.write_text("\n".join(lines) + "\n")
        stats = _parse_session(str(filepath))
        assert stats["turns"] == 1
        assert stats["input_tokens"] == 100

    def test_no_usage_entries_skipped(self, tmp_path):
        filepath = tmp_path / "nousage.jsonl"
        lines = [
            json.dumps({"type": "user", "timestamp": "2026-04-01T10:00:00Z",
                         "message": {"role": "user", "content": "hello"}}),
        ]
        filepath.write_text("\n".join(lines) + "\n")
        stats = _parse_session(str(filepath))
        assert stats["turns"] == 0


# ── _load_all_sessions ─────────────────────────────────────────


class TestLoadAllSessions:
    """Loading and aggregating JSONL transcripts."""

    def test_loads_sessions(self, jsonl_dir):
        with patch("web.blueprints.costs._jsonl_dir", return_value=jsonl_dir):
            sessions = _load_all_sessions()
        assert len(sessions) == 1
        assert sessions[0]["turns"] == 2

    def test_empty_dir(self, tmp_path):
        with patch("web.blueprints.costs._jsonl_dir", return_value=tmp_path):
            sessions = _load_all_sessions()
        assert sessions == []

    def test_nonexistent_dir(self, tmp_path):
        with patch("web.blueprints.costs._jsonl_dir", return_value=tmp_path / "nope"):
            sessions = _load_all_sessions()
        assert sessions == []

    def test_filters_agent_transcripts(self, jsonl_dir):
        # Create an agent transcript that should be filtered
        agent_file = jsonl_dir / "agent-task-abc.jsonl"
        agent_file.write_text(json.dumps({
            "type": "assistant", "timestamp": "2026-04-01T10:00:00Z",
            "message": {"role": "assistant", "model": "claude-sonnet-4-20250514",
                         "usage": {"input_tokens": 99999, "cache_read_input_tokens": 0,
                                   "cache_creation_input_tokens": 0, "output_tokens": 0},
                         "content": "agent"}
        }) + "\n")

        with patch("web.blueprints.costs._jsonl_dir", return_value=jsonl_dir):
            sessions = _load_all_sessions()
        assert len(sessions) == 1  # Agent file excluded

    def test_multiple_sessions(self, jsonl_dir):
        # Add a second session
        second = jsonl_dir / "def67890-second.jsonl"
        second.write_text(json.dumps({
            "type": "assistant", "timestamp": "2026-04-02T10:00:00Z",
            "message": {"role": "assistant", "model": "claude-sonnet-4-20250514",
                         "usage": {"input_tokens": 500, "cache_read_input_tokens": 0,
                                   "cache_creation_input_tokens": 0, "output_tokens": 100},
                         "content": "session 2"}
        }) + "\n")

        with patch("web.blueprints.costs._jsonl_dir", return_value=jsonl_dir):
            sessions = _load_all_sessions()
        assert len(sessions) == 2


# ── /costs route ───────────────────────────────────────────────


class TestCostsRoute:
    """Route rendering and response."""

    def test_costs_returns_200(self, client):
        resp = client.get("/costs")
        assert resp.status_code == 200

    def test_costs_contains_title(self, client):
        resp = client.get("/costs")
        html = resp.data.decode()
        assert "Token Usage" in html

    def test_costs_htmx_returns_fragment(self, client):
        resp = client.get("/costs", headers={"HX-Request": "true"})
        assert resp.status_code == 200
        html = resp.data.decode()
        assert "<!DOCTYPE" not in html

    def test_costs_with_no_sessions(self, client, tmp_path):
        empty = tmp_path / "empty"
        empty.mkdir()
        with patch("web.blueprints.costs._jsonl_dir", return_value=empty):
            resp = client.get("/costs")
        assert resp.status_code == 200
