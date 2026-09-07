# arc-020 G1 demo evidence — distinct co-resident correspondents
_Captured 2026-09-07T15:59:50.192296+00:00 against the live termlink hub (T-3340)._

## 1. Baseline: the fingerprint collapse (G-105 / T-3286), live

- Sessions on this hub carrying a crypto fingerprint: **179**
- Distinct fingerprints among them: **3**
- One fingerprint `d1993c2c3ec44c94` is shared by **177** sessions — termlink reads all of them as *one* correspondent.
- Two of those co-resident sessions: `tl-7kfmfr4i`, `tl-mdchsajc` — same fingerprint, indistinguishable to a peer addressing 'the agent'.

## 2. The AEF fix: the durable name is the correspondent

- agent **alpha** durable name: `aef::host=this-host::hub=hub-a::project=/opt/999-Agentic-Engineering-Framework::@alpha::`
- agent **beta**  durable name: `aef::host=this-host::hub=hub-a::project=/opt/999-Agentic-Engineering-Framework::@beta::`
- Both co-resident (same host+hub+project); both would share crypto fingerprint `d1993c2c3ec44c94`.

| key | alpha | beta | distinguishes? |
|-----|-------|------|----------------|
| crypto fingerprint | `d1993c2c3ec44c94` | `d1993c2c3ec44c94` | **NO — collapses** |
| AEF durable name | `aef::host=this-host::hub=hub-a::project=/opt/999-Agentic-Engineering-Framework::@alpha::` | `aef::host=this-host::hub=hub-a::project=/opt/999-Agentic-Engineering-Framework::@beta::` | **YES** |

## 3. Distinct correspondents on the live substrate (claim election)

- alpha's election coordinate (sha256-derived topic): `aef-g1-demo-3610db060173be3b`
- beta's  election coordinate (sha256-derived topic): `aef-g1-demo-d8578be146c5e088`
- Distinct topics? **True** — the substrate keeps them separate before any claim is even placed.

- elect(alpha) → role=**won**, holder=`{'holder': 'cand-alpha', 'claim_id': 'clm-1788796790322325969-6-aef_g1_demo_3610-0', 'claimed_until': 1788796850316, 'topic': 'aef-g1-demo-3610db060173be3b', 'offset': 0}`
- elect(beta)  → role=**won**, holder=`{'holder': 'cand-beta', 'claim_id': 'clm-1788796790439226715-7-aef_g1_demo_d857-0', 'claimed_until': 1788796850439, 'topic': 'aef-g1-demo-d8578be146c5e088', 'offset': 0}`
- Live claim holders read back — alpha: `{'holder': 'cand-alpha', 'claim_id': 'clm-1788796790322325969-6-aef_g1_demo_3610-0', 'claimed_until': 1788796850316, 'topic': 'aef-g1-demo-3610db060173be3b', 'offset': 0}`, beta: `{'holder': 'cand-beta', 'claim_id': 'clm-1788796790439226715-7-aef_g1_demo_d857-0', 'claimed_until': 1788796850439, 'topic': 'aef-g1-demo-d8578be146c5e088', 'offset': 0}`

**RESULT:** both names elected their OWN coordinate (PASS); the two agents are distinct correspondents on the live hub while their crypto fingerprint is identical. G1 demonstrated.

_Claims released; election coordinates returned to electable._
