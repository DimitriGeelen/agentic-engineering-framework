"""T-4522 — docgen parses the shared corpus once per run, not once per card.

`fw docs --all` called find_related_tasks / find_related_learnings for every
card, and each call re-parsed the last 200 episodic YAMLs and the whole
learnings.yaml. At 1602 cards that is ~40 min of CPU, which hung
tests/integration/fw_docs.bats to the 900 s cap on a clean machine.

The assertion counts parses, not seconds: a parse count does not move with host
load, a wall-clock bound does (L-542).
"""
import os
import sys

import yaml

DOCGEN_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "agents",
    "docgen",
)
sys.path.insert(0, DOCGEN_DIR)

import generate_component  # noqa: E402

N_CARDS = 6
N_EPISODES = 3


def _fixture(root):
    comp = os.path.join(root, ".fabric", "components")
    epi = os.path.join(root, ".context", "episodic")
    proj = os.path.join(root, ".context", "project")
    for d in (comp, epi, proj):
        os.makedirs(d)
    for i in range(N_CARDS):
        with open(os.path.join(comp, f"c{i}.yaml"), "w") as f:
            yaml.safe_dump({"id": f"C-{i}", "name": f"comp{i}", "location": f"lib/c{i}.sh",
                            "purpose": "p", "tags": ["t"]}, f)
    for i in range(N_EPISODES):
        with open(os.path.join(epi, f"T-{i}.yaml"), "w") as f:
            yaml.safe_dump({"task_id": f"T-{i}", "task_name": f"task {i}",
                            "artifacts": [f"lib/c{i}.sh"]}, f)
    with open(os.path.join(proj, "learnings.yaml"), "w") as f:
        yaml.safe_dump([{"id": "L-1", "description": "about comp1", "tags": ["t"]}], f)
    return comp


def test_all_cards_parse_episodic_and_learnings_once(tmp_path, monkeypatch):
    root = str(tmp_path / "fw")
    comp = _fixture(root)
    out = tmp_path / "out"
    out.mkdir()

    parsed = []
    real_load = yaml.safe_load

    def counting_load(stream):
        parsed.append(getattr(stream, "name", "<str>"))
        return real_load(stream)

    monkeypatch.setattr(generate_component.yaml, "safe_load", counting_load)
    generate_component._load_episodic.cache_clear()
    generate_component._load_learnings.cache_clear()

    index = generate_component.build_card_index(root)
    for name in sorted(os.listdir(comp)):
        assert generate_component.generate_doc(os.path.join(comp, name), root, str(out), index)

    episodic = [p for p in parsed if os.sep + "episodic" + os.sep in p]
    learnings = [p for p in parsed if p.endswith("learnings.yaml")]
    assert len(episodic) == N_EPISODES, f"episodic parsed {len(episodic)}x for {N_CARDS} cards"
    assert len(learnings) == 1, f"learnings.yaml parsed {len(learnings)}x for {N_CARDS} cards"

    # Caching must not change what each card links to.
    doc1 = (out / "c1.md").read_text()
    assert "T-1: task 1" in doc1
    assert "L-1: about comp1" in doc1
    assert "T-0: task 0" not in doc1
