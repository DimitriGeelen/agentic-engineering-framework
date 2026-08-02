---
id: T-2718
name: "Keystone: fw init enumerates what is there and decides project shape (F-10)"
description: >
  Arc keystone for the harness+installer arc authorised by T-2715 GO item 2. F-10:
  lib/init.sh's 7-manifest detector treats absence of a known manifest as positive
  evidence of greenfield, so unrecognised ecosystems are classified as empty and land
  the user on a human-owned inception task requiring a decision the agent is structurally
  forbidden to record, behind the T-532 gate that blocks all other work. Re-reproduced
  2026-08-02 in this task: 4 of 8 real-code fixtures misclassify (.NET, C/C++, PHP,
  flat-python); the earlier "6 of 7" figure was specific to T-2715's fixture set —
  the
  class reproduces, the ratio does not. Fix shape per 832 rail 376: enumerate what
  IS
  there and decide, NOT a longer manifest list. Carries the arc's closure Recommendation.

status: work-completed
workflow_type: design
owner: agent
horizon: null
tags: [arc:onboarding-shape-detection]
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
created: 2026-08-02T00:33:29Z
last_update: 2026-08-02T06:02:20Z
date_finished: 2026-08-02T06:02:20Z
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
  - ts: '2026-08-02T00:37:39Z'
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
  - ts: '2026-08-02T05:42:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-02T00:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2718: Keystone: fw init enumerates what is there and decides project shape (F-10)

## Context

Arc keystone for **arc-015 onboarding-shape-detection**, authorised by the T-2715 GO (item 2).
Full inception evidence: `docs/reports/T-2715-first-run-experience.md` §F-10.

### The defect, located

`lib/init.sh:489-502`. The detector asks *"does one of these seven known manifests exist?"* and
treats **absence of a known manifest as positive evidence of greenfield**:

```bash
for manifest in package.json requirements.txt pyproject.toml go.mod Cargo.toml pom.xml setup.py; do
    [ -f "$target_dir/$manifest" ] && has_code=true && break
done
[ "$has_code" = false ] && for codedir in src lib app; do [ -d "$target_dir/$codedir" ] && has_code=true; done
```

Greenfield is the **default**, reached by falling off the end of a finite allowlist. Every ecosystem
not on that list — and every project whose layout does not happen to use `src/`, `lib/` or `app/` —
is classified as empty. The consequence is not cosmetic: greenfield seeds an `owner: human`
inception task, and the T-532 gate (`agents/context/check-active-task.sh:440-490`) blocks all
non-onboarding Write/Edit until the onboarding set is `work-completed`. The agent is structurally
forbidden from recording that inception decision. The user is deadlocked on their first run.

### Reproduction — measured 2026-08-02, this task

Nine synthetic projects, real `bin/fw init`, classification read from the seed line:

| Fixture | Contents | Classified |
|---|---|---|
| dotnet | `MyApp.sln`, `MyApp/MyApp.csproj`, `Program.cs` | **greenfield** ✗ |
| cpp | `Makefile`, `main.c`, `include/foo.h` | **greenfield** ✗ |
| php | `composer.json`, `index.php` | **greenfield** ✗ |
| flat-python | `main.py`, `utils.py`, `README.md` | **greenfield** ✗ |
| ruby | `Gemfile`, `Rakefile`, `app/models/user.rb` | existing ✓ |
| gradle-java | `build.gradle`, `src/main/java/Main.java` | existing ✓ |
| rust-ok | `Cargo.toml`, `src/main.rs` | existing ✓ |
| node-ok | `package.json`, `index.js` | existing ✓ |
| truly-empty | `.keep` | greenfield ✓ |

**4 of 8 real-code projects misclassify.** Note this differs from the "6 of 7" figure in the
T-2715 artifact — that count was specific to that fixture set, not a constant. The *class* is
what reproduces; the ratio is an artefact of which fixtures you pick. Recording the discrepancy
rather than repeating the earlier number.

Note also **why** ruby and gradle-java pass: not because the detector recognises Ruby or Gradle
(`Gemfile` and `build.gradle` are both absent from the allowlist) but because they incidentally
have `app/` and `src/`. They pass **by accident**. A Ruby project with a flat layout fails.

### Fix shape — ratified with 832 (rail 376)

> Enumerate what IS there and decide — **not** a longer manifest list.

Adding `.sln`, `composer.json`, `Gemfile`, `build.gradle`, `Makefile` to the array reproduces the
identical property with a later failure date: the 8th unlisted ecosystem deadlocks exactly as the
7th did. The defect is not *which* names are on the list, it is that **the list is the oracle**.

The correcting move is to **invert the default**. Greenfield is the narrow, positively-established
case (the directory is empty or holds nothing but framework scaffolding); "existing" is what you
conclude when you find *anything you did not put there*. Absence of recognition then means "I
don't recognise this stack", which is true and harmless, instead of "this directory is empty",
which is false and deadlocking.

The second half of the mechanic is **enumerate visibly** — `fw init` should report what it actually
found and the shape it inferred from it, so a wrong inference is legible to the user at the moment
it happens rather than three commands later when the gate fires.

### Scope fence

This keystone carries the arc's design decision and closure Recommendation. It does **not** hold the
implementation — that is a separate build task under arc-015, together with wiring the fresh-project
harness (`tests/unit/greenfield_seed_audit_prototype.bats`, T-2703, currently RED and globbed by no
runner) that would have caught this class at authoring time.

**Sequencing:** GO item 1 (arc-exit mechanism) gates this arc's *closure*, not its work.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] F-10 reproduced against real `bin/fw init` with a fixture table recording which ecosystems
      misclassify and, for those that pass, *why* they pass (incidental `src/`/`app/`, not recognition)
- [x] Design decision recorded in `## Decisions`: invert the default (greenfield positively
      established) + enumerate visibly, with the rejected alternative (longer allowlist) and the
      reason it is rejected (reproduces the property with a later failure date)
- [x] Build task(s) created under arc-015 for the implementation and for wiring the T-2703 harness
      — T-2722 (invert the default + enumerate visibly in `lib/init.sh`) and T-2723 (wire the
      fresh-project seed harness so F-10-class misclassification fails a runner), both tagged
      `arc:onboarding-shape-detection`
- [x] Scoped drivers proposed on the arc YAML (D-5: after this body is filled, before any approval)
      — two proposed (`unknown-input-safety` w6, `first-run-recoverability` w4), a third drafted and
      discarded rather than shipped to look thorough (R5); awaiting operator approval at
      `/arcs/onboarding-shape-detection`

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

# Both build tasks exist AND resolve into arc-015, read through the canonical CLI
# membership surface (`fw arc show` uses lib/arc_membership.sh). Checking membership
# rather than file-existence is deliberate: a task file that exists but never joined
# the arc is the failure this AC actually guards against, and file-existence alone
# would report success about the wrong object.
M=$(bin/fw arc show onboarding-shape-detection 2>&1); echo "$M" | grep -q "T-2722" && echo "$M" | grep -q "T-2723"
# The arc's anchor still points at this keystone (guards against an anchor rewrite
# silently orphaning the design decision the arc is built on).
grep -q "^anchor_task: T-2718$" .context/arcs/onboarding-shape-detection.yaml
# The rejected alternative is recorded, not just the chosen one — the whole point of
# this keystone is that the intuitive fix (longer allowlist) must stay explicitly refused.
sed -n '/^## Decisions/,/^## Updates/p' .tasks/active/T-2718-keystone-fw-init-enumerates-what-is-ther.md | grep -qi "rejected"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-08-02 — how `fw init` decides project shape

- **Chose:** **Invert the default, and enumerate visibly.** Greenfield becomes the narrow case that
  must be *positively established* (the target directory holds nothing but framework scaffolding);
  "existing project" is the conclusion drawn from finding anything the framework did not put there.
  Separately, `fw init` reports what it actually found and the shape it inferred, so a wrong
  inference is legible at the moment it happens rather than three commands later when T-532 fires.

- **Why:** the failure is not that the allowlist is too short — it is that **the allowlist is the
  oracle**. Under the current shape, "I don't recognise this stack" and "this directory is empty"
  produce the same answer, and only one of them is ever true. Inverting makes non-recognition
  harmless: an unrecognised Haskell or Zig or COBOL project is correctly treated as *existing*,
  which is the safe classification, because the cost matrix is asymmetric. Misclassifying existing
  → greenfield deadlocks the user behind a gate the agent cannot clear. Misclassifying greenfield →
  existing seeds a slightly-wrong task set the user can simply complete or delete. One is a wall;
  the other is mild noise. The default should sit on the cheap side of that asymmetry, and today it
  sits on the expensive side.

- **Rejected — extend the manifest array** (`.sln`, `composer.json`, `Gemfile`, `build.gradle`,
  `Makefile`, …). This is the intuitive fix and it is wrong: it repairs the four fixtures measured
  above while leaving the *property* intact, so the 8th unlisted ecosystem deadlocks exactly as the
  7th did, with a later failure date and a stronger false confidence (a longer list *looks* more
  thorough). Ratified independently with 832 (rail 376): *"enumerate what IS there and decide, not
  lengthen the list."* Recorded here explicitly because this is the alternative a future maintainer
  will reach for first.

- **Rejected — ask the user which mode they want.** Moves a decision the framework has enough
  evidence to make onto the person with the least context (they have just met the tool), and adds an
  interactive prompt to a command that must work non-interactively in `fw upgrade`/CI paths.

- **Evidence that the current shape passes for the wrong reason:** `ruby` and `gradle-java`
  classify correctly, but neither `Gemfile` nor `build.gradle` is on the allowlist — they pass only
  because they incidentally contain `app/` and `src/`. A green result produced by an accident is
  indistinguishable from a green result produced by recognition, which is the same
  check-reports-success-about-the-wrong-object class T-2715 catalogued twelve times.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-02T00:33:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2718-keystone-fw-init-enumerates-what-is-ther.md
- **Context:** Initial task creation

### 2026-08-02T00:36:50Z — status-update [task-update-agent]
- **Change:** tags: +arc:onboarding-shape-detection

### 2026-08-02T00:37:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b4f63904
- **Timestamp:** 2026-08-02T06:02:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-02T06:02:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
