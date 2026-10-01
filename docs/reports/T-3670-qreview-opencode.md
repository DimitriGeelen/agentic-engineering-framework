1. SHARPLESS. The "decision" is five decisions bundled: rewrite-or-not, language, scope, order, distribution. Reviewers will each pick a different one as primary. "Established, security-critical core" is undefined in the question (IW-2's module list exists only in the task file — externals can't see it). "This class of defect" conflates two classes: Tier 0 shell-obfuscation misses and the bash silent-failure catalogue; a reviewer could close one and not the other. "Closed by construction" is undefined (compile-time? AST? exhaustive tests?). No tie-breaker for criteria conflicts. "Ship to consumers"/"vendored" presumes facts externals don't have.

2. BIAS. The lean should stay disclosed — honesty beats a false neutral, and the invitation to disagree is good — but it leaks twice beyond the disclosure line: the options table names mvdan.cc/sh for Go only (no library named for Rust or Python), and "rewrite in a typed, strict language" plus "closed by construction" presets the frame that only a parser-in-typed-language can answer. Name candidate libraries for every option or none. Put the disclosure after the response structure, worded as data.

3. COMPLETENESS. Missing: threat model (who is the attacker — the agent's own output? a malicious repo? can it touch PATH/env/the hook binary itself? — this decides whether classifying typed text is even viable); latency budget and current p50/p95; team size and who maintains/reviews (humans? agents?); test-coverage facts (~170 tests stated only in background docs); hard constraints (network at install, Python floor on consumer hosts, license, binary size); cost of being wrong (is a false-block worse than a miss, and what's the blast radius of each?); confirmation that native Windows (non-WSL) is out of scope.

4. RESPONSE SHAPING. Mostly good: fixed sections, scales, confidence, assumptions, self-counterargument. Fixes: (a) seven unweighted criteria cannot be synthesised — weight them or make reviewers allocate 100 points; (b) no headline verdict field, so comparing seven answers requires reading 10,500 words; (c) the 35-cell table has no word budget inside a 1,500 cap — exclude it from the count; (d) "team and agents' ability to maintain it" is unanswerable without pack facts; (e) no explicit agree/disagree-with-lean flag.

5. CONTEXT PACK MUSTS. Numbered, citable sections: §1 module inventory (LOC, call frequency, test count per gate); §2 threat model + cost-of-wrong; §3 latency numbers and budget; §4 team/maintenance facts; §5 bash defect catalogue verbatim with one example each; §6 Tier 0 round 3–7 findings with example commands and probe outcomes; §7 consumer/install/constraint facts (P-01, vendoring, platforms, network); §8 the disclosed lean.

6. REWRITE.

[The question section]
The enforcement core of AEF (five gates, module list and sizes: pack §1) runs on every agent tool call and must fail closed. Over seven review rounds the Tier 0 classifier repeatedly missed destructive shell commands spelled via unmodelled constructs (brace expansion, line continuation, ANSI-C quoting, quote removal, target-normalisation collisions: pack §6). Separately, pack §5 records silent bash failures in the core itself.

Answer in priority order:
(a) PRIMARY: what architecture closes the Tier 0 miss class such that no new shell spelling can bypass review — a real bash parser? a different trust boundary entirely (e.g. don't classify text; interpose execution)? Argue which root cause dominates: parsing, implementation language, or gate design.
(b) CONTINGENT: if any core module changes implementation language, which language, for exactly which §1 modules, in what order, distributed how to vendored consumers (pack §7)?

If you reject the premise, say so in one sentence, then answer the question you think we should have asked, in this structure.

Priorities when criteria conflict: (1) no unreviewed destructive command executes — a miss is worse than a false block (pack §2); (2) fail closed, always; (3) hook p95 within budget (pack §3); (4) maintainable by the team described in pack §4; (5) migration cost.

[Response structure — ≤1,500 words; tables excluded]
0. VERDICT (one line): "REWRITE: yes/no | LANGUAGE: X or n/a | PILOT: <module> | CONFIDENCE: nn%"
1. Diagnosis (≤200): parsing vs language vs design; which dominates; one sentence each.
2. Recommendation (≤150): architecture from (a); if rewriting, language + first step.
3. Options table (≤350): keep-bash+real-parser; strict Python (bashlex); Go (mvdan.cc/sh); Rust; one free choice. Criteria, weighted: Tier-0 closure ×3; bash-catalogue closure ×2; portability ×2; distribution ×2; latency ×1; migration risk ×1; maintainability ×1. Score 1–5, one line of justification.
4. Scope (≤150): which §1 modules move/stay; criterion for "core".
5. Migration (≤300): sequence; side-by-side parity; behaviour when the new binary is absent (fail closed to what?); existing suites as contract; rollback trigger.
6. Pilot (≤150): one module; measurable success; explicit stop condition.
7. Strongest argument against your own recommendation (≤150).
8. Assumptions the pack did not settle (bullets).
9. Disagree with the disclosed lean? yes/no + one sentence.

Rules: no production code (≤15-line snippets); cite pack section numbers; the lean below is data, not preference — do not weight it.

Disclosed for transparency (after all tasks): an internal draft leaned Go with mvdan.cc/sh, piloted on Tier 0. Disagreement is more useful than agreement.

(≈870 words)
