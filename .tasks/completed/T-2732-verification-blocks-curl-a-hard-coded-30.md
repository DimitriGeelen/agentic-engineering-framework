---
id: T-2732
name: "verification blocks curl a hard-coded :3000 which is another project's watchtower"
description: >
  verification blocks curl a hard-coded :3000 which is another project's watchtower

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/task-create/update-task.sh, lib/verification-port.sh]
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
created: 2026-08-02T10:15:40Z
last_update: '2026-08-16T22:25:16Z'
date_finished: 2026-08-02T10:28:05Z
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
  - ts: '2026-08-16T22:25:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2732: verification blocks curl a hard-coded :3000 which is another project's watchtower

## Context

CLAUDE.md §Watchtower Port bans a literal `curl http://localhost:3000/...` in
verification examples, calls it an anti-pattern (T-1376), and says it "has caused
agents to kill or mis-target live sessions across projects". The rule is documented
and enforced nowhere.

Measured on this host, 2026-08-02:

| | lines | tasks | in active/ |
|---|---|---|---|
| bare `:3000`, no resolver on the line | 371 | 277 | 13 lines / 11 tasks |
| sanctioned `fw watchtower url \|\| echo …:3000` fallback | 15 | 4 | 14 lines / 3 tasks |

Two Watchtowers are running here: `:3000` is **832's**
(`/opt/832-Workflow-designer/.agentic-framework`, pid 1341537, up 5 days) and
`:3001` is AEF's (pid 2567301). The triple-file correctly resolves to
`http://192.168.10.107:3001`. So every bare-`:3000` verification line has been
curling **another project's** web server.

Both projects run the same Flask app, so the generic routes exist in both. Probed:

    /tasks/T-152    :3000(832)=200   :3001(AEF)=200    <- task IDs COLLIDE
    /tasks/T-2731   :3000(832)=404   :3001(AEF)=200
    /costs          :3000(832)=200   :3001(AEF)=200

224 of the 371 lines assert only reachability (`curl -sf … -o /dev/null`). Those
return **200 from 832's server** and assert nothing whatever about AEF — a green
that asserts less than it says. The remaining 147 assert page content and would go
red against 832, i.e. red for a reason unrelated to their task.

This is the T-1376 hazard live, not hypothetically.

## Acceptance Criteria

### Agent
- [x] `update-task.sh` refuses `--status work-completed` when the task's `## Verification` block contains a URL literal on port 3000 with no port resolution on the same line
- [x] The sanctioned defensive fallback (`WT_URL=$(bin/fw watchtower url) || echo "…:3000"`) is NOT refused — the discriminator is "resolves on the same line", not "mentions 3000"
- [x] The refusal message names the offending line, the resolver to use, and the bypass mechanism
- [x] `FW_ALLOW_HARDCODED_PORT=1` bypasses and writes a Tier-2 entry to `.gate-bypass-log.yaml`
- [x] Every task in `.tasks/active/` is free of bare-port verification lines (remediated to the resolver form)
- [x] bats suite covers: refusal, sanctioned-form pass, bypass, guard control (a violation appended to a COPY is caught), and a corpus scan of `active/` with no exclusions
- [x] Negative control run: with the guard reverted the suite goes red, and red *for the stated reason* (failure text names the condition, not merely rc!=0)

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
#
# NOTE: these lines deliberately do not spell a port-3000 URL literal — this
# task's own guard would (correctly) refuse them. The corpus scan lives in the
# bats suite, which builds the pattern rather than writing the URL.
# Asserts "no failures" + "the suite actually ran", NOT a pinned test count —
# a count pins a growing global into a per-task gate (G-015 shape, 832 rail-394).
out=$(bats tests/unit/verification_port_hardcode.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
out=$(bin/fw reviewer T-2732 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

**Symptom:** 371 verification lines across 277 tasks fetch `:3000`. On this host
that port belongs to 832's Watchtower, not AEF's (AEF resolves to `:3001`). 224 of
those lines assert only HTTP reachability, so they return 200 from the wrong
project's server and pass while asserting nothing about AEF.

**Root cause:** the port is a *runtime-resolved, per-project* value (triple-file →
`fw config get PORT` → 3000) written into task files as a *literal at authoring
time*. A literal cannot track a value that is by design per-project.

**Why structurally allowed:** the rule against it has existed in CLAUDE.md since
T-1376 as prose only. Nothing reads the `## Verification` block looking for it —
not the P-011 runner that executes those very lines, not audit, not the reviewer.
The one surface that had both the text and the opportunity (P-011, which runs each
line) never inspected what it was about to run. So the convention was documented,
repeatedly restated, and 371× violated with no signal.

Second-order: the failure mode is a *false green*, not a red. A red line gets
noticed the next time someone closes the task. A green line that asserts nothing
is indistinguishable from a green line that asserts everything — there is no moment
at which anyone is prompted to look. That is why it reached 371 rather than 3.

**Prevention:** P-011 refuses to run a verification block containing a
port-literal URL with no same-line resolution, naming the line and the resolver.
Distinct from the fix (remediating the 11 live tasks): the gate is what stops the
372nd. Completed tasks are deliberately left alone — their gates already ran and
the files are archived; rewriting 277 archived tasks is churn that would also
destroy the evidence trail for this RCA.

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

### 2026-08-02T10:15:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2732-verification-blocks-curl-a-hard-coded-30.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e822eb9e
- **Timestamp:** 2026-08-02T10:28:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-02T10:28:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
