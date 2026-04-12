# T-954: Human AC Classification Reform

## Research Artifact (C-001)

**Task:** T-954
**Created:** 2026-04-06
**Status:** Complete
**Related:** T-823 (auto-verification POC), T-193 (Agent/Human AC split), T-325 (actionable Human ACs), T-358 (prerequisite awareness), T-373 (human task completion rule)

---

## Phase 1: Categorize Existing Human ACs

### Current state

129 unchecked Human ACs across 82 tasks. Breakdown:

| Category | Count | % | Can automate? |
|----------|-------|---|---------------|
| Inception go/no-go decisions | 48 | 37% | **No** — sovereignty decisions |
| Writing voice/tone reviews | 7 | 5% | **No** — genuinely subjective |
| Content/architecture review | 12 | 9% | **No** — requires domain judgment |
| UI visual/UX reviews | 12 | 9% | **Partially** — HTTP + element checks, but "looks good" is subjective |
| RUBBER-STAMP CLI-testable (Linux) | 29 | 22% | **Yes** — deterministic, copy-pasteable commands |
| RUBBER-STAMP requires macOS | 4 | 3% | **Yes** — via TermLink to .107 Mac |
| RUBBER-STAMP requires phone | 2 | 2% | **No** — physical device needed |
| Unlabelled | 4 | 3% | Needs classification first |
| External actions (post, record video) | 4 | 3% | **No** — human action required |

### Key insight

**51% of Human ACs genuinely need human judgment** (inception decisions + subjective reviews). These should stay. **31% are deterministic tests** that happen to be labeled Human because they weren't classified by risk. **The remaining 18% are mixed or environment-blocked.**

### The inception go/no-go problem

48 of 129 ACs (37%) are identical boilerplate: "Review exploration findings and approve go/no-go decision." These are correct — inception decisions are sovereignty decisions. But 31 inception tasks have recommendations ready and waiting. The bottleneck isn't classification; it's review throughput.

Potential mitigations (not AC reclassification):
- Batch review page in Watchtower showing all pending inception decisions with summaries
- Priority scoring so the most impactful decisions surface first
- "Quick approve" for NO-GO and DEFER recommendations (lower risk than GO)

## Phase 2: Risk Classification Model

### Proposed dimensions

| Dimension | Low risk (Agent-verifiable) | High risk (Human required) |
|-----------|---------------------------|--------------------------|
| **Reversibility** | Can undo (git revert, config change) | Hard to undo (published content, deleted data, sent messages) |
| **Blast radius** | Single file/component | Cross-system, external-facing, multi-project |
| **Subjectivity** | Binary pass/fail (file exists, endpoint responds) | Judgment call (looks good, reads well, feels safe) |
| **External visibility** | Internal dev tooling | Published content, user-facing UI, public APIs |
| **Authority level** | Operational (how to implement) | Strategic (what to build, whether to proceed) |

### Classification rule

An AC should be **Human** if ANY of these apply:
1. **Strategic authority** — go/no-go decisions, architecture choices, priority calls
2. **Subjective judgment** — quality, tone, UX feel, "is this good enough?"
3. **Irreversible external action** — publishing, deploying to production, sending communications
4. **Cross-project blast radius** — changes affecting multiple consumer projects

An AC should be **Agent** (with programmatic verification) if ALL of these apply:
1. **Deterministic outcome** — binary pass/fail with clear expected result
2. **Reversible** — can be undone if wrong (git revert, config change)
3. **Internal scope** — affects only development tooling, not external users
4. **Mechanical execution** — no judgment needed, just "run X, check Y"

### The gray zone: UI verification

12 ACs say things like "renders correctly" or "looks good." These split into:
- **Functional** ("page loads, key elements present") → Agent-verifiable via HTTP + HTML parsing
- **Aesthetic** ("layout is clean", "feels intuitive") → Human judgment

**Proposal:** Split these into two ACs — Agent AC for functional check, Human AC only if aesthetic judgment is genuinely needed. Many "renders correctly" ACs are really asking "did you break it?" which is testable.

## Phase 3: Verification Tier Mapping

Based on T-823 proof-of-concept results:

| Tier | Method | Best for | Proven? | Cost |
|------|--------|----------|---------|------|
| 1: Programmatic | Shell commands, curl, grep, file checks | CLI tools, endpoints, file existence, config validation | Yes (T-823: 7/7 HTTP tests passed) | ~0 (existing infra) |
| 2: TermLink E2E | Spawn process, inject commands, check output | CLI workflows, process interaction, cross-terminal tests | Yes (T-823: loop detector verified) | Low (TermLink already installed) |
| 3: Playwright | Browser automation, screenshot comparison | Interactive UI, JavaScript-dependent pages | Partial (sandbox issues on root Linux) | Medium (needs sandbox fix or non-root) |

### What each tier can verify

**Tier 1 examples (29 ACs immediately convertible):**
- `curl -sf http://localhost:3000/page | grep -q "expected"` — page renders with key element
- `bin/fw costs session | grep -q "Session"` — CLI output format
- `test -f .mcp.json` — file created by init
- `bin/fw tier0 status | grep -q "blocked"` — gate enforcement

**Tier 2 examples (needs TermLink):**
- Spawn Claude Code session, verify hooks fire (tool counter increments)
- Run `claude-fw --termlink`, verify session registers
- Multi-step CLI workflows requiring process state

**Tier 3 examples (needs Playwright fix):**
- Fabric Explorer graph interaction (click, drag, zoom)
- Dark mode toggle persistence across pages
- QR code rendering and scannability

## Phase 4: Proposed CLAUDE.md Changes

### 1. Add AC Classification Rule to §Agent/Human AC Split

Current rule (T-193): "Agent ACs = criteria the agent can verify. Human ACs = criteria requiring human verification."

**Proposed addition:**

> **AC Classification Guidance:**
> - Use the risk matrix (reversibility × subjectivity × blast radius × external visibility) to classify
> - Default to Agent AC with programmatic verification for deterministic, reversible, internal checks
> - Default to Human AC for strategic decisions, subjective quality, irreversible external actions
> - RUBBER-STAMP ACs with deterministic test steps SHOULD be Agent ACs with verification commands
> - When in doubt, make it Human — false negatives (missing a broken thing) are worse than false positives (asking the human unnecessarily)

### 2. Add Verification Tier to Agent ACs

When converting a RUBBER-STAMP to an Agent AC, the verification command goes in `## Verification`:

```markdown
### Agent
- [x] Page renders with key elements
  Verification: `curl -sf http://localhost:3000/config | grep -q "Settings"`
```

### 3. Keep Human ACs for genuine judgment

No change to REVIEW-tagged ACs. The existing format (Steps/Expected/If not) is correct.

### 4. Inception go/no-go stays Human

No change. But add batch review tooling recommendation.

## Phase 5: Risk Assessment

### What could go wrong?

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Auto-verification passes but feature is broken | Medium | High | Verification commands must test behavior, not just existence. `curl -sf` + `grep` tests response content, not just HTTP 200. |
| Agent reclassifies a genuinely subjective AC | Low | Medium | Classification rule has "when in doubt, Human" default. Human can always override. |
| Destructive action slips through | Very low | Critical | Tier 0 gate is orthogonal to AC classification. Destructive actions are blocked by `check-tier0.sh`, not by Human ACs. |
| Reduced human oversight leads to quality drift | Medium | Medium | The audit (Loop 10/D2) still flags aging review queues. UI reviews and voice/tone stay Human. |

### What safeguards remain?

Even with reclassification, these structural protections are unchanged:
1. **Tier 0 gate** — blocks destructive commands regardless of AC type
2. **Inception gate** — go/no-go decisions always require human authority
3. **P-011 verification gate** — verification commands must pass before completion
4. **Authority model** — Human = SOVEREIGNTY, Agent = INITIATIVE
5. **Audit D2** — flags aging human review queue

### The balance point

The user's framing is correct: this is not about complete risk avoidance, it's about smart risk-taking. The current system is over-conservative for deterministic tests (asking a human to run `curl` and check output) while providing no additional safety over a programmatic check. Moving those to Agent ACs with verification commands actually **increases** reliability — machines are better at deterministic checks than humans who may skip steps.

The genuinely high-risk items (inception decisions, published content quality, architecture choices) stay Human. The deterministic checks get better enforcement through automation.

## Recommendation

**GO** — Implement in three phases:

### Phase 1: Framework rule change (CLAUDE.md)
Add AC classification guidance with the risk matrix. Change defaults so RUBBER-STAMP functional tests are Agent ACs with verification commands. No tooling changes needed.

### Phase 2: Reclassify existing ACs
Go through the 29 CLI-testable RUBBER-STAMP ACs and convert to Agent ACs with verification commands. This directly clears ~22% of the backlog. Split the 12 UI ACs into functional (Agent) and aesthetic (Human) where applicable.

### Phase 3: Tooling improvements
- `fw verify-acs --auto-check` (T-823 build task) for batch programmatic verification
- Batch inception review page in Watchtower for the 48 go/no-go decisions
- TermLink E2E test harness for Tier 2 verification

### What this achieves
- Reduces Human AC backlog by ~35-40% (45-50 of 129)
- Remaining Human ACs are genuinely judgment-requiring — higher signal-to-noise
- Deterministic checks get better enforcement (machine > human for pass/fail)
- No reduction in safety — Tier 0, inception gate, authority model unchanged
