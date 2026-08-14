# T-2679 — Determinism Graduation Tripwire: structural enforcement inception

**Status:** exploration · **Created:** 2026-07-29 · **Workflow:** inception (one question, one go/no-go)

## The Question

The framework's maturity ladder moves work from stochastic (agent initiative) to
deterministic (scripts, gates, cron), with the agent's terminal role being out-of-band
monitoring and exception management. That last stage assumes the deterministic tier
**fails loudly**. Nothing enforces this at graduation time — so deterministic components
are born without tripwires, drift silently, and the exception manager never receives an
exception.

**One question:** what is the enforceable form of the rule *"nothing graduates to the
deterministic tier without shipping its own tripwire"* — and what is the minimal first
slice?

## Evidence Base (why this is a class, not an incident)

Four instances inside one week, all the same shape — a deterministic component whose
frozen world-assumption drifted, failing with exit 0 and plausible output:

| Instance | Component | Silent failure | Undetected for |
|----------|-----------|----------------|----------------|
| T-2672 | `agents/healing/lib/resolve.sh` | fixed-indent emit against drifted store shape | months |
| T-2676 | `lib/harvest.sh` learnings/patterns greps | 4-space greps vs 2-space live shape — "No learnings found" always, 549:0 miss ratio | months |
| T-2677 | `agents/audit/audit.sh` graduation counter | 2-space-only ID grep counted 0 of 550; the ≥20 promote-suggest branch **never fired in its life** | since inception |
| 2026-07-29 (near-miss) | rail dry-run anchor for aef-knowledge-leveling | `if lid in promoted_ids:` occurs 3× in promote.sh; occurrence-1 anchoring extracts ZERO tokens | caught at authoring |

Prior art inside the framework:
- **Conformance rails (T-2621+, arc-014)** — exactly this rule already applied to
  maps-vs-code: a registered reality-check that re-verifies "stabilized" daily. Proven
  pattern; the RED dispatch-loop rail demonstrated loud honest failure.
- **Loud-fail already implemented for one probe family** — `tools/conformance-registry.yaml`
  states it as a rule for `vocabulary-set` source extraction: *"Empty source extraction is
  a LOAD ERROR (stale anchor must fail loudly)"*, enforced at `tools/corpus_conformance.py`.
  The doctrine this inception proposes is therefore not novel — it is already law on the
  maps-vs-code axis and merely unextended to script-vs-world.
  *(Correction: an earlier draft cited "G-001 loud-fail" as prior art here. That was a
  cross-register citation error — this repo's G-001 is "Enforcement tiers — Tier 0
  spec-only", closed; the loud-fail G-001 lives in the upstream/832 gap numbering. Left
  visible rather than silently deleted, per the same honesty convention the corpus maps
  use for dead legs.)*
- **L-291 / T-1501 toolchain-build rule** — same doctrine at the Verification gate:
  "the framework runs only what you write" → forgotten build command ships broken DLLs.
- **T-1828 / G-040 proxy class** — gates that verify artifact-exists rather than
  behavior-fires; the tripwire rule is the behavioral complement.

## The Doctrine (from operator dialogue, 2026-07-29)

Operator's articulation of the ladder:
1. Agent statelessness is compensated by context injection (tasks, arcs, context
   fabric, component fabric, handover + /resume protocols).
2. The framework runs a stepped model moving work **from stochastic to deterministic**.
3. Once deterministic — *proven, tested, stabilized* — the agent's role inverts to
   **monitoring + out-of-band exception management**.

Agent's counter-finding accepted into the doctrine: *"proven, tested, stabilized" is a
timestamp, not a state.* The deterministic tier decays silently unless each component
carries a tripwire that converts drift into a loud signal the exception manager can
consume. Silent-zero output is indistinguishable from legitimately-empty — forbidden at
graduation.

## Candidates

### A — Assumption-rail registry (runtime reality-check) · KEYSTONE CANDIDATE
Generalize the conformance-rail registry beyond maps: any deterministic component may
register **world-assumption probes** (e.g. "this grep returns >0 matches against the
live store", "this anchor is unique in its source file", "store shape matches the
pattern this script consumes"). Audit runs them daily; failures are WARN/FAIL — loud,
out-of-band, exactly the stage-4 exception feed.
- **For:** the only candidate that checks *reality* (behavior against live state), not a
  proxy. Would have caught all 4 evidence instances. Pattern already proven for maps.
- **Against:** new registry surface + per-component adoption effort; needs a probe
  vocabulary (count-floor, uniqueness, shape-match) designed carefully to stay cheap.
- **Blast radius:** audit.sh (new section), a registry file, probe runner lib. No
  behavior change to gated components.

### B — Author-time graduation gate
Task-close gate / reviewer detector: a task touching deterministic surfaces (`lib/`,
`agents/**/*.sh`, cron generators) must ship or update a pinned assumption test (bats)
and declare its loud-fail path.
- **For:** catches at the cheapest moment (authoring); mirrors L-291's table discipline.
- **Against:** mechanical detection of "touched a deterministic surface" is fuzzy →
  FP noise; verifies the *test artifact exists*, not that assumptions hold over time —
  partially the T-1828 proxy class again. Complements A; cannot replace it.

### C — Silent-zero lint (static scan)
Audit/reviewer static detector for the exact bug family: grep/count patterns against
`.context/` stores with zero-fallbacks (`|| echo 0`, `2>/dev/null` + count usage,
fixed-indent store greps).
- **For:** cheap, immediate, would have flagged T-2676/T-2677 verbatim.
- **Against:** narrow — catches the grep family only, not anchor ambiguity or future
  shapes; pattern list needs curation.

### D — Prose-only practice (CLAUDE.md paragraph)
- **Rejected by the doctrine itself** — advisory prose is the layer whose failure this
  inception exists to remediate. Listed for completeness.

## Recommendation

**Recommendation:** GO — Candidate A as keystone, Candidate C as first slice, B deferred.

**Rationale:** A is the only reality-checking option and matches the stage-4 doctrine
(the tripwire IS the exception feed); rails prove the pattern works and stays
maintainable in this codebase. C is a same-week cheap win that retires the known bug
family while A's probe vocabulary is designed. B is proxy-shaped; revisit only if A's
adoption lags — a gate can then force probe *registration*, which is a legitimate proxy
once the probe itself checks reality.

**Evidence:**
- 4 instances of the silent-drift class in one week (table above), 3 of them months-long
  blind spots, 1 caught only because a pair-round forced re-derivation.
- The audit graduation counter (T-2677) proves the severity ceiling: a deterministic
  component can be dead for its entire lifetime with zero signal.
- Conformance rails (arc-014) demonstrate the remediation pattern already works here for
  the maps-vs-code axis — this generalizes the same mechanic to script-vs-world.

Proposed build slices on GO (separate build tasks, not built under this ID):
1. **Slice 1 (C):** silent-zero / fixed-indent-store-grep detector → audit WARN section
   + reviewer pattern. Small, testable, immediate.
2. **Slice 2 (A-core):** probe registry (sibling to or inside the map-rail registry) +
   runner + audit section, seeded with probes for the 4 evidence sites (harvest shape,
   audit counter floor, resolve.sh emit shape, promote.sh anchor uniqueness).
3. **Slice 3 (A-adoption):** graduation checklist wiring — new deterministic components
   register probes at ship time (template + docs; gate decision deferred per IW-4).

## Assumptions to validate

- A-1: probe vocabulary of ~3 primitives (count-floor, uniqueness, shape-match) covers
  ≥80% of the known drift class. (Spike 1.) — **VALIDATED**, see below.
- A-2: daily audit cost of running probes is negligible (<2s for ~20 probes). (Spike 3.)
  — **VALIDATED with a design constraint**, see below.
- A-3: rail-registry generalization does not collide with T-2652's rail-generalization
  inception scope — merge, sequence, or independent. (Spike 2 / IW-3.) — **VALIDATED**,
  no collision: T-2652 is *completed*, and is prior art rather than a competitor.

## Spike Results (run 2026-07-29, pre-decision)

### Spike 1 — probe-vocabulary coverage (IW-1, A-1) · PASS

| Site | Assumption that silently broke | Primitive |
|------|-------------------------------|-----------|
| T-2676 harvest.sh | store greps return matches | **count-floor** (≥1) |
| T-2677 audit counter | learning-ID count is real | **count-floor** (≥ known floor) |
| T-2672 resolve.sh | appended entry is readable by the canonical reader | **shape-match** (round-trip) |
| promote.sh rail anchor | anchor string identifies one site | **uniqueness** (== 1) |

4 of 4 known drift sites are expressible in the 3 candidate primitives — no bespoke probe
needed. One adjacent case does **not** fit and is deliberately excluded: the T-2674
vendor-includes omission (`status-transitions.yaml` missing from `do_vendor`) is
*set-completeness*, not assumption-drift — a different class, candidate for a 4th
primitive later or for its own gap. Recording it here so the scope boundary is explicit
rather than discovered mid-build.

### Spike 2 — registry collision check (IW-2, IW-3, A-3) · PASS, and it reshapes IW-2

`tools/conformance-registry.yaml` + `tools/corpus_conformance.py` (T-2652 slice 1 /
T-2654) are **keyed by `map_id`** — the entry contract is "which corpus map has a rail,
and what it conforms against". A deterministic script with no corpus map has no key in
that space, so assumption probes are a **sibling registry, not a new primitive inside the
existing one**: same checker mechanic, same audit-section reporting shape, different key
space (component/script path instead of map id).

Two consequences worth carrying into the build:
1. **The loud-fail doctrine is already law on the map axis.** The registry's own comment
   requires empty source extraction to be a LOAD ERROR, "stale anchor must fail loudly".
   Slice 2 should reuse that exact stance rather than invent one.
2. **T-2652 is completed, not in flight** (`.tasks/completed/T-2652-…`), along with
   T-2654 (primitive library), T-2658/T-2659, T-2664. So there is no scope contention —
   this is a follow-on that copies a proven pattern onto a second axis.

### Spike 3 — probe cost (A-2) · PASS, with a binding design constraint

Measured on the live stores:

| Probe form | Cost each | 20 probes |
|------------|-----------|-----------|
| shell grep against a store | ~6 ms | **~0.12 s** |
| `python3 -c "yaml.safe_load(...)"` | ~630 ms | **~12.6 s** |

A-2 holds **only** for shell-primitive probes. A per-probe Python interpreter blows the
budget by 6×. Design constraint for Slice 2: probes are shell primitives, or every
parse-requiring probe is batched into a **single** interpreter process for the whole run.
This is exactly the kind of assumption that, left undiscovered, would have made the
tripwire mechanism itself the next thing quietly disabled for being slow.

### Spike 4 — exception surface (IW-5) · NOT RUN
Deferred to the build slice; the default (audit WARN section, mirroring
`check_map_conformance`) is adopted on prior-art grounds. See IW-5 disposition.

## Open Questions (mirrored from task file — dispositions live there)

- **IW-1** probe vocabulary: 3 primitives sufficient, or bespoke per site?
- **IW-2** one registry (two primitive families) or a separate surface?
- **IW-3** collision/subsumption with T-2652 rail-generalization?
- **IW-4** gate-enforced graduation vs adoption-led with audit surfacing unprobed components?
- **IW-5** operator-facing exception surface: audit WARN, Watchtower panel, or ntfy push?

## Dialogue Log

**Round 1 (operator):** *"why claude code dont understand that … though we had
deterministic scripts"* — challenge: why does drift persist despite pinned-down
deterministic tooling.

**Agent reflection:** (1) agent re-infers per session, never durably "understands" —
knowing lives in prose, which is advisory and skippable; every lesson that stuck became
a hook or gate; (2) deterministic scripts are frozen assumptions — repeatable, not
correct; vendoring freezes them harder (status-transitions.yaml enum freeze, T-2674);
(3) the dangerous joint is agent-trusts-script: exit-0 with plausible output is taken as
ground truth by the one party that could have questioned it.

**Round 2 (operator):** corrected and extended all three: (1) context injection (tasks,
arcs, context fabric, component fabric, handover + /resume) IS the designed compensation
for agent statelessness — the answer to "agent doesn't remember" is architectural, not
aspirational; (2) the framework deliberately runs a 3-4 stepped stochastic→deterministic
model; (3) once deterministic (proven/tested/stabilized) we monitor, and the agent's role
inverts to **out-of-band exception management**.

**Agent synthesis:** ladder affirmed and mapped to its embodiments — knowledge-leveling
lifecycle (insight → learning → dormant → practice → protocol → gate), the A→D error
escalation ladder, inception → build → cron, draft → pair-rounds → promoted → railed
maps. Role inversion named: early-stage the agent works and the framework watches;
late-stage the framework works and the agent watches. Two weak joints identified:
(a) middle rungs are manual and partly dead — the knowledge-leveling map's own `DEAD:`
findings (no ratification, dormant wait nothing crosses, candidates tier vestigial;
550 learnings with the promotion nudge firing for the first time this week);
(b) **"stabilized" is a timestamp, not a state** — and all three of this week's corpses
failed *silently*, so the exception manager had no exception to manage. Monitoring
cannot catch what never surfaces. Missing rule proposed: **promotion to the deterministic
tier requires shipping a tripwire** (assumption probe + loud-fail path), one commit, same
producer/consumer parity discipline as L-399.

**Round 3 (operator):** *"ok what do you suggest for structural remediation, incept
build?"* → incept, not build: three enforceable shapes with different blast radii exist
(A/B/C above) and the scope-fence choice is the operator's. Consistent with the standing
"mitigation is not prevention" discipline (G-019) — the fixes for T-2672/T-2676/T-2677
were mitigation; this inception is the prevention leg.
