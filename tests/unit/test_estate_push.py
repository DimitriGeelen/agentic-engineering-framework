"""T-4162: `fw estate push` — diff the local index against what was pushed, stage text+payload."""
from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

import estate_push as ep  # noqa: E402

PATTERNS = [("GitHub PAT", r"gh[pousr]_[A-Za-z0-9]{36,}"),
            ("SSH Private Key", r"-----BEGIN (RSA|DSA|EC|OPENSSH|PGP) PRIVATE KEY-----")]
# Built at run time so the scanned source never contains a literal secret shape.
GHP = "gh" + "p_" + "a" * 36


def make_db(tmp_path, rows):
    p = tmp_path / "idx.db"
    db = sqlite3.connect(p)
    db.execute("CREATE TABLE documents (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT, title TEXT,"
               " category TEXT, task_id TEXT DEFAULT '', chunk_index INTEGER DEFAULT 0, chunk_text TEXT)")
    db.execute("CREATE TABLE file_state (path TEXT PRIMARY KEY, content_hash TEXT, mtime REAL, updated_at REAL)")
    for path, cat, idx, text in rows:
        db.execute("INSERT INTO documents(path,title,category,task_id,chunk_index,chunk_text) VALUES (?,?,?,?,?,?)",
                   (path, "t", cat, "T-1", idx, text))
        db.execute("INSERT OR IGNORE INTO file_state VALUES (?,?,?,?)", (path, "h", 1.0, 1760000000.0))
    db.commit()
    db.close()
    return p


def plan(tmp_path, rows, ledger=None, **kw):
    db = make_db(tmp_path, rows)
    return ep.build_plan(db, ledger or {}, project="aef", patterns=PATTERNS, role_map={},
                         framework_version="1.8.10", **kw)


def test_only_pilot_categories(tmp_path):
    p = plan(tmp_path, [
        (".tasks/completed/T-1.md", "Completed Tasks", 0, "done"),
        (".tasks/active/T-2.md", "Active Tasks", 0, "wip"),
        (".context/handovers/H.md", "Handovers", 0, "ho"),
        (".context/episodic/T-1.yaml", "Episodic Memory", 0, "ep"),
    ])
    assert sorted(u["payload"]["category"] for u in p.upserts) == ["Completed Tasks", "Episodic Memory"]


def test_payload_fields_and_no_vectors(tmp_path):
    p = plan(tmp_path, [(".tasks/completed/T-1.md", "Completed Tasks", 3, "body")])
    pl = p.upserts[0]["payload"]
    for k in ("tenant", "project", "category", "item_type", "source_path", "task_id", "content_hash",
              "chunk_index", "observed_on", "framework_version", "chunk_key", "op", "text"):
        assert k in pl, k
    assert pl["tenant"] == "estate" and pl["project"] == "aef" and pl["op"] == "upsert"
    assert pl["chunk_index"] == 3 and pl["observed_on"].startswith("2025-")
    assert "vector" not in json.dumps(p.upserts[0]).lower().replace('"vector": {}', "")


def test_unchanged_not_restaged_changed_is_and_deleted_tombstoned(tmp_path):
    rows = [(".tasks/completed/T-1.md", "Completed Tasks", 0, "one"),
            (".tasks/completed/T-2.md", "Completed Tasks", 0, "two")]
    first = plan(tmp_path, rows)
    ledger = {u["payload"]["chunk_key"]: u["payload"]["content_hash"] for u in first.upserts}
    ledger["aef|.tasks/completed/T-gone.md|0"] = "oldhash"
    (tmp_path / "idx.db").unlink()
    second = plan(tmp_path, [rows[0], (".tasks/completed/T-2.md", "Completed Tasks", 0, "two CHANGED")], ledger)
    assert [u["payload"]["source_path"] for u in second.upserts] == [".tasks/completed/T-2.md"]
    assert [d["payload"]["chunk_key"] for d in second.deletes] == ["aef|.tasks/completed/T-gone.md|0"]
    assert second.deletes[0]["payload"]["op"] == "delete"


def test_secret_is_redacted_and_not_present(tmp_path):
    p = plan(tmp_path, [(".tasks/completed/T-1.md", "Completed Tasks", 0, f"token {GHP} end")])
    text = p.upserts[0]["payload"]["text"]
    assert GHP not in text and "[REDACTED:GitHub PAT]" in text
    assert ep.scan_items(p.upserts, PATTERNS) == []


def test_private_key_item_refused_and_logged_without_value(tmp_path):
    key = "-----BEGIN " + "RSA PRIVATE KEY-----\nMIIabc\n"
    p = plan(tmp_path, [(".tasks/completed/T-1.md", "Completed Tasks", 0, key)])
    assert p.upserts == []
    assert p.refused[0]["reason"] == "SSH Private Key"
    assert "MIIabc" not in json.dumps(p.refused)


def test_role_map_and_ip(tmp_path):
    db = make_db(tmp_path, [(".tasks/completed/T-1.md", "Completed Tasks", 0,
                             "host qdrant-estate.example.net at 10.1.2.3 and 10.9.9.9")])
    p = ep.build_plan(db, {}, project="aef", patterns=PATTERNS,
                      role_map={"qdrant-estate.example.net": "vector-store", "10.1.2.3": "vector-store"},
                      framework_version="1")
    t = p.upserts[0]["payload"]["text"]
    assert "qdrant-estate" not in t and "10.1.2.3" not in t and "10.9.9.9" not in t
    assert "[role:vector-store]" in t and "[ip]" in t


def test_size_gate(tmp_path):
    p = plan(tmp_path, [(".tasks/completed/T-1.md", "Completed Tasks", 0, "x" * 50000),
                        (".tasks/completed/blob.png", "Completed Tasks", 0, "x")])
    assert p.upserts == [] and {s["reason"] for s in p.skipped} == {"too-large", "type"}


def test_category_opt_in_override(tmp_path):
    p = plan(tmp_path, [(".tasks/completed/T-1.md", "Completed Tasks", 0, "a"),
                        (".context/episodic/T-1.yaml", "Episodic Memory", 0, "b")],
             categories={"Episodic Memory"})
    assert [u["payload"]["category"] for u in p.upserts] == ["Episodic Memory"]


def test_stage_batches_and_never_leaks_token(tmp_path):
    p = plan(tmp_path, [(".tasks/completed/T-%d.md" % i, "Completed Tasks", 0, "t%d" % i) for i in range(130)])
    calls = []

    def fake_put(url, token, body):
        calls.append((url, token, body))
        return 200

    n = ep.stage(p, "https://q.example", "SECRETTOKEN", "staging_aef", put=fake_put)
    assert n == 130 and len(calls) == 3 and all(len(c[2]["points"]) <= 64 for c in calls)
    assert calls[0][0] == "https://q.example/collections/staging_aef/points?wait=true"
    assert all(pt["vector"] == {} for c in calls for pt in c[2]["points"])
    assert "SECRETTOKEN" not in json.dumps([c[2] for c in calls])


def test_point_ids_are_deterministic(tmp_path):
    a = plan(tmp_path, [(".tasks/completed/T-1.md", "Completed Tasks", 0, "x")])
    (tmp_path / "idx.db").unlink()
    b = plan(tmp_path, [(".tasks/completed/T-1.md", "Completed Tasks", 0, "x")])
    assert a.upserts[0]["id"] == b.upserts[0]["id"]
