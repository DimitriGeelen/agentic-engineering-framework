---
id: T-2149
name: "Repair T-2116 frontmatter duplicate components key — unblocks BVP estimator
  batch"
description: >
  Repair T-2116 frontmatter duplicate components key — unblocks BVP estimator batch

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [frontmatter-repair, bvp-estimator, arc-006]
components: [.tasks/active/T-2116-arcsslugclose-headline-mechanic-box-cont.md]
related_tasks: [T-2116, T-2069, T-1918, T-1922]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T17:57:24Z
last_update: 2026-05-31T18:04:48Z
date_finished: 2026-05-31T18:04:48Z
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
  - ts: '2026-05-31T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 7
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-31T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2149: Repair T-2116 frontmatter duplicate components key — unblocks BVP estimator batch

## Context

T-2116 frontmatter has two `components:` keys (lines 13-14 in master): one with the real value `[web/templates/arc_close.html]`, one with empty `[]`. PyYAML rejects the duplicate, so `bin/fw bvp estimate all` errors on T-2116 and skips it (2113 estimated / 1 errored). The empty duplicate looks like a stray auto-update that didn't check for an existing key. T-2069 fixed a sibling class on T-1845 (folded-scalar bleed); this is the next instance.

Origin trigger: `bin/fw bvp estimate all --dry-run` during HV-LC BVP-arc work — estimator surfaced the YAML error inline.

## Acceptance Criteria

### Agent
- [x] T-2116 frontmatter has a single `components:` key (the populated one); the empty duplicate is removed.
- [x] T-2116 frontmatter parses cleanly with `python3 -c "import yaml; yaml.safe_load(open('.tasks/active/T-2116-*.md').read().split('---',2)[1])"` (no DuplicateKeyError).
- [x] `bin/fw bvp estimate all --dry-run` returns `0 errored` across all 2115 tasks (was 2114 estimated / 1 errored; now 2115 estimated / 0 errored; T-2149 itself adds the +1).

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

# T-2149 verification commands:
# Direct YAML-parseability check across all task frontmatters — same coverage the BVP
# estimator was tripping on, without invoking --dry-run (which the reviewer correctly
# flags as skip-as-pass in the general case). This is the underlying invariant.
# (One-line per P-011 line-splitter; uses tools/check_task_yamls.py for legibility.)
python3 tools/check_task_yamls.py

## RCA

**Symptom:** `bin/fw bvp estimate all` errored on T-2116 with `found duplicate key "components" with value "[]" (original value: "['web/templates/arc_close.html']")`. 2113 tasks estimated, 1 errored. PyYAML strict mode refuses duplicate top-level keys.

**Root cause:** T-2116's frontmatter has two adjacent `components:` lines — one with the real path-list (added at task creation), one empty `components: []` (added later by some auto-population path that didn't check for the existing key). The duplicate-write path is not yet identified — could be `update-task.sh`, a fabric hook, the estimator itself, or a manual edit.

**Why structurally allowed:**
1. No write-side guard against duplicate frontmatter keys when auto-population code (`update-task.sh`, fabric register, BVP estimator scoring writeback) modifies task files.
2. The BVP estimator's batch error-handler (T-1922) reports per-task errors but does not auto-file a follow-up task — silent rot until `--dry-run` exposes the counter.
3. `fw audit` structure check passes 18 project YAML files but does not enumerate `.tasks/{active,completed}/T-*.md` frontmatter for duplicate-key detection.

**Prevention:** Symptom fix here unblocks the estimator. Structural prevention is the larger pattern — file follow-up if this class repeats. T-2069 closed the sibling case (folded-scalar bleed on T-1845) without filing a write-side guard either; if T-2149 makes this the 3rd-incident, escalate.

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

### 2026-05-31 — verification command had to dodge two reviewer gates

- **What changed:** Initial Verification used `bin/fw bvp estimate all --dry-run | grep -q "0 errored"`. Two reviewer findings dropped onto that single line: (a) `grep -q "0 errored"` is a substring match, so `1 errored` / `10 errored` would also pass — a real bug, not a FP; (b) reviewer's `skip-as-pass` detector deterministically flags `--dry-run` as a skip-treated-as-pass pattern, which is correct in the general case but a FP for the BVP estimator (dry-run is the right verification — the alternative writes scores corpus-wide and is much more invasive).
- **Plan impact:** Verification rewritten to test the *underlying invariant* directly — every task frontmatter parses with PyYAML. Same coverage the estimator was tripping on, without invoking `--dry-run`. Extracted into `tools/check_task_yamls.py` because P-011 splits on newlines and the multi-line python -c was being parsed line-by-line as separate commands.
- **Triggered:** None — kept in-scope. The "BVP estimator should not be a verification command" insight is generally useful and may be worth a CLAUDE.md note for future authors, but that's a separate task class.

### 2026-05-31 — render-surface gate is path-grep-based and over-eager

- **What changed:** `T-1766` P-013 render-surface gate matched `web/templates/arc_close.html` and refused close. That path is in this task's body as *context* (it's what T-2116 originally touches). T-2149 itself edits zero render surfaces — only `.tasks/active/T-2116-*.md` frontmatter.
- **Plan impact:** Used `--skip-render-review` with a structured rationale citing exactly which file paths were edited vs. mentioned. Logged Tier-2. This is the canonical reviewer-FP case the bypass exists for (mentioned-not-touched).
- **Triggered:** Possibly a future detector refinement — render-surface gate could scan the git diff rather than the body text. Not filing now; one-bug-one-task and this is a single-instance gate over-fire so far.

## Recommendation

**Recommendation:** GO — agent-only ACs, all 3 ticked, BVP estimator unblocked.

**Rationale:** One-line frontmatter fix (remove a duplicate empty `components: []` key from T-2116). Reversible (one revert). No human judgement needed — the BVP batch estimator's per-task error counter is the deterministic pass/fail proxy. After the fix, `bin/fw bvp estimate all --dry-run` returns `0 errored / 2115 estimated` (was `1 errored / 2114 estimated`).

**Evidence:**
- T-2116 line 14 removal commit (this task's diff).
- `python3 -c "import yaml; yaml.safe_load(...)"` on T-2116 frontmatter passes.
- `bin/fw bvp estimate all --dry-run` → `Estimated 2115 tasks: 0 wrote, 2115 skipped, 0 errored` (full run in chat output 2026-05-31T18:00Z).

**What's next:** The root-cause path (who wrote the duplicate key?) is captured in §RCA but not pursued here — one-bug-one-task discipline. If a 3rd-incident lands, escalate to a write-side guard task in `update-task.sh` or the BVP estimator's writeback.

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

### 2026-05-31T17:57:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2149-repair-t-2116-frontmatter-duplicate-comp.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c9ab54b7
- **Timestamp:** 2026-05-31T18:04:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-31T18:04:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
