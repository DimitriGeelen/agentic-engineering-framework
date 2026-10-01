# T-3670 round 1 synthesis: three internal seats, blind

Seats: OpenAI (codex), Z.ai (GLM-5.2 via opencode), Anthropic (claude -p). Same frozen pack (~20K tokens, §1-§14) and question v3; the project's lean was not disclosed. Answers: `T-3670-r1-{openai,zai,anthropic}.md`. Cost logged (internal class).

## Consensus (3 of 3)
1. **D1, architecture: layered; the hooks are demoted to a guardrail.** The BOUNDARY is:
   - a **non-root agent uid**;
   - **enforcement files owned by root or a governance user**;
   - a **privileged broker** (T-2428's aef-govd) holding the approval state and, per Anthropic, the forge force-push credential;
   - **server-side ref protection** (OneDev).
   Per-harness adapters (Claude Code hooks, an opencode plugin) become the guardrail layer. The T-2428 payload proxy is the cross-harness guardrail, added as phase 2 (Z.ai, Anthropic) or as part of the hybrid (OpenAI). Confidence is **medium** for all three, for the same reason: the isolation legs are standard controls but NONE is deployed here yet (§13.1 "nothing installed"; §11 OneDev protection unknown).
2. **D5, elevation: a privileged broker issuing operator-signed, single-use, time-limited grants.** Low-risk categories run prompt-free (lockfile-pinned dependency installs, project-service restarts, policy writes, isolated builds). Destructive actions are one-tap: force-push, ref-delete, hard-reset, recursive delete outside the workspace, system packages, protected config, paid backends, and everything unmapped.
3. **PILOT: the Tier 0 approval path through the broker,** with reference sessions running as non-root. STOP conditions across the seats:
   - any unapproved effect, replay or self-approval executes;
   - the agent uid can write any §11 enforcement path;
   - any benign case T0-101…122 newly blocks;
   - an approval costs more than one operator action compared with today.
4. **D4, delivery:** signed, version-pinned artefacts (static per-OS/arch binaries per Z.ai and Anthropic; signed bundles per OpenAI). A **missing or mismatched component means DENY**, with no fallback to the legacy path.

## Split: D2, implementation language (the operator's call, or round 2)
| Seat | D2 |
|---|---|
| OpenAI | **TypeScript** for the new core (honours T-586) |
| Z.ai | **Polyglot:** Go (mvdan.cc/sh) for the Tier 0 engine; strict Python for the broker/relay (reuses existing T-2428 code); TypeScript for adapters/fw-util (T-586 rescoped); the bash dispatcher stays |
| Anthropic | **Polyglot:** Go for the broker, hook binary and Tier 0 classifier; bash stays as CLI glue; Python stays for Watchtower and the ledger; TypeScript frozen at its current scope |

Two of three choose **Go for the Tier 0 classifier** (because of the bash parser); one chooses TypeScript throughout. All three keep bash for the CLI glue. **The language decision is secondary to the architecture:** all three say the boundary comes from configuration (uid, file ownership, the broker, server-side protection), not from rewriting code. Language matters for the classifier and the broker.

## Partial overlap: D3, scope
- **All three:** Tier 0 plus pre-push; the broker/approval store; ledger signing/verification custody.
- **Two of three** (OpenAI, Z.ai): the task/focus gate engine.
- **Split:** the budget and task-close gates (OpenAI in; Anthropic out).

## What would change their minds
- OpenAI: a cross-platform adversarial pilot showing the broker boundary cannot stop unauthorised mutations without unacceptable friction.
- Z.ai: the Go engine failing parity on the 98-case corpus while a Python or TypeScript engine passes.
- Anthropic: see its answer file.

## Next steps (proposed)
- **Converge:** the pilot is the same for all three and does not depend on D2's split. Deploy aef-govd as the approval holder, run reference sessions as a non-root uid, move the approval store out of the agent's reach, and verify server-side protection. That can start without settling the language.
- **D2:** settle with a parity experiment (Z.ai's mind-changer). Run the 98-case §5 corpus against a Go/mvdan.cc/sh classifier versus a TypeScript one, or take it to round 2 / external seats per the T-3557 ladder.
