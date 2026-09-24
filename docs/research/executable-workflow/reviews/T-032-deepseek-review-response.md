# T-032 DeepSeek Review Response

## Metadata

- **Dossier SHA-256:** `99d337126d9e0b9ca9437f1511ecd8e1504103309c6e970003605d2f69ebc9eb`
- **Model:** `deepseek/deepseek-r1-0528`
- **OpenRouter response ID:** `gen-1787186592-wEELxpCYKwDGQ2ODhVoX`
- **Finish reason:** `stop`
- **Usage:** 15,670 prompt + 2,002 completion = 17,672 tokens; 1,032 reasoning tokens
- **Cost:** USD 0.01219936
- **Capture:** complete, raw response below

---

REVIEW VERSION: 99d337126d9e0b9ca9437f1511ecd8e1504103309c6e970003605d2f69ebc9eb  
REVIEWER: DeepSeek (runtime correctness lens)  
LENS: Runtime semantics review with AEF/task-authority cross-check  

## Verdict  
promising-but-incomplete  
The proposal advances executable workflows but lacks critical runtime invariants for task authority and failure recovery. It remains advisory; operator validation of compensation semantics and evidence integrity is essential.  

## Findings  
1. **blocker — Task-state/time-of-check-time-of-use (TOCTOU) vulnerability**  
   - Dossier section: 7.3 Instance state machine, 7.5 Per-node sequence  
   - Observation: Task-content snapshots occur at gates but not during node execution. Mutations after snapshot consumption (e.g., task cancellation mid-script) create authority/state divergence.  
   - Why it matters: Runner may advance nodes against invalid/canceled tasks, violating AEF sovereignty.  
   - Proposed disposition: Add per-attempt task-state preflight and continuous ledger hooks to AEF task service.  
   - Confidence: high  

2. **important — Unspecified compensation idempotency**  
   - Dossier section: 6.2.2 Failure, self-healing, and escalation  
   - Observation: Compensation actions lack idempotency guarantees. Retried remediation (e.g., `clean_test_artifacts`) could double-alter state if initial success wasn't recorded.  
   - Why it matters: Non-idempotent self-healing amplifies failures; violates "safe failure" principle.  
   - Proposed disposition: Require compensation actions to declare idempotency semantics (e.g., `run_once_per_artifact_hash`).  
   - Confidence: medium  

3. **important — Evidence-validation gap**  
   - Dossier section: 6.6.2 Executor and model preference, 7.5 Per-node sequence  
   - Observation: Output validation (e.g., `test_report.status == "passed"`) occurs before evidence is materialized/redacted, creating a race between validation and tampering.  
   - Why it matters: Adversarial agents could alter evidence post-validation but pre-recording.  
   - Proposed disposition: Move output validation after evidence snapshotting; treat evidence as immutable pre-validation input.  
   - Confidence: high  

## Shared whole-system answers  
1. **Contract coherence**: Partially coherent. Task binding and human gates respect AEF, but per-attempt task-state verification is absent. Component scope handling ("unmeasured ≠ zero impact") aligns.  
2. **Missing safety primitive/scenario**: Atomic task-state checks during node execution. Scenario: Task canceled mid-script must force compensation routing, not silent completion.  
3. **Failure for operator, agent, or maintainer**: Operator sees "completed" instance for canceled task. Agent wastes cycles on invalid work. Maintainer faces unreconciled state forks.  
4. **Smallest safe pilot and disqualifying evidence**: Pilot: Human gate → deterministic script → human gate with task-mutation mid-execution. Disqualifier: If instance advances despite task cancellation.  
5. **Inference versus supplied evidence**: Inference that "task-content snapshots prevent drift" – dossier lacks evidence that snapshots are revalidated at every state transition.  

## Missing primitives or acceptance scenarios  
- Atomic task-integrity checks before/during node execution  
- Compensation idempotency contracts  
- Evidence tamper-detection in validation pipeline  

## Smallest credible first pilot  
**Scope**: Single task → instance with two human gates and one registered script action.  
**Guardrails**:  
- Runner validates task state (approved/active) before script dispatch and after completion.  
- Task mutation forces pause → human reconciliation node.  
- Script output evidence snapshot precedes validation.  
**Disqualifying evidence**: Script runs without task-state check; evidence validated before snapshotting.  

## Human decisions required  
- **Task-state monitoring frequency**: Continuous hooks vs. per-transition checks? Trade-off: overhead vs. TOCTOU risk. Models cannot weigh operational load.  
- **Compensation idempotency policy**: Allow "at most once" vs. require explicit idempotency keys? Trade-off: flexibility vs. safety. Requires human risk assessment.  

## What would change this review  
- Evidence of task-state hooks integrated into transition ledger.  
- Example idempotency declaration in compensation action contracts.  
- Demonstration of evidence validation *after* immutable snapshot.
