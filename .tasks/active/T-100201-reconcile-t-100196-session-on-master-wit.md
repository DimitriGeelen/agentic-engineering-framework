---
id: T-100201
name: "Reconcile T-100196 session-on-master with T-2394 master-merge-only CLAUDE.md contradiction"
description: >
  Reconcile T-100196 session-on-master with T-2394 master-merge-only CLAUDE.md contradiction

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
created: 2026-07-05T22:34:27Z
last_update: 2026-07-05T22:34:27Z
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

# T-100201: Reconcile T-100196 session-on-master with T-2394 master-merge-only CLAUDE.md contradiction

## Context

This session (2026-07-05) shipped the T-100196 keystone into CLAUDE.md §Trunk-Based
Session Flow with the mechanism **"the persistent session runs on `master`; handover /
task-sync / context commits go straight to master."** That text directly contradicts the
pre-existing **T-2394 master-merge-only gate** (`agents/git/lib/master-guard.sh`,
`PROTECT_MASTER=1` live in this repo), which structurally BLOCKS any direct authored
commit on `master`. The conflict was hit live: the operator's GO-decision commit on the
main checkout was refused with `BLOCKED: direct commit on 'master' — master is merge-only
(T-2394 G1)`, forcing a worktree→FF workaround.

Two facts reconcile the conflict without a redesign:
1. **The invariant is unaffected.** T-100196's real value is the invariant *"the session
   never holds a commit that isn't on origin/master"* — a fast-forward satisfies it and
   never fires the T-2394 guard. Only the *"commit directly on master"* mechanism is wrong.
2. **Precedence already decides the interim rule.** T-2394 is a *structural* gate;
   T-100196's "commit on master" is *advisory* text. Per §Instruction Precedence + L-405
   (advisory-without-structure drifts to non-compliance), the structural gate wins until a
   deliberate mechanism decision says otherwise.

The **final mechanism** (how the persistent session commits governance while `PROTECT_MASTER=1`)
is an operator Level-D ways-of-working call — see `## Recommendation` (Option A recommended)
and the Human AC below.

## Acceptance Criteria

### Agent
- [x] Correction callout added to CLAUDE.md §Trunk-Based Session Flow naming the T-2394
      conflict, the live-incident evidence, the interim safe rule (worktree→FF, no direct
      master commit while `PROTECT_MASTER=1`), and the T-100201 pointer
- [x] Concern registered in `.context/concerns.yaml` for the T-100196↔T-2394 contradiction
      (register-first-fix-second) — OBS-091
- [x] Reconciliation options (A/B/C/D) + recommendation documented in `## Recommendation`

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

- [ ] [REVIEW] Approve the reconciliation mechanism for how the persistent session commits
      governance while `PROTECT_MASTER=1`
  **Steps:**
  1. Read `## Recommendation` below (Options A/B/C/D + recommended Option A).
  2. Decide which mechanism the framework should adopt (or reject all and keep the interim
     worktree→FF rule permanently).
  3. Reply with the chosen option (or "keep interim"). A GO on a mechanism spawns a
     separate build task to implement it and to rewrite the §Trunk-Based mechanism prose.
  **Expected:** One mechanism chosen (or interim-rule-permanent), recorded here.
  **If not:** Ask for clarification on a specific option's tradeoffs.

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

**Symptom:** CLAUDE.md §Trunk-Based Session Flow instructs "commit governance straight to
`master`", but `PROTECT_MASTER=1` (T-2394) structurally blocks that. Live incident
2026-07-05: operator's GO commit on master refused (`master is merge-only`), then a
six-command workaround cascade ending in a manual FF push from the worktree.

**Root cause:** the T-100196 keystone was authored and landed into CLAUDE.md *without
cross-checking it against the existing structural gates it would collide with*. T-2394
(master-guard, shipped earlier) and T-100196 (session-on-master, shipped this session) are
mutually exclusive on the "how does the session reach master" axis, and nothing forced the
author to reconcile them.

**Why structurally allowed:** there is no gate — nor even a checklist step — that validates
a *new keystone addition to CLAUDE.md* against the *set of already-active structural gates*.
Advisory prose can be added that contradicts a live hook, and the contradiction only
surfaces when an agent trips the hook at runtime (here, ~1 day later). This is the L-405
class (advisory-vs-structural drift) inverted: instead of advisory decaying against reality,
new advisory was born already-contradicting a structural rule.

**Prevention:** (a) this correction callout + T-100201 make the conflict visible immediately;
(b) candidate follow-up (out of scope here, note for the mechanism-decision task): a doctor
check or reviewer detector that flags CLAUDE.md guidance instructing an action a live
PreToolUse/pre-commit hook blocks (e.g. "commit on master" text while `PROTECT_MASTER=1`).
Advisory teach alone is insufficient (L-300/L-405) — the durable fix is structural.

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

## Recommendation

**Recommendation:** ship the interim correction note now (done — Agent ACs), and for the
**final mechanism** adopt **Option A** (scope the existing sanctioned bypass into the
framework's own governance-commit tooling). Operator picks via the Human [REVIEW] AC.

**The reconciliation options** (all preserve T-100196's *invariant*; they differ on *how the
session reaches master* while `PROTECT_MASTER=1`):

- **Option A — scope `FW_ALLOW_MASTER_COMMIT=1` into `fw sync` / `fw handover --commit`.**
  T-2394 already documents `FW_ALLOW_MASTER_COMMIT=1` as its sanctioned Tier-2 bypass. Let the
  framework's own governance-commit tools set it for their *governance-path-only* commits
  (handovers, `.tasks/`, `.context/`). Keeps T-100196's "session on master, no branch" intact;
  real code still can't be committed directly (tools scope the bypass to governance paths). Cost:
  low (small change in two commands). Downside: a Tier-2 log entry per governance commit —
  arguably a feature (audit trail), arguably noise. **RECOMMENDED.**
- **Option B — session does NOT run on master; governance commits on a transient branch,
  FF-landed.** This is literally what happened this session. Preserves the invariant + respects
  T-2394 with zero code. But it re-introduces the session branch T-100196 exists to kill → the
  branch/worktree divergence class returns. **Reject** (undoes T-100196's benefit).
- **Option C — session on master; governance commits FF'd from a throwaway ref.** Create the
  commit on a temp ref, FF master to it (FF never fires the guard), delete the ref. Preserves both,
  no bypass log. Cost: medium (`fw sync` must orchestrate the temp-ref dance). Hold as fallback if
  the Option-A bypass-log noise is judged unacceptable.
- **Option D — turn OFF `PROTECT_MASTER` for the framework repo.** Simplest, but discards the
  T-2394 protection whose origin (worktree-isolated parallel agents clobbering master) is *still a
  live risk* in this repo's worktree flow. **Reject.**

**Why not just rewrite the mechanism prose myself:** choosing A/B/C/D changes how *every* session
commits governance — a Level-D ways-of-working decision that is the operator's authority, not the
agent's initiative. The agent's job here was (1) remove the live contradiction (interim note,
done) and (2) surface the options with a recommendation (this section). The operator decides.

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

### 2026-07-05T22:34:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100199-close/.tasks/active/T-100201-reconcile-t-100196-session-on-master-wit.md
- **Context:** Initial task creation
