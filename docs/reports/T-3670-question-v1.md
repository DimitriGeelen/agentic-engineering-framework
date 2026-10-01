# T-3670: Review question v1 (DRAFT, to be reviewed before it goes out)

Audience: seven independent reviewers: three internal harnesses (Claude, OpenAI Codex, Z.ai GLM) and four external models via OpenRouter. External reviewers see ONLY this question plus the context pack (docs/reports/T-3670-context-pack.md). Internal reviewers may also read the repo.

---

## The question

**AEF** is a governance framework for AI coding agents. Its enforcement core is a set of hooks and gates that run on every agent tool call: a Tier 0 destructive-action gate, the task and focus gates, a context-budget gate, a reviewer-verdict ledger, and task-close gates. Today this core is written mostly in **bash**, with some Python. It must fail closed, run on Linux, macOS and Windows (via WSL), and be vendored into consumer projects.

Over seven review rounds, the Tier 0 gate (which classifies typed shell commands as destructive or not) kept failing the same way. Each round found a new shell spelling the classifier did not model: brace expansion, line continuation, ANSI-C quoting, quote removal, and target normalisation that made two different targets share one approval. Separately, the project's learnings record a long list of silent bash-specific defects in the core itself.

**The decision we must make:** what architecture and implementation approach should the established, security-critical core use, so that this class of defect is closed by construction rather than patched spelling by spelling? Specifically: should it be rewritten in a typed, strict language, and if so which one, with what scope, in what order, and how do we ship it to consumers?

**Answer the decision, not just the question as posed.** If you think the framing is wrong (for example, the root cause is not the implementation language, or the Tier 0 gate should not classify typed text at all), say so first and argue it.

## What we need from you, in exactly this structure (≤1,500 words total)

1. **Diagnosis (≤200 words).** What is the root cause of the Tier 0 failure pattern, and of the bash defect catalogue? Separate the parsing problem, the implementation-language problem, and the design problem. Which dominates?
2. **Recommendation (≤150 words).** One clear recommendation: language (or "no rewrite"), scope, and the first step. Give a confidence from 0 to 100%.
3. **Options compared (a table).** At least: keep bash with a real parser; strict Python with a bash parser library; Go (e.g. mvdan.cc/sh); Rust; and one option of your choosing. Score each 1–5 against:
   - closes the Tier 0 defect class;
   - closes the bash defect catalogue;
   - hook latency;
   - portability (Linux/macOS/WSL, no runtime lock-in);
   - distribution to vendored consumers;
   - migration cost and risk;
   - the team and agents' ability to maintain it.
   One line of justification per score.
4. **Scope (≤150 words).** Which modules move, which stay, and the criterion for "established core".
5. **Migration plan (≤300 words).** Sequence; the parity strategy (old and new run side by side?); fail-closed behaviour when the new binary is missing; how the existing bats/pytest suites serve as the contract; the rollback trigger.
6. **Pilot (≤150 words).** Exactly one pilot module, what "success" means in measurable terms, and what result would make you STOP the migration.
7. **Risks and the strongest argument against your own recommendation (≤200 words).**
8. **Assumptions you made** that the context pack did not settle (a bullet list).

Rules:
- Do not write production code; snippets of at most 15 lines are fine.
- Cite context-pack section numbers for facts you rely on.
- Where you disagree with the project's current lean (below), say so plainly.

**Disclosed for transparency, NOT as a preferred answer:** the project's current lean is Go with the mvdan.cc/sh bash parser, piloted on the Tier 0 classifier. Treat it as one option among several. A well-argued disagreement is more useful to us than agreement.

---

## Notes for the question reviewers (not sent to the seven)
- Is the decision sharp and answerable from the pack?
- Does anything lead the answer?
- Will the structure make seven answers directly comparable (same sections, same scales)?
- Is anything missing that the answers will need?
