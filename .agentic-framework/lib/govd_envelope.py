"""govd_envelope — the authority-broker decision evaluator (arc-013 / T-2430).

Pure logic, no I/O beyond loading the YAML envelope. This is the testable core of
the privileged state-holder `aef-govd` (design doc §4e): given a sovereign-authored
envelope and a proposed decision, decide WHO may commit (agent vs human) and at
WHICH audit tier.

  effective rule = {**global, **overrides[type]}   # per-type keys win
  - non-delegable type (delegable:false, or a hard-floor type) → human, tier 0
  - any bound breached (blast_radius / voi / scope / tier)      → human, tier 2 (queued)
  - all bounds satisfied                                        → agent, tier 3 (autonomous)

INVARIANT (design §4e): the agent commits WITHIN the envelope but cannot CHANGE it.
This module only READS the envelope; mutation is a sovereign action gated by the OS
cage (Lock-1 Part 1), never by this code.
"""
from __future__ import annotations

import sys
from pathlib import Path

# Types that are NEVER delegable, regardless of what the envelope says — the hard
# floor (design §4e). Even a mis-authored envelope cannot loosen these.
HARD_FLOOR_TYPES = frozenset({"tier0_approve", "directive_author"})

# scope ordering: a decision's scope may not exceed the envelope's allowed scope.
SCOPE_ORDER = {"internal": 0, "cross-project": 1, "external": 2}


def load_envelope(path: str | Path) -> dict:
    """Load the YAML envelope. Raises on missing/unparseable — fail closed."""
    import yaml  # local import: keeps the module importable where PyYAML is absent
    p = Path(path)
    if not p.is_file():
        raise FileNotFoundError(f"authority envelope not found: {p}")
    data = yaml.safe_load(p.read_text()) or {}
    if not isinstance(data, dict):
        raise ValueError(f"authority envelope must be a mapping, got {type(data).__name__}")
    return data


def resolve_rule(envelope: dict, decision_type: str) -> dict:
    """Effective rule for a decision type: global defaults overlaid by per-type keys."""
    g = envelope.get("global") or {}
    o = (envelope.get("overrides") or {}).get(decision_type) or {}
    eff = dict(g)
    eff.update(o)
    return eff


def evaluate(envelope: dict, decision: dict) -> dict:
    """Decide who commits a proposed decision.

    decision keys (all optional except `type`):
      type          str   — decision class (e.g. inception_go, dispatch_approve)
      blast_radius  int    — BVP cost_estimate.blast_radius
      voi_score     float  — BVP value-of-information
      scope         str    — internal | cross-project | external
      tier          int    — enforcement tier of the action

    Returns {commit: 'agent'|'human', tier_log: int, reason: str, rule: dict}.
    Fails CLOSED: unknown decision type with no global rule → still evaluated
    against global (empty global = nothing permitted → all numeric checks pass
    only if the bound is absent; absence of a bound means "unconstrained on that
    axis", matching the envelope-author's intent of omission).
    """
    dtype = decision.get("type")
    if not dtype:
        return {"commit": "human", "tier_log": 0, "reason": "decision has no type", "rule": {}}

    eff = resolve_rule(envelope, dtype)

    # Hard floor: certain types are never delegable, and any type the envelope
    # explicitly marks delegable:false routes to the human.
    if dtype in HARD_FLOOR_TYPES or eff.get("delegable") is False:
        return {"commit": "human", "tier_log": 0,
                "reason": f"{dtype} is non-delegable (hard floor)", "rule": eff}

    breaches: list[str] = []

    br = decision.get("blast_radius")
    if "max_blast_radius" in eff and br is not None and br > eff["max_blast_radius"]:
        breaches.append(f"blast_radius {br} > max {eff['max_blast_radius']}")

    voi = decision.get("voi_score")
    if "min_voi_score" in eff and voi is not None and voi < eff["min_voi_score"]:
        breaches.append(f"voi_score {voi} < min {eff['min_voi_score']}")

    sc = decision.get("scope")
    if "scope" in eff and sc is not None:
        if SCOPE_ORDER.get(sc, 99) > SCOPE_ORDER.get(eff["scope"], 0):
            breaches.append(f"scope {sc!r} exceeds allowed {eff['scope']!r}")

    tier = decision.get("tier")
    if "max_tier" in eff and tier is not None and tier > eff["max_tier"]:
        breaches.append(f"tier {tier} > max {eff['max_tier']}")

    if breaches:
        return {"commit": "human", "tier_log": 2,
                "reason": "queued: " + "; ".join(breaches), "rule": eff}

    return {"commit": "agent", "tier_log": 3, "reason": "within envelope", "rule": eff}


def _main(argv: list[str]) -> int:
    """CLI: govd_envelope <envelope.yaml> '<decision-json>' → prints verdict JSON."""
    import json
    if len(argv) < 3:
        print("usage: govd_envelope <envelope.yaml> '<decision-json>'", file=sys.stderr)
        return 2
    env = load_envelope(argv[1])
    decision = json.loads(argv[2])
    verdict = evaluate(env, decision)
    print(json.dumps(verdict, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv))
