# T-2303 — Scoping inception: parallel-execution architecture (AEF + TermLink coordination)

**Status:** scoping inception, filed 2026-06-10, **GO 2026-06-10** (operator via Watchtower, commit `989fc1e6e`). Downstream cluster: T-2323 (AEF-IC-1 yield-point granularity) + T-2324 (AEF-IC-2 disjoint write-set policy) — both filed, both currently operator-parked captured/later awaiting spike dialogue.
**Task:** [T-2303](../../.tasks/completed/T-2303-scoping-inception--parallel-execution-ar.md)
**Arc:** `parallel-execution-aef` (arc-011) — anchor task; arc created 2026-06-10
**Related ADRs:** [`docs/architecture/parallel-execution-aef.md`](../architecture/parallel-execution-aef.md) + [`docs/architecture/parallel-execution-substrate.md`](../architecture/parallel-execution-substrate.md) (landed by T-2302)
**Recommendation at filing:** DEFER → **flipped GO** per §Recommendation evolution v3 (5-Whys + dialogue log + candidate matrix all complete; operator concurred 2026-06-10)

**Grill Me entry points:**
- This inception: see `## Grill Me` section in [`T-2303` task body](../../.tasks/completed/T-2303-scoping-inception--parallel-execution-ar.md) — full primary-grill-target list per IW spike, plus assumption stress-tests.
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

*Agent-drafted candidates as of 2026-06-10 — awaits operator confirm/redraw via dialogue.*

Three falsifiable wire-evidence candidates have been sharpened (see §"Spike 1 findings" + §"Agent prep work log" for full text):

- **WE-1 (live concurrency):** `.context/dispatches.jsonl` shows ≥2 `status: in_flight` rows with `started_at` within 60s of each other AND non-overlapping `artifactsWrites` globs.
- **WE-2 (governance-plane integrity):** Across one week of concurrent operation, zero merge-conflict markers in `.tasks/` and `.context/audits/` under `git log -p`.
- **WE-3 (decomposition discipline):** Average inter-agent message volume per task-pair < N (TBD, leaning N=5).

Per CLAUDE.md §Arc Completion Discipline (G-062), the headline mechanic ships with one captured demo_evidence instance of the chosen WE or it does not ship. Operator picks which WE is *the* demonstrating wire (likely WE-1, with WE-2/WE-3 as additional safety/quality checks).

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

### 2026-06-10 — Spike-resolution dialogue (operator + agent, autonomous-mode session continuation)

**Operator:** *"please provide links for inception, make sure they are with recommendation and rationale"* + *"ok why is it still at defer are we ready for go or is there more to do?"*

**Agent:** Surfaced T-2303 as the only started-work inception, evaluated against artifact's own GO criteria. Answered: NOT ready for GO — Spike 1, 3, 4, 5 awaiting operator confirm/redraw; Spike 2 already answered. Distinguished evidence-gap DEFER (legitimate) from confidence-gap DEFER (hedge) per T-2144.

**Operator:** *"ok is it really consequential what i pick?"* (on Spike 4 cluster shape)

**Course correction:** Agent admitted Spike 4 is least consequential — order/count self-correct during downstream-inception filing. Re-ranked spikes: Spike 1 (wire-evidence) + Spike 3 (TermLink first-contact) + Spike 5(b) (cross-repo sync protocol) are the load-bearing ones; Spike 4 + Spike 5(a) + Spike 5(c) are low-consequence defaults. Operator's question caught a framing miss in agent's prior triage.

**Operator:** *"then lets go"* — default-confirm Spike 4 + 5(a) + 5(c); walk consequential ones.

**Spike 1 resolution.** Three falsifiable wire-evidence candidates presented (WE-1 live concurrency / WE-2 governance-plane integrity / WE-3 decomposition discipline). Agent recommended WE-1 primary + WE-2 supporting + WE-3 deferred to post-close §ACD review.
- **Operator:** *"1"* — confirmed.
- **Outcome:** arc-011's `headline_mechanic` + `demo_evidence` bound to WE-1 (≥2 `status: in_flight` dispatches with non-overlapping `artifactsWrites` globs in `dispatches.jsonl`). WE-2 ships as supporting clause. WE-3 deferred. Demo executes on real concurrent dispatches (no fake task pair).

**Operator:** *"proceed as seen fit, prioritize HV-LC … use termlink where sensible … check messages → focus on parallel-execution-aef arc"* (autonomous-mode directive, 5th re-issuance)

**Spike 3 resolution (revised after delivery-failure detection).** Agent took directive as explicit authorisation to send first-contact via TermLink. Checked messages first (pending list: 4 prior cross-repo asks U-002/003/004/007 outstanding; inbox 0; TermLink 0.11.949 installed; termlink-agent listed `ready 2d` on local hub).
- **Attempted action 1:** registered **U-008** via `fw pending register` + sent first-contact via `termlink inject termlink-agent --enter '...'` (526 bytes injected).
- **Delivery failure detected on `termlink output termlink-agent` poll-back:** PTY at /opt/termlink is at a `bash` prompt, not a Claude session. Bash interpreted the injected message as a shell command and threw `bash: syntax error near unexpected token \`(\`` — the message was NOT received by any Claude agent. The TermLink-side coordination channel is currently dark (no listener).
- **Attempted action 2 (fallback):** `fw pickup send --task T-2303 --type feature-proposal` to create a durable envelope. **Also failed in spirit:** pickup is per-project, the envelope landed at `/opt/999-Agentic-Engineering-Framework/.context/pickup/inbox/P-047-feature-proposal.yaml` (AEF's own inbox), not at `/opt/termlink/.context/pickup/inbox/` (no shared inbox or cross-project pickup-route mechanism). P-047 retained as audit record of the attempt.
- **Documented defer with named trigger** (per GO-criterion alternative clause): TermLink engagement deferred until **operator action — start a Claude session at termlink-agent**, OR operator-mediated chat is confirmed as substitute mechanism. AEF fires downstream inceptions (AEF-IC-1 yield-point granularity first) under explicit provisional-substrate caveat per substrate §ACD until then. Concrete revisit trigger: live Claude session at termlink-agent PTY, OR operator-mediated chat confirming substrate-contracts shape.
- **Outcome:** Spike 3 disposition = **deferred-with-named-trigger** (not "sent + pending bilateral reply"). Satisfies GO-criterion alternative clause "documented decision to sequence AEF-side downstream inceptions first with TermLink engagement explicitly deferred to a named later trigger."

**Lesson captured.** The pattern "`termlink remote inject termlink-agent`" assumes a Claude agent is the PTY listener. Pre-condition check needed: `termlink output <session>` should show a Claude-style prompt (`>` or similar), not `bash$`. Otherwise the inject corrupts a bash session rather than reaching an agent. (Sibling pattern to L-475 detector↔corrector symmetry: "send" without "delivery-verify poll-back" is a silent failure class. Reusable across cross-repo first-contact + dispatch + remote-exec verbs.)

**Spike 4 + 5 resolution (default-confirm).**
- Spike 4: 5 AEF + 2 TermLink inception cluster default-confirmed; details self-correct when AEF-IC-1 fires.
- Spike 5(a): ADRs-are-record (no separate design-of-record inception).
- Spike 5(b): on-update-pickup via `fw pending` (TermLink registers `fw pending` entry on substrate ADR update → AEF picks up + diffs reference copy + records in this artifact's Dialogue Log).
- Spike 5(c): mirror-only for substrate reference copy; corrections raised via cross-repo pickup channel, not local patches.

**Outcome of session:** all five spikes resolved with operator-confirmed dispositions. Agent's Recommendation flips DEFER → GO. Decision lands operator-side via `/inception/T-2303` (Sovereign verb `fw inception decide` is $CLAUDECODE-blocked).

---

## Per-spike findings

*Each spike below is populated as exploration runs. The H3 headers below are placeholders for the operator-dialogue session that resolves each spike.*

### Spike 1 findings (IW-1: headline mechanic)

**Status:** agent-drafted proposal 2026-06-10 — awaits operator dialogue session.
Candidates surfaced in §"Agent prep work log" → "Spike 1 (IW-1: headline mechanic
wire-evidence-X) sharpening" (lines 239-249 of this artefact).

Three falsifiable wire-evidence candidates: **WE-1** (live concurrency via
≥2 `status: in_flight` dispatches with overlapping wall-clock + non-overlapping
`artifactsWrites` globs), **WE-2** (governance-plane integrity — zero merge
markers in `.tasks/` and `.context/audits/` under `git log -p`), **WE-3**
(decomposition discipline — average inter-agent message volume per task-pair
< N, leaning N=5).

WE-1 is load-bearing (proves the headline). WE-2 is the safety check. WE-3 is
the design-quality check. All three are observable from existing or near-existing
wire surfaces — no new instrumentation.

Operator dialogue resolves: (a) which WE is THE demonstrating wire that ships
with arc-011 demo_evidence, (b) concrete N for WE-3, (c) which named task-pair
plays the demo's two-agent role.

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
| v3      | 2026-06-10 | **GO** | Spike-resolution dialogue session this date (logged above). Spike 1: WE-1 primary + WE-2 supporting + WE-3 deferred. Spike 3: U-008 registered; termlink inject attempt + fw pickup attempt both failed delivery (PTY at bash / no cross-project pickup-route); **documented defer with named trigger** = "live Claude session at termlink-agent OR operator-mediated chat" per GO-criterion alternative clause. Spike 4 + 5(a) + 5(c): default-confirmed. Spike 5(b): on-update-pickup via `fw pending`. All five spikes have operator-confirmed dispositions. GO criteria evaluated: ✓ all 5 spikes answered ✓ TermLink coordination outcome documented (defer-with-named-trigger) ✓ downstream cluster documented ✓ arc placement done ✓ research artifact carries dialogue log. Decision lands operator-side via `/inception/T-2303`. AEF-IC-1 fires post-decision with provisional-substrate caveat until TermLink coordination channel resurrects. |

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
