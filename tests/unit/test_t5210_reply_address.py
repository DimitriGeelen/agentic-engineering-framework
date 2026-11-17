"""T-5210 (010 T-3815): a same-hub sub-agent sender keeps its sub-circuit in the reply address."""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib.sidecar import circuit, inbox  # noqa: E402

OWN = "cacc73ea32b121dd"
OTHER = "22c19fedafd73da2"


@pytest.fixture(autouse=True)
def own_hub(monkeypatch):
    monkeypatch.setattr(circuit, "hub_id", lambda: OWN)


def test_same_hub_sub_agent_keeps_its_circuit():
    msg = {"from": "1409-sprind", "from_circuit": f"{OWN}/1409-sprind/design"}
    assert inbox.reply_address(msg) == f"{OWN}/1409-sprind/design"


def test_same_hub_sub_agent_with_host_prefix_is_stripped():
    msg = {"from": "1409-sprind", "from_circuit": f"//dimitrimintdev/{OWN}/1409-sprind/design"}
    assert inbox.reply_address(msg) == f"{OWN}/1409-sprind/design"


def test_same_hub_project_sender_unchanged():
    msg = {"from": "832-Workflow-designer", "from_circuit": f"{OWN}/832-Workflow-designer"}
    assert inbox.reply_address(msg) == "832-Workflow-designer"


def test_other_hub_sender_unchanged():
    msg = {"from": "proxmox-ring20-management", "from_circuit": f"{OTHER}/proxmox-ring20-management"}
    assert inbox.reply_address(msg) == f"{OTHER}/proxmox-ring20-management"


def test_raw_post_has_no_address():
    assert inbox.reply_address({}) is None
