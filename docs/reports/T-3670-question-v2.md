# T-3670: Review question v2 (after the 3-model question review)

Changes from v1 are driven by docs/reports/T-3670-qreview-{claude-code,codex,opencode}.md:
- **Split into four separate decisions,** with the enforcement architecture first (all three).
- **"Closed" defined against an explicit threat model** (all three).
- **Lean leakage removed:** libraries named for every option or none; hypotheses stated as hypotheses (all three).
- **Lean WITHHELD in round 1** (Claude, Codex; Z.ai preferred disclosing it as data). An optional round 2 shows the lean and the other verdicts.
- **A machine-readable verdict block first,** weighted criteria with anchors, security as a pass/fail GATE rather than a weighted score (Codex), the table excluded from the word count (all three).
- **One frozen context pack for all seven;** internal reviewers report repo-only findings separately (Codex).
- **An explicit priority order when criteria conflict** (Z.ai).

Items marked **[OPERATOR]** need the operator's confirmation before dispatch.

---

## The question

AEF governs AI coding agents. Hooks run on every agent tool call and must fail closed (pack §2). The enforcement core comprises:
- the Tier 0 destructive-action gate;
- the task and focus gates;
- the context-budget gate;
- the reviewer-verdict ledger;
- the task-close gates.
It is written mostly in bash, with some Python (pack §1).

**Threat model (pack §3) [OPERATOR: confirm].** The gate is a guardrail against a cooperative agent's MISTAKES and against UNSOPHISTICATED self-approval. It is not a security boundary against a determined adversary: the agent runs as the same OS user and can write files, including the approval store. The operator accepted that residual explicitly (T-3581). Within that model, a missed destructive command (a false allow) is worse than a false block.

**Problem A (pack §5).** The Tier 0 gate classifies shell command TEXT as destructive or not. In each of seven review rounds, reviewers found a new spelling that bypassed it or reused an approval: brace expansion, line continuation, ANSI-C quoting, quote removal, target normalisation. Each cited case has an ID, the command and the expected outcome.

**Problem B (pack §6).** The core has a record of silent defects. Each is tagged by likely cause: language, parsing, or spec/design.

These observations do not by themselves establish causes or justify a rewrite.

**Decide four things, in this order:**
- **D1, the enforcement architecture for destructive actions.** Options include, and are not limited to:
  - patching the current matcher;
  - parsing a real syntax tree;
  - a default-deny allowlist of exact shapes;
  - harness-native permission rules or sandboxing;
  - interposing on execution instead of classifying text;
  - a hybrid.
  Define "closed": which bypass classes become impossible under the §3 threat model, and which remain?
- **D2, the implementation language for the core,** given D1: bash (status quo), strict Python, Go, Rust, or other. "No change" is a first-class answer.
- **D3, scope:** which pack-§1 modules are "core". Use or replace this criterion: security-critical, stable specification, a substantial test suite, runs on every call.
- **D4, delivery:** how the core ships to vendored consumers on Linux, macOS and Windows via WSL (pack §7), and what happens when a component is missing or fails. Falling back to a known-vulnerable path is NOT fail-closed.

If any decision is mis-framed, say so first, then answer the question you think we should have asked, in this same structure. "Insufficient evidence" is allowed if you name the experiment that would settle it.

**Priorities when criteria conflict:**
1. No unreviewed destructive action executes.
2. Fail closed, always.
3. Hook latency within budget (pack §4).
4. Maintainable by the team in pack §8.
5. Migration cost.

## Response structure (≤1,500 words, excluding the table)

0. **VERDICT block** (exact format, first):
   ```
   D1: <architecture> | survives-pilot confidence: <low|medium|high> because <evidence>
   D2: <bash | python-strict | go | rust | other:X | no-change>
   D3: <module list>
   D4: <mechanism>
   PILOT: <one module> | STOP IF: <measurable condition>
   WOULD CHANGE MY MIND: <one piece of evidence>
   ```
1. **Diagnosis (≤200 words).** Roughly what share of the pack §5 and §6 defects are parsing, language, or spec/design? Cite the case IDs.
2. **Security contract (≤150 words).** What is trusted, what is guaranteed, what is excluded, and how unsupported input is handled, under the §3 threat model.
3. **Options table.**
   - **Rows:** keep bash and patch; bash plus a parser; strict Python plus bashlex; Go plus mvdan.cc/sh; Rust plus tree-sitter-bash; harness-native or sandbox-first; one of your own.
   - **Gate column first, PASS/FAIL/UNKNOWN:** does it close the Tier 0 bypass class within §3?
   - **Scored columns, 1–5:** closes the §6 defects ×2; portability and distribution ×2; migration risk ×2; maintainability ×2; latency ×1.
   - **Score anchors:** 1 = worse or no effect, 3 = meets target, 5 = materially exceeds target; "?" = unknown, unscored.
   - **Justifications:** at most 12 words per cell.
4. **D1–D4 reasoning** (≤120 words each).
5. **Migration and validation (≤250 words):**
   - the sequence;
   - side-by-side parity runs;
   - the test suites as the behavioural contract, and what they do NOT cover;
   - fail-closed handling;
   - rollback triggers.
6. **Strongest case against your own verdict (≤150 words).**
7. **Assumptions and missing facts** (bullets, ranked by how likely each is to change your verdict; cite § or write "none").

Rules:
- Cite pack § and case IDs for every fact.
- No production code; snippets of 15 lines or fewer are fine.
- Do not invent benchmarks.
- Do not treat the existing tests as a complete security specification.

---

## Context pack additions required by v2 (the pack worker started from v1)
- §2 the hook protocol (JSON on stdin, exit codes) and the gate chain per tool call;
- **§3 the threat model** (above) and the cost of a false allow versus a false block;
- §4 the latency budget [OPERATOR] and the measured p50/p95 per hook;
- §5 Tier 0 cases with stable IDs: the command, the expected outcome and the round found, plus benign commands that must stay allowed;
- §6 the defect catalogue tagged language/parsing/spec;
- §7 distribution: vendoring, `fw upgrade`, the P-01 installer, supported OS and bash versions, hard constraints (no toolchain on consumer hosts, offline install, binary size, licence);
- §8 the team: one operator plus AI agents. Who reviews Go or Rust code?
- a neutral description of the parsers (mvdan.cc/sh, bashlex, tree-sitter-bash) and their known limits;
- the harness-native options (Claude Code permission rules, sandboxing) as they exist today.

## Process
1. Freeze the pack.
2. Round 1: all seven answer blind (no lean).
3. Synthesise the verdict blocks.
4. Optional round 2: show each reviewer the six other verdicts plus the lean, and ask for the strongest objection.
