# IW Spike Worker — Stellman/Strawman + BVP Scoring + Recommendation

Reusable prompt template for TermLink-dispatched workers researching one Open Question
of a parent inception. Originated as T-2209 sub-research (IW-1..IW-5). Generalises to any
multi-candidate inception with named candidates.

## Worker contract (mandatory steps)

When dispatched, you receive:
- `TASK_ID` — the spike task (e.g. `T-2210`)
- `PARENT_INCEPTION` — the parent (e.g. `T-2209`)
- `IW_TEXT` — the one open question this spike answers
- `CANDIDATES` — bullet list of named candidates (may be partial — you may add)

You MUST:

1. **Read the parent inception** at `.tasks/active/${PARENT_INCEPTION}-*.md` for context
   and the parent's research artifact (`docs/reports/${PARENT_INCEPTION}-*.md` if exists).

2. **Produce a steelman + strawman per candidate**:
   - **Steelman:** the strongest charitable argument FOR the candidate. Give it the best
     possible shot. Cite concrete evidence (file paths, existing implementations,
     framework-internal precedents — e.g. *"`claude-in-chrome` MCP uses Y, ergo Z is
     feasible"*, not *"X is good because it's clean"*).
   - **Strawman:** the strongest argument AGAINST the candidate (real failure modes,
     not caricature). Surface §B-005 / Sovereignty / §ACD hazards if applicable.

3. **BVP scoring per candidate** against active value drivers from `policy/value-drivers.yaml`:
   - **D1 Antifragility** (weight from policy)
   - **D2 Reliability**
   - **D3 Usability**
   - **D4 Portability**
   - **F-RECALL** (free driver, weight 6)
   - **F-ORCH** (free driver, weight 5)
   - Score 0-5 per driver per candidate. Show your reasoning in one sentence per cell.
   - Cost: `F8 = 0.6·blast_radius + 0.3·tier + 0.1·effort` per candidate. T-shirt size acceptable (`S=2 / M=4 / L=6 / XL=8`) if blast-radius isn't computable yet.

4. **Recommendation:**
   - One preferred candidate, with one-sentence rationale anchored in the BVP+cost
     deltas you computed.
   - If genuinely DEFER (not hedge — see CLAUDE.md *DEFER is for evidence gaps*),
     name the missing evidence and what experiment would resolve it.

5. **Write artifact** to `docs/reports/${TASK_ID}-iw-research.md` with sections:
   - `## Question` (IW_TEXT)
   - `## Candidates` (one subsection per candidate, with Steelman + Strawman)
   - `## BVP Scoring Matrix` (markdown table, candidates × drivers)
   - `## Cost Estimates` (one row per candidate, F8 components)
   - `## Recommendation` (preferred candidate + rationale)
   - `## Open Sub-Questions` (anything that surfaced but isn't this spike's scope)

6. **Bus post**:
   ```
   bin/fw bus post --task ${TASK_ID} --agent spike-iw \
     --summary "IW spike — recommends <CANDIDATE>: <one-line>" \
     --blob docs/reports/${TASK_ID}-iw-research.md
   ```

7. **Close the spike task** when artifact is committed:
   ```
   bin/fw task update ${TASK_ID} --status work-completed
   ```
   The Verification gate enforces artifact existence + bus entry.

## Constraints

- **No source edits.** This is a research spike. No `bin/fw` verb additions, no
  `.mcp.json` changes, no Watchtower template edits.
- **Path isolation:** stay within `/opt/999-Agentic-Engineering-Framework`. Read-only
  consultation of memory directory permitted.
- **Time-box:** 30 minutes worker time. If you can't reach a recommendation, post
  partial findings + DEFER recommendation with named evidence gap.
- **No Sovereign acts:** never call `fw inception decide`, `fw arc create`, `fw arc close`,
  or edit `.claude/settings.json`. Producer ≠ judge.
- **Cite evidence:** every claim ties to a file path, commit hash, memory entry,
  or framework-internal precedent. No assertions from training data.
- **Inception discipline:** you are *not* authorised to start build work on the
  recommended candidate. The output is a memo for the operator.

## References

- BVP policy: `policy/value-drivers.yaml` (D1-D4 + F-RECALL + F-ORCH)
- §ACD discipline: `CLAUDE.md` §Arc Completion Discipline
- DEFER vs hedge: `CLAUDE.md` §Presenting Work for Human Review
- Bus protocol: `CLAUDE.md` §Result Ledger
- Origin: T-2209 IW-1..IW-5 dispatch (2026-06-05)
