---
id: T-2488
name: "RCA + fix: bare dispatch worker hits 'Prompt is too long' on trivial task (T-2484 delegation reliability)"
description: >
  RCA + fix: bare dispatch worker hits 'Prompt is too long' on trivial task (T-2484 delegation reliability)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
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
created: 2026-06-24T18:59:46Z
last_update: 2026-06-24T18:59:46Z
date_finished: null
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
---

# T-2488: RCA + fix: bare dispatch worker hits 'Prompt is too long' on trivial task (T-2484 delegation reliability)

## Context

The first real `fw resolver run` dispatch (T-2487, T-2484 slice 2) sent a `--bare`
TermLink worker a prompt that the model rejected with **"Prompt is too long"** — on
a task that should be trivial. The dispatch path captured the error correctly, but a
bare worker that can't even start makes "agent delegates live" unreliable. This task
finds which part of the assembled worker prompt ballooned, bounds it, and pins the
bound so trivial dispatches succeed.

## Acceptance Criteria

### Agent
- [x] RCA identifies the real inflation source: NOT a prompt-template slot
      (prompt.txt was a clean 4925 chars) but **MCP tool-schema injection** —
      the worker's `claude -p` inherited the parent `.mcp.json` (termlink ~300
      tools, skills ~150, playwright, fw, context7) because the default workflow
      passed no `--strict-mcp-config`. Measured: iteration-0 `cache_creation`
      = 175,817 tokens (terminal `cache_creation` 224,865 > 200K window;
      `terminal_reason: blocking_limit`). See `## RCA`.
- [x] Fix runs the default (fallback) workflow strict-mcp by default — the
      worker no longer loads the parent MCP catalogue. Plumbed end-to-end:
      `default.yaml strict_mcp_config: true` → resolver envelope → spawn.py →
      `TermLinkWorker --strict-mcp-config` → cmd_dispatch sentinel → run.sh →
      `claude -p`. Resolver default is also `True` (lean by default; MCP is
      opt-in). Decision recorded in `## Decisions`.
- [x] Regression test pins the class at three joins (workflow declares it,
      envelope defaults it, worker emits the flag): `bats
      tests/unit/t2488_strict_mcp_lean_worker.bats` → 3/3 green.
- [x] Re-dispatch of the trivial probe (T-2485) via `fw resolver run T-2485
      default` completed: `is_error: False`, `result: "Dispatch received..."`,
      `terminal_reason: completed`. `cache_creation` dropped **224,865 → 48,516**
      tokens, cost $1.35 → $0.29. dispatch_id `ccaab4a3`; `strict_mcp` sentinel
      present on the worker dir.

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

bats tests/unit/t2488_strict_mcp_lean_worker.bats
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/workflows/default.yaml')); assert d.get('strict_mcp_config') is True"
grep -q 'strict_mcp_config' lib/resolver.py
grep -q 'strict-mcp-config' lib/termlink_worker.py

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

**Symptom:** The first real `fw resolver run` dispatch (T-2487) — a trivial task
("install litellm, curl localhost:4000") — failed with `result: "Prompt is too
long"`, `is_error: true`, `terminal_reason: blocking_limit`, after only 4 turns.

**Root cause:** NOT the prompt template. The assembled worker prompt (`prompt.txt`)
was a clean 4925 chars (~1.2K tokens); the task-file read added ~3K. The blow-up was
**MCP tool-schema injection**. `agents/termlink/termlink.sh:846` builds the worker
command as `claude -p "$PROMPT" $MODEL_FLAG $TOOLS_FLAG $MCP_CONFIG_FLAG
$STRICT_MCP_FLAG …`. The default workflow set none of the MCP flags, so `claude -p`
ran **without `--strict-mcp-config`** and inherited the parent worktree's `.mcp.json`
— 5 servers (`termlink` ~300 tools, `skills` ~150, `playwright`, `fw`, `context7`).
Their schemas are injected into the worker's system prompt: the terminal usage shows
`iterations[0].cache_creation_input_tokens = 175,817` — i.e. ~175K tokens consumed
*before the worker read anything*. Total `cache_creation` reached 224,865 against a
`contextWindow` of 200,000 → blocking_limit. `--tools`/`--allowed-tools` (which the
workflow *did* set: `[Read, Edit, Bash, Grep]`) gate which tools the model may *call*
— they do not stop MCP servers from connecting and injecting schemas. Only
`--strict-mcp-config` (T-2284 lever) does.

**Why structurally allowed:** The resolver dispatch substrate had never run end-to-end
until T-2484/T-2487 (it was unrunnable — see OBS-087). So no resolver-dispatched
`claude -p` worker had ever actually started with the inherited catalogue. The
T-2284 MCP-isolation lever existed but was opt-in and undocumented as a default; the
default workflow shipped with no MCP stance, so the first live worker silently
inherited 175K tokens of schemas. A zero-usage feature's most basic failure mode
(unbounded inherited context) had no test, no gate, and no default — sibling to PL-014
(exec-bit class, T-2486): a feature that ran exactly once exposed a blind spot the
whole time it sat unused.

**Prevention:** (1) The default (fallback) workflow now declares
`strict_mcp_config: true`, and the **resolver envelope defaults strict-mcp ON**
(`workflow.get("strict_mcp_config", True)`) — lean is the default; MCP is opt-in via
`strict_mcp_config: false` + `mcp_config: <path>`. (2) `tests/unit/t2488_*.bats`
pins the class at three joins (workflow declares / envelope defaults / worker emits
the flag), so a future workflow can't silently regress to inherited-catalogue. (3)
Live re-dispatch confirmed the bound: cache_creation 224,865 → 48,516, success.

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

### 2026-06-24 — strict-mcp as the default, not per-workflow opt-in
- **Chose:** Resolver-dispatched TermLink workers run strict-mcp by default
  (`envelope strict_mcp_config` defaults `True`; `default.yaml` declares it
  explicitly). Workflows that need MCP opt IN via `strict_mcp_config: false` +
  `mcp_config: <path>`.
- **Why:** Antifragility/Reliability — the safe failure mode is "too few tools"
  (worker says it lacks a tool, observable, recoverable), not "175K tokens of
  silent inherited schema that blows the window before any work" (opaque,
  expensive, only visible post-mortem). A bare task worker rarely needs MCP;
  making the expensive thing opt-in matches the cost.
- **Rejected:** (a) Capping/trimming the prompt template — wrong layer; the
  template was never the problem. (b) Per-workflow opt-IN to strict (leave
  default inheriting) — keeps the foot-gun armed for every new workflow. (c)
  Relying on `--tools`/`--allowed-tools` — those gate calling, not schema
  injection; proven insufficient (the failed run had them set).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-24T18:59:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2488-rca--fix-bare-dispatch-worker-hits-promp.md
- **Context:** Initial task creation
