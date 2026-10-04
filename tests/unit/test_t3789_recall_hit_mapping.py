"""T-3789: fw recall maps a vector hit to the learning it actually came from.

The old rule matched the FIRST item whose first three words (len > 3) appeared in the
snippet — L-001 "First learning" swallowed every hit on learnings.yaml. Pure tests:
no index, no Ollama.
"""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("memory_recall", ROOT / "agents/context/lib/memory-recall.py")
mr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mr)

ITEMS = [
    {"id": "L-001", "text": "First learning"},
    {"id": "L-690", "text": "OpenRouter key location: /root/.litellm-openrouter.env (root-owned EnvironmentFile created by T-2418 for the LiteLLM proxy; var OPENROUTER_API_KEY)."},
    {"id": "L-692", "text": "A framework cron job added only to AEF's own .context/cron-registry.yaml never reaches consumers: lib/cron-seed.sh seeds an explicit list."},
]


def test_hit_maps_to_its_own_learning_not_l001():
    hit = {"snippet": 'learning: "<b>OpenRouter</b> <b>key</b> <b>location</b>: /root/.litellm-<b>openrouter</b>.env (root-owned EnvironmentFile created by T-2418 for <b>the</b> LiteLLM proxy; var ...'}
    assert mr._match_hit_to_item(hit, ITEMS)["id"] == "L-690"


def test_a_generic_learning_word_does_not_match_l001():
    hit = {"snippet": "learning: A framework cron job added only to AEF's own .context/cron-registry.yaml never reaches consumers"}
    assert mr._match_hit_to_item(hit, ITEMS)["id"] == "L-692"


def test_unrelated_snippet_maps_to_nothing():
    hit = {"snippet": "learning: something about watchtower ports that no item here describes at all"}
    assert mr._match_hit_to_item(hit, ITEMS) is None


def test_pool_is_wide_enough_for_post_ranking_memory_filter():
    src = (ROOT / "agents/context/lib/memory-recall.py").read_text()
    assert "limit=max(80, limit * 16)" in src
