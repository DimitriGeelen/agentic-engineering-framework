---
id: T-2423
name: "_self_vendor_libs (lib/upgrade.sh) find does not prune node_modules/__pycache__
  — reports phantom pre-push drift ('would sync N file(s) to .agentic-framework/lib/')
  for untracked lib/ts/node_modules/**/*.md (argparse/esbuild/typescript READMEs etc).
  Blocks ALL master pushes whenever npm install has populated lib/ts/node_modules
  (true on main, false on fresh worktrees → silent until you push from main). Verified
  2026-06-14: gate said 11, find lib -path '*/node_modules/*' -name '*.md'|wc -l =
  11, diff -rq lib .agentic-framework/lib byte-identical. Fix: add -not -path '*/node_modules/*'
  -not -path '*/__pycache__/*' -not -path '*/.git/*' to the find in _self_vendor_libs
  AND check siblings _self_vendor_agents/_self_vendor_web (recurse **/*.{sh,py} —
  same gap likely). Workaround used: FW_SKIP_SELF_VENDOR_CHECK=1 git push (Tier-2).
  One bug=one task; needs bats + sibling sweep."
description: >
  Promoted from observation OBS-076

status: work-completed
workflow_type: build
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
created: 2026-06-16T14:49:20Z
last_update: '2026-08-16T22:25:05Z'
date_finished: 2026-06-16T14:52:46Z
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
  - ts: '2026-06-16T14:50:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2423: _self_vendor_libs (lib/upgrade.sh) find does not prune node_modules/__pycache__ — reports phantom pre-push drift ('would sync N file(s) to .agentic-framework/lib/') for untracked lib/ts/node_modules/**/*.md (argparse/esbuild/typescript READMEs etc). Blocks ALL master pushes whenever npm install has populated lib/ts/node_modules (true on main, false on fresh worktrees → silent until you push from main). Verified 2026-06-14: gate said 11, find lib -path '*/node_modules/*' -name '*.md'|wc -l = 11, diff -rq lib .agentic-framework/lib byte-identical. Fix: add -not -path '*/node_modules/*' -not -path '*/__pycache__/*' -not -path '*/.git/*' to the find in _self_vendor_libs AND check siblings _self_vendor_agents/_self_vendor_web (recurse **/*.{sh,py} — same gap likely). Workaround used: FW_SKIP_SELF_VENDOR_CHECK=1 git push (Tier-2). One bug=one task; needs bats + sibling sweep.

## Context

**Duplicate of T-2398** (commit `8c4073cb8`, 2026-06-14): the fix already shipped to master. All three recursive `find`-based self-vendor helpers prune `node_modules/__pycache__/.git`:
- `lib/upgrade.sh:172` — `_self_vendor_libs` recursive find
- `lib/upgrade.sh:401` — `_self_vendor_agents` recursive find
- `lib/upgrade.sh:463` — `_self_vendor_web` recursive find

The three non-recursive helpers (`_self_vendor_templates`, `_self_vendor_policy`, `_self_vendor_shim`) use explicit file lists, not `find`, so they are not affected by the class.

OBS-076 (filed 2026-06-14 in `.context/inbox.yaml`) predates T-2398's fix that same day. The promotion to task picked up the stale observation. Closing as duplicate; dismissing OBS-076 with reference to T-2398.

## Acceptance Criteria

### Agent
- [x] `_self_vendor_libs` find prunes `node_modules`/`__pycache__`/`.git` (verified at `lib/upgrade.sh:172`)
- [x] `_self_vendor_agents` find prunes the same paths (verified at `lib/upgrade.sh:401`)
- [x] `_self_vendor_web` find prunes the same paths (verified at `lib/upgrade.sh:463`)
- [x] OBS-076 in `.context/inbox.yaml` is `status: promoted, promoted_to: task` pointing at T-2423; this task body documents the duplicate-of-T-2398 audit trail

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

grep -q "node_modules" lib/upgrade.sh
test $(grep -c "node_modules" lib/upgrade.sh) -ge 3

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

**Symptom:** OBS-076 filed 2026-06-14 reported phantom pre-push drift on `node_modules/**/*.md`.

**Root cause:** `find lib/` walked into `lib/ts/node_modules/` because npm READMEs were added by `npm install` after the original `_self_vendor_libs` was written. Same gap class in `_self_vendor_agents` + `_self_vendor_web`.

**Why structurally allowed:** the original `find` had no `-prune` for build/cache trees. `npm install` populating `lib/ts/node_modules/` was a state change none of the existing tests covered.

**Prevention:** T-2398 (commit `8c4073cb8`, 2026-06-14) added `\( -path '*/node_modules/*' -o -path '*/__pycache__/*' -o -path '*/.git/*' \) -prune -o` to all three recursive-find self-vendor helpers. The observation OBS-076 was filed the same day before T-2398 landed; the promotion to T-2423 picked up stale state. T-2423 is the close ceremony — fix already in master; no code change.

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

## Recommendation

**Recommendation:** NO-GO (duplicate of T-2398)
**Rationale:** Fix already shipped 2026-06-14. Verified all three recursive `find`-based self-vendor helpers in `lib/upgrade.sh` prune `node_modules/__pycache__/.git`. Promotion of OBS-076 occurred without checking the current code state — the observation was filed the same day as the fix that resolved it.
**Evidence:**
- `lib/upgrade.sh:172` — `_self_vendor_libs` prune
- `lib/upgrade.sh:401` — `_self_vendor_agents` prune
- `lib/upgrade.sh:463` — `_self_vendor_web` prune
- `git log --oneline -S "node_modules" -- lib/upgrade.sh` → `8c4073cb8 T-2398: fix OBS-076 — self-vendor find prunes node_modules/__pycache__/.git`

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

### 2026-06-16T14:49:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2423-selfvendorlibs-libupgradesh-find-does-no.md
- **Context:** Initial task creation

### 2026-06-16T14:50:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-afb0ec24
- **Timestamp:** 2026-06-16T14:52:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#4 (Agent)

### 2026-06-16T14:52:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
