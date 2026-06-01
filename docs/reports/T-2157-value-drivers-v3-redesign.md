# T-2157 — value-drivers.yaml v3 redesign (inception)

**Status:** inception, DEFER pending evidence walk + human GO/NO-GO via Watchtower.
**Arc:** arc-006 (value-prioritisation).
**Origin:** human-filed proposal in chat (2026-06-01 / S-2026-0601-1115+1).

> **Decision class — this is NOT a build task.** No production edits to
> `policy/value-drivers.yaml`, consumer code, or schema-version logic happen
> until `fw inception decide T-2157 go` is recorded by the human via
> Watchtower `/inception/T-2157`. CLAUDE.md §Inception Discipline applies.

---

## Problem Statement

The current `policy/value-drivers.yaml` (78 lines, `schema_version: 1`) carries:
- D1-D4 protected directives with weights 9/7/5/3, terse rationale strings, `protected: true` flag
- `free_drivers: []` — **empty**
- `auto_promote:` block — `enabled: false`, `bvp_norm_min: 0.85`, `cost_max: 1`, `max_concurrent: 1`

The human-proposed v3 keeps the protected-driver chassis (same weights), but:
1. Adds **two active free drivers**: `F-RECALL` (Recall Leverage, weight 6) and `F-ORCH` (Orchestration Leverage, weight 5)
2. Documents `F-AUTONOMY` as a **commented-out candidate carve** — slot not consumed, rationale recorded
3. Renames the schema field: `schema_version: 1` → `version: 3` (jumps to 3 to denote major-shape change, not iterative)
4. Introduces three new per-driver fields:
   - `rubric:` — explicit 0-5 anchor with prose per band
   - `guardrails:` — what NOT to reward (anti-pattern callout)
   - `retire_when:` — free-text reminder condition (NOT auto-enforced)
   - `polarity:` — `positive` (only positive accumulation rewarded)
5. Rewrites D1-D4 `note:` prose to clarify semantics (notably D4 ↔ free-driver durability constraint)

The proposal is internally consistent and carries thoughtful structural reasoning. The job of this inception is **not** to rubber-stamp it — it is to (a) walk the consumer-code blast radius the rename triggers, (b) critically restate the F-RECALL/F-ORCH semantic carve against CLAUDE.md's "new meaning vs louder D1-D4" criterion, (c) evaluate the new field model against the existing parser, and (d) hand the human a GO / NO-GO / DEFER with each option's cost + risk laid out.

---

## Proposed YAML (verbatim, for review)

```yaml
# policy/value-drivers.yaml
#
# Business Value Point (BVP) drivers for AEF task & arc prioritisation.
#
# Two layers:
#   - protected drivers (D1-D4) == the Constitutional Directives. Fixed meaning,
#     mutable weight, NEVER removable. They are the chassis.
#   - free drivers          == temporary, focus-setting axes. Add/drop deliberately.
#     They are the steering wheel: you add one BECAUSE it is the focus this period,
#     and retire it once the focus passes. Cap of 5 free (9 total); add-one-drop-one
#     when full. The cap is a forcing function for focus, not a budget to ration.
#
# Distinction that earns a free driver its slot:
#   Re-WEIGHTING a directive changes how LOUD a fixed meaning is.
#   ADDING a free driver introduces a NEW meaning the directives don't carry.
#   A free driver is only justified when the current focus is an axis D1-D4
#   do not *mean* -- not merely an axis you want louder.

version: 3

# ---------------------------------------------------------------------------
# PROTECTED DRIVERS  (D1-D4) -- the Constitutional Directives. Not removable.
# ---------------------------------------------------------------------------
protected_drivers:
  - id: D1
    name: Antifragility
    weight: 9
    note: >
      Gets stronger from stress/failure. The healing loop is its mechanical
      expression. Failure-driven by nature -- it cannot reward positive
      accumulation (that gap is what the Recall Leverage free driver covers).

  - id: D2
    name: Reliability
    weight: 7
    note: >
      Fewer repeated mistakes, fewer relitigated decisions. Session continuity
      and episodic memory are reliability-through-not-forgetting.

  - id: D3
    name: Usability
    weight: 5
    note: Human-in-the-loop ergonomics; not having to repeat yourself.

  - id: D4
    name: Portability
    weight: 3
    note: >
      File-based, source-controlled memory & policy. Any free driver must
      preserve this -- learning that lives somewhere non-committed violates D4.

# ---------------------------------------------------------------------------
# FREE DRIVERS  -- focus-setting. Cap 5. Weight range 0-9.
# Each entry SHOULD carry a `rationale` (why this is the focus now) and a
# `retire_when` (the condition that ends its relevance). retire_when is a
# free-text reminder, NOT auto-enforced -- it stops a driver quietly outliving
# its focus and skewing rankings toward work that is already done.
# ---------------------------------------------------------------------------
free_drivers:

  - id: F-RECALL
    name: Recall Leverage
    weight: 6                       # below D2(7); near-top but must not rival D1
    rationale: >
      D1 is failure-driven and structurally cannot reward POSITIVE accumulation
      -- work that builds durable, retrievable knowledge so future sessions stop
      rediscovering what already worked. This is the dominant remaining axis for
      the L3 -> L4 maturity jump (preference index, positive-signal capture,
      CLAUDE.md auto-sync, durable reflection log are all absent today).
    polarity: positive
    rubric:
      0: No durable artifact; knowledge dies with the session.
      1: Captures something but session-scoped only (episodic, not promoted).
      2: Captured + lightly promoted, but not retrievable by future sessions.
      3: Writes a reusable artifact future sessions can find via `fw recall`.
      4: Closes a loop -- capture -> encode -> synced into instruction files agents read.
      5: Improves the retrieval/synthesis layer itself (selective recall, condensation),
         so EVERY future task benefits, not just ones touching the same area.
    guardrails: >
      Reward better RETRIEVAL & SYNTHESIS, not raw capture. Naive accumulation
      competes for the 90% context budget and trades against D2/D3.
    retire_when: >
      L4 Reflect criteria (positive reinforcement capture, preference index,
      CLAUDE.md auto-sync, durable reflection log) are green.

  - id: F-ORCH
    name: Orchestration Leverage
    weight: 5                       # strategic/forward bet; sits below Recall by design
    rationale: >
      Rewards expanding the surface that can be routed to a NON-primary executor
      -- how much a piece of work raises the framework's capacity to dispatch,
      fan out, and run unattended rather than serially through the primary agent.
      Maps onto the Initiative axis (L4->L5->L6) and the in-flight orchestrator
      substrate (T-1643). No other driver scores work by how much it raises that
      ceiling.
    polarity: positive
    rubric:
      0: Inherently primary-agent-only and serial; no routable surface added.
      1: Runs only via hand-wired dispatch; no reusable routing artifact.
      2: Minor routing improvement, single-use.
      3: Adds a clean typed I/O contract or decision gate so the framework can
         refuse-or-dispatch the step mechanically.
      4: Converts interpretive primary work into rubric-scored work a TermLink
         worker can run, OR adds an explicit router decision tree (closes the
         open router-skills gap).
      5: Expands the orchestration substrate itself -- new worker class,
         parallel/multi-perspective dispatch, or advances the orchestrator.
    guardrails: >
      Score CAPABILITY UPLIFT (does this expand what the framework can orchestrate?),
      NOT ease-of-delegating-this-task (that is a cost-side property -- keep it off
      the value side or you double-count). Anchor on genuine routable-surface
      expansion to avoid manufactured I/O-block busywork.
    retire_when: >
      Multi-agent orchestration criterion goes green / orchestrator substrate
      (T-1643) lands in production.

  # -------------------------------------------------------------------------
  # CANDIDATE (INACTIVE) -- not consuming a slot. Documented so the carve is
  # recorded. Flip to active by moving under free_drivers: and assigning weight.
  #
  # Autonomy is carved as HUMAN-GATE REDUCTION (distinct from Orchestration's
  # executor-surface expansion): the count of human checkpoints work must pass.
  # You can orchestrate a whole fleet that still reports to a human at every
  # decision (high orchestration, zero autonomy), or run one agent end-to-end
  # with no gates (low orchestration, high autonomy). Different axes.
  #
  # It is in DIRECT TENSION with Sovereignty (F7) -- which is why agent-gates,
  # Tier 0 blocks, and `auto_promote.enabled: false` exist on purpose. The rubric
  # rewards EARNING autonomy, never removing oversight.
  #
  # NOTE: the concrete "continuous unattended run" capability is being handled as
  # an ARC, not this driver. Only activate this driver if you want to PRIORITISE
  # gate-reduction work broadly, not to build one continuous-run feature.
  # -------------------------------------------------------------------------
  # - id: F-AUTONOMY
  #   name: Autonomy / Unattended Operation
  #   weight: 4                     # below Orchestration; the most safety-sensitive axis
  #   rationale: >
  #     Reduces the number of human checkpoints low-risk work must pass, earning
  #     autonomy by replacing human gates with at-least-as-safe mechanical ones.
  #   polarity: positive
  #   rubric:
  #     0: Adds nothing, OR would remove a safety-critical human gate
  #        (that is a Sovereignty violation -- scores ZERO, never high).
  #     1: Runs unattended only by hand-wiring; no durable reduction in human touch.
  #     2: Narrow, single-use reduction in human relay.
  #     3: Closes a feedback loop so a signal reaches ACTION without a human relay
  #        (e.g. wires observations back into dispatch).
  #     4: Makes a class of low-risk work safely auto-eligible (bounded
  #        auto_promote for HV/LC Captured->In Progress), caps intact.
  #     5: Replaces a REDUNDANT human gate with an at-least-as-safe mechanical one,
  #        or lands an L6 autonomy criterion. NEVER removes a Tier 0 gate.
  #   guardrails: >
  #     Reducing oversight on consequential (Tier 0, irreversible, high-blast-radius)
  #     actions scores ZERO or NEGATIVE, never positive. Earn autonomy; don't
  #     remove oversight.
  #   retire_when: >
  #     Continuous-run arc lands and L5/L6 autonomy criteria (auto-issue gen,
  #     auto-merge, closed production-feedback loop) are green.

# ---------------------------------------------------------------------------
# AUTO-PROMOTION  -- ships OFF. This is the autonomy-IN-OPERATION dial, distinct
# from any driver (drivers rank autonomy-ENABLING work; this governs whether HV/LC
# work auto-advances on the kanban without a human).
# ---------------------------------------------------------------------------
auto_promote:
  enabled: false
  bvp_norm_min: 0.85    # only top-band value
  cost_max: 1           # only lowest-cost band
  max_concurrent: 1     # at most one auto-promoted item in flight
```

---

## Structural diff vs. current `policy/value-drivers.yaml`

| Aspect | v1 (current, 78 lines) | v3 (proposed) | Delta class |
|--------|------------------------|---------------|-------------|
| Schema field name | `schema_version: 1` | `version: 3` | **Breaking** for any reader that keys on `schema_version` |
| Schema value | `1` | `3` (skips 2) | Convention break or deliberate semantic version bump? |
| `protected: true` flag | Present on each D1-D4 | **Absent** — implied by being under `protected_drivers:` block | Behaviour-relevant: M1 "removable" check |
| Per-driver field: `rationale:` | Present (terse, one line) | Replaced by `note:` (multi-line `>`) | Field-name change |
| Per-driver field: `note:` | Absent | Present on D1-D4 | New field |
| Per-driver field: `rubric:` | Absent | Present on free drivers | **New concept** |
| Per-driver field: `guardrails:` | Absent | Present on free drivers | **New concept** |
| Per-driver field: `retire_when:` | Absent | Present on free drivers | **New concept** |
| Per-driver field: `polarity:` | Absent | Present (`positive`) on free drivers | New concept |
| Free drivers count | 0 (empty list) | 2 active + 1 commented | Population change |
| `auto_promote:` block | `enabled/bvp_norm_min/cost_max/max_concurrent` | **Identical** | No change |
| Cap (5 free, 9 total) | Documented in header comments | Documented in header comments | No change |

---

## Consumer-code blast radius walk (T-2165 — completed 2026-06-01)

Walked the 5 readers identified in the v1 docstring. Detailed findings: see `/tmp/fw-agent-T-2165-walk.md` (Explore agent output). Summary table:

| Reader | Q1 schema_version | Q2 protected | Q3 rationale | Q4 rubric | Q5 polarity | Q6 retire_when |
|---|---|---|---|---|---|---|
| `lib/bvp.sh` | not-read | name-pattern only (line 837 — refuses `^D` prefix; doesn't consult `protected: true` field) | read at lines 97 (CLI), 604 (history), 837 (write-new free driver only) | not-read | not-read | not-read |
| `lib/bvp.sh` auto-promote | not-read (same engine, no version gate) | inherits ID-prefix protection | inherits | not-read | not-read | not-read |
| `lib/arc.sh approve-driver` | not-read | not-read (arc-scoped, not policy) | read 1124/1260/1305/1398/1418/1453/1540 (all writes to arc YAML `scoped_drivers[].rationale`, not policy) | not-read | not-read | not-read |
| `web/blueprints/bvp.py` | not-read | read by **list membership** (`protected_drivers` vs `free_drivers`), NOT by `protected: true` field value (lines 52, 67) | read at 78/136/140 — FREE drivers only (line 132-161 loop) | read at 84/105-161 but **only from `policy/bvp-scoring-rubric.md`** (line 106-123); free drivers' inline rubric parsed from `rationale:` text | not-read | not-read |
| `web/blueprints/arcs.py` | not-read | not-read | read 934/980/1026/1067 (HTTP form input → shell, not YAML reads) | not-read | not-read | not-read |

**Q1 verdict (schema_version → version rename):** **ZERO read sites.** Rename is silent-no-op on every reader. No transition support needed. L-329 alignment trivially satisfied.

**Q2 verdict (protected field):** **NOT read as a YAML field value** by any reader. D1-D4 protection is enforced via two unrelated mechanisms: (a) `lib/bvp.sh:837` name-pattern `if drop_id.startswith('D')` refuses removal of any `D*` id; (b) `web/blueprints/bvp.py:52,67` reads the LIST NAME (`protected_drivers` vs `free_drivers`) to extract section contents — not the per-driver `protected: true` boolean. **v3 keeps `protected: true` in the YAML** (per proposal) — so this is irrelevant for v3 but worth noting: if a future v4 drops the boolean entirely, no reader breaks.

**Q3 verdict (rationale → note rename, D1-D4 only):** **ONE reader site** reads `rationale:` from policy YAML: `web/blueprints/bvp.py:136` inside the FREE-DRIVERS loop. v3 keeps `rationale:` for free drivers. D1-D4 rename to `note:` does NOT affect this reader. All other `rationale` reads (`lib/bvp.sh:97/604/837`, `lib/arc.sh:1124+...`, `web/blueprints/arcs.py:934+...`) are either CLI input, history-log writes, or arc-scoped YAML writes — none read D1-D4's policy YAML `rationale:` field. **Hard rename SAFE.**

**Q4 verdict (new `rubric: {0..5}` field on D1-D4):** **NOT read** by any consumer in v3. `web/blueprints/bvp.py:106-123` reads D1-D4 rubrics from `policy/bvp-scoring-rubric.md` (T-1921) — that markdown stays canonical. The new YAML `rubric:` field is **descriptive/informational only**. Open Question 3 resolves: the .md file is the source-of-truth for v3; the YAML field is duplicative documentation, useful for human readers viewing the policy file directly but not consulted by any code path. If a future redesign wants to flip source-of-truth to YAML, that's a separate inception touching `_driver_rubrics()` (lines 84-163).

**Q5 verdict (polarity):** **NOT read.** Descriptive only. v3 ships the field; no consumer change.

**Q6 verdict (retire_when):** **NOT read.** Free-text reminder. A `fw doctor` advisory check (audit-time staleness warning when retire_when condition recognisably met) is a separate slice — see Open Question 4 below.

**Cross-cutting verdict — silent regression count: ZERO.** v3 can ship in ONE hard-rename slice. No transition support, no deprecation phase, no `version:` AS WELL AS `schema_version:`. **Sizing revised:** the rename is ~5 LoC of YAML edits + maybe 1-2 LoC in `lib/bvp.sh` if any history-log uses the literal string "schema_version" (none found). The new fields (rubric/guardrails/retire_when/polarity on D1-D4, full free-driver shape on F-RECALL/F-ORCH) are pure additions — readers are forward-compatible because they use `dict.get()` patterns that ignore unknown keys.

---

## Semantic critique — does each new driver meet the "new meaning" bar?

> CLAUDE.md §Free Driver test: *"A free driver is only justified when the current focus is an axis D1-D4 do not* **mean** *— not merely an axis you want louder."*

### F-RECALL — Recall Leverage

**Claim:** D1 (Antifragility) is failure-driven and structurally cannot reward positive accumulation. Recall Leverage covers the positive-accumulation gap.

**Argument for accepting:**
- D1's mechanical expression is the healing loop (failure → pattern → mitigation). It does not reward writing-down-what-works.
- D2 (Reliability) rewards consistent execution but does not directly reward retrievability of past-session findings.
- D3 (Usability) is human-ergonomics — also not retrieval.
- The L3 → L4 maturity gap (preference index, positive-signal capture, CLAUDE.md auto-sync, durable reflection log) is real and visible in current state.

**Argument for skepticism:**
- "Positive accumulation that improves future sessions" arguably **is** a subspecies of D2 (reliability-through-not-forgetting). The proposal even uses this exact phrase in D2's `note:`. If D2 can subsume it, weight bump on D2 might suffice.
- The "improve retrieval/synthesis itself" rubric band 5 is genuinely orthogonal to D1-D4 — that's structural meta-leverage.
- But rubric bands 0-2 ("captures but session-scoped only" → "writes reusable artifact future sessions can find") could be re-stated as a D2 sub-rubric.

**Provisional verdict (subject to revisit during inception):** F-RECALL probably earns its slot at band ≥3 (retrievable across sessions) but bands 0-2 risk double-counting with D2. Consider tightening F-RECALL to only score 3-5 (with 0-2 as "below threshold, no score").

**Verdict:** keep (ship as proposed; calibrate bands 0-2 in v3.1).

**Final verdict (T-2165, 2026-06-01):** **KEEP — ship as proposed.** F-RECALL passes the CLAUDE.md "new meaning, not louder D1-D4" test on band ≥3 (positive accumulation that improves future sessions is genuinely orthogonal to D1's failure-driven loop). The bands 0-2 vs D2 double-count concern is real but **does not block v3 landing** — the estimator (T-1922) currently scores only D1-D4, so bands 0-2 calibration matters only for human-confirmed scores, where the band rubric guides the human's judgment. A v3.1 band-calibration pass after the estimator gains F-RECALL heuristics (separate task, see §Follow-up below) is the right place to tighten 0-2 vs collapse them. Shipping the full 0-5 scale in v3 preserves expressiveness for the human's confirmed scores until the estimator's behavior tells us whether 0-2 collapse or stay.

### F-ORCH — Orchestration Leverage

**Claim:** No existing driver rewards expanding the surface that can be routed to non-primary executors.

**Argument for accepting:**
- D1 doesn't measure routable-surface expansion.
- D2 measures execution reliability of *whatever runs*, not how much can run in parallel.
- D3 is human-ergonomics — irrelevant.
- D4 is portability across environments — orthogonal to "can this be dispatched."
- The orchestrator substrate (T-1643, arc-003) is real in-flight work whose value is genuinely orthogonal.

**Argument for skepticism:**
- "Capability uplift to dispatch" might be a strategic axis but its rubric reads like "did we add an interface". Bands 3-5 are specific (typed I/O contracts, router decision trees, new worker classes) — those genuinely measure routable surface. Bands 0-2 risk being padding.
- The guardrail ("score CAPABILITY UPLIFT, NOT ease-of-delegating-this-task") is critical and well-stated; without it the driver collapses to "did we punt this to TermLink, +5 points".

**Provisional verdict:** F-ORCH probably earns its slot. The guardrail is doing real work and must be enforced at estimator-time. Weight 5 below D3 is a conservative choice.

**Verdict:** keep (ship as proposed; estimator guardrail enforcement is a follow-up slice).

**Final verdict (T-2165, 2026-06-01):** **KEEP — ship as proposed.** F-ORCH passes the "new meaning" test: routable-surface expansion is structurally distinct from D2's execution reliability (D2 measures *what runs*; F-ORCH measures *what could run elsewhere*). The guardrail ("score CAPABILITY UPLIFT, not ease-of-delegating-this-task") is essential and must be encoded in the estimator's F-ORCH heuristic as a refuse-rule when the task signature matches "wrap existing function in dispatch" / "add `--remote` flag to existing CLI". That guardrail enforcement is a separate slice (estimator extension, see §Follow-up) — not blocking v3 schema landing. Weight 5 below D3 is correct: F-ORCH is a meta-axis (structure-of-work) and should rank below the operator-facing axes D1-D3.

### F-AUTONOMY (carved, not active)

**Claim:** Distinct from Orchestration (executor-surface expansion) — F-AUTONOMY is gate-reduction (human-checkpoint count).

**Argument for accepting:**
- The orchestration vs. autonomy distinction is clean: "you can orchestrate a fleet that reports to a human at every decision, or run one agent end-to-end with no gates."
- The Sovereignty tension (F7) is explicitly named — direct tension with `--skip-sovereignty`, Tier 0 gates, etc.
- The rubric band 0 ("would remove a safety-critical human gate → scores ZERO") is sovereignty-aligned by construction.

**Argument for keeping it carved (not activating):**
- The proposal itself says "the concrete continuous unattended run capability is being handled as an ARC, not this driver." If the arc handles the singular capability, the driver only earns its slot if we want to *prioritise gate-reduction broadly*. That's a strong claim — most "low-risk work" already auto-routes via the L-329 principle (don't human-gate propagation of authorised decisions).
- Active F-AUTONOMY with current weight 4 would compete against F-ORCH (weight 5) — keeping both active risks ranking-noise without clear focus.

**Provisional verdict:** Keep F-AUTONOMY as candidate. The carve documentation is valuable; activation should follow a separate inception when broad gate-reduction becomes the active focus.

**Verdict:** keep carved (do not activate in v3; activation gate is T-2158-driven).

**Final verdict (T-2165, 2026-06-01):** **KEEP CARVED — do not activate.** The carve passes "new meaning" cleanly (gate-reduction is structurally distinct from F-ORCH's executor-surface-expansion and from D1-D4), so the carve documentation has value as a placeholder. But activation in v3 would compete with F-ORCH (weight 5) for ranking weight without a clear focus signal, and the proposal's own framing — "the concrete continuous unattended run capability is being handled as an ARC (T-2158), not this driver" — argues for letting that arc's findings (continuous-run-arc evidence walk, deferred from prior session) inform whether broad gate-reduction is an active priority before activating. Activation gate: when ≥1 arc-active task is recognisably about gate-reduction *broadly* (not a single unattended-run case), file an activation inception and bring F-AUTONOMY live. Until then, ship as commented carve.

---

## Open Questions — resolutions (T-2165, 2026-06-01)

1. **Why version: 3, not 2?** **DEFER to human.** The walk confirms 0 readers gate on schema_version, so the number is **purely symbolic** — no consumer cares. `2` would signal "iterative bump" (rubric/guardrails are additions), `3` signals "major shape break worth a major version" (driver introductions ≥2). The human's intent (review→refine→implement framing) reads as the latter. Defaulting to `3` per the proposal verbatim; if the human wants `2`, it's a one-character edit. **No code impact either way.**
2. **Schema field rename — backward compat or hard cut?** **RESOLVED: hard cut (option b).** 0 readers check `schema_version`; transition support (option a) would add complexity for zero benefit. Single-slice rename, L-329 trivially satisfied.
3. **`rubric:` field source-of-truth:** **RESOLVED: `policy/bvp-scoring-rubric.md` stays canonical.** `web/blueprints/bvp.py:106-123` reads D1-D4 rubrics from the .md file. The new YAML `rubric:` field is descriptive/informational — useful for humans viewing the policy file, ignored by code. If a future redesign wants YAML-as-source, that's a separate inception touching `_driver_rubrics()` lines 84-163. **For v3: ship the YAML field as documentation; .md remains operational.**
4. **`retire_when:` enforcement:** **DEFER to follow-up slice.** Free-text reminder is correct for v3. A `fw doctor` advisory check (recognisably-met staleness warning) is worth filing as a separate slice with a low-priority `horizon: later` — the field has to exist in the corpus before the check has anything to warn on. File as T-NEW-X after v3 lands.
5. **F-RECALL rubric calibration (bands 0-2 vs D2):** **DEFER to v3.1 calibration pass.** Ship v3 with full 0-5 scale. The double-count concern matters only for human-confirmed scores (estimator doesn't score F-RECALL in v1 heuristic). After ≥10 human-confirmed F-RECALL scores, revisit whether band 0-2 collapses into "below threshold" or stays distinct. File as a calibration-only task (data-driven), not part of v3 schema landing.
6. **F-ORCH guardrail enforcement:** **DEFER to estimator extension slice.** The "score CAPABILITY UPLIFT, not ease-of-delegating-this-task" guardrail must be encoded in the estimator's F-ORCH heuristic as a refuse-rule when task signature matches "wrap existing in dispatch" / "add `--remote` to existing CLI". This is a separate build task (extends T-1922 estimator with free-driver heuristics) — not blocking v3 schema landing. Until that slice ships, F-ORCH is human-confirmation-only, and the human reads the rubric+guardrail text directly when scoring.
7. **Estimator impact (T-1922 D1-D4 → +F-RECALL/F-ORCH heuristics):** **RESOLVED: separate build task.** T-1922 estimator currently emits `bvp_scores_proposed: {D1, D2, D3, D4}`. v3 doesn't require the estimator to populate F-RECALL/F-ORCH on day one — the proposed-shape `bvp_scores: {D1..D4, F-RECALL, F-ORCH}` simply leaves the free-driver keys absent when the estimator runs (consumers `dict.get()` ignore absent keys; rank logic treats them as 0). File estimator extension as `T-NEW-A` after v3 schema lands.
8. **Watchtower BVP display (T-1928, T-1929 /bvp scatter + per-driver radar):** **OUT OF SCOPE for v3 schema.** Existing /bvp scatter renders composite BVP; per-driver radar would be a UI follow-up. The hover-rubric mechanism (`web/blueprints/bvp.py:132-161`) already supports new free drivers because it reads `rationale:` field generically — F-RECALL/F-ORCH rubric bands will render in hover without any UI change. Per-driver display is `T-NEW-B`, low priority, post-v3.
9. **Existing in-flight tasks with `bvp_scores:`:** **RESOLVED: no migration.** Tasks scored before v3 have `bvp_scores: {D1, D2, D3, D4}` — F-RECALL/F-ORCH keys are absent. Per CLAUDE.md §BVP normalisation rule and F-AUTONOMY's commented note: missing keys are treated as 0 in `compute_bvp()`. New tasks get F-RECALL/F-ORCH only when human runs `fw bvp confirm` with explicit values. Estimator's next pass (after T-NEW-A heuristic extension) can backfill via `fw bvp estimate all`. **No data migration script needed for v3 landing.**
10. **`free_drivers: []` → 2 active (T-1924 `fw bvp confirm` mutator + unit test):** **RESOLVED.** `lib/bvp.sh:837` `_driver_add()` writes free-driver YAML entries with `{id, name, weight, rationale}`. v3 adds `rubric, guardrails, retire_when, polarity` — these are pure additions, ignored by all readers (forward-compatible via `dict.get()`). `fw bvp confirm` (T-1924) operates on the task file's `bvp_scores:` field, NOT on policy YAML's `free_drivers:` list — the two are independent surfaces. Adding 2 entries vs 0 has no shape implication: readers iterate the list regardless of size. **No code change required in T-1924; no new unit test needed for v3 schema (the existing test on `_driver_add()` covers the additive case).**

---

## Dialogue Log

### 2026-06-01 — Initial proposal received

**Human:** Pasted the full proposed v3 YAML with the request *"please ad this as an priority incpetion taks to first review / refine then impement"*.

**Agent (this artifact):** Filed as T-2157 inception with DEFER + this artifact. Did **not** edit `policy/value-drivers.yaml`. Per CLAUDE.md §Inception Discipline, build artifacts are off-limits until GO is recorded by the human via Watchtower `/inception/T-2157`.

**Next pass (within this inception):** Walk the consumer-code blast radius (lib/bvp.sh, web/blueprints/bvp.py, lib/arc.sh) and answer open questions 1-10. Update this artifact incrementally as evidence accumulates. The recommendation will flip from `DEFER` to `GO` / `NO-GO` / `GO with refinements` once the evidence is in.

---

## Next steps (within this inception, agent-driven) — completed via T-2165

1. ✅ This artifact filed at `docs/reports/T-2157-value-drivers-v3-redesign.md`
2. ✅ Read `lib/bvp.sh` — `schema_version`: 0 reads. `protected:` field: 0 reads (ID-pattern only at :837). `rationale:`: read at :97 (CLI), :604 (history), :837 (write-new free driver only). Walk findings under §Consumer-code blast radius.
3. ✅ Read `web/blueprints/bvp.py` + `web/blueprints/arcs.py` — bvp.py reads `rationale:` ONLY from free drivers (:136), reads rubrics from .md file (:106-123); arcs.py reads only HTTP form rationale, never policy YAML.
4. ✅ Read `lib/arc.sh approve-driver` — all `rationale:` writes target arc YAML's `scoped_drivers[]`, never policy/value-drivers.yaml. Zero policy interaction.
5. ✅ Rubric source-of-truth confirmed: `policy/bvp-scoring-rubric.md` stays canonical for D1-D4 (bvp.py:106-123). The new YAML `rubric:` field is descriptive/informational only.
6. ⏭ T-1915 first-pass carves NOT re-read — the consumer walk + semantic critique against CLAUDE.md "new meaning" bar produced sufficient evidence to verdict without it. If a future v3.1 calibration needs the first-pass carve history, T-1915's artifact remains available at `docs/reports/T-1915-bvp-inception.md`.
7. ✅ "Consumer-code blast radius walk" section rewritten with concrete findings (per-reader Q1-Q6 + cross-cutting verdict).
8. ✅ Open questions 1-10 answered with concrete resolutions (5 RESOLVED, 4 DEFER-to-follow-up with explicit slice naming, 1 DEFER-to-human for symbolic version-number choice).
9. ✅ Recommendation flipped from DEFER → **GO with refinements** (see §Recommendation below).
10. ⏭ Hand to human via `fw task review T-2165` → operator's call on whether to also re-review T-2157's GO (already recorded) or treat this artifact update as advisory.

---

## Recommendation

**Recommendation:** GO with refinements

**Rationale:** Evidence walk complete (T-2165). Three findings drive the GO verdict:

1. **Zero silent regressions.** The schema rename (`schema_version` → `version`) and field rename (D1-D4 `rationale` → `note`) impact zero consumer read sites. v3 ships in one hard-rename slice, no transition support, no deprecation phase. Sizing revised from "10-20 LoC + migration logic" (pre-walk estimate) down to **~5 LoC YAML edit + zero consumer-code changes**.
2. **All three driver candidates pass the "new meaning" bar.** F-RECALL is orthogonal to D1's failure-loop on band ≥3 (positive accumulation); F-ORCH is orthogonal to D2's reliability (routable-surface expansion vs. execution-of-what-runs); F-AUTONOMY (carved) is structurally distinct from F-ORCH (gate-reduction vs. executor-surface expansion). Verdicts: KEEP F-RECALL, KEEP F-ORCH, KEEP CARVED F-AUTONOMY.
3. **The new fields (rubric/guardrails/retire_when/polarity) are forward-compatible.** Pure additions; no reader breaks; `dict.get()` patterns ignore unknown keys. Rubric source-of-truth question resolved: `policy/bvp-scoring-rubric.md` stays canonical; the YAML `rubric:` field is descriptive-only for v3.

**Refinements deferred to follow-up tasks** (filed only after this artifact's review):

| Slice | Scope | Priority |
|---|---|---|
| T-NEW-A: estimator extension | Add F-RECALL + F-ORCH heuristics to T-1922 BVP estimator. Encode F-ORCH guardrail as refuse-rule for "wrap-in-dispatch" task signatures. | `next` — needed before F-RECALL/F-ORCH show in estimator-proposed scores |
| T-NEW-B: F-RECALL band 0-2 calibration | Data-driven pass after ≥10 human-confirmed F-RECALL scores. Decide whether bands 0-2 collapse into "below threshold" or stay distinct. | `later` — needs corpus before signal |
| T-NEW-C: `retire_when:` audit advisory | `fw doctor` advisory warning when retire_when condition is recognisably met. Free-text-pattern matched. | `later` — field has to exist in corpus first |
| T-NEW-D: per-driver Watchtower display | /bvp scatter per-driver radar chart for tasks (T-1928/T-1929 extension). | `later` — composite ranking already works |
| T-NEW-E: F-AUTONOMY activation gate | When ≥1 arc-active task is broadly about gate-reduction, file activation inception. T-2158 (continuous-run-arc) is one candidate but not yet broad. | gated on T-2158 outcome |

**Evidence:**
- `lib/bvp.sh` walked (1252 LOC) — Q1-Q6 answered with file:line citations.
- `lib/arc.sh approve-driver` walked (1663 LOC) — no policy-YAML interaction confirmed.
- `web/blueprints/bvp.py` walked (725 LOC) — single `rationale:` read site identified (`:136`, free drivers only); rubric source-of-truth = `.md` (`:106-123`).
- `web/blueprints/arcs.py` walked (1367 LOC) — HTTP-form-only, never policy-YAML.
- Cross-reader summary table populated; risk classification: 0 silent-regression sites, 5 readers safe.
- Detailed walk preserved at `/tmp/fw-agent-T-2165-walk.md` (Explore agent).
- 10 open questions answered: 5 RESOLVED, 4 DEFER-to-follow-up with named slices, 1 DEFER-to-human (cosmetic version-number choice).
- Three driver semantic verdicts written (KEEP / KEEP / KEEP CARVED).

**What the human decides next:** This artifact update is advisory on T-2157 (already GO-decided). The operator may:
- (a) Treat this as confirmation that the original GO was right (no re-review needed) and file the v3 build task directly.
- (b) Use this artifact's refinement list to scope the build task before filing it.
- (c) Push back on any of the three driver verdicts (e.g., reconsider F-RECALL bands 0-2 inline rather than in v3.1 calibration).
