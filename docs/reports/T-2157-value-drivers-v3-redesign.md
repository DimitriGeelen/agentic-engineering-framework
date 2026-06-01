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

## Consumer-code blast radius walk (DEFERRED — to be filled before GO recommendation)

**Files that read `policy/value-drivers.yaml`** (per the v1 header docstring):
1. `lib/bvp.sh` (read paths T-1919, mutating T-1920)
2. `lib/bvp.sh auto-promote` logic (T-1931 logic, T-1932 enabling)
3. `lib/arc.sh approve-driver` (T-1926 arc-scoped drivers)
4. `web/blueprints/bvp.py` (T-1928/T-1929)
5. `web/blueprints/arcs.py` (T-1930)

Each call site needs a walk:
- **Q1:** Does it read `schema_version` for version-gating? If yes, rename breaks it silently (no error — just falls through default branch).
- **Q2:** Does it read `protected: true` to refuse removal? If absent on v3, M1's "refuse to remove D1-D4" path may collapse.
- **Q3:** Does it consume `rationale:` strings (Watchtower display)? The rename to `note:` for D1-D4 vs. retained `rationale:` for free drivers is shape-asymmetric.
- **Q4:** Does the estimator / BVP-compute code read `rubric:`? If absent, the new in-policy rubric is purely human-facing — fine. If present, it shifts the rubric source-of-truth from `policy/bvp-scoring-rubric.md` (T-1921) to per-driver YAML, creating a cross-file-duplication concern.
- **Q5:** Does anything enforce `polarity: positive`? If not, the field is descriptive; if yes, dual-polarity drivers stop working.
- **Q6:** Does `retire_when:` need lint / audit support? Currently free-text; adding a cron or audit-time staleness check (M1 says "NOT auto-enforced") could land separately.

**Provisional sizing** (pre-walk): 6 readers × 6 questions = ~10-20 LoC changes likely, plus migration logic for the version field. Could be 1 small build slice (rename + ignore-new-fields) or a larger one (consume rubric/guardrails/retire_when from YAML, deprecate the cross-file rubric MD).

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

---

## Open Questions (to resolve before GO recommendation)

1. **Why version: 3, not 2?** Skipping a number signals a deliberate major-shape break. If iterative, `2` is more honest. If major, `3` is fine but the migration cost is higher. Human intent?
2. **Schema field rename — backward compat or hard cut?** Two options:
   - (a) Add `version:` AS WELL AS keep `schema_version: 1` during transition; deprecate in v4
   - (b) Hard rename; consumers updated in same slice
   Option (a) is L-329-aligned (don't gate propagation of authorised decisions on synchronised consumer rewrites). Option (b) is cleaner but riskier.
3. **`rubric:` field source-of-truth:** Does this move the rubric from `policy/bvp-scoring-rubric.md` (T-1921) to per-driver YAML? If yes, the markdown becomes generated/derived; if no, the YAML duplicates the markdown.
4. **`retire_when:` enforcement:** Free-text reminder is fine for v3. Should a `fw doctor` advisory check exist (audit-time staleness warning when retire_when condition is recognisably met)? Separate slice if yes.
5. **F-RECALL rubric calibration:** Do bands 0-2 risk double-counting with D2? Should F-RECALL only score 3-5?
6. **F-ORCH guardrail enforcement:** The "score CAPABILITY UPLIFT, not ease-of-delegating-this-task" rule is critical. Does the estimator (T-1922 BVP estimator) get a sub-rule to refuse F-ORCH=5 when the task is just "wrap existing function in dispatch"?
7. **Estimator impact:** The T-1922 BVP estimator currently scores against D1-D4. Adding F-RECALL + F-ORCH means it needs new heuristics. Is the estimator re-train / re-rule a separate inception or in-scope for this build?
8. **Watchtower BVP display (T-1928, T-1929):** Does the `/bvp` scatter need new axes for the free drivers? Per-driver radar chart for tasks? Out-of-scope for this slice or required?
9. **Existing in-flight tasks with `bvp_scores:`:** Any task scored before v3 has no F-RECALL/F-ORCH entries. Migration: leave as null (treated as 0 in compute) or backfill on next scan? Estimator-side question.
10. **`free_drivers: []` → 2 active:** This is the first non-empty free-drivers config. Does the `fw bvp confirm` mutator (T-1924) support the new shape? Is there a unit test?

---

## Dialogue Log

### 2026-06-01 — Initial proposal received

**Human:** Pasted the full proposed v3 YAML with the request *"please ad this as an priority incpetion taks to first review / refine then impement"*.

**Agent (this artifact):** Filed as T-2157 inception with DEFER + this artifact. Did **not** edit `policy/value-drivers.yaml`. Per CLAUDE.md §Inception Discipline, build artifacts are off-limits until GO is recorded by the human via Watchtower `/inception/T-2157`.

**Next pass (within this inception):** Walk the consumer-code blast radius (lib/bvp.sh, web/blueprints/bvp.py, lib/arc.sh) and answer open questions 1-10. Update this artifact incrementally as evidence accumulates. The recommendation will flip from `DEFER` to `GO` / `NO-GO` / `GO with refinements` once the evidence is in.

---

## Next steps (within this inception, agent-driven)

1. ✅ This artifact filed at `docs/reports/T-2157-value-drivers-v3-redesign.md`
2. ⬜ Read `lib/bvp.sh` — identify all `schema_version` reads + `protected:` reads + `rationale:` reads
3. ⬜ Read `web/blueprints/bvp.py` + `web/blueprints/arcs.py` — same walk
4. ⬜ Read `lib/arc.sh approve-driver` — same walk
5. ⬜ Read `policy/bvp-scoring-rubric.md` (T-1921) — confirm the rubric source-of-truth question
6. ⬜ Read T-1915 inception artifact (`docs/reports/T-1915-bvp-inception.md`) — see what semantic carves were considered at first-pass
7. ⬜ Update this artifact's "Consumer-code blast radius walk" section with concrete findings
8. ⬜ Answer open questions 1-10 with evidence cited
9. ⬜ Flip Recommendation from DEFER → GO / NO-GO / GO-with-refinements
10. ⬜ Hand to human via `fw task review T-2157` → Watchtower `/inception/T-2157`

---

## Recommendation

**Recommendation:** DEFER

**Rationale:** Inception is at filing-time. Evidence walk (consumer-code blast radius + semantic critique vs. CLAUDE.md's "new meaning" bar + open questions 1-10) has not yet been conducted. Per T-2144 (defer-as-hedge distinction), this is a genuine evidence gap — the artifact reflects the proposal verbatim and the structural diff, but the cost/risk side requires file-walks the agent has not performed. Recommendation will flip once steps 2-9 above are complete and posted into this artifact. The human's GO / NO-GO is the final decision.

**Evidence (so far):**
- Proposed YAML captured verbatim (above)
- Structural diff table populated (12 axes)
- Provisional semantic critique on F-RECALL / F-ORCH / F-AUTONOMY (each marked "subject to revisit")
- 10 open questions enumerated with disambiguation criteria
