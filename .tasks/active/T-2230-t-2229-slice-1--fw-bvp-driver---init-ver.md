---
id: T-2230
name: "T-2229 Slice 1 — fw bvp driver --init verb (consumer policy bootstrap)"
description: >
  T-2229 Slice 1 — fw bvp driver --init verb (consumer policy bootstrap)

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
created: 2026-06-06T12:52:07Z
last_update: '2026-06-06T13:00:02Z'
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
bvp_scores_proposed:
  - ts: '2026-06-06T13:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-06T13:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2230: T-2229 Slice 1 — fw bvp driver --init verb (consumer policy bootstrap)

## Context

T-2229 (inception, GO 2026-06-06 via Watchtower) confirmed the BVP onboarding
bootstrap gap: `policy/value-drivers.yaml` is per-consumer state that
`fw init`/`fw upgrade`/`fw vendor` never create. Consumers hit
`ERROR: policy file not found` on their first BVP touch.

This slice ships the verb the error message at `lib/bvp.sh:133` already
promises (`fw bvp driver --init`). Slice 2 will wire it into the three
onboarding surfaces; this slice is just the verb plus the error-message
update so the existing dead reference becomes a working pointer.

Research artifact: `docs/reports/T-2229-onboarding-bootstrap-gap.md`.

## Acceptance Criteria

### Agent
- [x] `_driver_init()` function added to lib/bvp.sh inside the Python heredoc engine
- [x] `cmd_driver()` routes `--init` to `_driver_init()` (before --add / --remove)
- [x] `FRAMEWORK_ROOT` is bound from `os.environ` inside the Python engine (needed to locate the template)
- [x] When `policy/value-drivers.yaml` does not exist, `fw bvp driver --init` copies the framework template and exits 0
- [x] When the target file already exists, `fw bvp driver --init` is idempotent — no overwrite, exit 0, helpful message
- [x] `--force` overrides the idempotent guard and overwrites the target
- [x] After `--init`, `fw bvp` (rank) no longer emits "policy file not found"
- [x] Error message at `lib/bvp.sh:133` no longer says "once T-1920 ships" — points at the working verb
- [x] `fw bvp driver --help` (or fallback usage) advertises `--init [--force]`
- [x] New bats file `tests/unit/t2230_bvp_driver_init.bats` covers: create path, idempotent path, force path, error-message rewrite, help advertisement
- [x] No `### Agent` AC is ticked until its corresponding work is in place (T-1831 C-4 progressive ticking)

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

bash -n lib/bvp.sh
grep -q "def _driver_init" lib/bvp.sh
grep -q "'--init' in args" lib/bvp.sh
# AC#4 path-correctness: implementation references the canonical consumer-side path
grep -q "policy.*value-drivers.yaml" lib/bvp.sh
# AC#4 path-correctness: bats coverage actually asserts the file at that path
grep -q "policy/value-drivers.yaml" tests/unit/t2230_bvp_driver_init.bats
out=$(grep -n "once T-1920 ships" lib/bvp.sh 2>&1 || true); [ -z "$out" ] || { echo "stale T-1920 ref still present"; exit 1; }
out=$(bin/fw bvp driver 2>&1 || true); echo "$out" | grep -q -- "--init"
bats tests/unit/t2230_bvp_driver_init.bats

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

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the dead reference at `lib/bvp.sh:133` that has pointed
at a non-existent verb since T-1920 shipped. Ships the bootstrap verb the
operator-facing error message already promised — every consumer that hits the
"policy file not found" error now has a working one-line fix. Idempotent by
default + `--force` override matches the established pattern. Not §ACD-gated
because first-write of a starter template is sovereignty-neutral; subsequent
weight/driver mutations remain gated. Composes cleanly with Slice 2 (wire
into `fw init`/`upgrade`/`vendor`) which is a separate task.

**Evidence:**

- 10/10 new bats PASS (`tests/unit/t2230_bvp_driver_init.bats`) — create,
  idempotent, --force, rank-after-init, error-rewrite, usage, --help, §ACD
- 113/113 BVP pytest PASS — no regression
- 6/6 `bvp_auto_promote.bats` PASS — no regression
- Live smoke: `bin/fw bvp driver --init` in framework repo hits idempotent
  branch; `bin/fw bvp driver` (no args) shows `--init` first; `bin/fw bvp --help`
  advertises the verb
- Dead reference removed: `grep -c "once T-1920 ships" lib/bvp.sh` = 0

## Updates

### 2026-06-06T12:52:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2230-t-2229-slice-1--fw-bvp-driver---init-ver.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3eb1971d
- **Timestamp:** 2026-06-06T13:00:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
