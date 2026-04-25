# T-1442: AC Validation Default-Flip — Mechanical Verification with Persisted Evidence

## Status
**Phase:** Exploration / Dialogue (in progress)
**Linked:** T-1443 (I-B reviewer agent — depends on this inception's GO)

## Problem

Human ACs are accumulating as approval-queue noise. Many describe checks that don't require human judgment — they're mechanically evidenceable but currently default to Human review. This adds friction without proportional risk-management value.

Pattern observed across multiple consumer projects.

## Framing North Star

| Axis | Value |
|---|---|
| **Goal** | Frictionless development |
| **Constraint** | Preserve antifragility + reliability + auditability (4 directives) |
| **Pain** | Human-AC backlog = friction without proportional risk management |
| **Solution shape** | Mechanical verification + reviewer agent = remove friction *without* removing rigor |

## Proposal

Flip the default for AC validation from "Human" toward one of three mechanical tiers, with **persisted evidence** (not just exit-code pass/fail). Human AC is reserved for genuine judgment (tone, UX feel, strategic go/no-go).

| Tier | Method | Existing? |
|---|---|---|
| A | Programmatic (shell, curl, grep) | Yes — Tier 1 / P-011 |
| B | E2E via TermLink (spawn, inject, output) | Yes — Tier 2 |
| C | Browser automation via Playwright | Yes — Tier 3 (`fw test playwright`) |

Infrastructure exists. What is **new**:
1. Default-flip in AC classification guidance (T-954 extension)
2. **Evidence persistence** — verification runs must capture artifacts (stdout, screenshots, structured records), not just exit codes
3. Hand-off contract to I-B (reviewer agent) for evidence assessment

## Open Questions (in scope for this inception)

- **Q1 — Evidence persistence shape**: append to task file? `fw bus post`? `docs/reports/T-XXX-evidence.md`? combination?
- **Q3 — Trigger model**: runs on `--status work-completed`? hard pre-req gate before `work-completed` is even allowed? Watchtower button? combination?
- **Q5a — Relationship to existing controls**: is this an *extension* of T-954 (AC classification) + P-011 (verification gate) + `fw verify-acs`, or a *replacement*?
- **Q (emergent) — Migration**: how do we treat the existing backlog of Human ACs that are mechanically evidenceable in retrospect? Bulk re-classify? Leave alone? Reclassify only on next touch?

## Confirmed-yes (locked, not in dialogue)

- **Q2** (was open, now confirmed): Reviewer agent (I-B) **may auto-tick Agent ACs** and only escalate Human ACs when reviewer says "needs human." Reviewer authority is **mechanical-tick only** — sovereignty over Human ACs preserved.
- Two linked inceptions, sequenced I-A → I-B.

## Out of Scope

- Reviewer agent design (I-B / T-1443).
- Re-classifying every existing Human AC in the backlog — out per "incremental, not bulk."

## Dialogue Log

### 2026-04-25 — Genesis (user-initiated)

**User observation:** Human ACs becoming noise. Three validation methods already exist (programmatic / TermLink E2E / Playwright). Pattern emerges across multiple projects. Two proposals:
1. Default-flip toward mechanical verification with evidence recording
2. Independent reviewer agent (own profile) dispatched via TermLink to assess evidence and ACs

User directive: "playback this to verify we have a common understanding" before incepting.

**Agent playback (this file's framing + 5 open questions).**

**User answers:**
1. ✅ Capture correct
2. ✅ Reviewer auto-ticks Agent ACs; escalates to human only when "needs human"
3. ❓ "`work-completed` trigger or pre-req for work-completed?" — explore in I-A
4. ❓ "incept that" → reviewer scope (generic vs per-tier) → folded into I-B
5. ❓ "incept that, think about goals + risks + frictionless development" → framing absorbed, relationship-to-existing-controls explored in both

### 2026-04-25 — Dialogue Turn 2 (Q3 trigger model — first attempt)

Agent presented 4 trigger models (X post-trigger / Y hard pre-req gate / Z async-anytime / W lazy hybrid) with friction/risk tradeoff matrix. Recommended W: auto-fire on work-completed, cache evidence by source-touch invariant, surface "Verify now" button in Watchtower. Justification was "frictionless invisible pass-through."

### 2026-04-25 — Dialogue Turn 3 (User's antifragility pushback — design pivot)

User pushed back: *"work is only valuable when quality working product is delivered. False 'successfully tested' undermines this and can have severe downstream effects when subsequent development build on this. please reflect on this."*

This was the principle that re-framed the entire design.

**Agent reflection:** Model W is insufficient. Caching contradicts the antifragility principle. Re-framed: "friction is not the enemy — *wasted* friction is. Human-time friction is expensive; computational friction is cheap and tireless." Pivoted to **Model V (defense-in-depth)**:
- Always re-run at work-completed (no cache)
- Reviewer assesses evidence quality (not just pass/fail)
- Blast-radius invalidation on commit
- Periodic background re-validation cron
- On detected drift → re-open task to `issues`

Implication for T-1443 (reviewer agent): reviewer's job becomes harder and more valuable — must detect false-positive anti-patterns (tautology, empty output, mock-only coverage, scope-narrowing, skip-as-pass). Recorded as scope expansion for T-1443.

### 2026-04-25 — Dialogue Turn 4 (V locked + V+W struck + escalation reframe)

User confirmed:
1. ✅ Model V with validation as **hard prereq** for `--status work-completed`
2. Asked: elaborate on V+W hybrid I had floated
3. ❌ "first-time human signoff for ALL tasks" — instead: human signoff for **high risk / destructive / high-impact UX patterns**. Asked: how/if can we codify this at all?

**Agent response:**
- Q1: Confirmed V pure, hard prereq gate. Auto-fire on `work-completed` (frictionless) with `fw task verify` standalone available for early/iterative checks.
- Q2: **V+W struck**. The "+W" was a momentary lapse back into compute-optimization caching. Caching contradicts V's principle. The cron has no useful cache to consult — verification IS the cache invalidator. Strike V+W; pure V; rolling cron schedule for compute spread (not caching).
- Q3 (codification): proposed two-layer escalation model —
  - **Layer 1** mechanical pattern triggers (`policy/escalation-patterns.yaml`)
  - **Layer 2** declared frontmatter (`risk`, `human_signoff` fields)
  - **Layer 3** audit safety-net cron catches false-negatives
- Acknowledged honest limits: false-negatives WILL happen; antifragile loop tunes Layer 1 over time.

### 2026-04-25 — Dialogue Turn 5 (cron specification)

User confirmed:
1. ✅ Always invoke validation agent on `work-completed`
2. ✅ Two-layer + audit confirmed
3. ✅ Cron runs daily
4. Asked: what does the cronjob look at?

**Agent specified two passes (one daily schedule, shared task scan):**

| Pass | Scope | Per-task action | Catches |
|---|---|---|---|
| A — Drift Detection | Rolling 30-day completed + always-on core fabric components | Re-runs verification fresh; reviewer re-assesses; on fail → task back to `issues` with diff | Env drift, dep upgrades, transitive code changes invisible to source-touch |
| B — Escalation Audit | Completed tasks since last audit | Cross-references commits + frontmatter against Layer 1; flags pattern-match + mechanical-tick (no human signoff) | False-negatives in Layer 1 catalogue; each catch tunes pattern set |

Combined output → Watchtower `/cron/validation-audit` page (antifragility dashboard). Cost envelope ~13 min/day.

### 2026-04-25 — Dialogue Turn 6 (Q1 final — evidence persistence shape)

Agent proposed:
- Task body new `## Verification Output` section: reviewer verdict + summary + anti-pattern flags + link to full evidence (~10 lines max)
- `docs/reports/T-XXX-evidence.md`: full stdout/stderr/exit-codes/timing/env-fingerprint per verification command
- `fw bus post` envelope: optional, only for cross-agent review (not always-on)

User confirmed.

## Decisions captured (final design)

1. **Model V** (defense-in-depth) — always-fresh verification, no cache, no first-time exception, hard prereq gate on `--status work-completed`.
2. **Validation agent always invoked** on `work-completed` — auto-fire is the trigger.
3. **Reviewer (T-1443) assesses evidence quality** including anti-pattern detection — scope expanded.
4. **Two-layer human-escalation** — mechanical patterns + frontmatter declarations.
5. **Layer 3 audit safety-net cron, daily** — Pass A drift detection + Pass B escalation audit.
6. **Evidence persistence (Q1)** — task body summary + `docs/reports/T-XXX-evidence.md` + optional bus envelope.
7. **Extension of existing controls** — T-954, P-011, `fw verify-acs`, `fw fabric`, `fw cron`, `docs/reports/` reusable; no replacement.
8. **Migration incremental** — bulk re-classification of existing Human ACs is OUT; happens on next-touch only.
9. **Honest false-negative limit accepted** — antifragile loop (Layer 3 → Layer 1 catalogue tuning) is the mitigation.
10. **8 follow-up build tasks** decomposed in Recommendation block of T-1442 task body (B1–B8).

### 2026-04-25 — Dialogue Turn 7 (slash-command + orchestrator routing)

User: *"consider should we route agent review via /command, so we can use this also to route to different kind of models?? eg more in thought of our orchestarting routing dialoge we had before"*

This connects T-1443 to the orchestrator routing thread (T-1064/T-1065).

**Agent reflection:**
- For T-1442 (policy/data/cron): tiny implication — invocation contract changes from "framework calls `fw termlink dispatch agents/reviewer/`" to "framework calls `/review T-XXX` slash command (programmatic equivalent: `fw skill invoke review --task T-XXX`)." Policy unchanged.
- For T-1443 (reviewer agent design): significant — Spike B reframed from "profile scope" to "routing strategy." The question becomes "what routing rules govern which model handles which review."

**Routing matrix proposed:**

| Profile | Model | Why |
|---|---|---|
| Routine mechanical-tick | Haiku 4.5 | Fast, cheap, sufficient for pattern-matching with anti-pattern checks |
| Standard review | Sonnet 4.6 | Balanced; handles evidence-quality assessment |
| High-risk / governance / security | Opus 4.7 | Careful judgment, expensive but warranted |
| Domain specialist | External / specialised | Pluggable via routing rules |
| Cron Pass A (rerun verification) | Haiku | Bulk, cheap, exit-code + diff |
| Cron Pass B (escalation audit) | Sonnet | Moderate reasoning over commit history |

Routing inputs: task `risk` field + Layer 1 pattern match + evidence size + AC count + fabric blast-radius.

**Architectural fit:** Same routing primitive as T-1064/T-1065 — one routing engine, multiple use-cases. T-1443 becomes T-1064's first concrete consumer. Develop in parallel.

Recorded in T-1442 Recommendation step 1 + new step 6 (slash-command surface + orchestrator routing). Recorded in T-1443 as Spike H + reframe of Spike B.

## Recommendation

**GO** (full text in `.tasks/completed/T-1442-ac-validation-default-flip--mechanical-v.md` § Recommendation). Decision recorded 2026-04-25T07:22Z.

## Rollout Addendum (2026-04-25 — post-decision refinement)

Following user pushback on scope-creep risk + tighter-data-review-cadence emphasis, the 8 originally-decomposed B-tasks (B1–B8) are restructured into **micro-version progression** with data-driven advancement gates.

### Micro-version progression

| Version | Adds | ~Time | Success metric |
|---|---|---|---|
| **v1.0** | Static anti-pattern scan on `--status work-completed`. 4 patterns. Pure pre-flight. Feedback stream from day 1. | 1 session | Tasks scanned, patterns fired, false-positive count |
| **v1.1** | `## Verification Output` section + `risk` frontmatter | 1 session | % proactive risk declarations, risk-level distribution |
| **v1.2** | Reviewer agent (Sonnet hardcoded), per-AC verdicts | 1 session | Per-AC verdict distribution, mechanical-tick rate |
| **v1.3** | Spike I override mechanism (Watchtower UX MVP + feedback stream consumer) | 1 session | Override frequency, top over-firing patterns, reclassification suggestions |
| **v1.4** | Layer 1 mechanical patterns (initial 5) | 1 session | Pattern match rate, per-pattern false-positive rate |
| **v1.5** | Layer 1 expansion via corpus mining | 1 session | Diff between agent-suggested vs human-confirmed patterns |
| **v2.0** | Daily cron Pass A (drift detection) | 1 session | Drift events / week, drift classes |
| **v2.1** | Daily cron Pass B (escalation audit) | 1 session | Missed escalations / week, % becoming new Layer 1 patterns |
| **v3.0+** | Orchestrator routing (T-1064 dep), anti-pattern catalogue expansion (B-N), evidence file split, semantic checks, cross-project peer dispatch | per readiness | per-bump metrics |

### Three-cadence data review

| Cadence | Mechanism | Human time |
|---|---|---|
| Continuous | Every `/review` invocation appends structured record to `.context/working/feedback-stream.yaml` (Spike I infrastructure pulled forward to v1.0). Automatic. | 0 |
| Weekly summary | Friday cron generates Watchtower page: 7-day stats — review count, verdict distribution, top patterns, override velocity, false-positive rate, reclassification suggestions. | ~2 min |
| Threshold-triggered | Override count >5/week or false-positive rate >20% → push notification + ad-hoc review. | ~5 min when triggered |
| Per-version-bump | Explicit go/hold/iterate decision before advancing v1.x → v1.x+1, based on weekly summary data. | ~5 min per bump |

**Total human attention**: ~5–10 min/week routine + ad-hoc when alerts fire. Frictionless-feedback principle applied to the meta-process itself.

### Key shift: Spike I feedback stream pulled forward to v1.0

Override UX itself doesn't ship until v1.3, but the **feedback-stream data capture** runs from v1.0 day 1. By v1.3 we already have 3+ sessions of override-relevant data to validate the UX against.

### Why this addresses the calibration risk

Spike A (sample audit of % mechanically-evidenceable Human ACs) was deferred. The micro-version rollout **measures it in production data starting v1.0** — not in an abstract spike. If the % is <30%, we abandon early and avoid sunk cost; if 70%+, we ship faster than full-build would have.

### Antifragility positioned in iteration cycle

Each version's weekly summary feeds the next version's design decisions. Layer 1 patterns aren't designed in advance (v1.4-v1.5) — they're derived from what v1.0-v1.3 actually catches. The catalogue grows with evidence, not speculation.

## Anchor files

| Artifact | Path |
|---|---|
| Inception task body | `.tasks/active/T-1442-ac-validation-default-flip--mechanical-v.md` |
| Linked sister inception | `.tasks/active/T-1443-independent-reviewer-agent--termlink-dis.md` |
| Existing AC guidance | `CLAUDE.md` § AC Classification Guidance (T-954) |
| Existing verification gate | `CLAUDE.md` § Verification Gate (P-011) |
| Existing CLI | `bin/fw verify-acs` |
