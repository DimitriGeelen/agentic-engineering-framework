---
id: T-2251
name: "BVP bundle: fix fw bvp init references to correct fw bvp driver --init verb"
description: >
  BVP bundle: fix fw bvp init references to correct fw bvp driver --init verb

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
created: 2026-06-08T09:37:17Z
last_update: '2026-06-11T22:24:13Z'
date_finished: 2026-06-08T09:39:34Z
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
  - ts: '2026-06-11T22:24:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2251: BVP bundle: fix fw bvp init references to correct fw bvp driver --init verb

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

## Context

Bundle prose says `fw bvp init` in 6 places (init-refusal copy + discipline-failure-modes "no value-drivers.yaml" anti-pattern + sharpening-subroutine convergence-test note). That verb does not exist — the actual verb is `fw bvp driver --init` (see `lib/bvp.sh:1255-1258`). An operator hitting the "Init refusal" prose and running `fw bvp init` gets `ERROR: unknown verb 'init'`. Pure factual error — unlike `fw bvp driver suggest|create|edit|retire` and `fw bvp recompute` (those are genuinely deferred per T-2245 IW-3), `--init` ships today.

Tiny fix: replace 6 instances of `fw bvp init` with `fw bvp driver --init` in 3 bundle files. No CLI build, no semantic change.

## Acceptance Criteria

### Agent
- [x] Zero `fw bvp init` (sans `driver --`) remain in `policy/prompts/` (grep returns nothing) — verified live: `grep -rE "fw bvp init([^-]|$)" policy/prompts/` → empty
- [x] `fw bvp driver --init` appears in `policy/prompts/bvp-driver-session.md` "Init refusal" section — verified via grep PASS
- [x] `fw bvp driver --init` appears in `policy/prompts/bvp-references/discipline-failure-modes.md` anti-pattern — verified via grep PASS
- [x] Bundle still references the actual init verb that exists (`bin/fw bvp driver --init` runs without "unknown verb" error) — `bin/fw bvp driver --help` shows `--init` verb, PASS

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
out=$(grep -rE "fw bvp init([^-]|$)" policy/prompts/ 2>&1); test -z "$out"
grep -q "fw bvp driver --init" policy/prompts/bvp-driver-session.md
grep -q "fw bvp driver --init" policy/prompts/bvp-references/discipline-failure-modes.md
out=$(bin/fw bvp driver --help 2>&1); echo "$out" | grep -q -- "--init"
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

**Symptom:** Bundle prose's "Init refusal" section instructs operators to run `fw bvp init`. That verb doesn't exist — running it returns `ERROR: unknown verb 'init'`. The actual verb is `fw bvp driver --init` (T-2230, T-2229 Slice 1).

**Root cause:** Bundle was authored derivatively from `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §6 (per T-2245 GO Path B). The design dialogue specified `fw bvp init` as the desired verb shape (flat namespace, like `fw bvp recompute`); the implementation went with `fw bvp driver --init` (nested under `driver` subcommand). Bundle authoring (T-2246) reflected the design intent, not the implementation. Six instances across 3 files inherited the wrong verb name.

**Why structurally allowed:** Bundle prose doesn't go through any CLI-name validator. The reviewer agent's static-scan catches AC routing patterns, RCA completeness, and L-387 SIGPIPE — none of which check whether referenced `fw <verb>` strings resolve to actual verbs in `bin/fw`/`lib/`. Bundle text is treated as design documentation, not executable instruction. Compounding factor: the OTHER 5 verbs the bundle references (`suggest|create|edit|retire|recompute`) genuinely don't exist (deferred per T-2245 IW-3), so the agent has no clear signal of which references are "design intent" vs "factual error".

**Prevention:** None implemented in this slice (T-2251 is the mitigation, not the prevention). Possible future preventions:
- Bundle-verb-validation lint: grep bundle prose for `\bfw [a-z]+( [a-z]+)?\b` patterns, cross-check against `bin/fw <verb> --help` exit code 0. Fires on `fw bvp init` but not on `fw bvp driver --init` once corrected. Could be a Tier-1 lint at commit-msg time.
- Deferred-verb annotation: bundle could mark verbs that are deferred (e.g., `fw bvp driver suggest [DEFERRED]`) so future verb-name drift between design and impl is visible.
Filing as captured/later if operator wants to formalise (T-NEW-FW-BUNDLE-LINT or similar).


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

**Recommendation:** GO

**Rationale:** 6 instances of `fw bvp init` (non-existent verb) corrected to `fw bvp driver --init` (working verb, lib/bvp.sh:1255-1258) across 3 bundle files. Bundle prose's "Init refusal" copy and discipline-failure-modes anti-pattern now reference a verb operators can actually run. Pure factual fix — unlike the other bundle verb references (`suggest|create|edit|retire|recompute`) which are genuinely deferred per T-2245 IW-3, `--init` ships today. No semantic change to the workflows.

**Evidence:**
- 4/4 verification checks PASS (zero stale; new verb present in keystone + failure-modes; `--init` verifiably exists in fw bvp driver --help)
- Sibling slice of T-2250 (which closed the discoverability gap at the help surface); this slice closes the prose-accuracy gap inside the bundle

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

### 2026-06-08T09:37:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2251-bvp-bundle-fix-fw-bvp-init-references-to.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b6a7f052
- **Timestamp:** 2026-06-08T09:39:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-08T09:39:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
