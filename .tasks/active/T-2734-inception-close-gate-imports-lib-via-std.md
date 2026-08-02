---
id: T-2734
name: "inception close gate imports lib via stdin __file__, fails outside framework
  CWD"
description: >
  inception close gate imports lib via stdin __file__, fails outside framework CWD

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
created: 2026-08-02T10:54:51Z
last_update: '2026-08-02T11:00:10Z'
date_finished:
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
  - ts: '2026-08-02T11:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T11:00:10Z'
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

# T-2734: inception close gate imports lib via stdin __file__, fails outside framework CWD

## Context

`update-task.sh:check_inception_scope_trace` (T-1984 GO-scope trace gate) runs its
reachability check via `python3 - <<'PYEOF'`, and the heredoc starts with:

    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

The script is read from **stdin**, so `__file__` is the literal string `'<stdin>'`.
`abspath('<stdin>')` resolves against the CWD, and three `dirname`s later the
computed entry is `'/'` — measured, from both the framework root and elsewhere.
The line has never contributed anything.

The import nevertheless succeeds when CWD is the framework root, because Python
prepends the CWD to `sys.path` for a stdin script and the framework root happens
to contain `lib/`. Anywhere else it raises:

    ModuleNotFoundError: No module named 'lib.inception_decisions'

and `update-task.sh` exits 1. Reproduced: closing a `workflow_type: inception`
task from a temp project root gives `RC=1` with the traceback on stderr.

Consumers invoke `.agentic-framework/bin/fw task update …` from their own root,
which has no `lib/`. So **inception close is broken for every consumer project**,
and has been since T-1984. The gate is load-bearing on an accident of CWD.

Found while fixing T-2733: `tests/unit/rca_gate.bats` test 4 is red because of
this, not because of a fixture problem.

## Acceptance Criteria

### Agent
- [x] The heredoc resolves the framework path explicitly (from `FRAMEWORK_ROOT`, passed in) rather than from `__file__`, which is `'<stdin>'` for a piped script
- [x] Closing an inception task with a project root that is NOT the framework root succeeds, with no traceback on stderr — verified by running it, not by reading the diff
- [x] Closing an inception task from the framework root still succeeds (no regression on the path that worked by accident)
- [x] `tests/unit/rca_gate.bats` is 12/12 green as a consequence
- [x] bats coverage pins the consumer-shaped case (project root ≠ framework root ≠ CWD), and a negative control confirms it goes red with the fix reverted
- [x] Swept for the same `__file__`-in-heredoc shape elsewhere in the tree; count stated, each instance fixed or filed

**Sweep result:** 2 instances of `abspath(__file__)` inside stdin-piped python
blocks in shell scripts. `agents/task-create/update-task.sh:597` — active
failure, fixed here. `agents/audit/audit.sh:5279` — latent: it is the eagerly
evaluated *default* of `os.environ.get("PROJECT_ROOT", …)`, and that key is
always set by the caller, so the wrong value (`/`) is computed and discarded. Not
fixed here (no failure to fix); excluded from the shape guard by SHAPE — the
guard skips lines carrying `environ.get(` on the same line — rather than by
filename, so a future unguarded instance in audit.sh would still be caught.
The other 13 `abspath(__file__)` hits are in real `.py` files, where `__file__`
is legitimate.

**Negative control:** fix reverted in place → tests 1, 2 and 4 red; test 3
(framework-root close) stays green, which is correct and is the whole point —
that path passed against the broken code too. Restored byte-clean (residue 0).

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
out=$(bats tests/unit/inception_close_consumer_root.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
out=$(bats tests/unit/rca_gate.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
out=$(bin/fw reviewer T-2734 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

**Symptom:** `fw task update <inception> --status work-completed` exits 1 with
`ModuleNotFoundError: No module named 'lib.inception_decisions'` in any project
whose CWD is not the framework root — i.e. every consumer.

**Root cause:** the T-1984 scope-trace gate runs `python3 - <<'PYEOF'` and
computed its `sys.path` entry from `__file__`. For a script read from stdin
`__file__` is the literal `'<stdin>'`, so `abspath()` resolved it against the CWD
and three `dirname()`s yielded `'/'` — measured, from every location. The line
never contributed anything.

**Why structurally allowed:** the import still worked in the framework repo,
because Python prepends the CWD to `sys.path` for a stdin script and the
framework root contains `lib/`. So the gate passed its own tests and every
developer run. The defect was only reachable from a CWD nobody tested from, and
the framework's own suite runs from the framework root — the one place the bug is
invisible. Same family as the T-2726 unwitnessable-check class: the check could
not fail where it was being observed.

**Prevention:** `tests/unit/inception_close_consumer_root.bats` runs the close
with CWD deliberately outside the framework, plus a source-derived shape guard
over stdin-piped python blocks that compute a path from `__file__`, with a guard
control. The shape guard is what generalises — this exact expression is easy to
write again, and it is wrong every time it appears in a piped block.

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

### 2026-08-02T10:54:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2734-inception-close-gate-imports-lib-via-std.md
- **Context:** Initial task creation
