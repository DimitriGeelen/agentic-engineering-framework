# T-1443: Independent Reviewer Agent — TermLink-Dispatched, Evidence-Gated

## Status
**Phase:** Captured (blocked on T-1442 GO)
**Linked:** T-1442 (I-A AC validation default-flip — prerequisite)

## Problem

If T-1442 lands a default-flip toward mechanical verification with persisted evidence, *something* must judge whether the recorded evidence is sufficient to tick an Agent AC. Today the agent self-assesses (P-011 only checks exit codes). A second-opinion check would close the loop and make the system antifragile to a single agent's blind spots.

## Framing (inherits from T-1442)

Same North Star: frictionless development, preserve 4 directives, remove friction without removing rigor. This inception adds the mechanism that *enforces* the rigor without the human bottleneck.

## Proposal Sketch (subject to dialogue)

A separate agent profile (e.g. `agents/reviewer/`), dispatched **independently via TermLink** (true context isolation, not Task tool sub-agent), that:

1. Reads recorded evidence (shape determined by I-A / T-1442)
2. Judges whether each Agent AC is properly evidenced
3. **May auto-tick Agent ACs** when evidence is sufficient (confirmed by user 2026-04-25)
4. Escalates to human only when reviewer says "needs human" — judgment-level Human ACs preserved
5. Output is an audit trail (where? — open question)

## Open Questions (in scope for this inception)

- **Q4 — Profile scope**: generic AC reviewer, or specialised one-per-tier (programmatic-reviewer / e2e-reviewer / ui-reviewer)? Hybrid (generic dispatcher → specialist sub-routines)?
- **Q5b — Slot in existing flow**: where does reviewer fire — pre-`work-completed` gate, post-`work-completed` validator, on-demand `fw task review-evidence`?
- **Q (emergent) — Output protocol**: `fw bus post` envelope? Append to task body Updates section? Watchtower review page? All three?
- **Q (emergent) — Authority bounds**: explicit list of what reviewer **cannot** do (e.g. cannot tick Human ACs, cannot decide inceptions, cannot mark `work-completed` itself).
- **Q (emergent) — Failure mode**: reviewer says "evidence insufficient" — does that block, warn, or surface to human queue?
- **Q (emergent) — Reviewer's own auditability**: reviewer is an agent making decisions. Who reviews the reviewer? Sampling? Periodic audit of reviewer ticks?

## Confirmed-yes (locked, not in dialogue)

- Reviewer authority = **mechanical tick on Agent ACs only** (NOT Human ACs).
- Independent dispatch via **TermLink** (not Task tool sub-agent) — context-isolated.
- Sovereignty over Human ACs **preserved** — reviewer cannot escalate authority, only initiative.
- Two linked inceptions; this one waits for T-1442 GO before active dialogue.

## Pre-conditions

- T-1442 reaches GO with at least Q3 (trigger model) and Q1 (evidence shape) decided. Without those, this inception cannot meaningfully design the reviewer's input contract.

## Dialogue Log

### 2026-04-25 — Captured

Genesis dialogue lives in `docs/reports/T-1442-ac-validation-default-flip.md` § Dialogue Log. This task captured concurrently with horizon=next pending I-A's GO.

User answers relevant to this inception:
- Q2 ✅ "Auto-tick Agent ACs and only escalate Human ACs when reviewer says 'needs human'"
- Q4 → "incept that" (reviewer scope = explore here)
- Q5 → "incept that, think about our goals and purpose of framework and risks we are trying to manage while enabling frictionless development"

### 2026-04-25 — Inherited design from T-1442 dialogue (status still: captured, blocked)

T-1442's 6-turn dialogue resolved enough to constrain T-1443's design. Inherited constraints:

1. **Always-invoked, never optional** — reviewer fires on every `--status work-completed`. No skip path. No cache.
2. **Hard prereq gate** — reviewer's verdict structurally blocks status change. "Insufficient evidence" → `work-completed` rejected.
3. **Evidence quality assessment, not pass/fail** — reviewer must detect false-positive anti-patterns: tautology, empty output, mock-only, scope-narrowing, skip-as-pass.
4. **Layer 1 + Layer 2 consultation** — reviewer reads `policy/escalation-patterns.yaml` (mechanical patterns) AND task frontmatter (`risk`, `human_signoff`). Pattern match → escalate to human, regardless of evidence quality.
5. **Three-way verdict, not binary** — `mechanical-tick` / `needs-human` / `insufficient-evidence`. The third triggers the Model V re-run loop.
6. **Input contract specified** — reviewer reads task body `## Verification Output` summary + `docs/reports/T-XXX-evidence.md` full output + optional bus envelope.
7. **Daily cron ALSO uses reviewer** — Pass A re-validation invokes reviewer on fresh evidence; reviewer judges whether drift has occurred.

Spike list updated to add Spike F (anti-pattern catalogue) and Spike G (pattern-consultation interface).

### 2026-04-25 — Inherited Turn 7 (slash-command + orchestrator routing)

User raised in T-1442 dialogue: should reviewer be exposed via `/review` slash command + routed via orchestrator (T-1064) to appropriate model class?

**Answer:** Yes — strong architectural fit.
- `/review T-XXX` is the uniform entry point (slash-command surface)
- Behind it: orchestrator routes per task profile (Haiku for routine, Sonnet for standard, Opus for high-risk, external for specialised)
- Routing inputs: task `risk` + Layer 1 match + evidence size + AC count + blast-radius
- Same primitive as T-1064/T-1065 — no duplicate routing layer
- T-1443 becomes T-1064's first concrete consumer

**Spike B reframed** from "profile scope" to "routing strategy."
**Spike H added**: slash-command interface + orchestrator routing integration.
**Soft dependency:** T-1064 must be operational, or T-1443 ships with hard-coded default and swaps when T-1064 lands.

## Status (2026-04-25 update)
**T-1442 GO recorded.** Active dialogue underway. Spikes A, D, F (refactored), I resolved. Remaining: B, C, E, G (next), H.

## Dialogue Log (active session)

### 2026-04-25 — Turn 8: Spike A (reviewer interface)

Agent proposed structured envelope:
- **Input**: task file (frontmatter + agent_acs) + evidence (summary + full + optional bus) + context (commits + fabric blast-radius + Layer 1 patterns) + routing metadata (model_class + review_depth)
- **Output**: overall_verdict (mechanical-tick / needs-human / insufficient-evidence) + per-AC granular verdicts + reasoning + reviewer_signature + digest

Three baked-in shape decisions:
1. Output is structured envelope, not free-form text
2. Per-AC verdicts (granular) — reviewer acts per individual Agent AC, not whole task
3. Reviewer signature + digest for auditability + tamper detection

### 2026-04-25 — Turn 9: User question — how is "needs-human" established?

User flagged that my "needs-human" verdict was overloaded. Five distinct drivers identified:

1. **Original AC classification** — `### Human` vs `### Agent` heading at task creation
2. **Layer 1 mechanical patterns** — `policy/escalation-patterns.yaml` (T-1442)
3. **Layer 2 frontmatter** — `risk: high`, `human_signoff: required`
4. **Evidence anti-patterns at runtime** — reviewer-detected (Spike F)
5. **AC content semantic patterns** — subjective-judgment language (codifiable as Layer 1 sub-pattern)

**Verdict rule**: AC needs human if ANY driver fires (additive, not exclusive).

**Critical sovereignty rule**: Reviewer NEVER auto-ticks a `### Human` AC. Original classification is inviolable. Reviewer can only:
- Surface Human ACs with full evidence + recommendation
- Flag classification drift ("could be reclassified Agent")
- Pre-fill verification steps to speed human review

Refined per-AC envelope: `original_classification` + `drivers_evaluated` + `reviewer_judgment` + `classification_drift_flag` + `action`.

### 2026-04-25 — Turn 10: User asks for learning loop — Spike I emerges

User: *"want to emphasize... means to learn, where I can say don't ask me for this in the future or something like that?"*

Two feedback shapes identified:
- **A: "Don't escalate this pattern again"** — suppress matching Layer 1 pattern for fingerprint
- **B: "Reclassify this AC type as Agent"** — tune T-954 guidance, flag drift as resolved

Override mechanism designed:
- File: `policy/escalation-overrides.yaml`
- Per-override: source_pattern + scope (fingerprint, breadth) + action (suppress / downgrade-to-warn) + reason + created_by (always human) + created_at + expires_at + auto_revoke_triggers
- Watchtower UX: collapsed-by-default override checkboxes alongside Approve/Decline/Insufficient buttons
- Antifragility safeguards: auto-revoke on related-incident detection by Pass B audit cron, on concern register hits, on TTL expiry; surface for renewal

Sovereignty: human creates overrides; agent never; auto-revoke triggers respect human authority.

### 2026-04-25 — Turn 11: User emphasizes feedback UX is load-bearing

User: *"these UX capabilities for human to quickly consistently provide feedback is important for this to work well... frictionless feedback, makes regular feedback, pre-formatted feedback options with ability to expand, structured data signals."*

Seven UX principles locked:
1. Default path is one-click (a/d/i keyboard shortcuts)
2. Override options always visible, never required (collapsed-by-default but discoverable)
3. Pre-formatted choices first, free-text last
4. Consistent across every escalation (muscle memory)
5. Structured data only — no free-form classification
6. Aggregable + queryable — every click writes structured record to `.context/working/feedback-stream.yaml`
7. Reversible without penalty — every override has undo + TTL

Feedback stream feeds three downstream consumers: Layer 1 pattern catalogue, T-954 classification guidance, Watchtower analytics page.

### 2026-04-25 — Turn 12: Spike F (anti-pattern catalogue) seed

Agent drafted 12-category seed:
1. Tautology assertion
2. Empty-body test
3. Mock-only integration
4. Empty-output success
5. Skip-as-pass
6. Safety-mechanism bypass
7. Stale evidence
8. AC-verification mismatch
9. Output spoofing
10. Swallowed errors
11. Zero-test gaming
12. Partial-truth scope

Each with detection mechanism (static / dynamic) and tier applicability.

### 2026-04-25 — Turn 13: User flags severity-axis conflation — major refactor

User: *"not sure if we using classification low/medium/high correctly here... believe we are mixing risks with occurrences / type of failure / cause of failure can that be?"*

**Conceded conflation.** Three axes were collapsed into one HIGH/MEDIUM label:
- Detection confidence (am I sure this IS the pattern?)
- Lie severity (how badly does the evidence shape mislead?)
- Action severity (what should the framework do in response?)

**Refactored model:**

**Axis A — about the anti-pattern itself (intrinsic):**
- `detection_confidence`: deterministic / heuristic / semantic
- `lie_severity`: complete / severe / partial / narrow / staleness

**Axis B — about the task being verified (already-existing concerns):**
- `task.risk` (T-1442 Layer 2 frontmatter)
- `task.blast_radius` (`fw fabric impact`)
- `task.workflow_type`

**Axis C — action = function(A, B, overrides)** — separate policy file `policy/action-matrix.yaml`. Decision matrix combines anti-pattern attributes with task attributes to determine action (block / escalate / note). Spike I overrides apply at the action layer.

Default action mapping (rough):
| lie_severity | risk | action |
|---|---|---|
| complete or severe | any | block (insufficient-evidence) |
| partial | low | escalate (needs-human) |
| partial | medium / high | block |
| narrow | low | note |
| narrow | medium | escalate |
| narrow | high | block |
| staleness | any | re-run (Model V mandates) |

User also raised that catalogue should be expanded beyond agent's view via:
- External research (industry test-smell catalogues, mutation testing literature, academic SE)
- Internal corpus mining (`.tasks/completed/` evidence files, `.context/audits/`, `concerns.yaml`)
- Peer-agent TermLink dispatch for cross-project anti-pattern capture

→ Captured as **B-Anti-Patterns-Expansion** (B-N) follow-up build task.

## Decisions captured (so far)

1. **Reviewer interface = structured envelope** with per-AC granularity + signature + digest (Spike A)
2. **Per-AC verdicts, not whole-task** — partial blocks possible (Spike A + D)
3. **Sovereignty preservation: reviewer NEVER ticks `### Human` ACs** — structurally enforced
4. **5-driver "needs-human" model**: original classification + Layer 1 + Layer 2 + anti-patterns + AC semantic class — additive (Turn 9)
5. **Spike I — override mechanism**: don't-ask-pattern + reclassify-AC-type with TTL + auto-revoke; human creates, agent never
6. **7 UX principles** for Watchtower feedback (Turn 11)
7. **Anti-pattern catalogue 12-category seed** + multi-source expansion (Spike F + Turn 13)
8. **Severity refactor**: separate pattern attributes from task attributes from action policy
9. **Three policy files** anticipated: `policy/anti-patterns.yaml` (catalogue) + `policy/action-matrix.yaml` (action) + `policy/escalation-overrides.yaml` (Spike I overrides). Plus `policy/escalation-patterns.yaml` from T-1442.

## Dialogue Turns 14–17 (2026-04-25 continued)

### Turn 14: Spike G — Pattern-consultation interface

Agent presented cheap-first DAG algorithm (Phase 1 load → 2 cheap static + L1 + L2 → 3 apply overrides → 4 verification fresh (Model V) → 5 dynamic scan → 6 per-AC compute → 7 Human ACs surfaced → 8 atomic envelope write). Three-tier failure policy (T1 hard fail-closed / T2 retry-then-fail / T3 fail-soft). Implementation shape options A/B/C with strong lean for C (library + thin CLI).

### Turn 15: User asks for steelman/strawman against the 4 directives

Refined model emerged:
- **Q1 ordering**: confirm cheap-first as a **DAG with documented rationale**, no short-circuit (Model V mandates all phases run)
- **Q2 fail-closed**: refine to **three-tier policy** (T1 hard / T2 retry-then-fail / T3 fail-soft), declared per anti-pattern entry; learning lives in iteration, not in failure handling
- **Q3 implementation**: confirm Option C with explicit **Python library + bash CLI**, version-pinned via `.framework.yaml`, vendored
- **Q4 invariants**: confirm with **multi-layer enforcement specifications** — atomicity (write-temp+fsync+rename), idempotency reframed (deterministic bit-exact + semantic signed-for-reproducibility), signature + append-only evidence, sovereignty enforced at 3 layers, retention lifecycle (90d full / 1y summary / archive)

### Turn 16: User asks honest reflection — does design still match original ask?

Agent reflection: design is well-aligned with original ask + antifragility principle, but has grown to multi-month build. Spike A's deferred uncertainty (% of mechanically-evidenceable Human ACs) means we're designing for unmeasured problem size. Recommended **staged rollout** (v1 minimal → v2-v5 progression based on data).

### Turn 17: User pushes back — shorten review windows + more data review moments

Refactor to **micro-version progression** (v1.0 → v1.5 → v2.0 → v2.1 → v3+, each ~1 session) with **three-cadence data review** (continuous capture + weekly auto-summary + threshold alerts + per-version GO). **Spike I feedback stream pulled forward to v1.0** so data accumulates from day 1.

This rollout addendum is captured in both T-1442 and T-1443 research artifacts. T-1442's 8-task decomposition is replaced with the micro-version progression; T-1443's build follow-ups inherit the same staging.

## Decisions captured (final, for this inception)

(Adds to earlier Decisions list)

10. **Cheap-first DAG ordering** with documented rationale, no short-circuit (Model V mandates all phases run)
11. **Three-tier failure policy** (T1 hard / T2 retry / T3 fail-soft), declared per anti-pattern entry
12. **Python library + bash CLI** implementation, version-pinned, vendored to consumers
13. **5 correctness invariants with multi-layer enforcement** specifications (atomicity protocol, idempotency reframed, signature + append-only, sovereignty 3-layer, retention lifecycle)
14. **Micro-version staged rollout** (v1.0 → v3.0+, each ~1 session) instead of single big build
15. **Three-cadence data review** (continuous + weekly + threshold + per-version-bump) — frictionless meta-process
16. **Spike I feedback stream pulled forward to v1.0** — data captures from day 1, UX at v1.3

## Spike status (final)

- ✅ **Spike A**: Reviewer interface (structured envelope, per-AC granularity)
- 🔄 **Spike B**: Routing strategy — DEFERRED to v3.0 (orchestrator routing, T-1064 dep). v1.2 ships with hardcoded Sonnet.
- 🔄 **Spike C**: Authority bounds — addressed by 5 invariants + 3-layer sovereignty enforcement; concrete enforcement shipped per-version (envelope schema validator at v1.2, update-task.sh tick rejection at v1.2, Watchtower UI at v1.3).
- ✅ **Spike D**: Failure mode (insufficient-evidence blocks, needs-human escalates per-AC)
- 🔄 **Spike E**: Reviewer auditability — addressed by signature + digest + append-only evidence (in envelope from v1.2). Sampling/shadow-review deferred to v3.0+.
- ✅ **Spike F**: Anti-pattern catalogue (12-category seed + B-Anti-Patterns-Expansion)
- ✅ **Spike G**: Pattern-consultation algorithm (cheap-first DAG + three-tier failure)
- 🔄 **Spike H**: Slash-command + orchestrator — `/review T-XXX` shape locked; orchestrator integration deferred to v3.0
- ✅ **Spike I**: Override mechanism + 7 UX principles + feedback stream

5 spikes resolved; 4 spikes addressed via staging (concrete delivery in named versions).

## Recommendation

**GO** (full text in `.tasks/active/T-1443-independent-reviewer-agent--termlink-dis.md` § Recommendation).

Hand to user via `fw task review T-1443` for GO/NO-GO/DEFER.

## Empirical Results (v1.0 → v1.4, 2026-04-25)

Five micro-versions shipped in two sessions. Per D-009 staged rollout, each version was followed by re-dogfood over all 1358 completed tasks.

| Version | Patterns | Layers | Tests | PASS | CONCERN | FAIL | needs_human |
|---------|----------|--------|-------|------|---------|------|-------------|
| v1.0 (T-1445) | 4 seed | code-path | 31 | 98.9% | 0.0% | 1.1% | n/a |
| v1.1 (T-1446) | 8 seed | + Layer 1/2 | 57 | 85.8% | 12.5% | 1.7% | 3.4% |
| v1.2 (T-1447) | 8 + transitive | + Layer 3 cron | 62 | 86.7% | 11.6% | 1.7% | 3.4% |
| v1.3 (T-1448) | 8 (same) | + per-AC linkage | 68 | 86.7% | 11.6% | 1.7% | 3.4% |
| v1.4 (T-1449) | 8 (same) | + override mechanism | 83 | 86.7%* | 11.6%* | 1.7%* | 3.4%* |

*v1.4 baseline: identical to v1.3 with zero active overrides. Live test (single wildcard override on T-1020): PASS=86.7%→86.8% CONCERN=11.6%→11.5%, AC-verify-mismatch fires 192→190.

Pattern fire counts (v1.2 final):
- AC-verify-mismatch: 192 (was 226 in v1.1; -15% via transitive-coverage tuning)
- empty-output-success: 46
- swallowed-errors: 14 (was 15; T-1086 false-positive cleared by L-264 fix)
- skip-as-pass: 11
- mock-only-integration: 4
- tautology: 3
- output-spoofing: 0 (heuristic still too narrow — v1.3+ tuning candidate)
- empty-body: 0 (no historical task ships with placeholder body)

Layer 1 escalations (v1.2):
- cross-project-blast: 31
- destructive-action: 13
- secret-handling: 1
- external-publish: 1

**Validated assumption:** the unmeasured-problem-size question from the inception (% of Human ACs that are mechanically evidenceable) is now measured. Across 1358 historical completions, ~13% have at least one mechanically-detectable concern; ~3% are FAILs with high-confidence patterns; ~3.4% require Layer-1 escalation regardless. This is the empirical baseline for v1.3+ tuning and v3+ pattern expansion.

Learning entries: L-264 (v1.0 dogfood), L-265 (v1.1 + L-264-(a) fix), L-266 (v1.2 transitive-coverage delta), L-267 (v1.3 per-AC linkage shipped without changing detection sensitivity), L-268 (v1.4 override mechanism live-validated on T-1020).

## Tunings recorded for next versions

- ✅ **v1.3** (per-AC granular): shipped — `Finding.ac_index/ac_subhead/ac_text` populated by AC-bound detectors; verdict groups findings under each AC.
- ✅ **v1.4** (override mechanism): shipped — TTL'd per-(task, pattern, ac?) waivers; `bin/fw reviewer override add/list/prune/remove`; suppressions emit `override_applied` to feedback-stream; default 90d TTL forces quarterly re-review.
- **v1.5** (Pass A drift re-verification): sandboxed re-run of task verification commands to detect post-completion drift. High blast radius — needs isolation strategy. Bundle with Watchtower override management UI.
- **v2.1** (sovereignty enforcement on overrides): authority gate on who can add overrides; Watchtower approval flow.
- **v3+** (catalogue expansion): mine literature + internal corpus + peer-agent dispatch to extend 8 seed patterns toward 12+ categories.

## Anchor files

| Artifact | Path |
|---|---|
| Inception task body | `.tasks/active/T-1443-independent-reviewer-agent--termlink-dis.md` |
| Linked sister inception | `.tasks/active/T-1442-ac-validation-default-flip--mechanical-v.md` |
| Genesis dialogue | `docs/reports/T-1442-ac-validation-default-flip.md` |
| TermLink dispatch reference | `CLAUDE.md` § TermLink Integration |
| Authority model reference | `CLAUDE.md` § Authority Model |
