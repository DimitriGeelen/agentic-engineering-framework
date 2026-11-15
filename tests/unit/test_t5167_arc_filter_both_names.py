"""T-5167: /tasks?arc= matches an arc named by id or by slug.

The landing cards link /tasks?arc=arc-NNN while most tasks record the slug in `arc_id:`, so the
filter returned nothing. arc_identities() maps either form to both.
"""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.arc_membership import arc_identities, task_dict_in_arc  # noqa: E402


@pytest.fixture()
def project(tmp_path):
    arcs = tmp_path / ".context" / "arcs"
    arcs.mkdir(parents=True)
    (arcs / "arc-grooming.yaml").write_text('id: arc-005\nslug: arc-grooming\nname: "Grooming"\n')
    (arcs / "arc-020.yaml").write_text("id: arc-020\nslug: arc-020\n")
    return tmp_path


TASKS = [
    {"id": "T-1", "arc_id": "arc-grooming"},           # by slug
    {"id": "T-2", "arc_id": "arc-005"},                # by id
    {"id": "T-3", "_tags": ["arc:arc-grooming"]},      # legacy tag
    {"id": "T-4", "arc_id": "arc-020"},                # another arc
    {"id": "T-5"},                                     # none
]


def _filter(project, name):
    slug, num = arc_identities(project, name)
    return [t["id"] for t in TASKS if task_dict_in_arc(t, slug, num)]


def test_identities_either_way(project):
    assert arc_identities(project, "arc-005") == ("arc-grooming", "arc-005")
    assert arc_identities(project, "arc-grooming") == ("arc-grooming", "arc-005")
    assert arc_identities(project, "ARC-005") == ("arc-grooming", "arc-005")


def test_id_and_slug_list_the_same_tasks(project):
    assert _filter(project, "arc-005") == _filter(project, "arc-grooming") == ["T-1", "T-2", "T-3"]


def test_other_arc_unaffected(project):
    assert _filter(project, "arc-020") == ["T-4"]


def test_unknown_name_lists_nothing(project):
    assert arc_identities(project, "no-such-arc") == ("no-such-arc", None)
    assert _filter(project, "no-such-arc") == []


def test_no_arcs_dir(tmp_path):
    assert arc_identities(tmp_path, "arc-005") == ("arc-005", None)
