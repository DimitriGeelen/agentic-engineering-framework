# arc-020 G3 demo evidence — a dropped circuit self-heals
_Captured 2026-09-07T17:18:24.070110+00:00 against the live termlink hub (T-3341)._

- Durable name (correspondent, no `session=`): `aef::host=dimitrimintdev::hub=hub-a::project=/opt/999-Agentic-Engineering-Framework::@healer::`

## 1. Bind: the durable name is bound to circuit-1 (live)

- circuit-1 id: `tl-kmkfvx7g`
- circuit-1 address (durable name + `session=`): `aef::host=dimitrimintdev::hub=hub-a::project=/opt/999-Agentic-Engineering-Framework::session=tl-kmkfvx7g::@healer::`
- live probe → circuit-1 alive? **True**
- message `LANDED-c1-90cf5b10` delivered to circuit-1 → lands? **True**

## 2. Drop: circuit-1 is killed; the live probe reports it absent

- circuit-1's listener killed; the stale registration evicted (`termlink clean`).
- live T-3338 probe → circuit-1 **definitively absent** (hub answered 'not found', not 'unreachable')? **True**
  This is the D4-A distinction the self-heal rests on: a False here means *heal*, a raise would have meant *retry*.

## 3. Elect: two candidates race the durable name — exactly one wins

- elect(healer-A) → role=**won**
- elect(healer-B) → role=**lost** (holder=`{'holder': 'healer-A', 'claim_id': 'clm-1788801504687417614-12-aef_g3_demo_fd3d-0', 'claimed_until': 1788801564687, 'topic': 'aef-g3-demo-fd3dc6a7d1e793da', 'offset': 0}`)
- exactly one candidate won the durable name? **True**

## 4. Heal: the winner re-provisions a NEW circuit under the same name

- provision(durable) → outcome=**provisioned** (resolve found_at=`aef::host=dimitrimintdev::hub=hub-a::project=/opt/999-Agentic-Engineering-Framework::`)
- materialized (top-down): ['aef::host=dimitrimintdev::hub=hub-a::project=/opt/999-Agentic-Engineering-Framework::session=tl-xrtat6j5::', 'aef::host=dimitrimintdev::hub=hub-a::project=/opt/999-Agentic-Engineering-Framework::session=tl-xrtat6j5::@healer::']
- circuit-2 id: `tl-xrtat6j5`
- circuit-1 `tl-kmkfvx7g` ≠ circuit-2 `tl-xrtat6j5` (D1 — new instance, not a resurrection)? **True**

## 5. Land: the peer's message lands on the healed circuit-2

- live probe → circuit-2 alive? **True**
- message `LANDED-c2-90cf5b10` delivered to circuit-2 → lands? **True**

## Result

**RESULT:** the dropped circuit self-healed — the durable name `healer` outlived circuit-1, elected exactly-once, re-provisioned to a distinct circuit-2, and the peer's message landed. G3 demonstrated ✓.

_Claims released; spawned circuits terminated and cleaned._
