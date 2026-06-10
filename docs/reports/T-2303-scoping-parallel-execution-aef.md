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

**Resolved 2026-06-10** (recorded in task body IW-2 disposition `answered`).

- **Chose:** *(b) sibling arc — close-arc-003-separately is the operator path; AEF-side new sibling = `parallel-execution-aef` (arc-011).*
- **Why:** arc-003 orchestrator-rethink's HM ("orchestrator picks model based on task_type + historical success rates → observable on /orchestrator") is functionally complete on its existing demo + W-wirings. Bundling parallel-execution into it risks the umbrella-arc anti-pattern (arc never closes, §ACD ledger noise). Parallel-execution is a distinct trajectory (multi-agent concurrency over disjoint write-sets) — sibling-arc placement keeps closure-evidence clean for both.
- **Outcome:** `.context/arcs/parallel-execution-aef.yaml` (arc-011) created 2026-06-10 by `bin/fw arc create` (NOT Sovereign-gated) with anchor `T-2303`, headline_mechanic the candidate "two agents on disjoint-write-set tasks run concurrently … two dispatch IDs in flight at once in dispatches.jsonl … no .tasks/ or .context/audits/ merge conflicts" (Spike 1 sharpens wire-evidence-X).
- **TermLink-side note:** their own arc lives in their repo. arc-011 here covers AEF-consumer-side work only — the cross-repo seam (substrate §9) is the contract boundary, not an arc boundary.

### Spike 3 findings (IW-3: TermLink coordination)

**Status:** partial — first-contact proposal drafted, NOT sent. Operator authorisation required (engages another project's agent; "executing actions with care" per CLAUDE.md).

- **Drafted artefact:** `docs/proposals/T-2303-cross-repo-parallel-execution-coordination.md` mirrors the T-1804 pattern (registered as U-007 in `fw pending list`).
- **Three questions identified for first-contact:**
  1. **ADR ratification.** Does TermLink-side accept `parallel-execution-substrate.md` (authoritative in their repo) as the spec, or do they want amendments before AEF builds against it?
  2. **§6 primitive build order + ETA.** Substrate §6 lists 10 primitives ordered by foundation/resilience/keystone/supporting. Which lands first, in what order, with what calendar window?
  3. **Ongoing-coordination mechanism.** AEF and TermLink need a coordination channel for the §9 soft dependencies (write-observation shape, un-partitionable-file regeneration, conservative→optimistic flip criteria). Proposal: low-cadence (per substrate-§9 "rising consultation volume is a smell" rule) via `fw pending` cross-repo channel, with anchor reviews at each primitive's sign-off.
- **Proposed send mechanism:** `termlink remote inject termlink-agent --enter '<message>'` — exact command embedded in proposal.
- **Timing recommendation:** *before* AEF-side downstream inceptions fire. No downstream inception should commit to a substrate-contract shape until TermLink confirms or counter-proposes. 7-day timeout: if no reply, AEF fires downstream inceptions with explicit "substrate-contract is provisional pending TermLink sign-off" caveat per §ACD.
- **Open subquestions still to resolve via dialogue:**
  1. Contract artefact shape — extract from substrate ADR §6+§9 inline, OR author a dedicated `parallel-execution-contracts.md` artifact both sides evolve together?
  2. Receipt protocol — what evidence counts as "TermLink confirmed primitive X with signature Y"? (Posting to channel? `fw pending resolve`? Commit hash of a contract-doc update?)

### Spike 4 findings (IW-4: inception cluster)

**Status:** agent-drafted proposal 2026-06-10 — awaits operator dialogue session to confirm/redraw.

**Candidate cluster (5 AEF-side inceptions, 2 TermLink-side, ordered):**

| Order | ID | Title | Predecessor(s) | Substrate dep | One-question scope |
|-------|------|-------|----------------|---------------|---------------------|
| 1 | AEF-IC-1 | Yield-point granularity (§6.1) | T-2303 GO | None — pure harness decision | Where in the agent's tool loop does it check the flag and ear? (leading: before every file-write tool call) |
| 2 | AEF-IC-2 | §2-3 Disjoint write-set policy | T-2303 GO | None — algorithm runs on declared `artifactsWrites` metadata, not write-observation | What is the schema for `artifactsWrites` globs + `depends_on`, and the disjointness-proof algorithm the orchestrator runs? |
| 3 | AEF-IC-3 | §4 Active-dispatcher architecture | AEF-IC-2 | **Consumes** TL-IC-1.{claim, idle/busy, pull/assign} | Standing process model + idle/busy state + assignment loop + integration queue? |
| 4 | AEF-IC-4 | §5 Sidecar + cooperative-poll harness | AEF-IC-1 (+ parallel to AEF-IC-3) | **Consumes** TL-IC-1.{reconnect+queue, presence} | Sidecar process design + heartbeat protocol + flag shape + ear-check semantics? |
| 5 | AEF-IC-5 | §6 Scale ceiling + optimistic-flip criteria | AEF-IC-3 + AEF-IC-4 + TL-IC-2 | **Consumes** TL-IC-2 write-observation outcome | Ring20 agent ceiling + tolerable hub-restart pause + write-observation flip criteria? (decision-only, may fold into AEF-IC-3/4 if scope shrinks) |
| (TL) | TL-IC-1 | §6 substrate-primitive build order | IW-3 first-contact resolved | — | Order + signed-off contracts for §6.1-§6.10 (claim, idle/busy, pull/assign, reconnect+queue, auth, presence, typed git surface, etc.) |
| (TL) | TL-IC-2 | §6.4 filesystem-write observation | TL-IC-1 foundation | — | Mechanism (inotify/fanotify/ptrace/wrapper) + observation API + cost + blind spots |

**Dependency DAG (text form, AEF-side reads left-to-right):**

```
T-2303 GO
  ├── AEF-IC-1 (yield granularity) ──┬── AEF-IC-2 (disjoint policy) ── AEF-IC-3 (dispatcher) ← TL-IC-1
  │                                  └── AEF-IC-4 (sidecar harness)  ← TL-IC-1
  │                                       └── AEF-IC-5 (scale + flip) ← TL-IC-2
  └── (IW-3 first-contact) ── TL-IC-1 (substrate contracts) ── TL-IC-2 (write-observation)
```

**Design rationale:**
- **§6 AEF open-questions are NOT a separate inception bundle** — they decompose into AEF-IC-1 (yield granularity), AEF-IC-4 (heartbeat + flag), and AEF-IC-5 (scale + flip). Five questions, three owner inceptions. Avoids the "umbrella inception" anti-pattern (one-question-five-decisions).
- **AEF-IC-2 is the bottleneck.** Active-dispatcher (IC-3) cannot start without the disjointness algorithm. Sidecar harness (IC-4) can run parallel from a different branch of the DAG, since cooperative polling doesn't need disjointness proof.
- **Cross-repo cut.** TL-IC-1 (substrate-contract sign-off) is the seam between AEF-IC-3/4 (consume substrate primitives) and TermLink-side build. Per substrate §9, contracts are agreed once, then both sides run independently.
- **AEF-IC-5 is the most likely to fold** (decision-only, may absorb into IC-3 for scale-ceiling-and-restart-pause and IC-4 for write-observation-flip-criteria). If exploratory dialogue in IC-3/4 surfaces the answers naturally, IC-5 doesn't need filing.

**Alternative cluster shapes considered (and rejected):**
- *3-inception variant (collapse IC-1 into IC-4, collapse IC-5 into IC-3).* Rejected: yield-point granularity is a cross-cutting concern that constrains both IC-2 schema and IC-4 ear-check semantics; deferring it inside IC-4 buries the cross-cutting nature.
- *Single AEF design-of-record inception.* Rejected: the ADRs already are the design-of-record (see Spike 5). The downstream inceptions are *build-readiness* inceptions, not design-record ones.
- *9-inception variant (per §6 open question).* Rejected: violates "one question = one inception" by going *too far* — yield granularity and ear-check semantics are the same decision viewed twice.

**Open dialogue questions for the operator session:**
- Is the proposed order right, or does dispatcher-first make more sense as a way to drive the disjointness-policy decision empirically?
- Should write-observation-flip-criteria (IC-5 second half) be its own inception even though it's decision-only? It's the single most-debated future flip.
- Should `parallel-execution-contracts.md` be a separate artifact (per Spike 3 open question) — and if so, does it become its own design-of-record inception that gates the §9 collaboration seam?

### Spike 5 findings (IW-5: artifact placement)

**Status:** agent-drafted proposal 2026-06-10 — awaits operator dialogue session to confirm/redraw.

**Three orthogonal decisions:**

#### (a) Design-of-record placement

**Recommendation:** the two ADRs in `docs/architecture/` ARE the design-of-record. **No separate design-of-record inception.**

- `docs/architecture/parallel-execution-aef.md` — this-repo authoritative
- `docs/architecture/parallel-execution-substrate.md` — TermLink-authoritative *reference copy*

Each downstream inception references the matching ADR section as canonical. If exploratory dialogue surfaces a *correction* to an ADR, the inception updates the ADR section directly + records the change in the inception's Dialogue Log.

**Rejected alternative:** a separate "design-of-record ratification" inception. Reasoning: the ADRs already passed an authoring dialogue with the operator (T-2302 landing); a ratification inception would re-litigate decisions the operator has already made and add overhead without surface improvement. Each downstream inception's filing acts as implicit ratification of the ADR section it references.

#### (b) Substrate-doc re-sync protocol

**Recommendation:** **on-update pickup via `fw pending`**, not periodic-cron-mirror, not one-time freeze.

- **How:** TermLink agent updates substrate ADR in their repo → registers a `fw pending` entry on AEF-side ("substrate-doc rev `<hash>` published") → AEF agent picks up + runs `diff` → updates reference copy + records review in this research artefact's Dialogue Log.
- **Why:** explicit, auditable, doesn't depend on operator-driven manual cadence; cost is ~1 minute per update; signals the seam-boundary moment for §9 cross-repo dialogue.
- **Failure mode tolerance:** if TermLink update fires without `fw pending` registration, AEF stays on stale reference copy until next manual diff. Acceptable — substrate-§9 says "rising consultation volume is a smell," so frequent silent updates would themselves be a design smell.

**Rejected alternatives:**
- *Cron-driven mirror.* Hides update events, complicates §9 dialogue (each update is a coordination point we want visible).
- *One-time freeze.* TermLink's substrate is actively evolving — freeze would force re-sync via a heavier mechanism eventually.
- *Operator-mediated diff.* Adds human latency without observability gain.

#### (c) ADR-update governance

**Recommendation:**
- **AEF-side ADR (`parallel-execution-aef.md`):** direct edit + commit + reflect in this research artefact's Dialogue Log. Standard AEF workflow.
- **Substrate-side reference copy (`parallel-execution-substrate.md`):** **mirror-only — never edit locally.** Pickup updates from TermLink per (b) above.
- **Correction surfacing (AEF discovers a substrate-doc problem):** raise via the cross-repo pickup channel (per IW-3 mechanism); don't patch the reference copy locally. TermLink is the producer; AEF is the consumer-validator (per §9 producer ≠ judge).

**Open dialogue questions for the operator session:**
- Is on-update pickup sustainable in practice, or does it require Spike 3's IW-3 first-contact to land first (so the channel exists)?
- Does "mirror-only" extend to commit history (replay TermLink's commits as `Co-Authored-By:` chain), or just to file-content equivalence?
- Should AEF-discovered corrections surface as a *PR-style proposal* to TermLink (inline diff + rationale) rather than a free-text pickup message? More formal but matches §9 "good contract = disjoint work-streams."

---

**Spike 1 (IW-1: headline mechanic wire-evidence-X) sharpening — agent-drafted candidate, 2026-06-10:**

Building on the candidate framing carried in `## Goals`, the falsifiable wire-evidence test could read:

> **WE-1 (live concurrency):** At time T, `.context/dispatches.jsonl` shows ≥2 dispatch envelopes with `status: in_flight` AND `started_at` within 60s of each other AND non-overlapping `artifactsWrites` globs. Falsified if only one envelope is ever in-flight at a time during a load period meant to exercise concurrency.
>
> **WE-2 (governance-plane integrity):** Across one week of concurrent operation, `.tasks/` and `.context/audits/` have zero merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) in `git log -p`. Falsified if any are present.
>
> **WE-3 (decomposition discipline):** Average inter-agent message volume per task-pair < N (TBD by Spike 1 dialogue — leaning N=5). Falsified if pairs that ran concurrently logged >N messages, signalling the boundary was drawn wrong (per ADR §2 "high coordination volume = decomposition smell").

WE-1 is the load-bearing wire-evidence. WE-2 is the safety check. WE-3 is the design-quality check. All three are observable from existing or near-existing wire surfaces — no new instrumentation required.

**Open dialogue question for Spike 1:** Is "concurrent dispatches in `dispatches.jsonl`" the right wire to read, or does a stronger demonstration require a parallel-execution-tagged build task pair (e.g. T-FAKE-A + T-FAKE-B in disjoint files) that completes on a known timeline and can be measured end-to-end?

---

## Recommendation evolution

| Version | Date       | Recommendation | Note |
|---------|------------|----------------|------|
| v1      | 2026-06-10 | DEFER          | Legitimate evidence-gap DEFER at filing time; recommendation revised after Spike 5 resolves. |
| v2      | 2026-06-10 | DEFER (sharpened) | Spike 2 closed (IW-2 answered — sibling arc-011). Spikes 4 + 5 + 1 sharpened with agent-drafted concrete proposals (5-AEF + 2-TermLink inception cluster, ADRs-are-record + on-update-pickup sync protocol, 3-wire-evidence test). Recommendation stays DEFER pending operator dialogue (Spike 3 IW-3 first-contact still load-bearing; Spike 1 + 4 + 5 proposals still need operator confirm/redraw). |

When the recommendation is revised, the new row records the date, the new value (GO / NO-GO / DEFER-with-revisit-trigger), and the evidence basis.

## Agent prep work log (sessions, not operator dialogue)

This sub-section records autonomous agent prep work that *did not* involve operator dialogue — proposals drafted, options analysed, candidate scoping written. Operator dialogue captured under `## Dialogue Log`. Agent prep is here so the trace of "where did this candidate framing come from?" is preserved.

### 2026-06-10 — Agent-drafted Spike 4 + 5 + 1 proposals (autonomous mandate, post-T-2305 BVP filing)

**Trigger:** operator's standing directive to focus on the parallel-execution-aef-orchestration arc during autonomous-mode session continuation. T-2305 BVP work blocked at Sovereign gate (`/review/T-2306` handoff); switched focus to T-2303 to prep this arc.

**What changed:** Spike 4 (inception cluster) populated with a 5-AEF + 2-TermLink ordered cluster + dependency DAG + alternatives-considered rationale. Spike 5 (artifact placement) populated with three orthogonal-decisions proposal: ADRs-are-record + on-update-pickup sync + mirror-only governance. Spike 1 (wire-evidence) sharpened to three falsifiable wire tests (WE-1/2/3) — concurrency, governance-plane integrity, decomposition discipline.

**What's explicitly NOT done:** Operator dialogue for any of Spikes 1, 3, 4, 5. Spike 3 first-contact is drafted but not sent (engages another project's agent — Sovereign-equivalent boundary per CLAUDE.md). The candidate proposals above are starting points for the operator dialogue session, not decisions.

**Confidence (per-spike, post-prep):**
- Spike 1: confidence 1 (was 0) — three wire-evidence candidates surface the actual question. Operator confirms which is "the" demonstrating wire.
- Spike 2: confidence 3 (was 2) — answered, sibling arc-011 created.
- Spike 3: confidence 1 (unchanged) — first-contact drafted, send-or-defer is operator-only.
- Spike 4: confidence 2 (was 0) — concrete cluster proposed with DAG + rationale; operator confirms order + count.
- Spike 5: confidence 2 (was 1) — concrete protocols proposed for each of three sub-questions; operator confirms.

**Effect on Recommendation:** evidence-gap DEFER remains correct (Spike 3 is genuinely external; Spikes 1/4/5 need operator confirm-or-redraw to land). But the evidence-gap narrowed: operator now has concrete proposals to react to, not blank-page prompts. Recommendation evolution row v2 records the sharpening.
