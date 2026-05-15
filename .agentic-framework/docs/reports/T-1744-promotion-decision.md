# T-1744 — Spike-D Off-ramp: Pick a Different G-064 First-Consumer

**Type:** Inception decision artifact
**Filed:** 2026-05-05
**Focus task:** [T-1744](../../.tasks/active/T-1744-spike-d-off-ramp-pick-a-different-g-064-.md)
**Arc:** orchestrator-rethink
**Predecessors:** T-1688 (G-064 candidate-consumer survey), T-1726 (escalation-scan v0.5 inception → GO), T-1741 + T-1743 (Spike D / D′ → NO-GO)
**Successor:** T-1727 (escalation-scan v0.5 build) on GO

## Executive summary

**Recommendation: GO** — promote T-1727 (escalation-scan v0.5) from `captured/next` to `started-work/now` and wire it as the orchestrator's first real production consumer. Close G-064 via T-1688 option 4.

Three independent decisions converge on the same answer:

| Decision | Date | Outcome | What it tells us |
|---|---|---|---|
| T-1688 (G-064 candidate-consumer survey) | 2026-05-02 | GO on option 1+4 | T-1727 is the smallest concrete real-consumer path. Retrofit ruled out. |
| T-1726 (escalation-scan v0.5 inception) | 2026-05-04 | GO | LLM-augmentation path approved for the escalation queue. |
| Spike B/C/D/D′ (T-1736/T-1740/T-1741/T-1743) | 2026-05-05 | NO-GO on prompt-triage | Confirms T-1688's prediction that none of the existing autonomous workloads is LLM-amenable today. |

Spike D / D′ closed prompt-triage as a viable consumer; T-1727 was never on the closed path.

## Why this is a promotion decision, not an exploration

The exploration was already done:

1. **T-1688** surveyed 18 autonomous workloads and ruled out retrofit. Internal source-code precedent already exists:
   - `tools/escalation-scan-v0.py:1` declares itself a v0 spike (lines 6-10 say *"intentionally simple"*)
   - `lib/reviewer/static_scan.py:18-19` already has a "Orchestrator routing (v3+)" hook stub
2. **T-1726** approved the LLM-augmentation path explicitly. T-1727 is the build-task child of that GO.
3. **Spike-arc** (B → C → D → D′) closed prompt-triage. That confirms — does not undermine — the T-1688 conclusion that the existing autonomous workloads are not LLM-amenable retrofits.

No new candidates have surfaced since T-1688. No competing path needs to be explored.

## Architectural ceiling — design constraint inherited from Spike-arc

**L-355** captures the cross-formulation finding from Spike D and D′:

| Spike | What | Best result | Verdict |
|-------|------|-------------|---------|
| B (T-1736) | hermes3:8b, original template | 40% acc / GO recall 0.40 | NO-GO |
| C (T-1740) | hermes3:8b, calibrated template | 70% acc / GO recall 0.97 | NO-GO (DEFER F1 = 0) |
| D (T-1741) | qwen3 / qwen35 / gemma4, calibrated template | qwen35 76.74% / DEFER F1 0.286 | NO-GO |
| D′ (T-1743) | binary reframe (DEFER → NON_GO) on D results | qwen35 79.07% / GO P 0.839 | NO-GO |

Threshold (3-class): accuracy ≥ 80% AND GO recall ≥ 0.85 AND DEFER F1 ≥ 0.5.
Threshold (binary): accuracy ≥ 90% AND GO recall ≥ 0.85 AND GO precision ≥ 0.85.

**Architectural ceiling, not model-pick or template-tuning.** Future orchestrator consumers must tolerate ~75-80% LLM accuracy on 7-8B local; design must use one of:

1. Advisory output (don't block; surface for human review)
2. Confidence-thresholded fallback
3. Skip LLM augmentation entirely for high-precision gating workloads

## Why escalation-scan v0.5 fits the ceiling

The Spike-arc ceiling is **design-tolerable** for escalation-scan because:

- The workload's purpose is to **surface candidate escalations for human review**, not to gate user prompts.
- False positives are cheap: human ignores the escalation.
- False negatives are mitigated: the existing static-scan layer (`lib/reviewer/static_scan.py`) already runs and catches the deterministic cases.
- The 80% ceiling becomes a virtue: noisy-but-better-than-zero augmentation is exactly what an advisory escalation queue needs.

Counter-example (why the ceiling is fatal for prompt-triage but not escalation-scan): prompt-triage gates the user input before tool execution. An 80%-accurate gate either (a) lets through 20% of bad prompts, or (b) blocks 20% of good prompts. Both are bad enough to make the gate worse than no gate. Escalation-scan has no such precision constraint — the human is the precision filter.

## Off-ramp triage from T-1741

T-1741 named three off-ramps. Their disposition:

| Off-ramp | Status | Rationale |
|---|---|---|
| T-1742 (qwen35 max_tokens=4096) | Captured/later — likely obsolete | Even best-case parse-fail recovery caps qwen35 at ~83-86% binary accuracy, short of 90% threshold. Run only if a future agent specifically needs to validate the parse-fail content. |
| T-1743 (binary reframe) | Completed — NO-GO | Confirmed architectural ceiling; closed Spike-arc. |
| T-1744 (this task — different first-consumer) | Started-work — GO recommended | This artifact. Names T-1727 as the path forward. |

## Substrate health (pre-flight)

`bin/fw orchestrator status` confirms the substrate is healthy and ready for a real consumer:

```
Dispatches:        5
Outcome events:    6
Enriched:          5/5 (100%)
Synthetic:         50 (T-stress-* — excluded from headline)

By task_type:
  default                        3
  prompt-triage                  2

By worker_kind:
  TermLink                       3
  ollama-loop                    2
```

The 5 dispatches are spike/research dispatches (T-1696, T-1697, T-1698, T-1733, T-1738) — substrate is invoked, but not by a production consumer. T-1727 closes that gap.

## Go/No-Go criteria evaluation

**GO if (promote T-1727 to active horizon):** ✓
- T-1727 named in T-1688 + T-1726: ✓
- T-1727 has ACs/Verification scope from T-1726: ✓ (locked-AC contract A1-A9)
- No competing candidate surfaced in Spike-arc: ✓
- Spike-D ceiling is design-tolerable for escalation-scan workload: ✓ (advisory queue, not gating)

**DEFER if:** —
- T-1727 scope needs rework: no — A1-A9 are concrete, build-ready
- Higher priority outranks G-064 closure this week: human's call
- Open arc work upstream of T-1727 unresolved: T-1718 (evolution-gate) is shipped; T-1722 (artefact paths) is shipped

**NO-GO if:** —
- Stronger candidate surfaced since T-1688: none
- Architectural learning rules out LLM-augmented orchestrator consumers entirely: it doesn't (only 90%+ classification on 7-8B local is ruled out — escalation-scan is advisory, not gating)
- G-064 closure via "developer-facing tool, no production consumer" alone (T-1688 option 1 without option 4): possible but weaker — leaves the substrate unexercised

## What human GO authorizes

1. T-1727 promoted from `captured/next` to `started-work/now` via `bin/fw work-on T-1727`
2. Build proceeds per A1-A9 (locked at T-1726 filing)
3. `## Verification` runs per pre-flight commands committed at e723e4b73
4. Design constraint from L-355 honored: no AC assumes >85% LLM accuracy

## What human GO does NOT authorize

- Any modification to A1-A9 without an `## Evolution` entry (T-1718 gate)
- Bypass of P-011 verification at completion
- Closure of the orchestrator-rethink arc itself (Default-to-OPEN per §ACD §3-pushback rule; arc closure is a separate human decision via Watchtower)

## Asks of the human

1. **Confirm GO** via Watchtower at `http://192.168.10.107:3002/inception/T-1744`, OR
2. **DEFER** if other work outranks this week, OR
3. **NO-GO** to close G-064 by accepting "developer-facing tool, no production consumer" (T-1688 option 1 alone, dropping option 4)

## Evidence

- `docs/reports/T-1688-candidate-consumer-survey.md` — G-064 candidate survey
- `.tasks/completed/T-1688-g-064-candidate-consumer-survey--classif.md` — GO on option 1+4
- `.tasks/completed/T-1726-escalation-scan-v05--llm-augmentation-as.md` — `**Recommendation:** GO`
- `.tasks/active/T-1727-v05-build--escalation-scan-with-llm-augm.md` — build task, queue-ready
- `docs/reports/T-1741-spike-d.md` — Spike D NO-GO (4 models)
- `docs/reports/T-1743-binary-rescore.md` — Spike D′ NO-GO (binary reframe)
- L-355 — architectural ceiling captured in `.context/project/learnings.yaml`
- `bin/fw orchestrator status` — substrate health
