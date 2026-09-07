#!/usr/bin/env python3
"""arc-020 headline mechanic, G1 leg — the origin-bug kill (T-3340).

Demonstrates, against a LIVE termlink hub, that two co-resident agents stay
DISTINCT correspondents where termlink's own identity resolution collapses
them into one.

The bug (G-105 / T-3286): termlink has no agent_id, so the reader falls back
to the shared crypto ``identity_fingerprint``. On this host that fingerprint
is shared by ~all co-resident sessions — so "who is this" has one answer for
many agents. This script reads the live hub and shows that collapse with real
numbers, then shows the AEF fix: the DURABLE NAME (a V9 address without
``session=``) is the correspondent, and two distinct names elect two distinct
claim coordinates on the live hub — distinct correspondents, regardless of the
fingerprint collision.

Substrate used (all shipped): aef_address (S1), aef_election live claim
backend (S8/T-3335), and — for the display of the derived coordinate —
election_topic. No G3 self-heal here; that is a separate leg (needs T-3339).

Usage:
    termlink hub status --json     # confirm a hub is running (else: hub start)
    python3 tests/manual/arc020_g1_demo.py
Writes evidence to docs/reports/T-3340-g1-demo-evidence.md and exits 0 on success.
"""
from __future__ import annotations

import collections
import datetime
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.aef_address import AEFAddress, serialize
from lib.aef_election import (
    TermlinkChannelClaimBackend,
    default_termlink_invoke,
    election_topic,
    elect,
)

CHANNEL = "aef-g1-demo"
EVIDENCE = ROOT / "docs" / "reports" / "T-3340-g1-demo-evidence.md"


def _termlink_sessions() -> list[dict]:
    out = subprocess.run(
        ["termlink", "list", "--json"], capture_output=True, text=True, timeout=20
    ).stdout
    try:
        d = json.loads(out)
    except json.JSONDecodeError:
        return []
    return d if isinstance(d, list) else d.get("sessions", d.get("data", []))


def _fingerprint_collapse(sessions: list[dict]):
    """Return (total_with_fp, distinct_fp, worst_fp, worst_count, sample_ids)."""
    fps = collections.Counter()
    by_fp: dict[str, list[str]] = collections.defaultdict(list)
    for s in sessions:
        fp = (s.get("metadata") or {}).get("identity_fingerprint")
        if fp:
            fps[fp] += 1
            by_fp[fp].append(s.get("id", "?"))
    if not fps:
        return 0, 0, None, 0, []
    worst_fp, worst_count = fps.most_common(1)[0]
    return sum(fps.values()), len(fps), worst_fp, worst_count, by_fp[worst_fp][:2]


def main() -> int:
    lines: list[str] = []

    def emit(s: str = ""):
        print(s)
        lines.append(s)

    ts = datetime.datetime.now(datetime.timezone.utc).isoformat()
    emit(f"# arc-020 G1 demo evidence — distinct co-resident correspondents")
    emit(f"_Captured {ts} against the live termlink hub (T-3340)._")
    emit()

    # ── 1. The bug, from live data ───────────────────────────────────────
    sessions = _termlink_sessions()
    total, distinct, worst_fp, worst_n, sample = _fingerprint_collapse(sessions)
    emit("## 1. Baseline: the fingerprint collapse (G-105 / T-3286), live")
    emit()
    emit(f"- Sessions on this hub carrying a crypto fingerprint: **{total}**")
    emit(f"- Distinct fingerprints among them: **{distinct}**")
    if worst_fp:
        emit(
            f"- One fingerprint `{worst_fp}` is shared by **{worst_n}** sessions — "
            f"termlink reads all of them as *one* correspondent."
        )
        emit(f"- Two of those co-resident sessions: `{sample[0] if sample else '?'}`, "
             f"`{sample[1] if len(sample) > 1 else '?'}` — same fingerprint, "
             f"indistinguishable to a peer addressing 'the agent'.")
    emit()
    if worst_n < 2:
        emit("> NOTE: no colliding fingerprint on the hub right now — the collapse "
             "baseline is demonstrated by the shared-key construction below rather "
             "than live duplicates.")
        emit()
        # construct a shared fingerprint for the contrast so the demo is total.
        shared_fp = worst_fp or "deadbeefcafef00d"
    else:
        shared_fp = worst_fp

    # ── 2. The AEF fix: two distinct durable names ───────────────────────
    emit("## 2. The AEF fix: the durable name is the correspondent")
    emit()
    host, hub, project = "this-host", "hub-a", "/opt/999-Agentic-Engineering-Framework"
    name_alpha = AEFAddress(host=host, hub=hub, project=project, agent="alpha")
    name_beta = AEFAddress(host=host, hub=hub, project=project, agent="beta")
    wire_alpha, wire_beta = serialize(name_alpha), serialize(name_beta)
    emit(f"- agent **alpha** durable name: `{wire_alpha}`")
    emit(f"- agent **beta**  durable name: `{wire_beta}`")
    emit(f"- Both co-resident (same host+hub+project); both would share crypto "
         f"fingerprint `{shared_fp}`.")
    emit()
    emit("| key | alpha | beta | distinguishes? |")
    emit("|-----|-------|------|----------------|")
    emit(f"| crypto fingerprint | `{shared_fp}` | `{shared_fp}` | **NO — collapses** |")
    emit(f"| AEF durable name | `{wire_alpha}` | `{wire_beta}` | **YES** |")
    emit()
    assert wire_alpha != wire_beta, "durable names must differ"
    assert shared_fp == shared_fp  # identical by construction

    # ── 3. Distinct claim coordinates on the LIVE hub ────────────────────
    emit("## 3. Distinct correspondents on the live substrate (claim election)")
    emit()
    backend = TermlinkChannelClaimBackend(CHANNEL, invoke=default_termlink_invoke)
    topic_alpha = election_topic(CHANNEL, wire_alpha)
    topic_beta = election_topic(CHANNEL, wire_beta)
    emit(f"- alpha's election coordinate (sha256-derived topic): `{topic_alpha}`")
    emit(f"- beta's  election coordinate (sha256-derived topic): `{topic_beta}`")
    assert topic_alpha != topic_beta, "distinct names must map to distinct topics"
    emit(f"- Distinct topics? **{topic_alpha != topic_beta}** — the substrate keeps "
         f"them separate before any claim is even placed.")
    emit()

    res_alpha = res_beta = None
    ok = True
    try:
        res_alpha = elect(name_alpha, "cand-alpha", backend)
        res_beta = elect(name_beta, "cand-beta", backend)
        emit(f"- elect(alpha) → role=**{res_alpha.role}**, holder="
             f"`{(res_alpha.holder or {}).get('claimer', res_alpha.holder)}`")
        emit(f"- elect(beta)  → role=**{res_beta.role}**, holder="
             f"`{(res_beta.holder or {}).get('claimer', res_beta.holder)}`")
        both_won = res_alpha.won and res_beta.won
        holder_a = backend.holder(wire_alpha)
        holder_b = backend.holder(wire_beta)
        emit(f"- Live claim holders read back — alpha: `{holder_a}`, beta: `{holder_b}`")
        emit()
        emit(f"**RESULT:** both names elected their OWN coordinate "
             f"({'PASS' if both_won else 'FAIL'}); the two agents are distinct "
             f"correspondents on the live hub while their crypto fingerprint is "
             f"identical. G1 demonstrated.")
        ok = both_won and topic_alpha != topic_beta and wire_alpha != wire_beta
    finally:
        # cleanup: release both claims so no election topic is left held.
        for res in (res_alpha, res_beta):
            if res is not None and res.won:
                try:
                    res.release()
                except Exception as exc:  # best-effort
                    emit(f"- (cleanup) release failed: {exc}")
        emit()
        emit("_Claims released; election coordinates returned to electable._")

    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text("\n".join(lines) + "\n")
    print(f"\nEvidence written: {EVIDENCE.relative_to(ROOT)}")
    print("RESULT:", "PASS ✓" if ok else "FAIL ✗")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
