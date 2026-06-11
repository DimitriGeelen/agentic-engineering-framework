---
id: T-1748
name: "harden v0.5 parse_verdict_envelope — regex fallback for unquoted rationales"
description: >
  harden v0.5 parse_verdict_envelope — regex fallback for unquoted rationales

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [escalation-scan, v0.5, parser]
components: [tests/unit/test_escalation_v05_parser.py, 
      tools/escalation-scan-v0.5.py]
related_tasks: [T-1727]
arc_id: orchestrator-rethink
created: 2026-05-05T18:24:26Z
last_update: '2026-06-11T22:23:57Z'
date_finished: 2026-05-05T18:28:45Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 3
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=3 (body:typed-io-or-gate); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1748: harden v0.5 parse_verdict_envelope — regex fallback for unquoted rationales

## Context

T-1727 forward work. The v0.5 disagreement-rate report (`docs/reports/T-1727-v0-5-disagreement-rate.md`) captured **10/170 = 5.9% PARSE-FAIL rate** on the 30-day backlog run. The current `parse_verdict_envelope` in `tools/escalation-scan-v0.5.py:243-276`:

1. Locates a fenced ` ```yaml ... ``` ` block.
2. Calls `yaml.safe_load` on the block content.
3. Returns `{}` on any `yaml.YAMLError` → `verdict = "PARSE-FAIL"`.

The failure mode (verified against `T-1123` and 9 others in the report): the model emits a syntactically *intentful* envelope where `verdict:` and `confidence:` are recognisable but `rationale:` contains an unquoted colon (e.g. `rationale: This is a fix: a clear bug response`), or the closing fence is missing, or the LLM emitted plain text without the fence at all. yaml.safe_load aborts on the first syntactic error and the entire envelope is discarded — even though the verdict word is sitting right there in plain text.

**Hardening pattern:** when yaml.safe_load fails (or the fenced extraction yields nothing), fall back to a regex extractor that captures the verdict word, confidence number, and rationale-as-rest. This trades structural strictness for robustness — appropriate for an advisory pipeline where any verdict is more useful than a black-hole envelope.

**Out of scope:** changing the prompt's output contract (a separate v1 promotion criterion in the report). The fix is purely on the parsing side — the prompt stays as-is, but we tolerate sloppier outputs.

## Acceptance Criteria

### Agent
- [x] **A1.** `parse_verdict_envelope` returns a populated dict (verdict ∈ {real_symptom_fix, false_positive, defer}, confidence ∈ [0,1]) for inputs that previously returned {}: (a) unquoted colon in rationale; (b) missing closing fence; (c) no fence at all (verdict line in plain text). Verifiable via unit tests.
- [x] **A2.** When yaml.safe_load succeeds, behaviour is unchanged — no regression on the 160/170 happy-path verdicts. Verifiable via unit test pinning the existing format.
- [x] **A3.** When the regex fallback ALSO fails (input is gibberish with no `verdict:` line), `parse_verdict_envelope` returns `{}` exactly as today — PARSE-FAIL is still emitted for unsalvageable inputs, just rarer. Verifiable via unit test.
- [x] **A4.** Verdict word recognition is constrained to the three valid verdicts — the regex MUST NOT accept arbitrary words just because they sit after `verdict:` (avoid `verdict: maybe` slipping through as a real verdict). Verifiable via unit test (input "verdict: maybe" → PARSE-FAIL, not "maybe").
- [x] **A5.** Regression test in `tests/unit/test_escalation_v05_parser.py` covers A1+A2+A3+A4 and is wired in such that future refactors of the parser fail loudly.
- [x] **A6.** Existing bats test `tests/unit/escalation_scan_v05.bats` still passes (no regression on the dispatch envelope schema or workflow contract).

## Verification

# T-1748 — single-line commands only (L-356).
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_escalation_v05_parser.py -q --no-header
cd /opt/999-Agentic-Engineering-Framework && python3 -c "import ast; ast.parse(open('tools/escalation-scan-v0.5.py').read()); print('OK')"
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/escalation_scan_v05.bats > /tmp/_t1748_bats.out 2>&1; tail -3 /tmp/_t1748_bats.out
cd /opt/999-Agentic-Engineering-Framework && grep -q 'ok 14' /tmp/_t1748_bats.out

## RCA

**Symptom:** v0.5's first 30-day backlog run (T-1727, 170 dispatches) produced 10 PARSE-FAIL verdicts (5.9%). Each PARSE-FAIL is a candidate triaged at full LLM cost (network + model latency + tokens) but yielding no usable signal — the envelope was discarded wholesale because of a syntactic technicality, even when the verdict word was sitting in plain text.

**Root cause:** `parse_verdict_envelope` was written as a strict structural parser: extract the fenced YAML block, hand it to `yaml.safe_load`, accept-or-discard. This works when the LLM produces well-formed YAML, but small models (hermes3:8b on the ollama-loop pipeline) routinely emit *intentful* output that is *syntactically loose* — the most common failure being an unquoted colon inside the `rationale:` value (`rationale: This is a fix: a clear bug response`), which yaml.safe_load aborts on. The parser had no graceful degradation path; one yaml error → entire envelope lost.

**Why structurally allowed:** Two reinforcing factors. (a) The architectural ceiling of 7-8B local models (L-355) means we *expected* per-call quality variance, but the parser was tuned for the well-formed case only — strict-and-discard was the wrong tradeoff for an advisory pipeline where any verdict word beats no signal. (b) The 5.9% rate is high enough to matter (10 wasted dispatches per run, multiplied by 365 cron runs/year = ~3,650 wasted candidates without intervention) but low enough to look like noise on first glance, so the report named it as v1 promotion forward work rather than a bug. The actual incident here was that "advisory pipeline" was implicit in the design intent but not in the parser's tradeoff.

**Prevention:**
- `parse_verdict_envelope` now layered: strict YAML first (unchanged behaviour for the 160/170 happy path), regex fallback on failure (handles unquoted colons, missing fences, plain-text-no-fence). Verdict constrained to `{real_symptom_fix, false_positive, defer}` on BOTH paths — invalid words cannot leak through.
- `tests/unit/test_escalation_v05_parser.py` (15 cases) pins the failure modes named in the disagreement-rate report PLUS adversarial cases (`verdict: maybe` gating, verdict-word-inside-rationale not leaking, confidence clamping). Future refactors that re-introduce strict-only parsing fail the test.
- The pattern (advisory-pipeline parsing tradeoffs) is now visible in the parser's docstring and L-358 (filed below) so future ollama-loop consumers don't repeat the strict-and-discard mistake.

## Evolution

### 2026-05-05 — verdict-word constraint applied to YAML path too
- **What changed:** Initial AC framing said "regex must constrain to the three valid words". Once writing the test suite, realised the YAML path had the same leak: `verdict: maybe` parsed by yaml.safe_load would set `verdict="maybe"` and propagate. Added the same constraint to the YAML branch — verdict not in VALID_VERDICTS → fall through to regex fallback (which also rejects, returning {}).
- **Plan impact:** A4 expanded to cover both paths (test_invalid_verdict_word_in_yaml_returns_empty added). Single-branch fix would have been a half-measure.
- **Triggered:** None — caught at test-design time, no scope creep.

### 2026-05-05 — regex applied to full text, not just fence content
- **What changed:** Considered running the regex fallback against `fenced` only (the extracted block content). Rejected: the most common no-fence failure mode is the LLM omitting the fence entirely and emitting `verdict: foo` in plain text. Running on full text handles all three failure modes (unquoted colon, missing fence, no fence) in one branch.
- **Plan impact:** None — design choice converged at implementation time.
- **Triggered:** None.

## Decisions

### 2026-05-05 — fix the parser, not the prompt
- **Chose:** Harden the parsing side; leave the prompt's output contract unchanged.
- **Why:** (a) The prompt change is named in the v0.5 report as a v1 promotion criterion — a separate decision belonging to a v1 scope discussion. (b) Even if the prompt were perfect, ollama-loop's per-call variance (L-355: 76-79% accuracy ceiling for 7-8B) means sloppy outputs will recur regardless of prompt quality. (c) Parser-side hardening composes additively with eventual prompt tightening; prompt-side fix would have a smaller robustness margin. Better to be strict-then-tolerant than perpetually chase prompt formats.
- **Rejected:** Prompt change ("emit ONLY a YAML block, nothing before or after, all string values quoted"). Would help on the margin but doesn't address the architectural ceiling, and creates promotion-criterion entanglement with the v0.5→v1 decision.

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 agent ACs pass. 15/15 new parser unit tests green; 14/14 existing v0.5 bats tests still green (no regression). The fix targets the exact failure modes named in the T-1727 disagreement-rate report (unquoted colon, missing fence, plain text) plus adversarial cases (invalid verdict words on both YAML and regex paths). Verdict-word constraint applied uniformly so `verdict: maybe` cannot leak. Parser is now layered: strict YAML for the 94% happy path, regex fallback for the sloppy 6%, true PARSE-FAIL only when no verdict word exists anywhere. Direct, bounded, structural class-fix — not a one-off patch.

**Expected impact:** Next cron run (5:33 UTC) should produce a meaningfully lower PARSE-FAIL count. Will validate by reading `.context/working/escalation-drift-LATEST-v0.5.yaml` after the next firing. If PARSE-FAIL stays elevated (>3%) despite the hardening, that's signal for v1 prompt-tightening — but the existing 5.9% baseline came from intentful-but-sloppy output, not gibberish, so the regex fallback should catch most of it.

**Evidence:**
- `tools/escalation-scan-v0.5.py:243-340` — layered parser with `_regex_fallback` helper
- `tests/unit/test_escalation_v05_parser.py` — 15/15 PASS
- `tests/unit/escalation_scan_v05.bats` — 14/14 PASS (no regression)
- Verdict-word constraint applied on both paths (test_invalid_verdict_word_in_yaml_returns_empty + test_invalid_verdict_word_returns_empty_via_regex)

## Updates

### 2026-05-05T18:24:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1748-harden-v05-parseverdictenvelope--regex-f.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-00b6e277
- **Timestamp:** 2026-06-02T14:59:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-05T18:28:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
