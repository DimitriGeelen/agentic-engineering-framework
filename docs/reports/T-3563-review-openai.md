# T-3563 external review — openai

Reviewer: OpenAI (codex CLI, read-only sandbox). Run 2026-09-29, isolated, input `T-3563-external-review-brief.md` only. Verbatim.

---

**An arc should be a compact, authoritative statement of intent with an evidence-backed explanation—not another research report.** The missing piece is not a longer headline; it is an explicit objective and a readable account of why that objective was chosen.

1. **What it should carry**

   Keep the existing identity, status, membership, and anchor. Add:
   - **Brief:** what this initiative is, the problem or background, who benefits, and why it matters. Aim for 100–200 words.
   - **Objective:** the outcome being pursued, linked to named project objectives.
   - **Success criteria:** stable IDs, observable conditions, and expected evidence.
   - **Scope and non-goals:** boundaries needed to make inclusion and closure decisions.
   - **Current rationale:** the few decisions, rejected alternatives, and unresolved questions that materially constrain further work, with source references.
   - **Material changes:** a short index of approved changes to intent, scope, or decisions.

   Do not copy dialogue logs, full research reports, task lists, implementation diaries, or every rejected idea onto the arc. Keep those in their authoritative artefacts. An anchor link alone is insufficient: identify the relevant section or decision.

2. **Headline versus story**

   Keep `headline_mechanic` separate and testable. Its existing protection against “substrate complete” closure is valuable.

   Expanding it into narrative makes the acceptance claim harder to inspect and easier to evade. Keeping it separate introduces some repetition and a risk of disagreement; address that by linking the headline to the success criterion it demonstrates. The headline need not demonstrate every criterion.

3. **Derived or written**

   Use both, with clear authority:
   - Agents may draft the brief and rationale from inception evidence.
   - The human confirms the objective, scope, and consequential decisions; a generated interpretation cannot silently become intent.
   - Each summary records its source sections and the source revision last reviewed.
   - Source changes visibly mark the affected summary as needing review. Regeneration produces a proposed replacement, never an automatic overwrite of approved intent.

   Existing research is evidence of deliberation, not necessarily the current decision. Preserve unresolved disagreements instead of generating consensus. For arcs without research reports, write a short account from available evidence and label gaps; do not manufacture an inception retrospectively.

4. **Goals and drivers**

   Establish one canonical objective on the arc, with stable success-criterion IDs and explicit project-objective references. Explain the contribution upward in one sentence; a bare parent ID does not establish alignment.

   Each scoped driver must state how it measures contribution to that objective and which criteria it informs. Task scoring must cite the relevant contribution and scoring-spec version. Drivers are prioritisation lenses, **not substitutes for acceptance criteria**.

   Revise L3 to require an evidence-backed disposition for every success criterion: achieved, unmet, or explicitly waived by the human with rationale. An anchor recommendation may support this assessment but cannot replace it. If an unmet criterion is removed, record an approved scope change. Low BVP must never make required outcome work disappear from closure consideration.

5. **Evolution**

   Present the current approved position first. Keep a compact change index containing date, affected objective/criterion/decision ID, what changed, why, and the approval/evidence link. Store extended reasoning elsewhere.

   Preserve superseded versions and mark old decisions as superseded. After a material pivot, identify affected open tasks and review their scores; do not silently reinterpret historical scores against new goals.

6. **For agents specifically**

   Provide a predictable reading order: brief → objective and criteria → scope → headline → current decisions and unresolved questions → evidence links. Use stable IDs and explicit statuses rather than requiring inference from prose.

   Expose this as one compact rendered view of the canonical arc data. Deeper evidence should be available on demand. Avoid a separate agent summary that can become a second, conflicting account of intent.

7. **Likely practical failures**

   The greatest danger is a polished summary being treated as authoritative despite omitting a qualification, reversal, or human objection. Provenance and explicit approval matter more than fluent prose.

   Other failures include boilerplate objectives, drivers invented to inflate scores, broken source links in consumer projects, and excessive maintenance requirements. Validate meaningful relationships and resolvable evidence, not word counts. Distinguish framework-local sources from consumer-project sources. Pilot the structure on three contrasting arcs before making it mandatory across all projects.

VERDICT: amber
GUIDANCE: Preserve the testable headline. Add a canonical objective, explicit success criteria, and a compact sourced brief. Make L3 assess each criterion. Require human approval for changes to intent; flag source drift without automatically rewriting approved content. Pilot before enforcing.
PROPOSED STRUCTURE:
  identity: Existing name, description, status, and anchor reference.
  brief: Problem, background, beneficiaries, and reason for pursuing the initiative.
  objective: Canonical intended outcome, project-objective references, and contribution rationale.
  success_criteria: Stable IDs, observable conditions, evidence requirements, and closure dispositions.
  scope: Included work, non-goals, and consequential constraints.
  headline_mechanic: Separate testable user-visible claim linked to success criteria.
  scoped_drivers: Rationale, scoring spec, objective/criterion mapping, and version.
  current_rationale: Active decisions, material alternatives, and unresolved questions with dispositions and sources.
  evidence: Research, decision, and demo references with reviewed source revisions.
  changes: Dated material changes, rationale, supersession, and human approval references.
TOP RISK: An agent-generated summary silently becomes authoritative intent while losing the human’s qualifications or later decisions.