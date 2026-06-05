# T-2213 — IW-4 Spike: Headline-Mechanic Research (G-062 §ACD wire-level demos)

**Parent inception:** T-2209 (Capability-overlay arc — MCP subsystem + CLI route)
**Spike worker:** spike-iw4 (TermLink-dispatched, read-only)
**Methodology:** `docs/dispatch-templates/iw-spike-worker.md` §steps 2-5 (steelman + strawman + BVP + cost + recommendation)
**Date:** 2026-06-05
**Status:** research memo for operator — NOT a decision. Producer ≠ judge.

---

## Question

**IW-4:** *"Wire-level headline mechanic per G-062 §ACD — one named user-visible deliverable that proves the arc fires."*

The §ACD class hazard (CLAUDE.md §Arc Completion Discipline): an arc closes-then-reopens when its headline mechanic is **substrate-phrased** ("MCP server exists and accepts calls", "CLI overlay returns JSON") instead of **deliverable-phrased** ("the operator opens X and sees Y, the same artefact they would have on shell invocation"). Three prior arcs burned on exactly this: T-1626 (arc-001), T-1641 (arc-002), T-1670 (arc-003) — each closed on substrate, reopened on operator pushback. The G-062 gate now refuses `fw arc create` without `--headline-mechanic` and `fw arc close` without `--demo` (a wire-level artefact). So IW-4 is not cosmetic: the mechanic the operator names is the literal close-gate condition for the whole arc.

**Reference good examples** (from existing arc YAMLs):
- `arc-001` (`.context/arcs/dispatch-safety.yaml:8-12`): *"Agent dispatches a Worker; Worker hits an ambiguity … emits pause_requested … operator sees [PAUSE] in Watchtower review queue; operator answers; Agent re-dispatches … Worker completes correctly first-try."* — names the actor, the action, the observable operator surface, and the end-state.
- `arc-006` (`.context/arcs/value-prioritisation.yaml:7-8`): *"agent runs fw bvp → sees directive-weighted scores … Watchtower /bvp shows quadrant scatter with live weight sliders."* — terminates on a named Watchtower page render.

Both name **who does what** and **what user-visible surface the result lands on**. That is the bar each candidate below must clear.

---

## Candidates

Five starting candidates HM-A..HM-E (from the dispatch). One added, **HM-F**, emerged during the steelman pass.

### HM-A — Operator opens `/review/T-XXX` for a task an MCP-routed agent completed end-to-end

*"An MCP-routed agent picks up a task, works it through to `work-completed` calling framework primitives as MCP tools (`mcp__fw__work_on`, `mcp__fw__task_update`, `mcp__fw__task_review`), and the operator opens `/review/T-XXX` to find the same rendered review page they would see had the agent shelled out to `bin/fw`."*
**Wire artefact:** operator's screenshot of the rendered `/review/T-XXX` page.

**Steelman.** Bounded and honest. The verb set is small and entirely **agent-authority** class (`work_on`, `task_update`, `note`, `task_review` — all agent-allowed per inception artifact §3, `docs/reports/T-2209-cli-mcp-overlay-inception.md:64-66`), so it ships without any new auth model — Candidate D (shell-only underlay) or Candidate A (env-inherit) is sufficient (no sovereign verb is exposed). The terminating surface (`/review/T-XXX`) is a page the operator already consults daily (`web/blueprints/tasks.py`), so there is zero novelty cost in "what to look at." Critically, it is *deliverable-phrased by construction*: the operator observes a **completed task's review page that exists because the agent worked through MCP** — the result, not the plumbing. This is precisely the inception artifact's own opening recommendation (T-2209 §6 HM-A variant, §7 "recommend Shape-1 or Shape-4 … honest §ACD demo HM-A", `docs/reports/T-2209-cli-mcp-overlay-inception.md:108,126`).

**Strawman.** The weakness is *proof-of-arc-firing*: "MCP-routed" can be hand-waved. An agent could call **one** MCP tool (`task_review`) and shell out (`Bash → bin/fw`) for everything else, and the `/review` page would look identical. The arc's actual claim is "agent-callable framework primitives replace shell screen-scraping" — a single-tool demo does not prove that claim fired. Mitigation (grafted from HM-E): require the demo's **session JSONL** to show that the task-lifecycle fw calls (`work_on`, `task_update`) were MCP tool-calls, not `Bash(bin/fw …)` invocations. This is a cheap rider (one `grep` over the JSONL) that closes the substrate loophole without inflating scope.

### HM-B — Agent calls `fw_inception_start` → `fw_inception_decide` via MCP; operator sees decision at `/inception/T-XXX`

*"An agent files and decides an inception through MCP; operator sees the GO/NO-GO recorded at Watchtower `/inception/T-XXX`."*
**Wire artefact:** the decision YAML + Watchtower page render.

**Steelman.** Terminates on a real, class-correct operator surface (`/inception/<id>`, the canonical inception-decision page per CLAUDE.md §Per-class URL mapping and [[feedback_handoff_url_per_class]]). `fw_inception_start` is agent-authority class and ships cleanly. Inception filing-through-MCP would exercise the richest gate stack (check-inception-recommendation T-2205, G-067 disposition gate, G-020 placeholder-AC gate) — a strong "gates survive MCP" proof.

**Strawman (severe — §B-005 sovereignty hazard).** `fw inception decide` is **Sovereignty-bound and agent-blocked under `$CLAUDECODE=1`** — `lib/inception.sh do_inception_decide` refuses agent invocation and points at `fw task review` (CLAUDE.md §Presenting Work for Human Review, "Structural enforcement T-1259/T-1260"; inception artifact §3 Sovereignty-bound row, `:64`). An MCP tool `mcp__fw__inception_decide` that an *agent* can call is, by definition, a sovereignty-gate bypass — the exact §B-005 class the framework protects most fiercely. To ship HM-B as literally phrased, the arc would have to either (a) violate the agent-block (unshippable), or (b) build Candidate B/C token-auth to gate the sovereign verb (huge auth surface, IW-3's hardest path). The only sovereignty-safe reframe is **start-only** ("agent files inception via MCP; the *human* decides via Watchtower") — but then the headline mechanic's punchline (the *decision* appearing) is performed by the human, not proven by the arc. That splits the demo and weakens it as a single clean mechanic.

### HM-C — Watchtower frontend POSTs JSON to a local CLI-overlay endpoint and recovers a structured response

*"Watchtower's frontend POSTs JSON to a local CLI-overlay endpoint and recovers a structured response, replacing today's argv-shape POST → ANSI-output shell-out."*
**Wire artefact:** the request/response pair captured in browser DevTools.

**Steelman.** Lowest blast radius of all candidates — internal to Watchtower, no new process, no agent-facing surface, no auth model needed (Flask process boundary, Candidate D). Addresses a real wart: Watchtower currently builds POST payloads matching CLI argv shape and screen-scrapes ANSI output (T-2209 §Problem Statement, `:79`).

**Strawman (§ACD REJECT).** This is **textbook substrate phrasing** — the precise pattern the dispatch prompt and G-062 say to reject. "Recovers a structured response" is the *mechanism*; "a request/response pair in browser DevTools" is **not an operator surface** — it is developer plumbing. No operator opens DevTools as part of their workflow. There is no user-visible deliverable; the "result" is the wire itself. Adopting HM-C as the headline mechanic would reproduce the T-1626/T-1641/T-1670 close-then-reopen failure class on its first contact with operator review. **Reject.**

### HM-D — Cross-machine bridge: TermLink worker on machine A calls MCP primitives on framework on machine B

*"A TermLink-dispatched worker on machine A calls framework MCP primitives on machine B; the cross-machine dispatch envelope + outcome is the artefact."*
**Wire artefact:** cross-machine dispatch envelope + outcome.

**Steelman.** Highest **orchestration** value (F-ORCH) — a worker on one host driving the framework on another is genuine routable-surface expansion (value-drivers.yaml F-ORCH rubric 4-5, `policy/value-drivers.yaml:135-141`). Builds naturally on existing TermLink remote transport and the `fw pickup`/`fw dispatch` cross-machine substrate (CLAUDE.md §Cross-Machine Dispatch).

**Strawman.** Largest blast radius and the hardest auth dependency. Cross-machine **cannot use env-inherit** (Candidate A) — `$CLAUDECODE` does not propagate across hosts — so it forces IW-3 onto Candidate B/C (TOFU-pinned token, the most code). The artefact ("dispatch envelope") is substrate-leaning; "outcome" is the only deliverable component, and the candidate names **no operator surface** the outcome lands on (the operator must go hunting in `fw pickup status` or a JSONL). Premature as an *opening* mechanic — it couples the arc's close-gate to the framework's most complex transport + auth path before the basic single-host overlay is proven.

### HM-E — MCP-routed agent runs a full task lifecycle without shelling out to `bin/fw` once

*"An agent runs work-on → edit → verify → work-completed entirely through MCP tools (the Edit tool does the file edit; every *fw* call is an MCP tool-call), and the operator opens `/review/T-XXX`. The session JSONL shows zero `Bash(bin/fw …)` calls — only `mcp__fw__*` tool-calls — alongside the final render."*
**Wire artefact:** session JSONL (proving zero shell-out) + final `/review/T-XXX` render.

**Steelman.** The **strongest proof** that the arc actually fired — it proves the *negative* (the agent never fell back to shell), which is the literal claim of "agent-callable primitives replace shell screen-scraping." Deliverable-phrased AND machine-verifiable: it terminates on a Watchtower render (operator surface) and the JSONL is a wire artefact the operator/audit can `grep`. Exercises the full agent-authority gate stack through MCP (check-active-task, focus-drift, budget-gate, P-010, P-011, G-067, boundary-hook), proving none were weakened by the overlay.

**Strawman.** **Maximal scope** — this is Shape-3 (MCP-server-full, T-2209 §7 `:122`), the highest-blast-radius shape in the inception. The headline mechanic cannot fire until the *entire* agent-authority verb set is wrapped and every gate is verified through the MCP transport. That inverts the §ACD purpose: a headline mechanic should be **demonstrable early and drive the slices**, not require the whole arc built before it can be shown once. G-062's own guidance ("small enough to demo … without rewriting half the framework") points away from HM-E as the *opening* mechanic. It is the ideal **closing/expansion demo** for a later slice — HM-A plus the "zero shell-out" proof.

### HM-F (added) — MCP read-only round-trip parity on `/approvals`

*"Claude Code calls `mcp__fw__review_queue()` and the operator confirms the returned queue (verdicts, ages, horizons) is identical to `bin/fw review-queue`, surfaced in the same `/approvals` page the operator consults."*
**Wire artefact:** operator screenshot of `/approvals` + the MCP tool's JSON return.

**Steelman.** Smallest possible honest demo — read-only verbs only (`review_queue`, `task_list`, `task_show`), **zero auth** (Candidate D), zero state mutation, zero gate traversal. A genuine "MCP transport works and returns framework-correct data" proof with no sovereignty exposure whatsoever.

**Strawman (§ACD borderline).** Read-only parity verges on substrate: the operator observes a task list **that already exists** — the MCP call did not *produce* the deliverable, it only *read* it. Phrased as "the same list comes back" it reads as "the transport works" (substrate). It only clears §ACD if reframed as "the operator observes the **agent acting on** the returned queue" — at which point it collapses into HM-A. Useful as a **slice-1 smoke test**, not as the arc's headline mechanic.

---

## BVP Scoring Matrix

Active drivers from `policy/value-drivers.yaml` (v3): D1=9, D2=7, D3=5, D4=3, F-RECALL=6, F-ORCH=5. Scores 0-5 per rubric (`policy/bvp-scoring-rubric.md`). One-line reasoning per cell.

| Driver (weight) | HM-A | HM-B | HM-C | HM-D | HM-E |
|-----------------|:----:|:----:|:----:|:----:|:----:|
| **D1 Antifragility (9)** | 2 | 1 | 0 | 1 | 2 |
| **D2 Reliability (7)** | 3 | 2 | 2 | 2 | 4 |
| **D3 Usability (5)** | 3 | 3 | 1 | 1 | 3 |
| **D4 Portability (3)** | 3 | 3 | 1 | 3 | 3 |
| **F-RECALL (6)** | 1 | 1 | 0 | 0 | 1 |
| **F-ORCH (5)** | 3 | 3 | 2 | 4 | 4 |
| **Weighted total** | **84** | **68** | **32** | **57** | **96** |
| **Normalised (/175)** | **0.48** | **0.39** | **0.18** | **0.33** | **0.55** |

**Reasoning (one line per cell):**

- **D1** — HM-A/E=2: full-lifecycle-through-gates proves the overlay didn't weaken the framework's protection class (a reliability-of-gates demonstration). HM-C=0: substrate phrasing actively *reproduces* the close-then-reopen failure class. HM-B/D=1: incidental.
- **D2** — HM-E=4: typed tools + observable lifecycle + gate-firing-proof removes the silent "MCP bypassed a gate" failure mode framework-wide. HM-A=3: replaces ANSI screen-scrape with structured returns for the task lifecycle (component-level). HM-B/C/D=2: single-path observability.
- **D3** — HM-A/B/E=3: terminate on a Watchtower page the operator already knows. HM-C/D=1: DevTools / `pickup status` are dev/infra-facing, not operator ergonomics.
- **D4** — all MCP candidates=3: MCP is a standard the directive explicitly prefers (CLAUDE.md Directive 4 "prefer standards — MCP, LSP, OpenAPI"). HM-C=1: custom Watchtower→CLI HTTP endpoint, not MCP.
- **F-RECALL** — uniformly 0-1: an MCP overlay routes/calls; it does not capture or synthesise durable knowledge. HM-E=1 only because session JSONL is a durable artefact (a stretch).
- **F-ORCH** — the arc's strongest axis. HM-E/D=4: full-lifecycle-as-typed-tools / cross-machine bridge = genuine routable-surface expansion (rubric 4). HM-A/B=3: typed I/O contract for a verb class a worker can call (rubric 3). HM-C=2: single internal consumer, minor.

---

## Cost Estimates

F8 = 0.6·blast_radius + 0.3·tier + 0.1·effort. T-shirt → blast_radius (S=2/M=4/L=6/XL=8); tier = sovereignty exposure (1 read-only … 5 sovereign); effort = build days proxy 0-9.

| Candidate | blast_radius | tier | effort | **F8** | T-shirt | Value/cost (norm BVP ÷ F8) |
|-----------|:------------:|:----:|:------:|:------:|:-------:|:--------------------------:|
| **HM-A** | 4 (M) | 3 | 5 | **3.8** | M | **0.126** ← best |
| HM-B (with decide) | 5 | 5 | 6 | 5.1 | M-L | 0.076 |
| HM-C | 3 | 2 | 4 | 2.8 | S-M | 0.064 |
| HM-D | 7 (L) | 4 | 8 | 6.2 | L | 0.053 |
| HM-E | 7 (L) | 4 | 8 | 6.2 | L | 0.089 |
| *HM-F (read-only)* | 2 (S) | 1 | 3 | *1.8* | S | *(smoke test, not scored as mechanic)* |

**Cost notes:** HM-A exposes only agent-authority verbs → tier 3, no new auth model needed (Candidate D/A). HM-B's cost spikes to tier 5 *only if* `inception_decide` is exposed (sovereignty); start-only reframe drops it to ~3.1/S-M. HM-E and HM-D are both L because they require, respectively, the full Shape-3 verb wrap + all-gates-through-MCP, and the cross-machine token-auth path (Candidate B/C).

---

## Recommendation

**Recommend HM-A, hardened with HM-E's no-shell-out rider.**

> **Headline mechanic (proposed wording for `fw arc create --headline-mechanic`):**
> *"An MCP-routed agent picks up task T-XXX and works it to `work-completed` calling framework primitives as MCP tools (`mcp__fw__work_on`, `mcp__fw__task_update`); the operator opens `/review/T-XXX` and finds the same rendered review page they would have on shell invocation; the session JSONL shows the task-lifecycle fw calls were `mcp__fw__*` tool-calls, not `Bash(bin/fw …)`."*

**Rationale (anchored in the BVP+cost deltas):** HM-A has the **best value/cost ratio (0.126)** — it captures the arc's core reliability (D2=3) and orchestration (F-ORCH=3) value at M cost, while HM-E (highest absolute BVP, 0.55) costs ~1.6× more (F8 6.2 vs 3.8) because it requires the full Shape-3 build before the mechanic can fire once. §ACD discipline (G-062: "small enough to demo without rewriting half the framework") and HV/LC prioritisation both favour the bounded option. The single weakness of HM-A — that "MCP-routed" can be faked by one tool-call — is closed by grafting HM-E's cheap **session-JSONL no-shell-out rider** (one `grep`), giving deliverable honesty *and* arc-firing proof without the Shape-3 cost.

**Sequencing recommendation (for the arc, not this spike's call to make):** HM-F as slice-1 read-only smoke test → HM-A as the headline mechanic (slices 2-3, agent-authority verbs) → **HM-E as the closing/expansion demo** (later slice, full Shape-3). HM-A and HM-E are the same demo at two scope levels; adopt HM-A now, reserve HM-E to *close* the arc.

**Explicitly reject HM-C** (pure substrate — would reproduce the T-1626/1641/1670 failure class). **Defer HM-D** to a post-v1 cross-machine slice (forces the hardest auth path before single-host is proven). **Reframe-or-drop HM-B** — its literal form (`inception_decide` via MCP) is a §B-005 sovereignty bypass; only a start-only reframe is shippable, and that splits the demo.

This is a **GO-shaped recommendation** with complete evidence (steelman/strawman per candidate, BVP matrix, cost walk) — not a DEFER hedge (per [[feedback_defer_for_evidence_not_confidence]] / CLAUDE.md §DEFER is for evidence gaps). The operator's job is to confirm HM-A or override toward HM-E/HM-F; the evidence to choose is on the table.

---

## §ACD Discipline Check

One paragraph per candidate confirming the deliverable-vs-substrate test, with a **§ACD-substrate-risk score 0-5** (0 = pure deliverable, 5 = pure substrate).

- **HM-A — substrate-risk 1 (PASS).** "The operator opens `/review/T-XXX` and sees the completed-task review page" is deliverable-phrased: the operator observes a *result* (a finished task's page) that exists *because* the agent worked through MCP, identical to the shell-path artefact. The only residual substrate risk — that "MCP-routed" is asserted not shown — is closed by the JSONL rider, dropping it to 1.

- **HM-B — substrate-risk 2 (PASS on phrasing, FAIL on sovereignty).** "Operator sees the decision recorded at `/inception/T-XXX`" is deliverable-phrased and lands on a class-correct surface. But the *mechanism* (agent calls `inception_decide`) is a §B-005 violation, and "the decision YAML" as an artefact leans toward inspecting-the-wire. Passes §ACD's deliverable test only in the start-only reframe; the as-written form is disqualified by sovereignty, not by substrate.

- **HM-C — substrate-risk 5 (FAIL — REJECT).** "Recovers a structured response … request/response pair in browser DevTools" is the textbook substrate phrasing G-062 exists to reject. There is no operator surface (DevTools is dev plumbing) and no user-visible deliverable — the "result" *is* the wire. Adopting it would reproduce the close-then-reopen failure class on first operator contact.

- **HM-D — substrate-risk 3 (MARGINAL).** "Cross-machine dispatch envelope + outcome" is mixed: "envelope" is substrate, "outcome" is a deliverable component, but the candidate names **no operator surface** the outcome lands on — the operator must hunt in `fw pickup status`/JSONL. It would only clear §ACD if reworded to terminate on a named Watchtower view of the inbound transfer.

- **HM-E — substrate-risk 1 (PASS, strongest).** Terminates on a `/review/T-XXX` render (operator surface) AND proves the arc's negative claim via session JSONL. Deliverable-phrased and machine-verifiable. The JSONL is a dev artefact, but it is *paired with* an operator-facing render, so the operator still observes a real deliverable — substrate-risk 1.

---

## Open Sub-Questions (surfaced, out of this spike's scope)

- **Feeds IW-2 (verb scope, T-2211):** HM-A bounds the v1 verb set to agent-authority + read-only (`work_on`, `task_update`, `task_review`, `task_show`, `review_queue`, `note`) — ~6-10 tools, well under the 22-tool soft cap (T-2209 §3 `:72`). HM-E would pull the full agent-authority set + verify path. Sovereignty-bound verbs (`inception_decide`, `arc_close`, `bvp_confirm`, `tier0_approve`) stay shell-only under every candidate except HM-B.
- **Feeds IW-3 (auth model, T-2212):** HM-A/C/F ship on Candidate D (shell-only underlay) or A (env-inherit) — no token. HM-B (with decide) and HM-D **force** Candidate B/C (per-client token / capability handshake). The headline-mechanic choice therefore *constrains* the auth answer: picking HM-A keeps IW-3 on the cheapest, sovereignty-safest path.
- **Feeds IW-1 (delivery shape, T-2210):** HM-A maps to Shape-1 (CLI-overlay) or Shape-2/4 (MCP read+authority); HM-E maps to Shape-3 (MCP-full); HM-C maps to a Watchtower-internal overlay (neither MCP nor agent-facing CLI). The mechanic and the shape are coupled — recommend resolving IW-4 *before* IW-1 finalises.
- **Render-surface gate note (P-013):** HM-A/B/E terminate on Watchtower renders. If the arc's build slices touch `web/templates/` or `web/blueprints/`, the render-surface gate (T-1766) will require a `[REVIEW]` Human AC on those slices. Flag for the build-task author, not this spike.
