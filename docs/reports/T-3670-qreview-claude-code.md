The draft is above average, but it isn't yet sharp enough for seven reviewers to answer the same question. The three biggest gaps:

- It bundles about five decisions into one.
- It leaks the project's lean in four places, not just the disclosure paragraph.
- It has no threat model, and the whole answer depends on one.

1. SHARPNESS

- **Compound decision.** "Rewrite? Which language? Scope? Order? Shipping?" is five decisions. Reviewers will each weight a different one. Split it into D1 (Tier 0 approach), D2 (core implementation language), D3 (scope) and D4 (delivery), and ask for a verdict on each.
- **Undefined terms.** "Established core" is never defined; the criteria in IW-2 are not in the question. "Closed by construction" is also undefined. A parser models syntax, but it cannot resolve `$VAR`, `eval`, aliases, or a script the agent wrote and then runs. Say what "closed" means: syntactic spellings only, or semantic intent too?
- **Who the gate defends against is unstated.** Is it a mistaken cooperative agent (a guardrail) or an adversarial agent (a security boundary)? Opposite answers follow from each.

2. BIAS

The lean leaks in several places:

- the task title;
- "should it be rewritten in a typed, strict language";
- the option list, which names mvdan.cc/sh for Go but gives Python only "a bash parser library";
- the defect examples, which are all language-specific.

The "no rewrite" and "don't classify text at all" options are offered only as an escape clause. The defect list should also include defects that a rewrite would not fix (spec and logic errors), or the diagnosis is pre-loaded.

**Don't disclose the lean in round 1.** "Not a preferred answer" still anchors the reviewers. Collect the blind answers first, then optionally run a round 2: "The project leans X; what is the strongest case against it?"

3. COMPLETENESS

The question is missing:

- **Threat model:** can the agent edit hooks, set env vars, write and run scripts, or call the harness's own tools?
- **Latency budget:** ms per hook and calls per session, plus the current measured numbers.
- **Who builds and maintains it:** one operator plus AI agents. Who can review Go or Rust?
- **Size of the core:** LOC per core module and test counts.
- **Hard constraints:** no toolchain on consumer hosts, offline install, bash 3.2 on macOS, binary signing.
- **Harness-native alternatives:** Claude Code permission rules and sandboxing.
- **Cost of being wrong, in both directions:** a missed destructive command, or a stalled half-migration.
- **Time and effort budget.**
- **Evidence that would change the answer.**

4. RESPONSE SHAPING

- **Scores won't compare.** The scale has no anchors and the criteria have no weights, so seven 1–5 tables can't be compared. Define what 1, 3 and 5 mean, fix the weights, and make the options a closed set (plus one free slot).
- **Lead with a fixed summary block.** Put a machine-readable verdict block first, so the synthesis is mechanical.
- **Confidence needs a definition.** Ask for "probability this recommendation survives the pilot", not a bare 0–100%.
- **Word limits.** The section limits already sum to 1,150, and the table's 35 justification lines will blow the 1,500 total. Exclude the table from the count and cap each justification at 12 words.

5. WHAT THE CONTEXT PACK MUST CONTAIN

- The hook protocol (JSON on stdin, exit codes) and the chain of gates per tool call.
- The Tier 0 classifier's code and the round 3–7 probes, verbatim.
- The threat model.
- The defect catalogue, with each item tagged as language, parsing or spec.
- Per-module LOC, test counts and measured latency.
- How the core is distributed: vendoring, `fw upgrade`, the P-01 installer, supported OS and bash versions.
- Team composition.
- Hard constraints.
- A neutral description of the available parsers (mvdan.cc/sh, bashlex, tree-sitter-bash) and their known limits.

Every section must be numbered so reviewers can cite it.

6. REWRITE

---

**The question**

AEF governs AI coding agents. Hooks run on every tool call and must fail closed (§2). The adversary and the attacker's capabilities are defined in §3. Today the core is mostly bash, with some Python (§4).

Problem A: the Tier 0 gate classifies shell command text as destructive or not. Across seven review rounds, every round found a new bypass spelling (§5).

Problem B: the core has a record of silent defects (§6). Each one is tagged by cause: language, parsing, or spec.

Decide four things independently:

- **D1, Tier 0.** How should destructive-action detection work? Options include patching the matcher, parsing an AST, a default-deny allowlist, harness-native permissions or a sandbox, or a combination. Define "closed" in your answer: which bypasses become impossible, and which remain?
- **D2, language.** Should the core (as defined in D3) stay in bash, move to strict Python, Go, Rust, or something else? "No change" is a first-class answer.
- **D3, scope.** Which modules count as the core? Use or replace this criterion: security-critical, stable spec, at least N tests, runs on every call.
- **D4, delivery.** How does the core ship to vendored consumers on Linux, macOS and WSL, and what happens when a component is missing?

Constraints are in §7: the latency budget, team size, no toolchain on consumer hosts, and the cost of each kind of error. If any decision is mis-framed, say so first.

**Response structure** (≤1,400 words excluding the table)

0. **Verdict block** (exact format):
   - D1: <option> | confidence that it survives the pilot: <0–100>
   - D2: <bash / py-strict / go / rust / other: X>
   - D3: <module list>
   - D4: <mechanism>
   - Pilot: <module>
   - STOP if: <measurable condition>
   - Would change my mind: <one piece of evidence>
1. **Diagnosis (≤200 words).** Of the §5 and §6 defects, roughly what share is parsing, language, or spec/design? Cite defect IDs.
2. **D1–D4 reasoning (≤120 words each).**
3. **Options table.** Rows: bash plus a parser; strict Python plus bashlex; Go plus mvdan.cc/sh; Rust plus tree-sitter-bash; harness-native or sandbox-first; your own option. Columns, with weights: closes the Tier 0 class (×3); closes the §6 defects (×2); fits the latency budget (×1); portability and distribution (×2); migration risk (×2); maintainable by this team (×2). Anchors: 1 = makes it worse or no effect, 3 = partly, 5 = eliminates or fully meets. Each cell gets a justification of 12 words or fewer.
4. **Migration plan (≤250 words).** The sequence; running old and new side by side for parity; which test suites act as the contract; fail-closed behaviour; the rollback trigger.
5. **Strongest case against your own verdict (≤150 words).**
6. **Assumptions not settled by the pack** (bullets, each with a § reference or "none").

Rules: cite § numbers for every fact; no production code (snippets of 15 lines or fewer are fine); flag where your answer depends on the threat model in §3.

---

If you want a round 2, send each reviewer the lean and the six other verdict blocks only after all seven blind answers are in.
