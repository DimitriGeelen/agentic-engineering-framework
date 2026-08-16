---
id: T-2381
name: "arc-012 controlled live-fire — drive one budget-critical restart cycle via
  TermLink (evidence for T-2376 live E2E)"
description: >
  arc-012 controlled live-fire — drive one budget-critical restart cycle via TermLink
  (evidence for T-2376 live E2E)

status: work-completed
workflow_type: test
owner: agent
horizon:
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
created: 2026-06-13T22:03:59Z
last_update: '2026-08-16T22:25:04Z'
date_finished: 2026-06-13T22:12:57Z
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
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2381: arc-012 controlled live-fire — drive one budget-critical restart cycle via TermLink (evidence for T-2376 live E2E)

## Context

Operator authorized (option 1) a controlled live-fire to empirically prove the arc-012 continuous-run loop fires end-to-end with a REAL claude, rather than relying only on the per-link bats tests. Run `claude-fw` in a TermLink PTY in the MAIN repo with a tiny `FW_CONTEXT_WINDOW` so claude is over-critical immediately, inject one Read directive, observe the loop, then kill. This is observation/evidence only — no framework source is modified.

## Acceptance Criteria

### Agent
- [x] A real `claude-fw` session runs in the main repo under a tiny `FW_CONTEXT_WINDOW` and at least one real claude turn occurs (transcript/PTY output captured)
- [x] Loop link evidence captured for as many of the 4 links as fire: #1 gauge reads critical, #2 `.restart-requested` written, #3 terminator ends the claude session, #4 restart advances `current_iteration`
- [x] Outcome documented (which links fired, which did not, and why) in the task body; session cleaned up (`termlink clean`), no runaway claude processes left
- [x] No unintended mutations to main-repo source (only expected loop side effects: handover commits to local master, not pushed)

## Findings

**Setup:** spawned TermLink PTY session `arc012-lf` in `/opt/999-Agentic-Engineering-Framework` (master), launched `FW_CONTEXT_WINDOW=30000 FW_HANDOVER_TOTAL_TIMEOUT=40 claude-fw`, injected a single Read directive. Separate `arc012-obs` shell for observation. Baseline `current_iteration: 1`, `enabled: true`.

**What fired (real evidence):**
- ✅ **claude-fw boots + runs a real claude in the main repo.** The wrapper launched claude's TUI; the injected directive ("Read README.md, reply first line only") produced a real Read tool call and claude replied with the README's first line (`![agentic-engineering-framework]...`). The deployed wrapper + hooks + auth all work as root.
- ✅ **Deployment confirmed live**, complementing the earlier static blob verification (all 4 links present on master).

**What did NOT fire — and why (the valuable part):**
- ❌ **Links #1–#4 did not fire on the single Read.** Root cause: `checkpoint.sh` post-tool runs the token gauge only every `TOKEN_CHECK_INTERVAL` calls (`count % INTERVAL == 0 || count == 1`, checkpoint.sh:290). The `.tool-counter` is **repo-global and shared** with the operator's other active sessions, so my one Read did not land on a check interval → gauge never ran → no `.restart-requested`, `current_iteration` stayed 1, `.budget-status` stayed 12h-stale.
- ⛔ **I deliberately did NOT escalate** (more Reads to cross the throttle). Discovery: `.restart-requested`, `.tool-counter`, `.budget-status` are all **repo-global, not per-session**, and there were **5+ other `claude-fw` wrappers running** (operator's live sessions). Writing the global signal would have made *their* terminators SIGTERM-and-restart their claude children. Firing the loop in a shared repo while other claude-fw sessions are live is unsafe.

**Operational constraint discovered (runbook-worthy):** a true live-fire is only safe when **no other `claude-fw` wrappers are running on the same repo** — otherwise the global `.restart-requested` collides across sessions. This strengthens the existing runbook guidance ("interactive, not bg-job") with a quiet-repo precondition. Filed as a follow-up.

**Cleanup:** graceful `/exit` → `termlink clean` (2 sessions removed). Verified: claude-fw count 6→4 (mine gone), 0 orphans, no `arc012` tmux sessions, **no `.restart-requested` written**, operator sessions untouched.

**Net:** the loop is deployed and a real claude runs under it; the mechanical link-firing remains proven by the 4 per-link bats tests on master (the safe way to verify, vs. a shared-repo live signal). The operator's own interactive run — on a quiet repo — remains the canonical §G-062 demo.

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

### 2026-06-13T22:03:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2381-arc-012-controlled-live-fire--drive-one-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c1137192
- **Timestamp:** 2026-06-13T22:12:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T22:12:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
