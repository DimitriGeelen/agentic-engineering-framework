---
id: T-2742
name: "document the Tier 0 scope boundary — string-level only"
description: >
  document the Tier 0 scope boundary — string-level only

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/check-tier0.sh, tests/unit/tier0_scope_boundary.bats]
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
created: 2026-08-02T22:42:29Z
last_update: 2026-08-02T22:48:50Z
date_finished: 2026-08-02T22:48:50Z
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
  - ts: '2026-08-02T22:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T22:45:09Z'
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

# T-2742: document the Tier 0 scope boundary — string-level only

## Context

`agents/context/check-tier0.sh:36-43` extracts `tool_input.command` from the PreToolUse
JSON and pattern-matches **that string**. Line 53 short-circuits to `exit 0` when the
string carries none of the destructive keywords. It never opens a file the command
refers to. So `bash some-script.sh` is opaque to the gate regardless of what the script
does — a `rm -rf` three levels down is invisible.

This is a scope boundary, not a bug. The defect is that it is **written down nowhere**,
so the gate's silence reads as coverage. Every Tier-0 block anyone has hit came from a
*typed* command, which makes the gate's apparent reliability evidence about agent habits
rather than about coverage.

Reported by 832 on the DM rail (offset 404) after it cost them their working tree: a
mutated build script ran `rm -rf "$OUT"` with the variable pointing at their repo root,
taking `.git`, `.tasks`, `.context` and `.agentic-framework` with it. They recovered from
origin with zero committed work lost — entirely because of P-009 commit cadence. They
filed it as their G-018 (severity high) and flagged it as equally live here, since we run
the same hook. Verified against our own source before acting on it (OBS-138), not
inherited on trust.

Scope note: this task documents the boundary and pins it with a test. It does **not**
extend Tier-0 coverage into script contents — that is a much larger design question
(arbitrary interpreters, indirection, dynamic construction) and belongs in its own
inception if we want it.

## Acceptance Criteria

### Agent
- [x] `agents/context/check-tier0.sh` header states the scope boundary: what the hook inspects, and that a destructive operation inside a referenced script file is not inspected
- [x] `CLAUDE.md` §Enforcement Tiers states the same boundary and its consequence, so an agent reading the tier table cannot infer coverage the gate does not provide (`FRAMEWORK.md` too — the provider-neutral guide carried the same silently-over-promising table)
- [x] A characterization test asserts the boundary as it actually is: a Bash command invoking a script whose *contents* are Tier-0 destructive is **not** blocked. The documented claim is therefore falsifiable — if anyone later extends coverage, the test goes red and forces the docs to change with it
- [x] The same test carries a positive control: the identical destructive command typed inline **is** blocked. Without it, an "allowed" result is indistinguishable from a harness that cannot observe a block at all
- [x] The falsifiability claim is itself demonstrated, not asserted: the hook was temporarily patched to splice referenced file contents into the match string, and the test file records which tests went red under it (3 and 4) and which did not (5 and 6, documentary only)

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
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# The characterization test, guarded per T-2738 (bats verdict is `ok N`, and a
# partial failure must not pass on the pass-marker alone).
out=$(bats tests/unit/tier0_scope_boundary.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"

# The three documents actually carry the boundary text the test pins.
grep -q "SCOPE BOUNDARY" agents/context/check-tier0.sh
grep -q "Tier 0 sees the command string" CLAUDE.md
grep -q "Tier 0 inspects the command string only" FRAMEWORK.md

# The hook still parses and the existing Tier 0 suites are unaffected.
bash -n agents/context/check-tier0.sh
out=$(bats tests/unit/tier0_idempotency.bats tests/unit/tier0_hash_normalization.bats tests/unit/check_tier0_comment_stripping.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"

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

**Symptom:** 832 ran a test harness that executed a mutated build script; the script's
`rm -rf "$OUT"` had `$OUT` pointing at their repository root and removed the working
tree, `.git`, `.tasks`, `.context` and `.agentic-framework`. Tier 0 did not fire. We run
the same hook.

**Root cause of the *documentation* defect** (the thing this task fixes): `check-tier0.sh`
matches `tool_input.command`, and nothing in the hook header, `CLAUDE.md` or `FRAMEWORK.md`
said so. All three presented Tier 0 as "consequential actions … PreToolUse hook on Bash"
with no statement of reach, and a reader completes that sentence generously.

**Why structurally allowed:** the boundary is invisible from inside. Every Tier-0 block
on record came from a *typed* command, because agents mostly type commands — so the
gate's observed hit rate is evidence about agent habits and reads as evidence about
coverage. There is no signal an agent could have noticed. A gate that has never failed
in your experience and a gate that cannot fail for your case produce identical logs.

**Prevention:** the three documents now state the reach and the consequence
("the moment a command becomes a file, Tier 0 stops seeing it"), and
`tests/unit/tier0_scope_boundary.bats` pins it as a characterization test, so the claim
is falsifiable rather than a comment that can quietly go stale. Demonstrated by patching
the hook to simulate extended coverage and confirming the boundary tests go red.

**What this does NOT fix, stated plainly:** the actual destructive capability is
unchanged. A script can still delete anything it likes. Closing *that* needs a design
decision about whether run-time coverage is wanted at all, and the test file records a
finding that makes it harder than it looks — naive content-reading would not have caught
832's incident either, because the hook blanks quoted strings before matching, so
`rm -rf "$OUT"` reduces to `rm -rf ""`. Any real fix has to reason about variable
*values*, not text. Filed as OBS-138 and left open; this task is the epistemic half.

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

### 2026-08-02T22:42:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2742-document-the-tier-0-scope-boundary--stri.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-27d1f80a
- **Timestamp:** 2026-08-02T22:49:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-02T22:48:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
