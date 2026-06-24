---
id: T-2489
name: "fw resolver pick — autonomous task selection + dispatch (T-2484 IW-4, off single-agent)"
description: >
  fw resolver pick — autonomous task selection + dispatch (T-2484 IW-4, off single-agent)

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
created: 2026-06-24T19:11:37Z
last_update: 2026-06-24T19:11:37Z
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

# T-2489: fw resolver pick — autonomous task selection + dispatch (T-2484 IW-4, off single-agent)

## Context

Manual dispatch works (`fw resolver run T-XXX default`, T-2487) and the worker
lane is reliable (T-2488). The next lever off single-agent execution (T-2484 IW-4)
is **selection**: the orchestrator picks an eligible task from the active backlog
and dispatches it — so "delegate live" doesn't require the agent to hand-pick a
task id each time. This adds `fw resolver pick`: enumerate active tasks, filter to
those safe for autonomous dispatch, rank, and (dry-run by default) surface the
pick — or `--dispatch` to fire it through the same resolve+spawn path as `run`.
Authority model: selection is initiative (default dry-run surfaces the pick);
execution stays explicit (`--dispatch`). Inception/human-owned/unscoped tasks are
excluded by eligibility — the picker can only ever fire agent-owned, scoped work.

## Acceptance Criteria

### Agent
- [x] `fw resolver pick` enumerates `.tasks/active/T-*.md`, applies the eligibility
      filter, ranks the eligible set, and (dry-run by default — no JSONL/blob write,
      no spawn) prints the ranked eligible tasks, the top pick, and the workflow it
      would dispatch with. Verified live: 17 eligible surfaced, top pick + workflow
      shown, exit 0; test 4 proves no dispatches.jsonl write in dry-run.
- [x] Eligibility EXCLUDES, with a recorded reason per exclusion: `workflow_type`
      ∈ {inception, specification, design}; `owner: human`; placeholder/unscoped ACs;
      `horizon: later`; tasks with an in-flight dispatch (latest dispatches.jsonl row
      with no terminal_event); AND the currently-focused task (don't dispatch what the
      main agent is working). Pinned by `t2489_resolver_pick.bats` test 1 over fixtures.
- [x] `--dispatch` fires the top pick through the same `resolve()` + `spawn_dispatch()`
      path as `cmd_run`, prints the outcome, returns exit 2 on a worker terminal error
      (parity with `fw resolver run`). `--json` emits
      `{eligible, pick, reason, excluded, dispatched, [outcome]}`. Pinned by test 5
      (in-process fake-spawn → exit 2, dispatched=True).
- [x] Regression test `tests/unit/t2489_resolver_pick.bats` green (5/5), and
      `bin/fw resolver pick` runs clean on the live repo (dry-run, exit 0).

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

bats tests/unit/t2489_resolver_pick.bats
bin/fw resolver pick >/dev/null
python3 -c "import ast; ast.parse(open('lib/resolver.py').read())"

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

### 2026-06-24 — dry-run by default; selection is initiative, dispatch is explicit
- **Chose:** `fw resolver pick` surfaces the ranked pick by default and only fires
  with `--dispatch`. Eligibility hard-excludes inception/spec/design, human-owned,
  unscoped, parked, in-flight, and the focused task.
- **Why:** Authority model — autonomous *selection* is delegated initiative, but
  *executing* work is an explicit act. A default-dispatch picker would let the
  orchestrator fire real workers unattended on the first invocation; default-dry-run
  keeps a human/agent in the decision while still automating the hard part (which
  task). The eligibility filter is the structural guard: the picker can never select
  inception go/no-go or human-owned work no matter how it's invoked.
- **Rejected:** (a) Auto-dispatch by default — crosses initiative→authority. (b)
  Cron/daemon loop — that's unattended autonomy, a later step once the single-pick
  path is trusted. (c) BVP-ranked selection now — cost_estimate/bvp_scores aren't
  populated corpus-wide; FIFO (started-work → now → oldest-id) is deterministic and
  testable today, and _pick_rank_key is the single seam to swap in BVP later.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-24T19:11:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2489-fw-resolver-pick--autonomous-task-select.md
- **Context:** Initial task creation
