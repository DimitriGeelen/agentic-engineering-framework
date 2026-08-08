#!/usr/bin/env python3
"""aef:meta key census — T-2871.

T-2870 measured the corpus by hand (56 diagrams, 501 <aef:meta> elements, 652
attributes) and found only 8% of that surface uses the four keys the standard
freezes (aef-bpmn-mapping-v1 Part I §2: horizon, workflowType, tier, agentType).
The other 91% uses keys §2 explicitly says MAY change without a standard bump.
That measurement lived only in a report (docs/reports/T-2870-mapping-v1-rulings.md)
until this module — a report can't be re-run, this can.

Two separate things live here, and they answer different questions:

  census()            — how many attributes of each key appear ANYWHERE in the
                         corpus, frozen vs not. Answers "what's the exposure".
  DEPENDED_ON_KEYS     — which of those keys our OWN tooling actually READS and
                         branches on, with the consumer named by file:function.
                         Answers "what breaks, mechanically, if 832 renames it".

A key can appear 393 times (`note`) and be depended on by nothing (display-only
in corpus_explain.py) — appearing is not depending. DEPENDED_ON_KEYS is compiled
by grepping every `.get("meta")` / `_meta_attr` site under tools/, not asserted
from memory; see the `consumers` list on each entry.

Namespace note: the corpus mixes at least three distinct `aef:` namespace URIs
across its history (`http://anchorpoint.framework/aef/extensions`,
`http://agentic.dev/schema/aef`, `urn:aef:workflow-designer`). An exact-URI
findall undercounts (discovered here: 498/649 vs the true 501/652). Matched by
local name instead, same convention as bpmn_to_tasks.py's `_local`.
"""

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Frozen v1 governance meta-keys (aef-bpmn-mapping-v1 Part I §2, pinned T-2869).
FROZEN_KEYS = frozenset({"horizon", "workflowType", "tier", "agentType"})

# Keys our tooling reads from <aef:meta> and branches/asserts on. Restricted to
# keys with LIVE corpus occurrences (count > 0 in census()) — a consumer that
# reads a key nothing in the corpus currently sets is a dormant code path, not
# a corpus dependency. (corpus_lint.py:cross_map_typed_events also reads
# `seamPending`, but the corpus currently carries zero — noted, not listed:
# nothing would visibly break today if that rename happened, which is a
# different exposure than the two below.)
DEPENDED_ON_KEYS = {
    "state": {
        "frozen": False,
        "consumers": [
            "tools/corpus_conformance.py:asserted_transitions",
            "tools/corpus_conformance.py:carrier_count",
            "tools/corpus_overlay.py:carriers",
        ],
        "why": (
            "the aef-task-lifecycle state-carrier design (T-2624) rests on this "
            "key, and the T-2621 conformance rail audits transition parity "
            "THROUGH it — a silent rename leaves the rail green (SKIP: zero "
            "carriers) while the map means nothing"
        ),
    },
    "workflowType": {
        "frozen": True,
        "consumers": ["tools/bpmn_to_tasks.py:_is_inception_subprocess"],
        "why": (
            "the inception-marker signal that gates whether a collapsed "
            "subProcess compiles to workflow_type: inception at all"
        ),
    },
}


def _local(tag) -> str:
    return tag.rsplit("}", 1)[-1] if isinstance(tag, str) and "}" in tag else tag


def corpus_files(root: Path = REPO_ROOT) -> list[Path]:
    return sorted(root.glob(".context/designer/projects/**/*.bpmn")) + sorted(
        root.glob("tests/fixtures/**/*.bpmn")
    )


def census(root: Path = REPO_ROOT) -> dict:
    """Namespace-agnostic count of <aef:meta> elements/attributes across the
    corpus (designer store + test fixtures)."""
    files = corpus_files(root)
    key_counts: dict[str, int] = {}
    elements = 0
    diagrams_with_meta = 0
    for p in files:
        root_el = ET.parse(p).getroot()
        found_here = False
        for el in root_el.iter():
            if _local(el.tag) != "meta":
                continue
            elements += 1
            found_here = True
            for k in el.attrib:
                lk = _local(k)
                key_counts[lk] = key_counts.get(lk, 0) + 1
        if found_here:
            diagrams_with_meta += 1
    attributes = sum(key_counts.values())
    frozen = sum(v for k, v in key_counts.items() if k in FROZEN_KEYS)
    return {
        "files": len(files),
        "diagrams_with_meta": diagrams_with_meta,
        "elements": elements,
        "attributes": attributes,
        "frozen_attributes": frozen,
        "non_frozen_attributes": attributes - frozen,
        "key_counts": key_counts,
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="aef_meta_census", description=__doc__)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    c = census()
    if args.json:
        print(json.dumps(c, indent=2, sort_keys=True))
        return 0

    print(
        f"{c['files']} files, {c['diagrams_with_meta']} carry <aef:meta>, "
        f"{c['elements']} elements, {c['attributes']} attributes"
    )
    if c["attributes"]:
        print(
            f"frozen (v1 §2): {c['frozen_attributes']} "
            f"({c['frozen_attributes'] * 100 // c['attributes']}%)  "
            f"non-frozen: {c['non_frozen_attributes']} "
            f"({c['non_frozen_attributes'] * 100 // c['attributes']}%)"
        )
    for k, v in sorted(c["key_counts"].items(), key=lambda kv: -kv[1]):
        tag = "frozen v1" if k in FROZEN_KEYS else "not frozen"
        dep = "  [DEPENDED ON]" if k in DEPENDED_ON_KEYS else ""
        print(f"  {k:15s} {v:4d}  {tag}{dep}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
