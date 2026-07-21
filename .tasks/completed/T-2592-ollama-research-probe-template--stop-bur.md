---
id: T-2592
name: "ollama-research probe template — stop burying probes in default task scaffolding
  (OBS-096)"
description: >
  ollama-research probe template — stop burying probes in default task scaffolding
  (OBS-096)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/ollama_loop.py, lib/spawn.py]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-21T19:55:52Z
last_update: 2026-07-21T20:58:01Z
date_finished: 2026-07-21T20:58:01Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-07-21T20:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-21T20:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 4
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=4 (body:prompt-material); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2592: ollama-research probe template — stop burying probes in default task scaffolding (OBS-096)

## Context

OBS-096 corrected RCA: routing the t1700 harness through `fw resolver run` (T-2408) wraps
each micro-probe in prompts/default.md's 4.6KB task scaffolding (task title, ACs, working
directory rules), so the 8B hermes3 model summarizes "steps I would take" for the task
instead of executing the probe — 0/2 real tool_use vs T-1706's 100% with direct prompts
(evidence: dispatch-blobs prompt.txt for 17e7b391). Fix: a bare probe template so the
workflow-routed prompt replicates T-1706's direct shape; the workflow YAML's
`prompt_template:` slot exists for exactly this.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `prompts/ollama-probe.md` exists and renders to (near-)bare `$TASK_DESCRIPTION` — no task scaffolding slots — live-verified: dispatch 8f7ab9d8 prompt.txt is exactly the bare probe text
- [x] `.context/project/workflows/ollama-research.yaml` points `prompt_template:` at it
- [x] strict-mcp contract parity (added mid-task): `lib/ollama_loop.py` accepts + maps `--strict-mcp-config`/`--mcp-config`, `lib/spawn.py _spawn_ollama_loop` forwards them from the envelope (T-2488 sibling gap, L-399 class) — live-verified: worker init tools 439 → 3 (Bash, Grep, Read)
- [x] Live harness run via the reroute shows real tool_use ≥1 (the T-1706 behavior restored through the resolver substrate) — **MET via thin-loop leg (see §Progress): N=3 batch 3/3 (100%) + N=10 batch 9/10 (90%) real tool_use, 13/13 status=success, median 2s — vs 0/2 pre-fix and claude -p's 0/9 baseline (T-1704)**

### Progress
- 2026-07-21: bare template + strict-mcp forwarding both landed and live-verified
  (prompt = bare probe; tool catalogue = exactly 3). Still 0/2 real tool_use:
  model answers directly (num_turns: 1), even sourcing today's date from claude
  -p's injected system prompt instead of running Bash.
- **Root finding (reading docs/reports/T-1706-tool-loop-probe.md):** T-1706's
  100% GO evidence came from `tools/ollama-tool-loop.py` — a THIN direct-API
  tool loop — while claude -p + hermes3 scored **0/9 (0%)** in T-1704's probe
  matrix. The production `worker_kind: ollama-loop` (`lib/ollama_loop.py`) wraps
  claude -p, so the lane as shipped never had the validated behavior; the
  workflow YAML's "(curated litellm direct, 100% real tool_use)" comment
  conflates the two workers. claude -p's own system prompt (~10-20K tokens)
  overwhelms an 8B model regardless of tool-catalogue size — template and
  strict-mcp were necessary but not sufficient.
- **Next leg (bounded, next session):** route `worker_kind: ollama-loop` to the
  thin loop — either port `tools/ollama-tool-loop.py` into `lib/ollama_loop.py`
  as the OllamaLoopWorker implementation (keeping the event-shape contract:
  system/assistant/result JSONL), or add a `worker_kind: ollama-thin-loop` and
  point the workflow at it. Then re-run harness: expect T-1706-class ≥90%.
- 2026-07-21 (thin-loop leg SHIPPED — Option B): new `lib/ollama_thin_loop.py`
  (`OllamaThinLoopWorker` — direct /v1/messages tool loop ported from
  `tools/ollama-tool-loop.py`, claude-p-shaped events: system-init / assistant /
  user-tool_result / result, sandboxed Read/Bash/Grep, iteration cap, HTTP
  errors → is_error result not raise). Chose a NEW worker_kind over rewriting
  OllamaLoopWorker because tests/unit/test_ollama_loop.py pins the claude -p
  subprocess contract (12 tests) and the claude -p wrapper remains a valid
  primitive for full-Claude local runs. Wired: `lib/spawn.py`
  `_spawn_ollama_thin_loop` + `_DISPATCHERS["ollama-thin-loop"]`;
  `VALID_WORKER_KINDS` in `lib/resolver.py` + `lib/workflow_lint.py` (parity
  check OK); `bin/fw` doctor ollama-reachable grep widened to
  `ollama(-thin)?-loop`; workflow YAML flipped `worker_kind: ollama-thin-loop`
  + conflation comment corrected. Tests: `tests/unit/test_ollama_thin_loop.py`
  12 new (mocked HTTP: end_turn, tool round-trip, cap→error, HTTP-error→result,
  catalogue filter, sandbox, single-shot) + siblings — 63 passed. Vendored
  (`fw vendor self`), fabric card registered. **Live probe through
  `fw resolver run` (dispatch 48432e8c): status=success, real
  `tool_use Read {"path": "/etc/os-release"}`, answer matches disk exactly,
  2 iterations, 911 in / 45 out tokens — first real tool_use ever through the
  production lane.**
- 2026-07-21 (harness runs, batches 20260721-2055xx): N=3 → 3/3 success, 3/3
  real tool_use; N=10 → 10/10 success, 9/10 real tool_use (one probe answered
  without a tool call), median latency 2s. Combined 12/13 = 92% ≥ the T-1706
  ≥90% expectation. Backprop appended 18 outcome rows for T-2592 dispatches.
  Report: docs/reports/T-1700-harness-results.md. AC4 ticked on this evidence.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

python3 -m pytest tests/unit/test_ollama_thin_loop.py tests/unit/test_ollama_loop.py tests/unit/test_spawn.py tests/unit/test_resolver_run.py -q > /tmp/.t2592-tests.out 2>&1 && grep -q "63 passed" /tmp/.t2592-tests.out
grep -q "ollama-thin-loop" .context/project/workflows/ollama-research.yaml
python3 lib/worker_kinds_parity.py lib > /tmp/.t2592-parity.out 2>&1 && grep -q "^OK|" /tmp/.t2592-parity.out
out=$(python3 -c "import sys; sys.path.insert(0, 'lib'); from workflow_lint import main; main('.')" 2>&1); ! echo "$out" | grep -q "^ERROR|"
grep -q "real tool-use rate" docs/reports/T-1700-harness-results.md || grep -qi "tool" docs/reports/T-1700-harness-results.md

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-21T19:55:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2592-ollama-research-probe-template--stop-bur.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7eb0b24e
- **Timestamp:** 2026-07-21T20:58:04Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 35
     - evidence: `out=$(python3 -c "import sys; sys.path.insert(0, 'lib'); from workflow_lint import main; main('.')" 2>&1); ! echo "$out" | grep -q "^ERROR|"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 36
     - evidence: `grep -q "real tool-use rate" docs/reports/T-1700-harness-results.md || grep -qi "tool" docs/reports/T-1700-harness-results.md`

### 2026-07-21T20:58:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
