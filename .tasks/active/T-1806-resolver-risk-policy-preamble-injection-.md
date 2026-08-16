---
id: T-1806
name: "Resolver risk-policy preamble injection (dispatch-safety slice 2)"
description: >
  Resolver risk-policy preamble injection (dispatch-safety slice 2)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [slice-2]
components: [lib/resolver.py, tests/unit/test_resolver.py]
related_tasks: []
arc_id: dispatch-safety
created: 2026-05-13T15:09:44Z
last_update: '2026-08-16T22:23:59Z'
date_finished: 2026-05-13T15:15:11Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 3
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=3 
      (body:typed-io-or-gate); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1806: Resolver risk-policy preamble injection (dispatch-safety slice 2)

## Context

Slice 2/5 of the dispatch-safety arc. Teaches the Resolver to inject a baseline risk-policy preamble at the front of every dispatch prompt when the workflow opts in via `allow_pause: true`. Without this, slice 1's substrate recognition is correct but inert — Workers don't know the protocol exists, and no `pause_requested` events will ever be emitted. The preamble instructs Workers to assess severity × likelihood before any irreversible action and emit a `pause_requested` terminal event (per ADR-0004) when the product crosses the workflow's `pause_threshold`. Workers spawn `--bare` (no CLAUDE.md, no hooks), so the envelope is the only governance channel they see; the preamble must live there.

Builds on [T-1805](T-1805) (substrate recognition). Unblocks slice 3 (workflow schema + doctor lint for `pause_threshold` / `allow_pause`).

## Acceptance Criteria

### Agent
- [x] `lib/resolver.py` exposes a `_risk_policy_preamble(workflow)` function that returns the baseline preamble text. The preamble contains: (a) explicit reference to `pause_requested` as the terminal-event type, (b) the JSON shape for the event, (c) severity/likelihood as the trigger criteria, (d) the workflow's `pause_threshold` value (defaults to `high` when absent), (e) "DO NOT timeout-assume-default" guidance (grid-power rule per ADR-0004).
- [x] `assemble_prompt(workflow, task_context)` prepends the preamble to the rendered output for all three strategies (static / assembled / meta-prompted) WHEN the workflow has `allow_pause: true`. When `allow_pause` is absent or `false`, no preamble is injected (no behavior change for existing workflows).
- [x] Per-workflow override: if the workflow defines `pause_preamble: <path>` (path relative to PROJECT_ROOT), the Resolver reads that file as the preamble text instead of the baseline. Falls back to baseline when the path is missing or the file is unreadable (with a warning emitted via stderr).
- [x] Unit test: workflow with `allow_pause: true` + assembled strategy → rendered prompt starts with the preamble; preamble mentions `pause_requested`, `severity`, `likelihood`, `pause_threshold`, and the rendered prompt body still follows.
- [x] Unit test: workflow with `allow_pause: false` (or absent) → no preamble injected; rendered prompt is unchanged from the existing T-1689 behavior.
- [x] Unit test: workflow with `allow_pause: true` + static strategy → preamble prepended to the static template body verbatim.
- [x] Unit test: workflow with `allow_pause: true` + `pause_preamble: prompts/risk/custom.md` → custom preamble used. Missing file → warning + fallback to baseline.
- [x] Unit test: `pause_threshold` value from workflow is substituted into the baseline preamble (test with `pause_threshold: medium` → text contains "medium"; with `pause_threshold` absent → text contains "high" as default).
- [x] No regression in 11 existing `test_resolver_run.py` tests or 50+ assembled-prompt tests.

### Human
- [ ] [REVIEW] Confirm the preamble text strikes the right tone — clear, directive, not preachy; instructs without over-explaining; honors the grid-power rule (no timeout-fallback) explicitly.
  **Steps:**
  1. Read the preamble text in `lib/resolver.py:_risk_policy_preamble` (or call it: `python3 -c "import sys; sys.path.insert(0,'lib'); from resolver import _risk_policy_preamble; print(_risk_policy_preamble({'pause_threshold': 'high'}))"`)
  2. Read it as a Worker would: do you know what to do if you face ambiguity?
  3. Check: does it tell you to pause for trivial uncertainty (bad)? Does it tell you to NOT pause for stylistic preferences (good)?
  **Expected:** Tight, directive text. A Worker reading it understands the protocol in one pass.
  **If not:** Note the lines that read poorly so they can be tightened.

## Verification

# Shell commands that MUST pass before work-completed.

python3 -m pytest tests/unit/test_resolver_run.py tests/unit/test_resolver.py -q 2>&1 | tail -5 || python3 -m pytest tests/unit/ -k resolver -q 2>&1 | tail -5
python3 -c "import sys; sys.path.insert(0, 'lib'); from resolver import _risk_policy_preamble; p = _risk_policy_preamble({'pause_threshold': 'high'}); assert 'pause_requested' in p and 'severity' in p and 'likelihood' in p and 'high' in p, f'preamble missing required content: {p[:200]}'"
python3 -c "import sys; sys.path.insert(0, 'lib'); from resolver import _risk_policy_preamble; p = _risk_policy_preamble({}); assert 'high' in p, 'default pause_threshold should be high'"
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

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

### 2026-05-13 — $PAUSE_THRESHOLD substitution is the only preamble variable
- **What changed:** Originally the preamble would have used the same $VAR engine as the body. But the preamble lives at the front of the prompt and serves a different purpose (governance instruction, not task content). Decided to support only `$PAUSE_THRESHOLD` substitution in preambles — other variables (RECENT_DISPATCHES, HEALING_PATTERNS) belong to the body. Keeps the preamble surface minimal and stable.
- **Plan impact:** Custom `pause_preamble` files only get `$PAUSE_THRESHOLD` substitution, not the full VAR_PAT machinery. Documented in `_risk_policy_preamble` docstring.
- **Triggered:** None.

### 2026-05-13 — preamble lives in front, regardless of strategy
- **What changed:** Refactored `assemble_prompt` to build the body first (per strategy), then prepend the preamble. Cleaner than the alternative of injecting in each strategy branch.
- **Plan impact:** All three prompt strategies (static / assembled / meta-prompted) get uniform preamble behavior. The test `test_assemble_prompt_preamble_with_static_strategy` pins that static still skips $VAR substitution in the body.
- **Triggered:** None.

### 2026-05-13 — `pause_preamble` is a path, not inline text
- **What changed:** Considered allowing `pause_preamble:` to hold either an inline string or a path. Rejected inline — workflow YAML files would get cluttered with long instructional text, and operators would have to maintain "preamble text drift" across N workflows. Path-based override forces operators to keep one source of truth for shared preambles (e.g. `prompts/risk/security-critical.md`).
- **Plan impact:** None to ACs. Tests assert path semantics only.
- **Triggered:** None — clean choice.
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

### 2026-05-13 — preamble injection lives in the Resolver, not in the prompt template
- **Chose:** The Resolver prepends the preamble; workflow `prompt_template` files do not include it.
- **Why:** Centralizes policy in one place. If operators had to copy the preamble into every prompt_template, drift would be guaranteed (one template gets updated, others don't). The preamble is shared infrastructure; the body is per-workflow.
- **Rejected:** Per-workflow inline preamble in each prompt_template — drift-prone. Per-workflow `pause_preamble: <path>` is supported as an OVERRIDE only, for genuinely different policies (security-critical, low-risk), not for the default case.

### 2026-05-13 — opt-in via `allow_pause: true`, not opt-out
- **Chose:** Workflows must explicitly set `allow_pause: true` to get the preamble. Absent or `false` → no preamble.
- **Why:** Backward compatibility with existing workflows. Cheap-research, inception-relay, and other low-stakes workflows should not get pause overhead by default. Opt-in forces the operator to make a conscious choice per workflow.
- **Rejected:** Opt-out via `allow_pause: false` (default true). Would change behavior for every existing workflow, requires every prompt_template to be re-validated against the new preamble interaction. Risk:benefit poor.

## Recommendation

**Recommendation:** GO

**Rationale:** Slice 2 closes the gap that made slice 1 inert. With the Resolver injecting the risk-policy preamble for `allow_pause: true` workflows, Workers now learn the pause protocol in their dispatch envelope (the only governance channel `--bare` Workers see). Backward-compatible: no existing workflow opts in yet, so nothing changes for existing dispatches. Opt-in is per-workflow, not framework-wide. 9 new tests pass; 27 pre-existing resolver tests still pass; 104 tests pass across resolver + spawn + outcome.

**Evidence:**
- `lib/resolver.py`: added `_BASELINE_RISK_PREAMBLE` text + `_risk_policy_preamble(workflow)` helper + `assemble_prompt` prepends when `allow_pause: true`
- Baseline preamble explicitly names: `pause_requested`, JSON shape, severity/likelihood, $PAUSE_THRESHOLD substitution, no-timeout-fallback rule (grid-power)
- Per-workflow override via `pause_preamble: <path>` (PROJECT_ROOT-relative); missing path → stderr warning + baseline fallback
- 9 new tests in `test_resolver.py`: directive content, default threshold, threshold substitution, no-preamble for absent/false allow_pause, preamble for true allow_pause, static-strategy preservation, custom preamble, custom preamble missing → fallback
- AC verification commands all pass: `_risk_policy_preamble({'pause_threshold': 'high'})` contains required content; defaulting to `high` works

**Next steps (slice 3):** Workflow schema additions (`pause_threshold`, `allow_pause`, `pause_preamble`) + `fw doctor` lint for valid values + enum coverage. Pure schema/validation work — Resolver already handles all three fields.

## Updates

### 2026-05-13T15:09:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1806-resolver-risk-policy-preamble-injection-.md
- **Context:** Initial task creation

### 2026-05-13T15:13:40Z — status-update [task-update-agent]
- **Change:** tags: +arc:dispatch-safety

### 2026-05-13T15:13:40Z — status-update [task-update-agent]
- **Change:** tags: +slice-2

## Reviewer Verdict (v1.4)

- **Scan ID:** R-f9eb1254
- **Timestamp:** 2026-05-18T09:30:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-13T15:15:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
