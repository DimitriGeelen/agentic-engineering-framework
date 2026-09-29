VERDICT: amber

FIDELITY: Checked the draft and T-3535 design/task against `001-Vision.md`, T-010, `005-DesignDirectives.md`, CLAUDE.md, T-3557, T-3558, T-3563, D-662, the disputed arc YAMLs, T-2209’s report, and the local EWCR contract material. Also inspected `metrics.sh`, dispatch ledger samples, T-3037’s measurement description, and the named test files. No files modified or tests run.

The headline is a defensible synthesis. The five objectives describe recognisable outcomes rather than merely renaming D1–D4. However, O-2 confuses retrievable learning with prevention; O-3 understates mandatory human involvement; O-4 unnecessarily excludes runtime portability; and two NONE mappings overlook contributions. T-3558 supports cross-project communication, but does not establish wholesale repeal of project boundaries.

CORRECTIONS:

- target: O-1 — measure  
  replace_with: >-
    Partly measurable. `fw metrics` reports the fraction of commit subjects containing a T-number; it does not establish that the referenced task exists, authorises the change, or preceded it. Bypass logs count recorded exceptions, not undetected bypasses. Gate effectiveness requires bounded refusal tests with negative controls; no complete measure of consequential actions escaping approval is established.
  why: `metrics.sh` matches `T-[0-9]+` in git output; neither reference presence nor low bypass counts proves enforcement.

- target: O-2 — text  
  replace_with: >-
    A new session resumes the recorded task, decisions and next steps without reconstructing prior work; lessons from witnessed failures are available when relevant and reduce recurrence.
  why: The sources support continuity and applied learning, not the claim that recording a failure prevents its repetition.

- target: O-2 — measure  
  replace_with: >-
    Pickup time and repeat-failure rate have no established instrumentation in the cited material. Learning, pattern and escalation-entry counts are computable coverage proxies, not evidence of retrieval, application or reduced recurrence. The 0-of-2416 trigger count is the historical diagnosis recorded in arc-018, not a current baseline.
  why: The draft labels proxies honestly but still gives their existence more evidential weight than they bear.

- target: O-3 — text and measure  
  replace_with: |
    text: >-
      Routine work proceeds without operator relay or rubber-stamp review.
      Tier 0, irreversible external acts and sovereignty decisions remain human;
      other reviews receive independent agent judgement, with unresolved cases
      escalated. Work that advances no project objective is ineligible.
    measure: >-
      Queue size and open Human-criterion classes are computable workload proxies.
      The historical 353 criteria / 11 tier-0-or-bypass figures do not identify
      the full human-required set: irreversible external acts, sovereignty and
      reviewer escalations must also be accounted for. No current end-to-end
      measure of correct review routing is established. Arc supports coverage
      is computable metadata, not a success target: report unsupported arcs and
      their staleness separately, and assess whether each claimed contribution
      is substantiated.
  why: T-3557 IW-1/IW-6 preserve additional human responsibilities; maximising nonempty `supports:` would reward precisely the forced mappings T-3535 seeks to prevent.

- target: O-4 — text and measure  
  replace_with: |
    text: >-
      A developer can install AEF in a new or existing project, complete a first
      governed task through supported CLI or MCP agent interfaces, and upgrade
      while preserving project-owned state, without dependence on a single
      agent runtime.
    measure: >-
      The three cited onboarding and upgrade test files exist and provide
      bounded fixture checks, not proof for every project or runtime.
      greenfield_seed_audit_prototype.bats documents its conversion to a live
      guard by T-2740; its original RED status is historical. No tests were run
      in this review. Cross-runtime governance parity and real consumer success
      are not established by these tests.
  why: Directive 4 and T-2209 support runtime-independent interfaces; “any shape” and “without breakage” exceed the available validation.

- target: mapping:capability-overlay  
  replace_with: |
    supports: [O-4]
    reason: "Enables a governed task lifecycle through MCP as well as CLI; contributes to interface portability, without yet proving cross-runtime governance parity."
  why: Its headline changes how an agent can perform governed work; dismissing it as merely a preference for MCP overlooks that outcome.

- target: mapping:ewcr-arc0-contract-evidence  
  replace_with: |
    supports: [O-1]
    reason: "Establishes versioned contracts, refusal scenarios and executable evidence fences for task binding and unskippable human gates; this is assurance preparation, not runtime enforcement delivered."
  why: The arc headline and local v1 contracts directly address O-1; an initiative need not be named in an objective to contribute to it.

- target: mapping:inception-review-loop  
  replace_with: |
    supports: [O-2]
    reason: "Structured operator feedback survives into the next agent session. The generic operator-decides-every-inception workflow needs reconciliation with T-3557 before claiming O-3."
  why: Two-click human review does not itself remove unnecessary review; durable feedback is an explicit, defensible contribution.

- target: mapping:dispatch-safety  
  replace_with: |
    supports: [O-3, O-5]
    reason: "Risk-threshold escalation preserves human handling of consequential uncertainty; linked re-dispatch preserves the handoff after resolution."
  why: Risk-based operator involvement is central to this arc’s headline, not incidental.

- target: mapping:designer-corpus — reason only  
  replace_with: >-
    NONE: its stated outcome is faithful, executable documentation of AEF processes and closure of vocabulary gaps. No direct contribution to the five proposed outcomes is established; collaboration with 832 alone does not establish O-5.
  why: NONE is defensible, but “serves 832’s designer development” misattributes the arc’s explicitly AEF-owned documentation and vocabulary work.

- target: O-5 — measure  
  replace_with: >-
    Dispatch verification pass rates are computable proxies: join outcome events to dispatches by dispatch_id and resolve task_id to workflow_type from task frontmatter, stating the reporting window, duplicate-event rule and missing-outcome coverage. They do not establish correct identity, authenticated delivery, recipient action or freedom from concurrent state corruption. Those outcomes require separate evidence; unread age and collision reports are partial diagnostics.
  why: T-3037 requires task metadata beyond the two ledgers, and sampled outcome events contain duplicates.

- target: out_of_scope — replace the real-time collaboration item and add the project-boundary item  
  replace_with: |
    - "A real-time multiplayer human editing product; concurrent agent execution and durable peer communication remain in scope."
    - "Cross-project communication does not merge project objectives, state or approval authority, and does not itself authorise cross-repository execution."
  why: T-010’s broad turn-based language conflicts with arc-011; T-3558 changes addressing scope without granting shared authority.

AUTHOR’S DOUBTS:

1. O-5 is supported, but “T-010 item 3 is superseded” is too broad: communication across instances and one framework instance per repository can coexist.
2. Keep O-3 together: avoiding operator bottlenecks and refusing irrelevant work form a coherent outcome, provided eligibility is explicit.
3. Keep the headline; it is a supported synthesis, with “only what matters” clarified by the corrected O-3.
4. Do not invent a cost-efficiency objective: arc-003 explicitly defers cost-aware selection; its outcome-informed routing remains a direction the operator must deliberately prioritise or leave unsupported.
5. Widen O-4 to supported agent interfaces and runtime independence; capability-overlay then contributes without claiming universal compatibility.
6. EWCR Arc 0 supports O-1 through assurance evidence; designer-corpus can remain NONE, but not because its work belongs wholly to another project.
7. Keep horizon-axis-hardening→O-2 and arc-grooming→O-3: accurate handovers and an abandonment lifecycle are concrete enabling contributions.
8. Measures need the corrections above; record counts, reference strings, test existence and dispatch success are not their corresponding outcomes.
9. Retain dated historical observations as such; do not present September 27 staleness or older diagnostic counts as current measurements.

OVERALL: These are fit to show the operator after correction: the five-objective structure is defensible and still permits refusal, but unsupported mappings must remain legitimate outcomes rather than defects to eliminate.