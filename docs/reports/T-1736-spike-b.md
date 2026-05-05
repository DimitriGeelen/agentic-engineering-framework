# T-1736 Spike B — prompt-triage classifier accuracy

Sibling of T-1733 (Spike A: substrate). Spike A established that the substrate
works end-to-end (litellm:4000 → ollama hermes3:8b, p50 ~1s, $0). Spike B
measures classifier accuracy on real user prompts harvested from 30 days of
session JSONLs across all consumer projects.

## Methodology

- **Harvest:** `~/.claude/projects/*/*.jsonl`, last 30 days, deduplicated, filtered
  to plain-string user messages 40–2000 chars long, sub-agent prompts kept (they
  are agent-issued but pass through `type:user` and the classifier sees them in
  production too via UserPromptSubmit).
- **Sample:** 50 prompts, stratified roughly equally across consumer projects.
- **Labels:** Hand-labeled by the framework agent against the verdict definitions in
  `prompts/prompt-triage.md`. Single-rater (caveat: not blind).
- **Run:** `claude-3-5-sonnet-hermes3` via litellm:4000, temp=0, max_tokens=256.

## Class distribution (ground truth)

- **GO:** 33 (66.0%)
- **NO-GO:** 12 (24.0%)
- **DEFER:** 5 (10.0%)

## Headline numbers (n=50)

- **Accuracy:** 40.00% (20/50)
- **Always-GO baseline:** 66.00%  ← classifier must beat this to add value
- **Macro precision:** 0.383
- **Macro recall:** 0.404
- **Macro F1:** 0.357
- **Weighted F1:** 0.434
- **Latency p50:** 1171ms · p95: 2059ms · mean: 1613ms
- **Parse failures:** 0 / 50
- **Errors:** 0 / 50

## Confusion matrix

| truth ↓ / pred → | GO | NO-GO | DEFER |
|---|---|---|---|
| **GO** | 13 | 15 | 5 |
| **NO-GO** | 4 | 5 | 3 |
| **DEFER** | 1 | 2 | 2 |

## Per-class metrics

| class | TP | FP | FN | precision | recall | F1 |
|---|---|---|---|---|---|---|
| GO | 13 | 5 | 20 | 0.722 | 0.394 | 0.510 |
| NO-GO | 5 | 17 | 7 | 0.227 | 0.417 | 0.294 |
| DEFER | 2 | 8 | 3 | 0.200 | 0.400 | 0.267 |

## Confidence calibration

- **Mean confidence on correct:** 0.915 (n=20)
- **Mean confidence on wrong:** 0.880 (n=30)
- **Gap:** +0.035 — positive means model is more confident when right.

## Sample disagreements

- **truth: GO, pred: NO-GO** (`ab30e5805ca7`)
  - prompt: `Run: bin/fw upgrade /opt/053-ntfy -- then verify the version pin in /opt/053-ntfy/.framework.yaml matches 1.5.593. Report success or failure`
  - rationale: The prompt is a direct command to run a framework upgrade and verify it, which is a read-write operation but does not re
- **truth: GO, pred: NO-GO** (`c99b76674cb2`)
  - prompt: `Commit the fw upgrade changes. Run: git add .agentic-framework/ && git commit -m 'T-012: fw upgrade v1.5.575 — performance cache, learnings,`
  - rationale: The prompt is a straightforward command to commit framework changes, which does not require creating or focusing a new t
- **truth: GO, pred: NO-GO** (`d638e2b9f582`)
  - prompt: `You are working in /opt/001-sprechloop. The framework was just upgraded from v1.4.566 to v1.4.576 via fw upgrade. Your job: 1) cd /opt/001-s`
  - rationale: The prompt describes a straightforward git workflow to sync framework changes, which does not require creating or focusi
- **truth: GO, pred: NO-GO** (`2d84d0501238`)
  - prompt: `You are working in /opt/051-Vinix24. The framework was just upgraded. Your job: 1) cd /opt/051-Vinix24 2) git add -A .agentic-framework/ .cl`
  - rationale: The prompt does not ask for any substantive changes or work - it only provides instructions to update the framework to a
- **truth: GO, pred: NO-GO** (`9985198ef357`)
  - prompt: `some cards have wronf fromatting lie for instance Assumption Testing - d.school`
  - rationale: The prompt appears to be an example input, not a request for substantive work or task creation.
- **truth: DEFER, pred: NO-GO** (`56b7fc6a6ee1`)
  - prompt: `also why it it showing v. 0.9.0 should it not be teh build numebr and get automatically updated ?`
  - rationale: The prompt asks an informational question about build versioning, not requesting any changes or work to be done.
- **truth: GO, pred: NO-GO** (`d2750c50b6f1`)
  - prompt: `Run: bin/fw upgrade /opt/052-KCP -- then verify the version pin in /opt/052-KCP/.framework.yaml matches 1.5.593. Report success or failure i`
  - rationale: The prompt is a direct command to run an upgrade and verify the result, which does not require creating or focusing a ne
- **truth: GO, pred: NO-GO** (`36c0982c430b`)
  - prompt: `T-198: check verdict on disclaim-detection demo. Should be FAIL with self-disclaim finding cited. Then close T-198 and report.`
  - rationale: The prompt is instructing the agent to check and report on an existing task's outcome, without needing to create or focu
- **truth: GO, pred: NO-GO** (`6aa328b0b57f`)
  - prompt: `Commit the fw upgrade changes. Run: git add .agentic-framework/ && git commit -m 'T-012: fw upgrade — perf cache + YAML fixes'. If no change`
  - rationale: The prompt is giving instructions to commit changes and report status, not asking for new work to be done.
- **truth: GO, pred: NO-GO** (`7272209e64d9`)
  - prompt: `You are working in /opt/995_2021-kosten. The framework was just upgraded. Your job: 1) cd /opt/995_2021-kosten 2) git add -A .agentic-framew`
  - rationale: The prompt provides step-by-step instructions that do not require creating or focusing a new task, but rather updating a

## Recommendation context

See task `## Recommendation` block for the GO/NO-GO/DEFER call on production
rollout, citing the numbers above.
