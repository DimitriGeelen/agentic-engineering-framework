# T-3726: synthesis of three external reviews (OpenAI/codex, Z.ai/GLM-5.2, Google/Antigravity), blind, 2026-10-02

Inputs:
- the brief: `T-3726-inception-process-rca.md`;
- the reviews: `T-3726-review-{openai,zai,google}.md`.

## The verdicts in one line each
- **OpenAI:** "enforces local paperwork but leaves readiness communication, implementation ownership, and proof of completion dependent on agents."
- **Z.ai:** "computes decision-readiness in five places but exposes it in none where the actor needs it — gates fire serially after a handoff instead of once before it, and GO is recorded with no build-completeness invariant."
- **Google:** "couples distributed, serial bash gatekeeping with decoupled UI presentation and zero structural lifecycle tracking between decision and execution."

## Root cause (3 of 3 agree)
1. **The decision surface is decoupled from readiness.**
   - Z.ai checked `web/blueprints/inception.py:344-503`: `inception_detail` never calls the readiness predicate. GO renders unconditionally and refuses only at POST.
   - The operator becomes the one who discovers the problem. The CLI refusal (T-3549) worked, but nothing stops a hand-built link from leading to an active GO button.
2. **Readiness is re-implemented in several places with different severities,** so blockers are found one at a time: G-067, T-3549, the T-3279 decide preflight, T-2190 at close, and the filing gates.
3. **The handoff channel mixes refusal and success on one stream.**
   - The output is noisy (banner, QR code) and the URL is guessable, so agents grep for the URL and synthesise it when it is missing.
   - A prose rule in CLAUDE.md demonstrably does not bind (E1).
4. **GO is terminal. Nothing turns it into a delivery obligation.**
   - Build traceability is optional and grandfathered (186/381 GO'd inceptions have no build link).
   - Build slices can fence requirements out with no owner, and completeness is only audited after the fact (E2).
5. **Workers author both the work and its proof,** so close gates accept self-graded evidence. Silent model downgrades make it worse (E4).
6. **"More gates" is part of the problem.** Each gate patches a symptom while the interface defects stay. Today's own additions (T-3691/T-3694) continue that pattern.

Agent behaviour (filtering away a refusal, synthesising the URL, the unverified AC claim) is real and is recorded as a learning. All three reviewers nonetheless rank the structural causes above it: **the system relied on agent obedience to connect the steps.**

## Fixes all three rank highest (consensus)
| # | Fix | Replaces / merges | Success measure |
|---|---|---|---|
| F1 | **Watchtower checks readiness when it renders the page:** GO/NO-GO hidden or disabled with the blockers listed; the submission re-checks atomically | the decide-time surprise | 0 operator-facing "Cannot record" events |
| F2 | **One readiness API** (`fw inception readiness T-XXX --json` → `{ready, blockers[]}`, exit 0/1/2) used by review, Watchtower, decide and close; models the auto-tick semantics | merges G-067, T-3549, T-3279 and T-2190 readiness logic | 1 refusal round per decision cycle |
| F3 | **Handoff output contract:** stdout is the URL or nothing; diagnostics on stderr; `--json`; no banner or QR code when not a tty. Longer term, the framework publishes the decision request to /approvals itself and the agent never builds a link | the grep-swallow and URL-synthesis class | 0 hand-built URLs |
| F4 | **GO creates a binding delivery obligation:** a mandatory requirement manifest with existing owner tasks, no grandfather for new GOs; descoping is operator-only; the inception (or its scope) stays open until every requirement is built or explicitly descoped (Google: an `approved-pending-build` state) | optional T-1984 `ships_in`, the T-3562 report, and today's T-3691/T-3694 register (folded into one mechanism) | 0 new GOs without build links; 0 unowned deferrals |
| F5 | **Independent acceptance:** closing work against a GO'd design requires evidence the closing worker did not author (a different worker or model) | worker-authored proof as sufficient | E4-class false closes caught at close |
| F6 | **Model routing visible per dispatch;** no silent downgrade | silent route cache (T-3709) | 0 silent downgrades |

## Removals (where they agree, and where they split)
- **Commit cap (15):** remove (Google), retire provisionally (OpenAI), insufficient evidence (Z.ai). **2 of 3 favour removal,** to be replaced by exploration age plus open questions.
- **Filing-time Recommendation gate plus the hourly DEFER-stub cron:** remove (Z.ai, Google); insufficient evidence (OpenAI). **2 of 3.** Z.ai asks for a count of stubs that turned into real decisions before killing it.
- **`@auto-tick-on-decide` ceremonial ACs:** remove (Z.ai, Google). They verify nothing and misled the agent in E1. **2 of 3.**
- **Open-questions edit gate (G-067):** remove (Google); insufficient evidence (OpenAI); Z.ai is silent. **Split:** the operator decides.
- **`.reviewed-T-XXX` marker gate:** remove (Z.ai only).
- **Duplicate readiness implementations:** remove (3 of 3; replaced by F2).

## Split, for the operator
- **Google's F7:** a capability-signed decision nonce, so a decision POST is only valid when issued after a passing readiness check. The other two did not propose it.
- **How hard F4 should bite:** Google wants GO to create child tasks atomically. OpenAI and Z.ai want a mandatory manifest with existing owners. Z.ai flags insufficient evidence on burden for small GOs (a distribution of requirements per GO would settle it).

## Proposed build order (each its own task, after the operator's decision)
1. F1 + F2 together: the readiness API and the Watchtower page that consumes it. This stops the E1 class at the source.
2. F3: the handoff output contract (small).
3. F4: the delivery obligation, which replaces and absorbs T-3691/T-3694's register and T-1984.
4. F5 + F6: independent acceptance and visible routing (T-3709 already filed).
5. Removals, each with the measurement the reviewers asked for first: cap interventions, DEFER-stub conversion.
