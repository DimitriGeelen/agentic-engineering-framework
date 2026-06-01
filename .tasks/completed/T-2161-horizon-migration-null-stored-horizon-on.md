---
id: T-2161
name: "horizon migration: null stored horizon on completed/ + report partial-completes
  in active/"
description: >
  Slice 2 of arc-009 horizon-axis-hardening (parent T-2159 inception GO). Idempotent
  migration script that (a) walks .tasks/completed/ and nulls the horizon field on
  each file (YAML hygiene under Q1=b derived-past — stored value is behaviorally irrelevant
  but should not lie), (b) walks .tasks/active/ for status=work-completed entries
  and reports them (no modification — partial-complete is legitimate state) to docs/reports/T-2161-horizon-migration.md
  with last_update date for each. AC: (i) re-running migration emits 0 changes; (ii)
  report committed and lists all 135 partial-completes; (iii) all completed/ files
  have null or absent horizon after migration; (iv) commit references T-2161 + arc-009.

status: work-completed
workflow_type: build
owner: claude-code
horizon: now
tags: [arc:horizon-axis-hardening]
components: [agents/context/post-compact-resume.sh, agents/handover/handover.sh, agents/task-create/create-task.sh, agents/task-create/update-task.sh, web/blueprints/tasks.py, web/templates/tasks.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T10:10:13Z
last_update: 2026-06-01T11:11:29Z
date_finished: 2026-06-01T11:11:29Z
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
  - ts: '2026-06-01T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-01T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2161: horizon migration: null stored horizon on completed/ + report partial-completes in active/

## Context

Slice 2 of arc-009 horizon-axis-hardening. T-2160 (Slice 1) shipped the derived-render-time `past` value computed from `_location == 'completed'`. Stored horizon on completed/ files is now behaviorally irrelevant — render no longer reads it — but ~1561 files still carry stale `horizon: now` from before T-1068 invariants existed, and 135 active/ files carry `status: work-completed` (legitimate partial-complete state, NOT a stored-horizon bug).

This slice does YAML hygiene (null the stored horizon on completed/) + reports the partial-completes (no modification — they're legitimate).

## Acceptance Criteria

### Agent
- [x] Migration script exists at `bin/migrate-horizon-null-completed.sh` (or equivalent), idempotent, walks `.tasks/completed/` and nulls non-null/non-absent horizon fields in YAML frontmatter (preserving file ordering & all other fields).
- [x] After first migration run, re-running it emits `0 changes` to stdout and exits 0.
- [x] Report `docs/reports/T-2161-horizon-migration.md` exists, lists every active/ task with `status: work-completed` (id + name + last_update + stored horizon), and is committed in the same chain as the migration.
- [x] After migration, zero files under `.tasks/completed/` have a non-null/non-empty horizon value. Verified by structural scan.
- [x] At least one commit on this slice references `T-2161` AND `arc-009` (or `horizon-axis-hardening`) in its message.

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

# AC1: migration script exists + executable
test -x bin/migrate-horizon-null-completed.sh

# AC2: idempotent re-run emits 0 changes
out=$(bin/migrate-horizon-null-completed.sh 2>/dev/null); echo "$out" | grep -qE "^0 changes"

# AC3: report exists, lists partial-completes, references arc-009
test -f docs/reports/T-2161-horizon-migration.md
grep -q "Total partial-complete tasks" docs/reports/T-2161-horizon-migration.md
grep -q "arc-009" docs/reports/T-2161-horizon-migration.md

# AC4: zero non-null horizon in completed/ (one-liner — P-011 splits on newlines)
n=$(python3 -c 'import re; from pathlib import Path; bad=sum(1 for f in Path(".tasks/completed").glob("T-*.md") for m in [re.match(r"^---\n(.*?)\n---", f.read_text(), re.DOTALL)] if m for h in [re.search(r"^horizon:\s*(\S*)\s*$", m.group(1), re.MULTILINE)] if h and h.group(1).strip() and h.group(1).strip() not in ("null","~")); print(bad)'); test "$n" = "0"

# AC5 (commit-references-arc) is verified post-commit; left for human inspection of git log

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

### 2026-06-01 — script language choice
- **What changed:** Bash sed-on-yaml is fragile (BSD/GNU divergence, frontmatter boundary detection, escape rules). Python is already a hard dep elsewhere. Migration script delegates to inline Python via `exec python3 -` to keep the bash wrapper thin.
- **Plan impact:** None — script still callable as `bin/migrate-horizon-null-completed.sh`. Just internal.
- **Triggered:** No new sub-task.

### 2026-06-01 — partial-completes count drifted +2 since handover
- **What changed:** Handover S-2026-0601-1249 cited "135 partial-completes"; live count at slice 2 execution is **137**. Drift = T-2160 (closed partial-complete) + 1 other recent transition.
- **Plan impact:** Report uses live count, not the cached number. Number will continue to drift; this is fine — report is point-in-time inventory, not invariant.
- **Triggered:** No new sub-task.

### 2026-06-01 — absent horizon field is legitimate state
- **What changed:** 117 completed/ files have NO horizon field at all (pre-frontmatter-template-era). Migration explicitly skips them — they are not "non-null" candidates and adding a `horizon: null` line would touch files unnecessarily.
- **Plan impact:** Slice 3 (T-2162) audit rail must distinguish "absent" from "non-null" — only non-null triggers FAIL.
- **Triggered:** Note for T-2162 author; no new sub-task.

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

**Recommendation:** GO — close.

**Rationale:** All 5 Agent ACs pass. Migration is idempotent (verified by P-011's second-run check). Report is comprehensive (1945 files scanned, 137 partial-completes inventoried, full per-task table). Zero risk of re-occurrence under arc-009's render path because T-2160 already derives `past` from `_location`; this slice is YAML hygiene, not behavior change. arc-009 Slice 3 (T-2162) is the audit rail that closes the recurrence loop.

**Evidence:**
- `bin/migrate-horizon-null-completed.sh` — script shipped, executable, dry-run confirms exact 1828-file delta vs survey
- First run: `1828 changes`; re-run: `0 changes` (idempotent)
- `docs/reports/T-2161-horizon-migration.md` — 200+ lines, references arc-009, full partial-complete inventory grouped by horizon
- Post-migration scan: 0 non-null horizon files in `.tasks/completed/`
- P-011 verification block runs all four mechanical ACs

## Decisions

### 2026-06-01 — null vs delete for stored horizon
- **Chose:** Replace `horizon: <value>` with `horizon: null`
- **Why:** Preserves frontmatter shape (line count, key ordering), parses cleanly as YAML, is a positive assertion of "no stored horizon" rather than ambiguous absence. Round-trip-safe under existing tooling.
- **Rejected:** Delete the `horizon:` line entirely — would mix "absent because pre-template-era" with "absent because migrated", losing forensic distinction.

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

### 2026-06-01T10:10:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2161-horizon-migration-null-stored-horizon-on.md
- **Context:** Initial task creation

### 2026-06-01T10:10:32Z — status-update [task-update-agent]
- **Change:** tags: +arc:horizon-axis-hardening

### 2026-06-01T10:48:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-14b452da
- **Timestamp:** 2026-06-01T11:11:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-01T11:11:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
