"""Regression: _load_subsystems must normalize list-of-dict entries (T-1318).

Source: termlink T-1129 pickup (P-036) → T-1314 inception → T-1318 build.

Pre-fix bug: when subsystems.yaml entries used `name:` as the identifier
(no `id:`), `web/blueprints/fabric.py:93` crashed with KeyError on `id` and
the `/fabric` page returned HTTP 500.

Post-fix invariant: `_load_subsystems` returns entries that always have
an `id` key — derived from `name` when `id` is absent.
"""

import importlib
import sys
from pathlib import Path

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))


def _reimport_fabric(project_root: Path, monkeypatch):
    """Force a re-import of web.blueprints.fabric so FABRIC_DIR picks up the
    project_root the test just set up. importlib.reload is required because
    the parent package (web.blueprints) caches the child module attribute."""
    monkeypatch.setenv("PROJECT_ROOT", str(project_root))
    # Drop the dependency chain so each module re-executes against fresh env.
    for mod in ("web.blueprints.fabric", "web.shared", "web.config"):
        sys.modules.pop(mod, None)
    import web.shared  # re-imports with fresh PROJECT_ROOT  # noqa: E402,F401
    importlib.import_module("web.blueprints.fabric")
    f = importlib.reload(sys.modules["web.blueprints.fabric"])
    return f


def _prepare(tmp_path: Path) -> Path:
    (tmp_path / ".fabric").mkdir(parents=True)
    (tmp_path / ".fabric" / "components").mkdir()
    return tmp_path


def test_list_of_dicts_with_only_name_is_normalized(tmp_path, monkeypatch):
    """The bug: entries with only `name:` (no `id:`) used to crash callers."""
    project = _prepare(tmp_path)
    (project / ".fabric" / "subsystems.yaml").write_text(
        "subsystems:\n"
        "  - name: protocol\n"
        "    purpose: Wire protocol\n"
        "  - name: storage\n"
        "    purpose: Persistence\n"
    )
    f = _reimport_fabric(project, monkeypatch)
    subs = f._load_subsystems()
    assert len(subs) == 2
    # Every entry has an `id` derived from `name`.
    assert {s["id"] for s in subs} == {"protocol", "storage"}
    # The original `name` is preserved.
    assert {s["name"] for s in subs} == {"protocol", "storage"}


def test_list_of_dicts_with_id_is_unchanged(tmp_path, monkeypatch):
    """Idempotency: entries that already have `id:` must not be rewritten."""
    project = _prepare(tmp_path)
    (project / ".fabric" / "subsystems.yaml").write_text(
        "subsystems:\n"
        "  - id: protocol\n"
        "    name: Wire Protocol\n"
        "  - id: storage\n"
        "    name: Persistence Layer\n"
    )
    f = _reimport_fabric(project, monkeypatch)
    subs = f._load_subsystems()
    assert {s["id"] for s in subs} == {"protocol", "storage"}
    # Names are NOT overwritten by the normalization.
    assert {s["name"] for s in subs} == {"Wire Protocol", "Persistence Layer"}


def test_list_of_dicts_mixed_id_and_name(tmp_path, monkeypatch):
    """One entry has `id`, another only `name` — both must end up with `id`."""
    project = _prepare(tmp_path)
    (project / ".fabric" / "subsystems.yaml").write_text(
        "subsystems:\n"
        "  - id: protocol\n"
        "    name: Wire Protocol\n"
        "  - name: storage\n"
    )
    f = _reimport_fabric(project, monkeypatch)
    subs = f._load_subsystems()
    assert {s["id"] for s in subs} == {"protocol", "storage"}


def test_dict_of_dicts_branch_unchanged(tmp_path, monkeypatch):
    """The dict-of-dicts branch already produced normalized output —
    must remain unchanged after this fix."""
    project = _prepare(tmp_path)
    (project / ".fabric" / "subsystems.yaml").write_text(
        "subsystems:\n"
        "  protocol:\n"
        "    name: Wire Protocol\n"
        "  storage:\n"
        "    name: Persistence Layer\n"
    )
    f = _reimport_fabric(project, monkeypatch)
    subs = f._load_subsystems()
    assert {s["id"] for s in subs} == {"protocol", "storage"}


def test_garbage_entries_dropped(tmp_path, monkeypatch):
    """Entries that are neither id-bearing nor name-bearing must be filtered
    out (defensive — keeps the use site safe even on malformed YAML)."""
    project = _prepare(tmp_path)
    (project / ".fabric" / "subsystems.yaml").write_text(
        "subsystems:\n"
        "  - name: protocol\n"
        "  - purpose: orphan with no id and no name\n"
        "  - 'just a string'\n"
    )
    f = _reimport_fabric(project, monkeypatch)
    subs = f._load_subsystems()
    # Only `protocol` survives.
    assert len(subs) == 1
    assert subs[0]["id"] == "protocol"


def test_missing_subsystems_file_returns_empty(tmp_path, monkeypatch):
    """No file → empty list (existing contract)."""
    project = _prepare(tmp_path)
    f = _reimport_fabric(project, monkeypatch)
    subs = f._load_subsystems()
    assert subs == []
