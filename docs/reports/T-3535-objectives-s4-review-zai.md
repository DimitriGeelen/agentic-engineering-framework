# T-3535 §4 review — Z.ai (GLM-5.2 via opencode, flat-rate), 2026-10-01

**VERDICT: amber** — recommendations 1 and 4 are solidly sourced; 2 has one unsupported detail; 3's core is right but two evidence claims fail against T-3580 itself.

**Per recommendation:**

1. **capability-overlay → NONE — agree.** Arc YAML confirms it is a typed MCP/CLI interface, not runtime portability; §2 marks it stale; treating D4 (Portability) as a judge-of-work directive rather than an objective matches the framework's own D1-D4 design.

2. **ewcr-arc0 → O-1 — agree, one detail wrong.** The YAML does say "authorized by the human on 2026-08-26" and the headline mechanic (contract trace + refusal scenario + verification fence) matches O-1's substance; the flip condition is honestly disclosed. But "it is the current focused arc" is unsupported: `focus.yaml` has `current_task: T-3535`.

3. **inception-review-loop → abandon — agree with the outcome, disagree with the evidence.** Supersession holds: T-3557 IW-2 (operator GO 2026-09-30) routes inceptions to the agent reviewer, killing the "two clicks" headline. But two claims are false: (a) "the path that lets a reviewer's verdict close [an inception] is being built in T-3580 slice 3" — T-3580's round-7 docs decision explicitly *removed* the sentence "inception gates are rewired by T-3580" as stale; T-3580 judges task criteria, not inceptions; (b) "captured as a note on T-3580" — no such note exists; the only T-3580 note is the T-3583 cost-system one. "Re-scoping would duplicate T-3580" is therefore overstated.

4. **Add O-6 — agree; measurable and not over-claiming.** Every element traces to CLAUDE.md §Review and Dispatch Cost Ruling (record every cost, per-request paid approval, `fw review cost report`, audit WARN on paid-without-proposal) and T-3557 IW-7 + T-3580 rounds 6-7 (ceiling, step-down WARN via `_audit_review_step_downs`). The "unlogged use is invisible" caveat matches the hook's typed-command-only limit; citing T-3583/*T-3586* correctly reflects the bypass correction. orchestrator-rethink's non_goals verifiably defer cost-aware routing.

**Corrections:**

- Rec 2: drop "it is the current focused arc" or substantiate it.
- Rec 3: replace the T-3580 claims — say the reviewer-judge *substrate* (verdict records, T-3579) is shared but inception decision routing is not yet built anywhere, and change "is captured as a note" to "a note will be added to T-3580 (or a small task) before abandonment". The abandonment itself is operator-sanctioned via the accept, so it can stand once reworded.

