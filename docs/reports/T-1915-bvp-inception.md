# T-1915 — BVP Inception Research Artefact

**Anchor:** T-1915 (work-completed 2026-05-19, decide-go via Watchtower)
**Arc:** arc-006 (`value-prioritisation`), status `draft`
**Source handoff:** `.context/handoffs/HANDOFF-value-prioritisation-2026-05-15.md`
**Filed by:** T-1916 enrichment slice (closes G2/G7/G9 gaps from critical re-audit)

This artefact captures the material from the handoff that did NOT cleanly fit into the closed T-1915 task body or per-slice build tasks: the risks register (G2), the assumption-review schedule (G7), and the conceptual framings load-bearing for build decisions (G9). It is a frozen reference: build slices (T-NEW-2..15) inherit this material without re-deriving from the handoff.

---

## 1. Decision recap

**Recommendation (agent):** GO
**Decision (human, via Watchtower):** GO at 2026-05-19T06:35:55Z (sovereignty bypass logged as `--skip-sovereignty` reason "Inception decision: GO" — this is Watchtower's `--from-watchtower` internal call shape per T-1259/T-1260).

**Q1–Q4 disposition:** Defaults stand unless explicitly overridden in a build slice. The build slices that touch a Q (notably T-NEW-2 on Q1, T-NEW-3 on Q2, T-NEW-12 on Q3, T-NEW-7 on Q4) MUST surface the relevant default in the slice body so the human can re-confirm at that point.

| Q | Default | Slice that consumes it |
|---|---|---|
| Q1 — Free drivers scope | Globally visible always; campaigns expressed as weight-change pattern with D9 audit-trail | T-NEW-2 (`policy/value-drivers.yaml` schema), T-NEW-5 (`fw bvp weight`) |
| Q2 — Cost fallback when blast_radius unknown | T-shirt fallback at task creation (S=2, M=4, L=6, XL=8); auto-recompute from real `blast_radius` after first commit | T-NEW-3 (`cost_estimate:` field), T-NEW-4 (`fw bvp` cost composition) |
| Q3 — `fw arc abandon` LV/HC trigger | No auto-trigger; Watchtower passive surface with one-click pre-filled `fw arc abandon --reason "..."` | T-NEW-12 (`/bvp` quadrant), T-NEW-13 (`/arcs/<id>` extensions) |
| Q4 — TermLink estimator `fw resume` SLA | 10s hard cap; on timeout task flagged `unscored: true` and async sweep handles it later; resume not blocked | T-NEW-7b (sweep + resume fallback) |

---

## 2. Risks register (G2 — closes the §9 gap)

Build slices SHOULD cite the relevant row and confirm the mitigation lands in their ACs.

### R1 — Arc-grooming dependency stalls
- **Likelihood:** medium (at handoff time; **now: resolved** — A1 verified, decision GO landed)
- **Mitigation:** §11.5 dual-condition check blocked task creation; surfaced rather than silent-failed
- **Detection:** `.context/handovers/` mentions repeated "BVP handoff blocked on arc-grooming"
- **Status at 2026-05-19:** CLOSED — arc-grooming is in-progress at arc-005 with first deliverable shipped

### R2 — Scoring rubric (T-NEW-6) encodes hidden biases
- **Likelihood:** medium
- **Failure mode:** rubric drawn from a reliability-heavy period systematically over-scores D2; or examples encode the author's blind spot
- **Mitigation:** T-NEW-6 has explicit `[REVIEW]` Human AC ("Worked examples reflect AEF's actual values, not hallucinated framings"); determinism is necessary but not sufficient — taste call is human
- **Detection:** Coherence audit (T-NEW-11) starts firing systematically on one driver — that pattern indicates rubric bias, not arc-mis-scoring
- **Build-slice impact:** T-NEW-6's Human AC is load-bearing; do not classify as `[REVIEWER]`

### R3 — TermLink estimator unstable across runs (A3 fails)
- **Likelihood:** medium
- **Failure mode:** same task body, different scores in separate sessions
- **Mitigation:** T-NEW-7 has explicit determinism AC blocking merge until ±1 stability is shown over 20 historical tasks; rubric tightening is the fallback path
- **Detection:** Determinism test failure during T-NEW-7 acceptance
- **Build-slice impact:** T-NEW-7a (harness) MUST establish the determinism measurement protocol BEFORE T-NEW-7b (sweep) attaches

### R4 — Cost formula (A6) systematically wrong
- **Likelihood:** medium
- **Failure mode:** HV/LC tasks turn out expensive in practice (or vice versa) — composite weighting wrong
- **Mitigation:** T-NEW-12 has Human AC spot-check ("≥4/5 placements match intuition"); 30-day review window per A6
- **Detection:** Auto-promote (T-NEW-14) regularly hits tasks that turn out hard to complete — i.e. the policy fires on tasks the human wouldn't have prioritised
- **Build-slice impact:** T-NEW-14a's log MUST capture enough metadata (bvp_norm, cost_estimate, blast_radius, tier, effort) to reconstruct the formula's reasoning post-hoc

### R5 — Agent manufactures arc-scoped drivers to look thorough (D6 failure)
- **Likelihood:** medium
- **Failure mode:** primary agent suggests 3 generic drivers per arc to "fill the slot" rather than proposing zero and recommending `--none`
- **Mitigation:** T-NEW-9 docs MUST include the verbatim "manufacturing drivers is worse than proposing zero" criterion; D6 quality requirement (rationale must explain what driver distinguishes that globals don't)
- **Detection:** Audit pattern — arcs with 3 scoped_drivers whose rationales repeat or are generic; ratio of `--none --justification` invocations vs affirmative approvals trends to 0
- **Build-slice impact:** T-NEW-9 wording is load-bearing; do not paraphrase

### R6 — `fw bvp weight` with insufficient rationale pollutes audit log
- **Likelihood:** low
- **Failure mode:** rationale field accepts thin text ("update", "tweak"); weight history becomes uninterpretable
- **Mitigation:** T-NEW-5 §ACD agent-gate enforces ≥30-char rationale (same shape as `fw arc close --justification`); refuses under `$CLAUDECODE=1`
- **Detection:** Periodic weight-history review surfaces entries with thin rationale
- **Build-slice impact:** T-NEW-5 AC MUST include the 30-char minimum AND the $CLAUDECODE=1 refusal test

### R7 — Auto-promote (T-NEW-14, opt-in) escalates over time
- **Likelihood:** medium-low
- **Failure mode:** human enables `auto_promote.enabled: true` once during a focused period, then forgets; framework promotes tasks the human wouldn't have approved
- **Mitigation:** `max_concurrent: 1` default (single promotion at a time); auto-promote log reviewable; policy is one config edit to disable
- **Detection:** Auto-promote log shows tasks the human wouldn't have prioritised — surfaced in periodic review (e.g. as a Watchtower nudge)
- **Build-slice impact:** T-NEW-14b's enabling path SHOULD include a "remind me in 30 days to review" pre-stage (cron or task)

### R8 — `proposed_scoped_drivers:` grows unbounded (D7 append-only persistence)
- **Likelihood:** low
- **Failure mode:** arc YAMLs accumulate suggestion events; Watchtower render slow; YAML size hits multi-KB
- **Mitigation:** Re-suggestions are rare (one-shot at major focus shifts); each event is a small YAML structure (≤10 entries × ~100 chars)
- **Detection:** Arc YAML size monitoring; if any arc exceeds 50 KB, investigate
- **Build-slice impact:** None — this is operational monitoring, not a build constraint

### R9 — Scoring rubric, once published, is hard to walk back
- **Likelihood:** medium
- **Failure mode:** agents (TermLink workers AND human cognitive frames) train against the rubric; bad rubric → bias propagates
- **Mitigation:** Rubric is versioned in git; bad versions can be replaced; determinism property means a rubric update re-scores all tasks consistently (no migration needed because scores are live-computed per D9)
- **Detection:** Per-driver score distribution should be roughly stable over time; sudden shifts after a rubric edit indicate impact; if shift is unexpected, revert
- **Build-slice impact:** T-NEW-6's worked examples are versioned content; treat with same care as code, not docs

**No one-way doors** — every BVP mechanic can be disabled (auto-promote off, estimator stopped, weights reset to neutral, rubric versions reverted) and the framework continues to function as before.

---

## 3. Assumption-review schedule (G7 — closes the unscheduled-review gap)

Each assumption has a deferred verification point. Capture as `revisit_at:` markers on the appropriate slice, or as a follow-up audit cron job.

| Assumption | Re-evaluation trigger | Owner | Method |
|---|---|---|---|
| A1 — arc-grooming dependency | **VERIFIED at filing** | — | Closed; no further review needed |
| A2 — audit YAML-parse accepts unknown fields | T-NEW-3 spike (filing time) | T-NEW-3 author | Hand-edit a task with `bvp_scores:`, run `fw audit`, confirm pass |
| A3 — TermLink estimator cost (<5s, <2k tokens/task) | T-NEW-7a build | T-NEW-7a author | Run worker against 20 historical `.tasks/completed/`, record per-task latency and tokens; fail if ≥3 outliers |
| A4 — Primary agent context sufficient for arc-scoped-driver suggestions | After first 3 arcs use the workflow (post T-NEW-9 + T-NEW-10) | Whoever observes the 3rd arc | Evaluate: did rationales differentiate vs globals, OR was `--none` correctly recommended? If ≥1 of 3 produced hollow suggestions, file a follow-up for heavier-context mechanism |
| A5 — Humans use `fw arc show-suggestions` | 3 months after first arc with persisted `proposed_scoped_drivers:` | Next handover cycle | `git log` for `fw arc show-suggestions` invocations; if zero, revisit D7 persistence model |
| A6 — Composite cost formula (0.6/0.3/0.1) accurate | 30 days after T-NEW-14a ships (auto-promote log accumulates) | Human via Watchtower review | Manual sample 5 tasks per quadrant; if <70% accuracy, file re-weighting follow-up |

**Recommendation for build slices:** every slice that operationalises an assumption should write a `revisit_at:` field with the expected review date. Watchtower's stale-arc/stale-task audit (T-1855) then surfaces unreviewed assumptions automatically.

---

## 4. Conceptual framings (G9 — load-bearing for build decisions)

These framings shape DECISIONS that look mechanical at the surface. Build agents reading slice ACs without context will optimize the wrong thing.

### F4-deep: "Classifier vs collaborator"

The split between TermLink estimator (D4 → T-NEW-7) and primary-agent driver-suggester (D5 → T-NEW-9) maps to a deeper distinction:

- **Classifier work** (BVP estimator): continuous, statistical, rubric-driven, low-temperature, reused thousands of times, *deterministic-by-design*. The rubric is the reusable state; preload pays. The worker doesn't reason about the task — it *categorises* it.
- **Collaborator work** (arc-scoped-driver suggester): rare (≤10 events/year), one-shot per arc, interpretive (reads prose), *judgement-by-design*. No preload benefit — each arc is fresh material. The agent doesn't categorise the arc — it *reasons about* it.

**Build implication:** if T-NEW-7a's prompt looks like T-NEW-9's prompt, one of them is wrong. The estimator should look like a scoring rubric application; the suggester should look like a conversation about purpose.

### D7-reframe: "Not for audit, for reuse"

The initial framing of `proposed_scoped_drivers:` was "audit trail — keep so we can show what the agent recommended". The human reframed during dialogue: **the field exists for future reuse, not retrospective audit.**

Mechanically identical (both persist the data). Materially different:

- Audit framing → field is informational, low-priority, can be archived or compressed
- Reuse framing → field is operational, must remain readable, `fw arc show-suggestions` must be discoverable and ergonomic

**Build implication:** T-NEW-10's `fw arc show-suggestions` is NOT a debug verb — it's a workflow verb the human uses when arc focus shifts. Surface it in CLAUDE.md alongside `fw arc focus`, not buried in arc-management internals.

### D8 — Sovereignty exercised at policy-edit time, not per task

Auto-promote (T-NEW-14) is opt-in via `policy/value-drivers.yaml`. Editing `auto_promote.enabled: true` IS the sovereignty exercise; the framework then enforces a pre-authorised rule per task.

Same shape as Tier-0 destructive-command pre-approvals: the human authorises a category, not individual instances. The integrity of the model rests on the policy file being *deliberately* edited (not silently default-on, not auto-suggested into edit).

**Build implication:** T-NEW-14b's enabling-path MUST require explicit `--enable --rationale "..."` from `fw bvp`, not just a YAML edit anyone could make accidentally. The enabling action is itself a §ACD-shape gate.

### F8-mechanic: Cost composition is approval-cost AND structural-cost AND labour-cost

The composite (`0.6 × blast_radius + 0.3 × tier + 0.1 × effort`) blends three *kinds* of cost:

- `blast_radius` (structural cost) — auto-computed, deterministic, fabric-derived
- `tier` (approval cost) — Tier 0 = needs human approval; Tier 2 = free; Tier 1/3 in between
- `effort` (labour cost) — sourced from `fw metrics` episodic-memory predictions; data quality scales with similar-task history

The 0.6/0.3/0.1 weighting reflects *reliability of the signal*, not relative importance of the cost dimension. blast_radius is reliable; effort is noisy; tier is policy-driven.

**Build implication:** T-NEW-4's `fw bvp` cost detail MUST show the three components separately, not just the composite. Otherwise human can't diagnose miscalibration (R4).

### Geelen 2019 BVP origin

The mechanic traces to a 2019 Dimitri Geelen blog post on Business Value Points for backlog prioritisation: `https://blog.dimitrigeelen.com/2019/10/using-business-value-points-for-backlog-prioritisation/`.

AEF adapts (not adopts) the mechanic:
- Original blog: free-form value drivers per project
- AEF: 4 constitutional protected drivers + up to 5 free, capped at 9 total (the "add-one-drop-one" mechanic)
- Original blog: BVP × cost quadrant for "reserved budget for low-risk, low-cost, high-value work"
- AEF: same quadrant, but auto-promote OFF by default (sovereignty boundary, F7)

**Build implication:** T-NEW-15 canonical doc (`040-ValueDrivers.md`) MUST cite the origin AND distinguish the AEF adaptations (protected drivers, sovereignty model). Future authors must understand both lineage and divergence.

### Reversibility statement

> No one-way doors in this handoff. The BVP system is additive — every mechanic can be disabled (auto-promote OFF, estimator stopped, weights reset to neutral) and the framework continues to function as before.

**Build implication:** every slice MUST preserve this property. If any T-NEW-N slice introduces a mechanic that cannot be cleanly disabled (data corruption on disable, irreversible state migration, dependency that breaks vanilla `fw` flow), that's a red flag — back out and redesign.

---

## 5. Cross-slice dependency graph (G5 — closes the implicit-deps gap)

```
                              T-1915 (decide-go, this artefact)
                                          │
                  ┌───────────────────────┼───────────────────────┐
                  │                       │                       │
              T-NEW-2                  T-NEW-6              T-NEW-9
        (policy/value-drivers.yaml) (scoring rubric)  (driver-suggest workflow doc)
                  │                       │                       │
                  │                       │                       │
              T-NEW-3                     │                       │
        (frontmatter schema)              │                       │
            │       │                     │                       │
          T-NEW-4   │                     │                       │
        (fw bvp R/O)│                     │                       │
            │       │                     │                       │
          T-NEW-5  T-NEW-7a ──── T-NEW-7b │                       │
        (mutating  (harness   (sweep +    │                       │
         verbs)     +trigger)  fw resume) │                       │
            │       │                     │                       │
            │     T-NEW-8 ────────────────┘                       │
            │   (fw bvp confirm)                                  │
            │       │                                             │
            │     T-NEW-11 ───────────────────────────── T-NEW-10
            │   (coherence audit)                  (fw arc approve-driver
            │       │                               + show-suggestions)
            │       │                                     │
          T-NEW-12a───T-NEW-12b           T-NEW-13 ───────┤
        (static scatter)(live sliders)   (/arcs/<id> ext)
            │                                       │
          T-NEW-14a───T-NEW-14b                     │
        (promote logic) (enable + cron)             │
                  │                                 │
                  └─────────────T-NEW-15────────────┘
                           (040-ValueDrivers.md
                            + FRAMEWORK.md updates)
```

**Critical paths (ship-blocking):**

- **Scoring path:** T-NEW-2 → T-NEW-3 → T-NEW-6 → T-NEW-7a → T-NEW-8 (must ship in this order; T-NEW-7a's determinism AC depends on T-NEW-6's rubric being ratified; T-NEW-8 needs T-NEW-7a's output schema)
- **Arc-driver path:** T-NEW-9 → T-NEW-10 → T-NEW-13 (must ship in this order; T-NEW-10 needs T-NEW-9 workflow doc to be discoverable)
- **Doc path:** T-NEW-15 ships LAST — it documents the post-implementation state, not the planned state

**Parallelisable:**

- T-NEW-2, T-NEW-6, T-NEW-9 can all start as soon as T-1915 lands (independent roots)
- T-NEW-7a and T-NEW-10 can run in parallel after their respective prereqs ship
- T-NEW-12a (static read-only) can start as soon as T-NEW-4 ships; doesn't need T-NEW-5

**Arc-006 transition gate:** arc-006 stays `draft` until T-NEW-10 ships AND a human runs `fw arc approve-driver value-prioritisation ...`. The arc's own driver-decision gate is one of its constituent build slices — circular by design, broken by `fw arc approve-driver --i-am-human` once the verb exists.

---

## 6. Build-slice manifest (G1+G3+G6+G8 references)

Each slice is filed as its own task with full ACs, verification, and components. This manifest is the index — the per-slice task bodies carry the detail.

| Task ID | Slice | Type | Splits | Files touched | Deps |
|---|---|---|---|---|---|
| T-1917 | T-NEW-2 — `policy/value-drivers.yaml` schema | build | — | `policy/`, `policy/value-drivers.yaml` | T-1915 |
| T-1918 | T-NEW-3 — frontmatter schema extensions | build | — | `.tasks/templates/zzz-default.md`, `lib/arc.sh`, `CLAUDE.md` | T-1917, arc-grooming T-NEW-2 |
| T-1919 | T-NEW-4 — `fw bvp` read-only CLI | build | — | `lib/bvp.sh`, `bin/fw` | T-1918 |
| T-1920 | T-NEW-5 — `fw bvp weight`/`driver` mutating + audit | build | — | `lib/bvp.sh`, `.context/bvp-weight-history.yaml` | T-1917, T-1919 |
| T-1921 | T-NEW-6 — `policy/bvp-scoring-rubric.md` | build | — | `policy/bvp-scoring-rubric.md` | T-1915 |
| T-1922 | T-NEW-7a — `bvp-estimator` harness + ready-trigger | build | parent T-NEW-7 | `agents/termlink/bvp-estimator/` | T-1918, T-1921, A3 |
| T-1923 | T-NEW-7b — sweep + `fw resume` SLA fallback | build | parent T-NEW-7 | `agents/termlink/bvp-estimator/`, `bin/fw resume` | T-1922 |
| T-1924 | T-NEW-8 — `fw bvp confirm` | build | — | `lib/bvp.sh` | T-1922 |
| T-1925 | T-NEW-9 — arc-scoped-driver suggestion workflow docs | build | — | `CLAUDE.md`, `AGENTS.md` | T-1918 |
| T-1926 | T-NEW-10 — `fw arc approve-driver` + `show-suggestions` | build | — | `lib/arc.sh`, `bin/fw`, `.context/audits/arc-scoped-driver-bypass.jsonl` | T-1918, T-1925 |
| T-1927 | T-NEW-11 — per-driver coherence audit | build | — | `agents/audit/audit.sh` | T-1924, arc-grooming T-NEW-3 |
| T-1928 | T-NEW-12a — `/bvp` static scatter (read-only) | build | parent T-NEW-12 | `web/blueprints/bvp.py`, `web/templates/bvp.html` | T-1919 |
| T-1929 | T-NEW-12b — `/bvp` live sliders + commit | build | parent T-NEW-12 | `web/blueprints/bvp.py`, `web/templates/bvp.html` | T-1928, T-1920 |
| T-1930 | T-NEW-13 — `/arcs/<id>` extensions | build | — | `web/blueprints/arcs.py`, template | T-1926, T-1927 |
| T-1931 | T-NEW-14a — auto-promote logic + log (off by default) | build | parent T-NEW-14 | `lib/bvp.sh`, `.context/bvp-auto-promote-log.yaml` | T-1917, T-1924 |
| T-1932 | T-NEW-14b — enabling + cron/trigger wiring | build | parent T-NEW-14 | `lib/bvp.sh`, cron registry | T-1931 |
| T-1933 | T-NEW-15 — `040-ValueDrivers.md` + FRAMEWORK.md updates | build | — | `040-ValueDrivers.md`, `FRAMEWORK.md` | T-1917,1920,1924,1926,1932 |

**Total: 17 build slices** (T-1917–T-1933, allocated alphabetically-by-creation by T-1916 enrichment).

---

## 7. Specific mechanics (G4 — closes the under-captured-mechanics gap)

These mechanic details must be preserved in build slices, not lost to handoff narrative:

### M1 — Driver cap and "add-one-drop-one" rule
- 4 protected drivers (D1/D2/D3/D4) + up to 5 free drivers = max 9 globals
- When 9 slots filled and user requests `fw bvp driver --add "new"`: refuse OR drop the lowest-weighted free driver (configurable; default refuse, require explicit `--drop <id>` flag)
- **Lands in:** T-1920 (T-NEW-5) ACs

### M2 — Scoped-driver weight cap ≤6
- Arc-scoped drivers (max 3 per arc) cannot exceed weight 6 — the maximum free-driver weight 9 minus an explicit "scoped < global" gap
- Rationale: scoped drivers must be additive, not overwhelming
- **Lands in:** T-1926 (T-NEW-10) ACs (`fw arc approve-driver --weight N` rejects N>6)

### M3 — `bvp_scores_proposed:` v2 delta semantics
- Estimator never overwrites confirmed `bvp_scores:`
- If estimator's score differs from confirmed by ≥2 on ANY driver: write a v2 delta entry into `bvp_scores_proposed:` with timestamp, surfaced for human review
- If difference is <2 on every driver: estimator stays silent (no churn)
- **Lands in:** T-1922 (T-NEW-7a) ACs (worker behavior) AND T-1923 (T-NEW-7b) ACs (sweep)

### M4 — Coherence audit thresholds (per-driver, not aggregated)
- Arc claims D_n score ≥4 AND ≥70% of constituents score D_n ≤1 → WARN
- Per-driver, separate warnings per mismatched driver
- Non-blocking — `fw audit` exit code unaffected
- Thresholds (4, 70%, 1) configurable via constants
- **Lands in:** T-1927 (T-NEW-11) ACs

### M5 — Auto-promote thresholds (default values)
- `bvp_norm_min: 0.85` (top ~15% by BVP)
- `cost_max: 1` (very low-cost only)
- `max_concurrent: 1` (one auto-promotion at a time)
- All three configurable in `policy/value-drivers.yaml`
- **Lands in:** T-1917 (T-NEW-2 schema), T-1931 (T-NEW-14a logic) ACs

### M6 — §ACD gate shape for `fw bvp weight` and `fw arc approve-driver`
- Both verbs refuse under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower`
- Both require `--rationale` (≥30 chars) or `--justification` (≥30 chars)
- Both log invocations including bypasses to `.context/audits/` audit log
- **Lands in:** T-1920 (T-NEW-5 weight), T-1926 (T-NEW-10 approve-driver) ACs

### M7 — Full CLI verb surface
```
fw bvp                         # rank all tasks by current BVP
fw bvp T-<id>                  # detail per task (per-driver scores + composite)
fw bvp arcs                    # rank arcs by global-driver BVP only
fw bvp --quadrant {hv-lc,hv-hc,lv-lc,lv-hc}   # filter by quadrant
fw bvp weight --set Dn=N --rationale "..."    # change weight, §ACD-gated
fw bvp driver --add "name" --weight N         # add free driver
fw bvp driver --remove <id>                   # remove free driver (refuses on D1-D4)
fw bvp confirm T-<id> [--override Dn=N ...]   # confirm proposed → sticky
fw arc approve-driver <arc> "<name>" [--weight N]   # affirmative driver decision
fw arc approve-driver <arc> --none --justification "..."  # justified-zero
fw arc show-suggestions <arc>                 # render proposed_scoped_drivers history
```
- **Lands in:** T-1919 (T-NEW-4 read-only), T-1920 (T-NEW-5 weight+driver), T-1924 (T-NEW-8 confirm), T-1926 (T-NEW-10 arc verbs) ACs

---

*End of inception research artefact. Source handoff sections: §3 (Findings), §4 (Decisions), §4a (Assumptions), §6 (Questions), §7 (Tasks), §9 (Risks), §10 (Dialogue log), §11 (Artifacts).*
