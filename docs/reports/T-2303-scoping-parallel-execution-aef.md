# T-2303 — Scoping inception: parallel-execution architecture (AEF + TermLink coordination)

**Status:** scoping inception, filed 2026-06-10. Exploration not yet started.
**Task:** [T-2303](../../.tasks/active/T-2303-scoping-inception--parallel-execution-ar.md)
**Arc:** `orchestrator-rethink` (arc-003) — extension, pending IW-2 resolution
**Related ADRs:** [`docs/architecture/parallel-execution-aef.md`](../architecture/parallel-execution-aef.md) + [`docs/architecture/parallel-execution-substrate.md`](../architecture/parallel-execution-substrate.md) (landed by T-2302)
**Recommendation at filing:** DEFER (legitimate evidence-gap per T-2144 — exploration spikes have not run)

**Grill Me entry points:**
- This inception: see `## Grill Me` section in [`T-2303` task body](../../.tasks/active/T-2303-scoping-inception--parallel-execution-ar.md) — full primary-grill-target list per IW spike, plus assumption stress-tests.
- AEF ADR: see `## 10. Grill Me` in [`docs/architecture/parallel-execution-aef.md`](../architecture/parallel-execution-aef.md).
- Substrate ADR: see `## 11. Grill Me` in [`docs/architecture/parallel-execution-substrate.md`](../architecture/parallel-execution-substrate.md).
- arc-003 parent: see `grill_me:` field in [`.context/arcs/orchestrator-rethink.yaml`](../../.context/arcs/orchestrator-rethink.yaml).
- Invocation: `/grill-with-docs` (skill: `.claude/skills/grill-with-docs/SKILL.md`).

---

## Scope

This research artifact is the persistent thinking trail for T-2303 per CLAUDE.md §Inception Discipline #6 (C-001). It is updated incrementally as dialogue produces findings and is committed after each dialogue segment.

T-2303's job is to decide **how** the parallel-execution architecture work gets decomposed, sequenced, and arc-placed — *not* to decide whether the design is right. Design correctness is a downstream design-of-record inception (or set of inceptions) that T-2303 schedules.

## Five spikes, five decisions

| Spike | Question (IW) | Decision recorded under |
|-------|---------------|-------------------------|
| 1     | IW-1 — Headline mechanic / success criterion | `## Goals` + `## Wire Evidence Test` |
| 2     | IW-2 — Arc shape (single vs. multi)         | `## Arc Shape` |
| 3     | IW-3 — TermLink coordination timing + mechanism | `## TermLink Coordination` |
| 4     | IW-4 — Downstream inception cluster + order | `## Inception Cluster` |
| 5     | IW-5 — Design-artifact placement + sync     | `## Artifact Placement` |

Each spike's resolution updates both this artifact and the corresponding IW-N entry in the task file (confidence 0→3, disposition deferred→answered, rationale citing the relevant dialogue-log segment).

---

## Goals

*Pending Spike 1 (IW-1). Candidate framing carried over from the inception filing:*

> *Two agents on disjoint-write-set tasks complete concurrently, integrate via the hub, with zero governance-plane corruption and zero un-decomposed coordination overhead, observable from wire evidence X.*

What "wire evidence X" *is* — the falsifiable artefact that would prove or refute the headline — is the unresolved part.

## Wire Evidence Test

*Pending Spike 1. The wire-evidence test must be a falsifiable observation drawn from the substrate's actual surface (e.g. a `dispatches.jsonl` row, a hub-side append-log entry, a `meta.json` capture) — not a verbal claim. Per CLAUDE.md §Arc Completion Discipline (G-062), the headline mechanic ships with wire evidence or it does not ship.*

## Arc Shape

*Pending Spike 2 (IW-2). Candidate placement assumed by frontmatter: `arc_id: orchestrator-rethink`. Alternatives surfaced during scoping draft:*

- *(a) extend arc-003 orchestrator-rethink (current default)*
- *(b) close arc-003 with a documented decision + open a new `parallel-execution-aef` sibling*
- *(c) multi-arc: AEF-side gets one arc, TermLink-side gets its own arc (in its repo), both run in parallel under bilateral collaboration-seam contract*

## TermLink Coordination

*Pending Spike 3 (IW-3). The load-bearing question. Substrate ADR §9 makes the cross-repo boundary first-class and explicitly says producer ≠ judge — AEF signs off on substrate primitives as consumer-validated.*

**Open subquestions:**

1. **Timing.** Does TermLink-side §8 substrate-contracts inception fire *before*, *in parallel with*, or *after* AEF-side downstream inceptions?
2. **First-contact mechanism.** `fw pending register` (framework-native), TermLink pickup, `termlink remote inject` to their session, out-of-band (operator-mediated chat). Tradeoffs differ on durability, observability, and round-trip latency.
3. **Contract artefact shape.** Extract from substrate ADR §6+§9 directly, or author a dedicated `parallel-execution-contracts.md` artifact that both sides agree to evolve together?
4. **Receipt protocol.** What evidence counts as "TermLink confirmed they will produce primitive X with signature Y"?

**Recurring constraint:** §9's "rising consultation volume on a hard dependency is a smell" rule. The contract has to be lean enough that the two sides do not need ongoing dialogue per build slice.

## Inception Cluster

*Pending Spike 4 (IW-4). Candidate cluster carried from inception body:*

| Order | Inception (candidate name) | Predecessor | Notes |
|-------|----------------------------|-------------|-------|
| ?     | design-of-record (ratify ADRs as spec) | T-2303 GO | May or may not be needed; depends on IW-5 |
| ?     | §2-3 disjoint write-set policy | design-of-record | Defines `artifactsWrites` schema + orchestrator's disjointness proof shape |
| ?     | §4 active-dispatcher architecture | §2-3 | Standing process + idle/busy model + assignment loop |
| ?     | §5 sidecar + cooperative-poll harness | §4 (or parallel) | Yield-point granularity, heartbeat tick/threshold, flag shape |
| ?     | §6 open-question resolution(s) | (each its owner inception) | Maybe folded into §2-3/§4/§5 rather than separate |
| ?     | TermLink-side §8 substrate contracts | T-2303 GO (or earlier) | Lives in TermLink repo, not ours |

Ordering and dependencies fall out of Spike 4 dialogue.

## Artifact Placement

*Pending Spike 5 (IW-5). Partial answer (from T-2302's filing decision):*

- `docs/architecture/parallel-execution-aef.md` — this-repo authoritative
- `docs/architecture/parallel-execution-substrate.md` — TermLink-authoritative *reference copy*

**Open:**

1. Re-sync protocol for the substrate reference copy. Manual diff (operator runs a periodic check), cron-driven mirror, on-update pickup from TermLink, or one-time freeze.
2. Whether a separate "design-of-record ratification" inception is needed or whether ratification is folded into the §2-3 / §4 / §5 inceptions implicitly (each one references the ADR's matching section as canonical).
3. Governance of updates. The ADRs were authored across multiple prior sessions; if dialogue in a downstream inception causes a *correction* to an ADR, how does that update land — direct edit + commit, or via a documented "ADR revision proposal" surface that both sides sign off on?

---

## Dialogue Log

*Per CLAUDE.md §Inception Discipline #7 (C-001 extension), this section records the operator dialogue that produces findings: questions posed, answers given, course corrections, outcomes. Captures WHY/HOW the reasoning evolved, beyond the WHAT recorded in the spike sections.*

### 2026-06-10 — Inception filed (origination)

**Operator:** *"shoudl we incept and arc design this ? thisa is a huge piece of work where also coordination with termlink agent is needed not ?"*

**Agent:** Recommended inception (yes) but not a single umbrella — the design factors into 3-5 independent go/no-go calls (umbrella anti-pattern per CLAUDE.md Task Sizing Rules). Recommended TermLink coordination is the load-bearing sequencing constraint per substrate §8. Recommended arc placement is extension of arc-003 orchestrator-rethink (not fragmenting closure evidence). Offered three filing paths: (1) just the design-of-record inception; (2) full cluster; (3) hold while TermLink coordinates.

**Operator:** *"this is a heave bearing , core actions, needs to be executed well and is allowed to bear significant costs, incept first arc (or multi arc creatioon) evaluate if we need to contact termlink first, main ocncvern now is tahgtw e losoe focus and do not get proper scoping and coherence estblised, eg well definition or goals,arrks, designs taks etc"*

**Course correction:** Operator authorised significant cost, asked for *scoping inception first* (not the design-of-record inception, not the full cluster) — the scoping inception's job is exactly to establish goals/arcs/designs/tasks coherence. Operator's voiced concern: *"we lose focus and do not get proper scoping and coherence."* TermLink coordination is part of the scoping question, not pre-decided. Multi-arc creation is one of the candidate outcomes, not the default.

**Outcome:** T-2303 filed as the scoping inception (this task). T-2302 landed both ADRs to disk first (operator picked option "1 a" earlier in dialogue). Operator explicitly authorised significant cost-bearing for execution.

**Agent's standing note (recorded for spike-time recall):** The substrate ADR pasted by the operator confirmed §9 (collaboration seam) is owned by TermLink-side. That sharpens IW-3 — AEF signs off as consumer-validator; the contract artefact and sign-off protocol are TermLink-authored.

---

## Per-spike findings

*Each spike below is populated as exploration runs. The H3 headers below are placeholders for the operator-dialogue session that resolves each spike.*

### Spike 1 findings (IW-1: headline mechanic)

*Not started.*

### Spike 2 findings (IW-2: arc shape)

*Not started.*

### Spike 3 findings (IW-3: TermLink coordination)

*Not started.*

### Spike 4 findings (IW-4: inception cluster)

*Not started.*

### Spike 5 findings (IW-5: artifact placement)

*Not started.*

---

## Recommendation evolution

| Version | Date       | Recommendation | Note |
|---------|------------|----------------|------|
| v1      | 2026-06-10 | DEFER          | Legitimate evidence-gap DEFER at filing time; recommendation revised after Spike 5 resolves. |

When the recommendation is revised, the new row records the date, the new value (GO / NO-GO / DEFER-with-revisit-trigger), and the evidence basis.
