# T-1741 Spike D — alternative model evaluation

Closes the prompt-triage rollout decision arc that T-1733 (Spike A) opened, T-1736
(Spike B) measured, and T-1740 (Spike C) revised. Spike D swaps only the underlying
ollama model — prompt template stays at T-1740 baseline. All four models run on the
identical 50-prompt benchmark from `.context/spikes/T-1736-sampled.jsonl`.

## Headline

| model | accuracy | GO recall | DEFER F1 | macro F1 | conf-gap | p50 ms | errors |
|---|---|---|---|---|---|---|---|
| hermes3 | 70.00% | 0.970 | 0.000 | 0.395 | -0.002 | 1432 | 0+0p |
| qwen3 | 66.00% | 0.667 | 0.471 | 0.600 | +0.091 | 15844 | 0+0p |
| qwen35 | 76.74% | 0.867 | 0.286 | 0.602 | +0.063 | 39673 | 0+7p |
| gemma4 | 68.00% | 0.727 | 0.500 | 0.601 | +0.015 | 8853 | 0+0p |

- **Always-GO baseline:** 66.00% (any model below this is worse than null)
- **Pass thresholds:** accuracy ≥ 80% AND GO recall ≥ 0.85 AND DEFER F1 ≥ 0.50
- **Best by accuracy:** **qwen35**

## hermes3

- accuracy: **70.00%** (35/50)
- macro F1: 0.395
- conf-gap: -0.002  (>0 = more confident when right)
- latency p50: 1432ms · errors: 0 · parse-fails: 0
- threshold check: acc≥80% **False** · GO recall≥0.85 **True** · DEFER F1≥0.50 **False**

**Confusion matrix:**

| truth ↓ / pred → | GO | NO-GO | DEFER |
|---|---|---|---|
| **GO** | 32 | 1 | 0 |
| **NO-GO** | 9 | 3 | 0 |
| **DEFER** | 5 | 0 | 0 |

| class | precision | recall | F1 |
|---|---|---|---|
| GO | 0.696 | 0.970 | 0.810 |
| NO-GO | 0.750 | 0.250 | 0.375 |
| DEFER | 0.000 | 0.000 | 0.000 |

## qwen3

- accuracy: **66.00%** (33/50)
- macro F1: 0.600
- conf-gap: +0.091  (>0 = more confident when right)
- latency p50: 15844ms · errors: 0 · parse-fails: 0
- threshold check: acc≥80% **False** · GO recall≥0.85 **False** · DEFER F1≥0.50 **False**

**Confusion matrix:**

| truth ↓ / pred → | GO | NO-GO | DEFER |
|---|---|---|---|
| **GO** | 22 | 4 | 7 |
| **NO-GO** | 4 | 7 | 1 |
| **DEFER** | 0 | 1 | 4 |

| class | precision | recall | F1 |
|---|---|---|---|
| GO | 0.846 | 0.667 | 0.746 |
| NO-GO | 0.583 | 0.583 | 0.583 |
| DEFER | 0.333 | 0.800 | 0.471 |

## qwen35

- accuracy: **76.74%** (33/43)
- macro F1: 0.602
- conf-gap: +0.063  (>0 = more confident when right)
- latency p50: 39673ms · errors: 0 · parse-fails: 7
- threshold check: acc≥80% **False** · GO recall≥0.85 **True** · DEFER F1≥0.50 **False**

**Confusion matrix:**

| truth ↓ / pred → | GO | NO-GO | DEFER |
|---|---|---|---|
| **GO** | 26 | 2 | 2 |
| **NO-GO** | 3 | 6 | 1 |
| **DEFER** | 2 | 0 | 1 |

| class | precision | recall | F1 |
|---|---|---|---|
| GO | 0.839 | 0.867 | 0.852 |
| NO-GO | 0.750 | 0.600 | 0.667 |
| DEFER | 0.250 | 0.333 | 0.286 |

## gemma4

- accuracy: **68.00%** (34/50)
- macro F1: 0.601
- conf-gap: +0.015  (>0 = more confident when right)
- latency p50: 8853ms · errors: 0 · parse-fails: 0
- threshold check: acc≥80% **False** · GO recall≥0.85 **False** · DEFER F1≥0.50 **True**

**Confusion matrix:**

| truth ↓ / pred → | GO | NO-GO | DEFER |
|---|---|---|---|
| **GO** | 24 | 8 | 1 |
| **NO-GO** | 4 | 8 | 0 |
| **DEFER** | 0 | 3 | 2 |

| class | precision | recall | F1 |
|---|---|---|---|
| GO | 0.857 | 0.727 | 0.787 |
| NO-GO | 0.421 | 0.667 | 0.516 |
| DEFER | 0.667 | 0.400 | 0.500 |

## Verdict

**NO-GO** — best model (qwen35) does not clear all thresholds.

Failing: accuracy 76.74% < 80%; DEFER F1 0.286 < 0.5

T-1737 (Slice 2) remains BLOCKED. See task `## Recommendation`.
