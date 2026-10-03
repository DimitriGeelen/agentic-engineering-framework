# T-3751: minted project_id at the sidecar circuit project level

Inception research artifact. Requested by 010-termlink (sidecar t3325-project-uuid,
@129, operator priority); run under the /decision-brief protocol (010 T-3305,
framework:pickup @294; adopted as the standing process, T-3764).

## Facts (verified 2026-10-03)

- The minted id exists: `project_id: pid-<16 hex>` in `.framework.yaml`
  (`lib/project_identity.sh`, T-3534), minted by `fw init` and `fw whoami --register`,
  back-filled by `fw upgrade` since T-3750. Ours: `pid-ffd1e8ea93077f93`.
- The project slot is two different things today:
  - path form on the wire: basename — `lib/sidecar/circuit.py:136 project_id()`,
    e.g. `//dimitrimintdev/cacc73ea32b121dd/832-Workflow-designer`;
  - V9 grammar: root path — `lib/aef_address.py:10`, ratified in T-3287 D2.
- The V9 ladder climbs agent → session → project → hub (`aef_address.py climb()`).
- Value-driver weights (`policy/value-drivers.yaml`): D1 9, D2 7, D3 5, D4 3,
  F-AUTONOMY 4 (F-RECALL 6, F1 7, F2 6, F3 7 not touched by IW-1).

## Decisions

| IW | Ruling | Date |
|----|--------|------|
| IW-1 | C — minted id in the project slot of both forms; name display-only | 2026-10-03 |

## Dialogue Log

### 2026-10-03 — IW-1 (decision 1)
- Agent correction stated first: told 010 the project level is "the folder name";
  in fact the path form uses the basename and the V9 grammar the full root path.
- Options A keep path (−25), B id only (+25), C id + display-only name (+35),
  D defer (−7). Recommendation C.
- Operator: "Okay, proceed as suggested." Read as: ruling C.

### 2026-10-03 — IW-4 (decision 2), operator thinking aloud, no ruling yet
Brief offered A ladder to host (−14), B stop at project (+25), C B + exactly-once
claim + receipt names the delivering level (+45, recommended), D no fallback (−34).

Operator response (voice, paraphrased faithfully; NOT a ruling):
1. The brief dropped a level: the full address is host / hub / project / session /
   agent. A host is identified by FQDN; its IP can change.
2. Model refinement: every level needs TWO labels — a FUNCTION label (static: what
   it is) and an ADDRESS/ID label (dynamic: which instance). Host: FQDN static, IP
   dynamic. Hub: assume one per host for now (otherwise hub1..n or named hubs,
   possibly one hub per project — undecided). Project: project id (fixed) plus a
   project INSTANCE id. Session: session name plus session instance id. Agent:
   agent name plus agent instance id.
3. Fallback is by FUNCTION, with respawn: a message for agent "research" whose
   instance died should spin up a new "research" agent that ingests the context and
   follows up. A message for a project whose instance died should spin up a new
   instance that continues from the saved context.
4. Session is a preference, not a requirement: delivering back into the same session
   keeps its context (efficiency), but a new session in the same project gives the
   same functionality (effectiveness) — context is saved often for exactly this.

Agent corrections after re-reading docs/reports/T-3287-identity-taxonomy-circuit-model.md:
- The brief omitted the host level (operator is right; circuit.py:22-31 keeps host out
  of the DESTINATION on purpose and carries it in metadata.from_circuit, which the brief
  should have said).
- The brief's options ignored two RATIFIED rulings that already say "respawn":
  T-3287 D1 (line 243: on a dead endpoint, climb the ladder until an ancestor can
  re-provision, then establish a NEW circuit; "a working equivalent, not the same B")
  and D5 (line 419: PROVISION a missing child is Tier-3 pre-authorized self-heal).
  Options A-D only chose where to DELIVER; none re-provisioned. The operator's point 3
  is D1/D5 applied; what is NEW is point 2 — an explicit function label per level, which
  is what "a working equivalent" has to be matched on. D1 ruled identity is instance-,
  not role-identity; point 2 keeps instance ids and adds the role beside them.


### 2026-10-03 — Decision 2a (after two 7-vendor reviews)
- Operator asked for an external review of the model ("this warrants an external review"), then a
  steelman/strawman + value-driver review of the options ("our standard … review").
- Results: model review 7/7 ADOPT-WITH-CHANGES; option review 7/7 B. Agent's scoring corrected by the
  reviewers (C net negative, A worse, B +1 not +2 on D1/D2, F2 and F-RECALL wrongly dropped).
- Operator (Dutch, voice; paraphrased): "OK, I think we can go as we say." Read as: ruling B.
  On item 7: two agents with one function can complement each other, but a running conversation belongs
  to the instance it began with; if a message moves to another instance, is that conversation's context
  lost? The context must travel — part of the context fabric — perhaps the receiving agent must fetch it.
  "Maybe another mechanism … a later task." → T-3780.

### 2026-10-03 — Decision 2b (respawn)
- Brief: A never (+3), B opt-in per project, guarded, default off (+45, recommended), C always (−26),
  D defer (+3). Agent correction stated first: D5 does not cover a peer's message (7/7 reviewers).
- Operator: "Proceed as suggested." Read as: ruling B.
- Operator amendment, two messages right after: "what do we do if it falters, breaks off — we do want a
  recovery mechanism even if it's not automatic"; "what you won't prevent is it goes by unnoticed and it
  never gets executed." Read as: the default (no respawn) must never be silent; a stranded message must
  escalate and be recoverable by one operator action. → T-3782 (now), T-3781 (later).
