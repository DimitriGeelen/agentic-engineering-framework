# T-2211 — IW-2 Research: fw verb scope for the capability overlay

**Spike:** T-2211 (IW-2 of parent inception T-2209)
**Worker:** spike-iw2 (TermLink-dispatched, read-only research)
**Date:** 2026-06-05
**Time-box:** 30 min
**Template:** `docs/dispatch-templates/iw-spike-worker.md` §Worker contract

---

## Question

**IW-2:** Which `fw` verbs are in scope for the MCP/CLI capability overlay — curated 22, curated 40, or full 129; and what is the classification rule?

This spike does **not** re-enumerate the verb tree. The parent inception's research artifact
(`docs/reports/T-2209-cli-mcp-overlay-inception.md §3 Spike 1`) already did the 129-branch
enumeration and the three-class split (Sovereignty-bound / agent-authority / read-only). IW-2
builds on that to decide the **scope-size cut** and the **classification rule** that governs it.

### Evidence base (carried from Spike 1, re-verified)

- `bin/fw` has **129 top-level dispatch branches** (`grep -cE '^\s+[a-z][a-z-]+\)' bin/fw` → 129; matches T-2209 §3).
- Three classes already identified (T-2209 §3 table):
  - **Sovereignty-bound** (agent-blocked under `$CLAUDECODE=1`): `inception decide`, `arc close`, `bvp confirm`, `tier0 approve`, `enforcement baseline` (§B-005), force-push/reset (Tier-0).
  - **Agent-authority** (state-changing, agent-allowed behind gates): `work-on`, `task update`, `cron generate`, `note`, `assumption add`, `context add-learning`.
  - **Read-only / advisory** (safe to expose unconditionally): `task list/show`, `review-queue`, `inception status`, `bvp rank`, `metrics`, `doctor`, `learnings`, `decisions`, `recall`, `ask`, `search`, `docs`, `gaps`, `fabric *`, `costs`, `version`.
- **Machine-callable underlay already partly exists:** `--json` appears **101×** in `bin/fw` routing and across `lib/{bvp,resolver,outcome,gaps,peer,pause_cli,reviewer}.{sh,py}` (`grep -rlE '\-\-json' lib/`). Supports A3 (overlay is additive, not a rewrite) and lowers effort for the read-only class specifically.
- Soft tool-count ceiling: T-2209 §3 notes a **~25-tool soft cap** keeps `claude --help` parseable; `mcp__skills__*` runs ~140 tools and is the cautionary counter-example.

---

## Candidates

### A. Curated-22 — minimum viable set (read-only + agent-authority only)

The exact set T-2209 §3 already proposed: ~16 read-only tools + ~6 agent-authority tools. Sovereignty-bound verbs stay shell-only.

- **Steelman.** Smallest honest §ACD demo surface — HM-A/HM-B/HM-C from T-2209 §6 all fit inside it. Stays under the ~25-tool soft cap (T-2209 §3), so the MCP tool list does not pollute `claude --help`. Every verb in the set has a *known* gate that already fires on shell invocation; wrapping 22 of them is testable end-to-end inside one arc. Lowest blast radius of any set that still does something useful. Directly matches the §ACD "small, verifiable headline mechanic" discipline (CLAUDE.md §Arc Completion Discipline).
- **Strawman.** A **hand-curated list is a maintenance liability**. The framework has 129 verbs today and grows monthly (T-2204, T-2185, T-2169 all added verbs this quarter). Every new read-only verb must be remembered-and-added to the list, or it silently stays shell-only — the exact "curated list goes stale" failure class. The "22" is also arbitrary: why these 16 read-only and not the other ~20 read-only verbs that are equally safe? The number encodes a snapshot, not a principle. Anti-F-RECALL: the list is a fact that future sessions must re-derive rather than a rule they can apply.

### B. Curated-40 — A plus operational/observational verbs

A plus `cron status`, `audit`, `doctor`, `gaps`, `metrics`, `context {focus,init,status}`, `termlink {check,dispatch}`, `bvp` read endpoints, `pause {list,resolve}`, `dispatch send`.

- **Steelman.** Covers the *operational* loop an unattended worker actually runs — `doctor`/`audit`/`metrics` for self-inspection, `pause`/`dispatch`/`termlink` for orchestration, `context focus` for session setup. Higher real-world coverage of the day-to-day agent path than A. Most of the 18 additions are **read-only observational** verbs, which the classification rule (Candidate D) would expose unconditionally anyway — so B is largely "the read-only class is simply bigger than 16," not a genuinely riskier set.
- **Strawman.** B has the **same staleness problem as A** (still a hand-curated list) with a *larger* surface to keep gated and tested, for marginal value over A on the value drivers (see matrix). It also smuggles in `dispatch send` and `pause resolve` — agent-authority verbs with cross-machine / state-changing blast radius — without the auth model (IW-3, still DEFERRED in T-2209 §5). Picking "40" over "22" is still a number-not-a-rule; it just moves the arbitrary line.

### C. Full-129 — every top-level branch, including Sovereignty-bound

Maximum surface area: exposes `inception decide`, `arc close`, `tier0 approve`, `work-completed`, force-push, etc.

- **Steelman.** Maximal routable surface — every framework primitive callable as a typed tool; no agent ever needs to shell-scrape ANSI again. Single uniform projection of the whole CLI.
- **Strawman — disqualifying.** Exposing Sovereignty-bound verbs through MCP **directly breaches §B-005 and the Authority Model** (CLAUDE.md §Authority Model: "Initiative ≠ Authority"). The MCP stdio transport carries **no agent identity** (T-2209 §5 — `claude-in-chrome` and `skills` both rely on process-boundary trust only), so an MCP-exposed `inception decide` / `arc close` would let any misconfigured client perform Sovereign acts the framework spends ten PreToolUse hooks preventing. It also blows past the ~25-tool soft cap by 5× (T-2209 §3 — `mcp__skills__*`'s ~140 tools is the named anti-pattern), and it violates the F-ORCH **guardrail** ("anchor on genuine routable-surface expansion … NOT manufactured busywork" — `policy/value-drivers.yaml:142`) by routing verbs that must never be auto-dispatched. The arc cannot pass G-020 (new privileged surface) or the §ACD demo without an auth model that does not yet exist (IW-3 DEFERRED).

### D. Classification-by-axis — a rule, not a number

Not a numeric cut. The rule: **expose all read-only verbs unconditionally; expose agent-authority verbs with `task_id` required (so `check-active-task` / focus-drift / budget gates still fire); refuse Sovereignty-bound verbs at the transport boundary.** The surface is whatever the rule yields against the current verb tree.

- **Steelman.** The rule *reuses the three-class split T-2209 §3 already produced* — zero new classification work, the artifact is the algorithm. New verbs **auto-classify**: a read-only verb added next month is exposed the moment it lands; a Sovereign verb is refused by construction. This is the **typed decision gate** F-ORCH rubric level 3 names verbatim ("adds a clean typed I/O contract or decision gate so the framework can refuse-or-dispatch the step mechanically" — `policy/value-drivers.yaml:138`). It is antifragile (D1): a mis-exposed verb becomes a one-line rule refinement, not a re-curation of a list. It closes a recall loop (F-RECALL rubric 4): the classification is encoded once where agents read it, not re-derived per session. It preserves §B-005 by *construction* — the refusal is a property of the class, not a verb the maintainer must remember to omit. The **first concrete surface the rule yields ≈ Candidate A** (read-only class + agent-authority class with `task_id`), and it grows naturally toward B as read-only verbs accumulate — but it **never** yields C, because the Sovereign class is refused structurally.
- **Strawman.** A rule is harder to eyeball than a fixed list — an operator cannot read "22 tools" off the config; they must run the classifier to see the current surface. The three classes are not yet machine-encoded (today they live in prose in T-2209 §3 and in the scattered `$CLAUDECODE=1` checks); turning them into an executable predicate is real effort and a place a bug could silently mis-classify a Sovereign verb as read-only — the one failure mode that matters most. Needs a test that asserts every `$CLAUDECODE`-blocked verb is in the refuse-set (mitigates the risk but must be built).

---

## BVP Scoring Matrix

Active drivers and weights from `policy/value-drivers.yaml` (v3): D1=9, D2=7, D3=5, D4=3, F-RECALL=6, F-ORCH=5. Score 0–5 per cell.

| Driver (weight) | A: Curated-22 | B: Curated-40 | C: Full-129 | D: Axis-rule |
|-----------------|:---:|:---:|:---:|:---:|
| **D1 Antifragility (9)** — strengthens under stress; mis-exposure is a learning event | 3 — small, gates survive, but list rots under growth | 3 — same, larger surface | 2 — sovereignty exposure is fragile, large blast | **4** — new verbs auto-classify; mis-class → 1-line rule fix |
| **D2 Reliability (7)** — predictable, auditable, no silent failures | 4 — 22 known gates, testable e2e | 3 — more surface, marginal gate-survival risk | 1 — 129 gates must survive MCP wrap; untestable | **4** — uniform per-class gate contract; one refuse-set test |
| **D3 Usability (5)** — sensible defaults, ergonomics | 4 — under 25-tool cap, clean list | 4 — covers operational loop | 1 — 129 tools break `claude --help` parseability | 3 — rule less eyeball-able than a fixed list |
| **D4 Portability (3)** — MCP standard, file-based | 4 — typed MCP tools, std transport | 4 — same | 2 — unwieldy at 129 | **4** — rule encoded once, portable |
| **F-RECALL (6)** — durable, retrievable knowledge; better synthesis | 3 — exposes recall/ask/learnings as tools | 3 — marginal over A | 2 — knowledge verbs drowned in 129 | **4** — reuses Spike-1 classification as durable artifact; closes loop |
| **F-ORCH (5)** — expands routable surface; typed I/O / decision gate | 4 — 22 typed contracts a worker can call | 4 — adds dispatch/pause/termlink | 2 — routes Sovereign verbs → violates F-ORCH guardrail | **5** — the rule *is* the refuse-or-dispatch decision gate (rubric L3) |
| **Weighted total** (Σ weight×score) | **125** | **118** | **58** | **140** |
| **Normalised** (÷175) | 0.71 | 0.67 | 0.33 | **0.80** |

**Reading:** D > A > B > C on weighted value. D and A are close on the read-only/authority body; D pulls ahead on D1/F-RECALL/F-ORCH precisely because it is a *rule* (auto-classifying, loop-closing, decision-gate-shaped) rather than a *snapshot list*. C is disqualified on D2/D3/F-ORCH for the sovereignty-exposure and tool-count reasons above.

---

## Cost Estimates

F8 = 0.6·blast_radius + 0.3·tier + 0.1·effort (CLAUDE.md §Task System; tier = sovereignty/auth weight, effort = build size, 0–9 scale).

| Candidate | blast_radius | tier | effort | **F8** | Notes |
|-----------|:---:|:---:|:---:|:---:|-------|
| A: Curated-22 | 3 (small subsystem) | 1 (no sovereignty exposed) | 5 | **2.6** | 22 verbs, read-only + light authority; underlay `--json` partly exists |
| B: Curated-40 | 4 | 1 | 6 | **3.3** | +18 verbs incl. dispatch/pause (cross-machine state) |
| C: Full-129 | 7 (multi-arc / framework-wide) | 4 (needs auth model IW-3) | 9 | **6.3** | requires the auth model that does not yet exist |
| D: Axis-rule | 3 (rule + initial read-only exposure) | 2 (authority needs task_id; sovereign refused by rule) | 6 (build + test the classifier predicate) | **3.0** | one-time rule cost; zero marginal cost per future verb |

**Value-per-cost:** A 0.71/2.6 = **0.27** · B 0.67/3.3 = 0.20 · C 0.33/6.3 = 0.05 · D 0.80/3.0 = **0.27**.

A and D tie on raw efficiency; D wins on absolute value and carries **zero marginal cost as the verb tree grows** (the A/B lists incur a re-curation cost on every new verb — an off-ledger maintenance tax that the F8 snapshot does not capture but D1/F-RECALL scoring does).

---

## Recommendation

**Adopt Candidate D (classification-by-axis) as the scope *rule*; its first concrete yield ≈ Candidate A (~22 tools).**

Rationale anchored in the deltas above: D is the highest-value candidate (0.80 vs A 0.71) at near-identical cost (F8 3.0 vs 2.6) **because it is a rule, not a number** — it reuses the three-class split T-2209 §3 already produced, auto-classifies future verbs (D1=4, F-RECALL=4), and is itself the typed refuse-or-dispatch decision gate F-ORCH rewards (F-ORCH=5). The A/B/C numeric cuts are all snapshots that go stale and must be re-curated; "22" and "40" just move an arbitrary line, and "129" is **disqualified** — exposing Sovereignty-bound verbs over an identity-less MCP transport breaches §B-005 and the Authority Model and violates the F-ORCH guardrail.

A and D are not competitors in the usual sense: **D is the principle, A is "apply D today and you get ~22 tools."** Recommend the operator adopt the rule (D) and have the *first arc slice* ship exactly the A-subset (read-only class + agent-authority class gated on `task_id`), with the Sovereign class refused at the transport boundary. The surface then grows toward ~B organically as read-only verbs land — and never toward C.

This is a **GO-shaped recommendation, not a hedge** (CLAUDE.md §DEFER is for evidence gaps): the evidence (Spike-1 classification, the §B-005 disqualifier for C, the existing `--json` underlay, the value/cost deltas) is sufficient to commit. The one genuine open dependency (the auth model for any agent-authority exposure) is IW-3's scope, not IW-2's — it does not block naming the rule.

---

## Open Sub-Questions

- **Coupling to IW-3 (auth):** Candidate D's "agent-authority verbs with `task_id` required" assumes the MCP transport can establish *which* task is active. That is IW-3's auth-model question. The read-only slice of D is unblocked regardless; the agent-authority slice waits on IW-3. (Out of IW-2 scope.)
- **Machine-encoding the classifier:** D requires turning the prose three-class split (T-2209 §3) into an executable predicate plus a test asserting every `$CLAUDECODE=1`-blocked verb is in the refuse-set. Sizing that is a build-slice concern, not this spike's. Flagged as the single highest-risk implementation detail (a mis-classified Sovereign verb is the one failure that matters).
- **Verb-tree drift detector:** if D ships, a periodic audit/doctor check could flag any new verb the classifier cannot place (forces an explicit class decision rather than a silent default). Candidate follow-up, not IW-2 scope.
- **Coupling to IW-1 (delivery shape):** the rule is shape-agnostic — it governs scope whether the overlay is CLI-`--json`, MCP server, or both (T-2209 §7 Shapes 1–4). C is the only candidate whose disqualification is shape-dependent (CLI-overlay-only would not expose Sovereign verbs to a network transport, softening C slightly — but the staleness and tool-count arguments still stand).
