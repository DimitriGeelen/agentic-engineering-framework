# T-1743 Spike-D binary re-score — drop DEFER, re-frame as GO / non-GO

Collapses DEFER labels into NO-GO in both truth and predictions, re-scores
the four T-1741 result files. No new inference. Question: if we drop the
DEFER class (consistently weakest signal across all 4 models in Spike D),
can a binary classifier clear T-1737 unblock thresholds?

**Binary thresholds (proposed):** accuracy >= 0.90 AND GO recall >= 0.85 AND GO precision >= 0.85

**Always-GO baseline (binary):** 66.00% (33/50 prompts)

## Headline

| model | acc | GO P | GO R | GO F1 | NON_GO F1 | macro F1 | parse-fails |
|---|---|---|---|---|---|---|---|
| hermes3 | 70.00% | 0.696 | 0.970 | 0.810 | 0.286 | 0.548 | 0 |
| qwen3 | 70.00% | 0.846 | 0.667 | 0.746 | 0.634 | 0.690 | 0 |
| qwen35 | 79.07% | 0.839 | 0.867 | 0.852 | 0.640 | 0.746 | 7 |
| gemma4 | 74.00% | 0.857 | 0.727 | 0.787 | 0.667 | 0.727 | 0 |

**Best by accuracy:** **qwen35** (acc=79.07%, GO F1=0.852)

## Verdict: NO-GO

Best model (qwen35) does not clear all binary thresholds. Failing: accuracy 79.07% < 90%; GO precision 0.839 < 0.85.

Binary reframe does not rescue T-1737. The architectural concern (3-class signal too noisy on 7-8B local model) propagates to binary as well. Recommend T-1744 (different G-064 first-consumer) over T-1742 (qwen35 max_tokens spike).

## Per-model confusion (binary)

### hermes3
- TP (GO->GO): 32  ·  FN (GO->NON_GO): 1
- FP (NON_GO->GO): 14  ·  TN (NON_GO->NON_GO): 3
- accuracy: 70.00%  ·  parse-fails: 0  ·  errors: 0

### qwen3
- TP (GO->GO): 22  ·  FN (GO->NON_GO): 11
- FP (NON_GO->GO): 4  ·  TN (NON_GO->NON_GO): 13
- accuracy: 70.00%  ·  parse-fails: 0  ·  errors: 0

### qwen35
- TP (GO->GO): 26  ·  FN (GO->NON_GO): 4
- FP (NON_GO->GO): 5  ·  TN (NON_GO->NON_GO): 8
- accuracy: 79.07%  ·  parse-fails: 7  ·  errors: 0

### gemma4
- TP (GO->GO): 24  ·  FN (GO->NON_GO): 9
- FP (NON_GO->GO): 4  ·  TN (NON_GO->NON_GO): 13
- accuracy: 74.00%  ·  parse-fails: 0  ·  errors: 0

