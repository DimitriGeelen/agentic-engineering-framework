# T-1740 Spike C — revised prompt template, re-run on T-1736 benchmark

Sibling of T-1736 (Spike B). Spike B revealed a calibration gap — classifier under-
predicts GO on direct commands. Spike C revises `prompts/prompt-triage.md` to add
calibration examples for direct-command-GO patterns and re-runs the same 50-prompt
benchmark with no other change.

## Headline

- **Verdict:** DEFER — partial pass; see Recommendation
- **Accuracy:** 70.00% (++30.00% ↑ vs 40.00%)
- **Always-GO baseline:** 66.00% (must beat this to add value)
- **Macro F1:** 0.395 (++0.038 ↑ vs 0.357)
- **GO recall:** 0.970 (++0.576 ↑ vs 0.394) (threshold for unblocking T-1737: ≥ 0.85)
- **Accuracy threshold for unblocking T-1737:** ≥ 80%  → FAIL
- **Latency p50:** 1432ms (vs T-1736 1171ms)
- **Errors / parse-fails:** 0 / 0

## Confusion matrix (T-1740 / new template)

| truth ↓ / pred → | GO | NO-GO | DEFER |
|---|---|---|---|
| **GO** | 32 | 1 | 0 |
| **NO-GO** | 9 | 3 | 0 |
| **DEFER** | 5 | 0 | 0 |

## Confusion matrix (T-1736 / baseline)

| truth ↓ / pred → | GO | NO-GO | DEFER |
|---|---|---|---|
| **GO** | 13 | 15 | 5 |
| **NO-GO** | 4 | 5 | 3 |
| **DEFER** | 1 | 2 | 2 |

## Per-class metrics — side-by-side delta

| class | metric | T-1736 (baseline) | T-1740 (revised) | Δ |
|---|---|---|---|---|
| GO | precision | 0.722 | 0.696 | -0.027 |
| GO | recall | 0.394 | 0.970 | ++0.576 |
| GO | F1 | 0.510 | 0.810 | ++0.300 |
| NO-GO | precision | 0.227 | 0.750 | ++0.523 |
| NO-GO | recall | 0.417 | 0.250 | -0.167 |
| NO-GO | F1 | 0.294 | 0.375 | ++0.081 |
| DEFER | precision | 0.200 | 0.000 | -0.200 |
| DEFER | recall | 0.400 | 0.000 | -0.400 |
| DEFER | F1 | 0.267 | 0.000 | -0.267 |

## Confidence calibration

- **Mean confidence on correct:** 0.941 (baseline 0.915)
- **Mean confidence on wrong:** 0.943 (baseline 0.880)
- **Gap (correct − wrong):** -0.002 (baseline +0.035)

## Sample disagreements (new run)

- **truth: DEFER, pred: GO** (`987787fcc79c`)
  - prompt: `hey we shloud be in openclau not .agentic farmework !!!`
  - rationale: The prompt contains an explicit command to change state by fixing a known bug in the framework's verification gate, whic
- **truth: DEFER, pred: GO** (`56b7fc6a6ee1`)
  - prompt: `also why it it showing v. 0.9.0 should it not be teh build numebr and get automatically updated ?`
  - rationale: The prompt asks the agent to take specific actions that will mutate state, such as running commands and committing chang
- **truth: DEFER, pred: GO** (`ecd02ce733ad`)
  - prompt: `=== Task Update === Task:    T-504 ("Investigate and enhance image generation pipeline") File:    /opt/3021-Bilderkarte-tool-llm/.tasks/acti`
  - rationale: The prompt contains a direct command to "fix the bug where T-1716 verification gate falsely blocked completion", which r
- **truth: NO-GO, pred: GO** (`90f6292f0602`)
  - prompt: `ok but is 4 hours stall expklainaible by taht ?`
  - rationale: The prompt asks if a 4-hour stall is explainable, which requires investigating and potentially fixing an issue that woul
- **truth: NO-GO, pred: GO** (`d2b2c5d28714`)
  - prompt: `ok and why is the 1.1.15 update not in the relkease notes ??!!!`
  - rationale: The prompt directly asks the agent to take state-mutating actions, including running commands and committing changes, wh
- **truth: NO-GO, pred: GO** (`c9345d718e22`)
  - prompt: `curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash`
  - rationale: Running the install.sh script will mutate framework state by installing or upgrading the Agentic Engineering Framework, 
- **truth: NO-GO, pred: GO** (`8c0897c2d5b7`)
  - prompt: `why 60d , didnt we want incremental feedback, get feedbacj as early as possible?? T-1166 retirement of legacy primitives is now structurally`
  - rationale: The prompt contains clear instructions to mutate state by running commands and committing changes, indicating it require
- **truth: NO-GO, pred: GO** (`daf4c9e1f884`)
  - prompt: `termlink remote list 192.168.10.109:9100 --secret 656e9ece3c409ba318b9203ea81d22eccdad667f56531081bc7d606d8ed063ad`
  - rationale: The prompt contains a direct command-line instruction that will mutate state when executed.
- **truth: NO-GO, pred: GO** (`c6ae6e9b4ee9`)
  - prompt: `> ok 1d , should taht not also be a .122 infrastructure taks ??`
  - rationale: The prompt asks if a specific task should also be classified as an infrastructure task, which implies it wants that task
- **truth: NO-GO, pred: GO** (`2e5562bc13ee`)
  - prompt: `does this has power consultion imnpact ?`
  - rationale: The prompt asks the agent to fix a specific bug, which requires creating or focusing a task first and mutating code stat

## Threshold check

- Accuracy ≥ 80%: **False**
- GO recall ≥ 0.85: **True**

## Recommendation context

See task `## Recommendation` for the GO/NO-GO/DEFER call on unblocking T-1737.
