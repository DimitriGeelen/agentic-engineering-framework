"""T-4162: `fw estate push` — diff the local index against what was pushed, stage text+payload."""
from __future__ import annotations

import base64
import json
import os
import shutil
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
    assert p.refused[0]["reason"] == "private-key"
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


# --- T-4162 batched first fill: cap, continuation, budget headroom, unreadable count -----------

class FakeStore:
    """Stands in for staging: `stage` adds points, `count` reads them back."""

    def __init__(self, staged=0, readable=True):
        self.staged = staged
        self.readable = readable
        self.stage_calls = []

    def count(self, url, token, collection):
        if not self.readable:
            raise OSError("connection refused")
        return self.staged

    def stage(self, plan, url, token, collection):
        self.stage_calls.append(len(plan.upserts) + len(plan.deletes))
        self.staged += len(plan.upserts) + len(plan.deletes)
        return len(plan.upserts) + len(plan.deletes)


def project(tmp_path, n_rows):
    root = tmp_path / "proj"
    (root / ".context/working").mkdir(parents=True)
    make_db(tmp_path, [(".tasks/completed/T-%d.md" % i, "Completed Tasks", 0, "t%d" % i) for i in range(n_rows)])
    (tmp_path / "idx.db").rename(root / ".context/working/fw-vec-index.db")
    shutil.copy(ROOT / ".secret-scan-patterns", root / ".secret-scan-patterns")
    return root


def run_main(monkeypatch, root, store, *extra):
    monkeypatch.setattr(ep, "_token", lambda: "TOK")
    monkeypatch.setattr(ep, "_count", store.count)
    monkeypatch.setattr(ep, "stage", store.stage)
    return ep.main(["--apply", "--project-root", str(root), *extra])


def ledger_of(root):
    return json.loads((root / ".context/working/estate-push-state.json").read_text())


def test_cap_limits_one_run(tmp_path, monkeypatch, capsys):
    root = project(tmp_path, 130)
    store = FakeStore()
    assert run_main(monkeypatch, root, store, "--max-points", "50") == 0
    assert store.stage_calls == [50]
    assert len(ledger_of(root)) == 50
    assert "this run stages 50" in capsys.readouterr().out


def test_continuation_across_runs_stages_everything_once(tmp_path, monkeypatch):
    root = project(tmp_path, 130)
    store = FakeStore()
    for _ in range(3):
        run_main(monkeypatch, root, store, "--max-points", "50")
    assert store.stage_calls == [50, 50, 30]
    assert len(ledger_of(root)) == 130
    run_main(monkeypatch, root, store, "--max-points", "50")
    assert store.stage_calls == [50, 50, 30]  # nothing left: a finished fill stages nothing more


def test_budget_headroom_bounds_the_batch(tmp_path, monkeypatch):
    monkeypatch.setattr(ep, "STAGING_BUDGET", 60)
    root = project(tmp_path, 130)
    store = FakeStore(staged=40)
    run_main(monkeypatch, root, store, "--max-points", "50")
    assert store.stage_calls == [20]  # headroom 60-40 is tighter than the cap of 50
    assert store.staged == 60


def test_full_budget_stages_nothing_and_says_so(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(ep, "STAGING_BUDGET", 60)
    root = project(tmp_path, 10)
    store = FakeStore(staged=60)
    assert run_main(monkeypatch, root, store) == 0
    assert store.stage_calls == []
    assert "staging budget full" in capsys.readouterr().out
    assert not (root / ".context/working/estate-push-state.json").exists()


def test_unreadable_count_stages_nothing(tmp_path, monkeypatch, capsys):
    root = project(tmp_path, 10)
    store = FakeStore(readable=False)
    assert run_main(monkeypatch, root, store) == 1
    assert store.stage_calls == []
    out = capsys.readouterr().out
    assert "connection refused" in out and "staging nothing" in out
    assert not (root / ".context/working/estate-push-state.json").exists()


def test_dry_run_reports_batch_and_runs_left_without_writing(tmp_path, monkeypatch, capsys):
    root = project(tmp_path, 130)
    store = FakeStore()
    monkeypatch.setattr(ep, "_token", lambda: "TOK")
    monkeypatch.setattr(ep, "_count", store.count)
    monkeypatch.setattr(ep, "stage", store.stage)
    assert ep.main(["--project-root", str(root), "--max-points", "50"]) == 0
    out = capsys.readouterr().out
    assert "130 to stage in total" in out and "this run stages 50" in out and "2 run(s) remain" in out
    assert store.stage_calls == []


def test_max_points_from_env(tmp_path, monkeypatch):
    root = project(tmp_path, 130)
    store = FakeStore()
    monkeypatch.setenv("FW_ESTATE_PUSH_MAX_POINTS", "40")
    run_main(monkeypatch, root, store)
    assert store.stage_calls == [40]


def test_non_positive_cap_is_refused(tmp_path, monkeypatch):
    root = project(tmp_path, 3)
    store = FakeStore()
    try:
        run_main(monkeypatch, root, store, "--max-points", "0")
        raise AssertionError("expected SystemExit")
    except SystemExit as e:
        assert "positive" in str(e)
    assert store.stage_calls == []


def test_tombstones_count_towards_the_cap():
    plan = ep.Plan(upserts=[{"payload": {"op": "upsert", "chunk_key": "u%d" % i}} for i in range(2)],
                   deletes=[{"payload": {"op": "delete", "chunk_key": "d%d" % i}} for i in range(5)])
    batch, remaining = ep.select_batch(plan, 4)
    assert [u["payload"]["chunk_key"] for u in batch.upserts] == ["u0", "u1"]
    assert [d["payload"]["chunk_key"] for d in batch.deletes] == ["d0", "d1"]
    assert remaining == 3


# --- token delivery: Infisical by name at run time (operator 2026-10-13, option 1) ---

def _creds(tmp_path, monkeypatch, **over):
    ua = {"client_id": "cid", "client_secret": "csec", "url": "https://inf.example", "project_id": "pid",
          "secret_path": "/"}
    ua.update(over)
    f = tmp_path / "creds.yaml"
    import yaml
    f.write_text(yaml.safe_dump({"credentials": {"infisical_ua": ua}}))
    monkeypatch.setenv("FW_ESTATE_CREDS_FILE", str(f))


def _no_local_token(monkeypatch, var="FW_QDRANT_ESTATE_STAGING_AEF_API_KEY"):
    monkeypatch.delenv(var, raising=False)
    sys.path.insert(0, str(ROOT))
    import web.secrets_store as ss
    monkeypatch.setattr(ss, "get_api_key", lambda name: None)


def _fake_http(monkeypatch, calls, value="tok-from-infisical"):
    def http(method, url, body=None, headers=None):
        calls.append((method, url, body, headers))
        if url.endswith("/api/v1/auth/universal-auth/login"):
            assert body == {"clientId": "cid", "clientSecret": "csec"}
            return {"accessToken": "acc"}
        assert headers == {"Authorization": "Bearer acc"}
        return {"secret": {"secretValue": value}}
    monkeypatch.setattr(ep, "_http_json", http)


def test_token_read_from_infisical_by_name_and_never_printed(tmp_path, monkeypatch, capsys):
    _no_local_token(monkeypatch)
    _creds(tmp_path, monkeypatch)
    calls = []
    _fake_http(monkeypatch, calls)
    assert ep._token() == "tok-from-infisical"
    read = calls[1][1]
    assert "/api/v3/secrets/raw/QDRANT_ESTATE_TOKEN_STAGING_AEF?" in read
    assert "workspaceId=pid" in read and "environment=prod" in read
    out = capsys.readouterr()
    assert "tok-from-infisical" not in out.out + out.err


def test_env_token_wins_over_infisical(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_QDRANT_ESTATE_STAGING_AEF_API_KEY", "env-tok")
    monkeypatch.setattr(ep, "_http_json", lambda *a, **k: (_ for _ in ()).throw(AssertionError("no network")))
    assert ep._token() == "env-tok"


def test_infisical_http_error_refuses_with_status_only(tmp_path, monkeypatch):
    import io
    import urllib.error
    import pytest
    _no_local_token(monkeypatch)
    _creds(tmp_path, monkeypatch)

    def http(method, url, body=None, headers=None):
        if "login" in url:
            return {"accessToken": "acc"}
        raise urllib.error.HTTPError(url, 404, "nf", {}, io.BytesIO(b'{"message": "Secret not found"}'))
    monkeypatch.setattr(ep, "_http_json", http)
    with pytest.raises(SystemExit) as e:
        ep._token()
    assert "QDRANT_ESTATE_TOKEN_STAGING_AEF" in str(e.value)
    assert "read HTTP 404: Secret not found" in str(e.value)
    assert "csec" not in str(e.value) and "acc" not in str(e.value).replace("access", "")


def test_missing_credential_file_is_a_named_miss(tmp_path, monkeypatch):
    import pytest
    _no_local_token(monkeypatch)
    monkeypatch.setenv("FW_ESTATE_CREDS_FILE", str(tmp_path / "absent.yaml"))
    with pytest.raises(SystemExit) as e:
        ep._token()
    assert "credential file not found" in str(e.value)


def test_incomplete_ua_settings_name_the_missing_keys(tmp_path, monkeypatch):
    import pytest
    _no_local_token(monkeypatch)
    _creds(tmp_path, monkeypatch, client_secret="")
    with pytest.raises(SystemExit) as e:
        ep._token()
    assert "infisical_ua.client_secret" in str(e.value)


def test_project_and_folder_overrides(tmp_path, monkeypatch):
    _no_local_token(monkeypatch)
    _creds(tmp_path, monkeypatch)
    monkeypatch.setenv("FW_ESTATE_INFISICAL_PROJECT_ID", "ring20proj")
    monkeypatch.setenv("FW_ESTATE_INFISICAL_PATH", "/estate")
    calls = []
    _fake_http(monkeypatch, calls)
    ep._token()
    assert "workspaceId=ring20proj" in calls[1][1] and "secretPath=%2Festate" in calls[1][1]


# --- T-4286: private keys refused by the match itself; whole blocks redacted; catalogue fails closed ---

import pytest  # noqa: E402

KEY_TYPES = ["OPENSSH ", "RSA ", "EC ", "DSA ", "ENCRYPTED ", ""]  # "" = plain PKCS8
RENAMED = [("private-key-header", r"-----BEGIN (RSA|OPENSSH) PRIVATE KEY-----"),
           ("GitHub PAT", r"gh[pousr]_[A-Za-z0-9]{36,}")]


def fake_key(kind):
    """Clearly fake key material: random bytes, base64-wrapped, built at run time (no literal key)."""
    body = [base64.b64encode(os.urandom(48)).decode() for _ in range(4)]
    dash = "-" * 5
    text = "\n".join([f"{dash}BEGIN {kind}PRIVATE KEY{dash}", *body, f"{dash}END {kind}PRIVATE KEY{dash}"])
    return text, body


def framework_catalogue():
    return ep.load_patterns(ROOT / ".secret-scan-patterns")


@pytest.mark.parametrize("kind", KEY_TYPES)
@pytest.mark.parametrize("catalogue", ["framework", "renamed"])
def test_t4286_any_private_key_refused_whatever_the_catalogue_calls_it(tmp_path, kind, catalogue):
    pats = framework_catalogue() if catalogue == "framework" else RENAMED
    key, body = fake_key(kind)
    db = make_db(tmp_path, [(".tasks/completed/T-1.md", "Completed Tasks", 0, f"notes\n{key}\nafter")])
    p = ep.build_plan(db, {}, project="aef", patterns=pats, role_map={}, framework_version="x")
    assert p.upserts == [] and [r["reason"] for r in p.refused] == ["private-key"]
    dumped = json.dumps(p.__dict__)
    assert not any(line in dumped for line in body)


@pytest.mark.parametrize("kind", KEY_TYPES)
@pytest.mark.parametrize("catalogue", ["framework", "renamed"])
def test_t4286_redact_removes_the_whole_block(kind, catalogue):
    pats = framework_catalogue() if catalogue == "framework" else RENAMED
    key, body = fake_key(kind)
    clean, fired = ep.redact(f"before\n{key}\nafter", pats, {})
    assert not any(line in clean for line in body)
    assert "PRIVATE KEY" not in clean and "before" in clean and "after" in clean
    assert "private-key" in fired


def test_t4286_unterminated_block_redacted_to_end():
    key, body = fake_key("RSA ")
    truncated = key.rsplit("\n", 1)[0]  # END line lost (e.g. chunk boundary)
    clean, _ = ep.redact(f"x\n{truncated}", RENAMED, {})
    assert not any(line in clean for line in body)


def test_t4286_final_gate_flags_a_surviving_key_with_no_catalogue_entry():
    key, _ = fake_key("EC ")
    bad = ep.scan_items([{"payload": {"text": key, "chunk_key": "k"}}], [("GitHub PAT", r"ghp_x")])
    assert [b["reason"] for b in bad] == ["private-key"]


def test_t4286_main_never_prints_or_stages_a_key_body(tmp_path, monkeypatch, capsys):
    root = project(tmp_path, 1)
    (root / ".secret-scan-patterns").write_text("private-key-header\t-----BEGIN RSA PRIVATE KEY-----\n")
    key, body = fake_key("OPENSSH ")
    db = sqlite3.connect(root / ".context/working/fw-vec-index.db")
    db.execute("UPDATE documents SET chunk_text=?", (key,))
    db.commit()
    db.close()
    store = FakeStore()
    staged = []
    monkeypatch.setattr(ep, "_token", lambda: "TOK")
    monkeypatch.setattr(ep, "_count", store.count)
    monkeypatch.setattr(ep, "stage", lambda plan, *a: staged.append(plan) or 0)
    ep.main(["--apply", "--project-root", str(root)])
    out = capsys.readouterr()
    written = "".join(p.read_text() for p in (root / ".context/working").glob("estate-push-*"))
    everything = out.out + out.err + written + json.dumps([p.__dict__ for p in staged])
    assert not any(line in everything for line in body)
    assert "1 refused" in out.out


@pytest.mark.parametrize("content,needle", [
    (None, "not found"),
    ("# only comments\n\n", "no patterns"),
    ("good\tabc\nbroken-one\t(unclosed\n", "broken-one"),
])
def test_t4286_missing_empty_or_broken_catalogue_refused(tmp_path, content, needle):
    path = tmp_path / ".secret-scan-patterns"
    if content is not None:
        path.write_text(content)
    with pytest.raises(ep.CatalogueError) as e:
        ep.load_patterns(path)
    assert needle in str(e.value) and str(path) in str(e.value)


@pytest.mark.parametrize("content", [None, "", "x\t(unclosed\n"])
def test_t4286_push_refuses_and_stages_nothing_on_bad_catalogue(tmp_path, monkeypatch, content):
    root = project(tmp_path, 3)
    cat = root / ".secret-scan-patterns"
    cat.unlink()
    if content is not None:
        cat.write_text(content)
    store = FakeStore()
    with pytest.raises(SystemExit) as e:
        run_main(monkeypatch, root, store)
    assert "REFUSED" in str(e.value) and str(cat) in str(e.value)
    assert store.stage_calls == []
    assert not (root / ".context/working/estate-push-state.json").exists()
