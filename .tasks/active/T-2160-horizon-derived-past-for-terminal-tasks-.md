---
id: T-2160
name: "horizon: derived past for terminal tasks + render-surface integration + invariant
  guard"
description: >
  Slice 1 of arc-009 horizon-axis-hardening (parent T-2159 inception GO). Add render-time
  'past' horizon derived from file location in .tasks/completed/. Update agents/handover/handover.sh,
  agents/context/post-compact-resume.sh, web/blueprints/tasks.py to compute and honor
  past. Add invariant guard in agents/task-create/update-task.sh that rejects --horizon
  past (cannot be set, only derived). Filter status=work-completed entries out of
  handover's now/next buckets and surface them in an explicit 'Partial-Complete —
  awaiting human' footer section (Q4 explicit-filter resolution). Closes the third
  T-1068 invariant (the missing completion edge).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:horizon-axis-hardening]
components: [agents/context/post-compact-resume.sh, agents/handover/handover.sh, agents/task-create/create-task.sh, agents/task-create/update-task.sh, web/blueprints/tasks.py, web/templates/tasks.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T10:09:58Z
last_update: 2026-06-01T10:47:46Z
date_finished: 2026-06-01T10:47:46Z
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
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
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

# T-2160: horizon: derived past for terminal tasks + render-surface integration + invariant guard

## Context

Slice 1 of arc-009 horizon-axis-hardening. Implements the Q1=(b) derived-past resolution from T-2159 inception: `past` is computed at read-time from file location (`.tasks/completed/`), never stored in YAML. Implements Q4 explicit-filter resolution: status=work-completed entries are removed from handover's now/next buckets and surfaced in an explicit "Partial-Complete — awaiting human" footer. Adds the missing third T-1068 invariant: rejects `--horizon past` because past has no write-path.

Research artifact: `docs/reports/T-2158-continuous-run.md` is a different arc (unrelated). The Step-0 verification + Q1-Q4 resolution lives in this session's chat log; design decisions captured in §Decisions below.

## Acceptance Criteria

### Agent
- [x] AC1 — `handover.sh` Work-in-Progress section emits zero `status: work-completed` entries under any `<!-- horizon: now -->` or `<!-- horizon: next -->` bucket
- [x] AC2 — `handover.sh` emits a `<!-- partial-complete-footer -->` section (or equivalent named anchor) listing every active task with status=work-completed (verifiable: count matches active/+work-completed task count)
- [x] AC3 — `web/blueprints/tasks.py` `/tasks?horizon=past` returns HTTP 200 and includes at least one task from `.tasks/completed/`
- [x] AC4 — `bin/fw task update T-XXX --horizon past` exits non-zero with stderr containing `past` and `derived` (clear error)
- [x] AC5 — `post-compact-resume.sh` Active Tasks block emits zero `status: work-completed` entries (Partial-Complete tasks surfaced separately or suppressed per §Decisions)
- [x] AC6 — `lib/enums.sh` `is_valid_horizon()` still returns true for now/next/later and false for past (storage enum unchanged; only render layer knows about past)

### Human
- [ ] [REVIEW] /tasks filter dropdown now shows "past" as a filter option, and selecting it renders completed tasks
  **Steps:**
  1. Open http://192.168.10.107:3000/tasks?view=list in a browser
  2. Locate the Horizon filter dropdown (alongside Status / Owner / Tag)
  3. Confirm "past" appears as a selectable option in addition to now/next/later
  4. Select "past" — page should reload and show only tasks from `.tasks/completed/`
  5. Verify the filter chip (top of page) says "horizon: past" with a clear-x
  6. Switch back to "All Horizons" — completed tasks should disappear from the list (they're under "past" view)
  **Expected:** "past" is selectable; selecting it shows completed tasks; filter chip reflects the choice; "All Horizons" returns to the unfiltered view
  **If not:** Note which step broke (dropdown missing past, no filter applied, etc.) and reopen the task

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

# AC1: zero work-completed under now/next buckets in handover Work-in-Progress
n=$(awk '/^## Work in Progress/{w=1;next} /^<!-- partial-complete-footer -->/{w=0} /^## /&&w&&!/Work in Progress/{w=0} w&&/<!-- horizon: (now|next) -->/{b=1;next} w&&/<!-- horizon: later -->/{b=0} w&&b&&/\*\*Status:\*\* work-completed/{c++} END{print c+0}' .context/handovers/LATEST.md); [ "$n" = "0" ]
# AC2: partial-complete footer present + count matches active/work-completed count
fc=$(grep -E "^### Partial-Complete — awaiting human \(([0-9]+) tasks\)" .context/handovers/LATEST.md | sed -E 's/.*\(([0-9]+).*/\1/' | head -1); ac=$(grep -lE "^status: work-completed" .tasks/active/T-*.md 2>/dev/null | wc -l); [ "$fc" = "$ac" ] && [ "$fc" -gt 0 ]
# AC3: /tasks?horizon=past returns 200 with completed tasks (list view — board view is paginated)
url=$(bin/fw watchtower url 2>/dev/null); curl -sf "$url/tasks?horizon=past&view=list" -o /tmp/t2160-past.html && grep -qE "T-(2155|2156|2159|111)" /tmp/t2160-past.html
# AC4: --horizon past rejected with derived+past in stderr. Uses a sibling
# task ID (T-2161) instead of T-2160 itself, to avoid self-recursion during
# completion-gate verification (running --horizon past on T-2160 while T-2160
# is being closed creates a process pile-up). T-2161 must exist; if it's
# closed before this runs, swap for any other active task ID.
out=$(bin/fw task update T-2161 --horizon past 2>&1 || true); echo "$out" | grep -qE "(past.*derived|derived.*past)"
# AC5: post-compact-resume Partial-Complete section present (em-dash em U+2014 may
# be JSON-escaped as \\u2014 — match either form with .{2,8})
po=$(bash agents/context/post-compact-resume.sh 2>/dev/null); echo "$po" | grep -qE "Partial-Complete.{2,8}awaiting human"
# AC6: storage enum unchanged
bash -c 'source lib/enums.sh; is_valid_horizon now && is_valid_horizon next && is_valid_horizon later && ! is_valid_horizon past' >/dev/null 2>&1

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

### 2026-06-01 — handover.sh already had partial-complete consolidation
- **What changed:** During implementation, found that `handover.sh:601-610` *already* consolidated work-completed tasks into "Awaiting Human Review" sub-sections — flushed per-horizon as a transition marker. The pollution wasn't that work-completed tasks rendered as full `### T-XXX:` WIP blocks; the pollution was that each horizon bucket got its own consolidation section (3 sub-sections for now/next/later) interleaved with active WIP, and the section header "Awaiting Human Review" buried the partial-complete framing.
- **Plan impact:** Simpler refactor than expected. The fix is two changes, not a rewrite:
  1. Move flush from per-horizon to single bottom footer
  2. Rename section: "Awaiting Human Review" → "Partial-Complete — awaiting human"
  Group inside footer by horizon (now/next/later) for the human's context, but as sub-headings under one footer, not as separate sections.
- **Triggered:** No new sub-tasks. The pre-existing code path made AC1 (zero work-completed in WIP buckets) trivially satisfiable — work-completed was already filtered out of full `### T-XXX:` rendering. Only the per-horizon-flush pattern needed restructuring.

### 2026-06-01 — `_location` field already exists on cached task metadata
- **What changed:** `web/shared.py:get_all_task_metadata()` already sets `_location: 'active'|'completed'` on every task dict (T-1244). Made AC3 (derived past on Watchtower) a two-line filter change.
- **Plan impact:** No template-side rendering changes needed for the kanban — the existing kanban groups by stored horizon, and completed tasks at stored horizon:now still appear under the "now" column in kanban view when filter=past is applied. List view (`view=list`) shows them flat. Acceptable; kanban semantics for past would need a follow-up.
- **Triggered:** Possible follow-up — kanban-mode rendering for `horizon=past` could either (a) hide the kanban grid + show a list, or (b) add a "Past" column. Not needed for arc-009 close; capture as observation if it matters.

### 2026-06-01 — create-task.sh also needed the guard
- **What changed:** Initial scope was just `update-task.sh`. Realised `create-task.sh` accepts `--horizon` too — without the guard, `bin/fw task create --horizon past` would succeed since `is_valid_horizon` doesn't know about the derived-past semantics (past isn't in the enum, but the error message would say "Invalid horizon" not "derived value, not settable").
- **Plan impact:** Added matching guard to `create-task.sh:118-125`. Both write-paths now reject past with the same explicit message.
- **Triggered:** No new sub-task. Single-line scope expansion within this slice.

## Decisions

### 2026-06-01 — Single bottom footer (Q4 explicit-filter execution)
- **Chose:** Move all partial-complete entries into ONE bottom footer (post-WIP, pre-Inceptions), grouped internally by horizon
- **Why:** The user resolved Q4 as "explicit filter" (not silent). Per-horizon sub-sections (the previous behavior) hid the framing — humans saw 136 tasks across 3 sub-sections labeled "Awaiting Human Review" and didn't connect them as one class. Single footer with the explicit name "Partial-Complete — awaiting human" makes the framing legible.
- **Rejected:** (a) Silent filter — violates Q4. (b) Per-horizon sub-sections — current behavior, the thing we're fixing. (c) Top-of-WIP footer — buries the actual WIP signal.

### 2026-06-01 — `enum_render_horizons` separate from `enum_horizons` (storage vs render)
- **Chose:** Storage enum (`enum_horizons`: now/next/later) stays the source of truth for write-paths (kanban-drag, inline edits, create form). New `enum_render_horizons` (storage + past) is for filter dropdowns only.
- **Why:** Per Q1=(b) past is derived from `_location`, not stored. If past appeared in write-path dropdowns, a user could set it and the storage layer would either accept it (breaking invariant) or reject silently (breaking UX). Two enums = clean separation: write-paths see only writable values, render-paths see past.
- **Rejected:** Single enum with past included — would require write-side validation in 4+ places. Two-enum split is the standard "storage vs render" pattern.

## Decision

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO

**Rationale:**

Slice 1 of arc-009 horizon-axis-hardening is complete. All 6 Agent ACs PASS under the P-011 verification gate (handover Work-in-Progress shows 0 work-completed entries in now/next buckets; explicit "Partial-Complete — awaiting human (136 tasks)" footer matches the active/work-completed task count exactly; `/tasks?horizon=past&view=list` returns 200 with completed tasks; `bin/fw task update T-XXX --horizon past` rejected with explicit derived+past error; post-compact-resume splits work-completed into its own section; storage enum `is_valid_horizon` unchanged).

The pre-existing partial-complete consolidation in `handover.sh` (line 601-610) was already filtering work-completed out of full `### T-XXX:` WIP rendering — what the user observed as "pollution" was the per-horizon flush pattern interleaving 136 partial-completes across 3 sub-sections labeled "Awaiting Human Review." The fix was a small restructure (move to single bottom footer + rename to "Partial-Complete — awaiting human") rather than a rewrite. See §Evolution for the reframe.

One remaining Human AC verifies the filter dropdown UI change in Watchtower (`/tasks?view=list` shows past as a filter option; selecting it filters to completed tasks; filter chip reflects the choice). Task enters partial-complete state per the AC split rule.

**Evidence:**

- Commit `90e4a5f7` — 7 files, +174/-54 lines: handover.sh (footer restructure), post-compact-resume.sh (split), update-task.sh + create-task.sh (invariant guard), web/blueprints/tasks.py + tasks.html (derived-past filter + enum_render_horizons)
- All 6 Agent ACs ticked and verified via P-011 gate (6/6 PASS at close-time)
- Live numbers at close: 136 partial-complete tasks (active/work-completed) — exact match between handover footer count and `.tasks/active/` grep
- `/tasks?horizon=past&view=list` returns 200 OK, contains T-111 / T-2155 / T-2156 / T-2159 (sampling of known completed tasks)
- Storage enum unchanged: bash-test confirms is_valid_horizon now/next/later → true, past → false
- `bin/fw task update T-XXX --horizon past` produces explicit error: "rejected — past is a derived render-time value, not settable"
- Unblocks T-2161 (migration — nulls stored horizon on completed/) and T-2162 (audit rail — fails when completed/ has non-null horizon)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-01T10:09:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2160-horizon-derived-past-for-terminal-tasks-.md
- **Context:** Initial task creation

### 2026-06-01T10:10:31Z — status-update [task-update-agent]
- **Change:** tags: +arc:horizon-axis-hardening

### 2026-06-01T10:25:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d25b57c8
- **Timestamp:** 2026-06-11T12:13:00Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#3 (Agent)** — AC3 — `web/blueprints/tasks.py` `/tasks?horizon=past` returns HTTP 200 and includes at least one task from `.tasks/completed/`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/tasks.py in: AC3 — `web/blueprints/tasks.py` `/tasks?horizon=past` returns HTTP 200 and includes at least one task from `.tasks/completed/``
- **AC#1 (Human)** — [REVIEW] /tasks filter dropdown now shows "past" as a filter option, and selecting it renders completed tasks
  - **human-ac-mechanical-signal** (partial, heuristic) — `matched='shows c' in Expected: "past" is selectable; selecting it shows completed tasks; filter chip reflects the choice; "All Horizons" returns to the unfiltered view`

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 48
     - evidence: `bash -c 'source lib/enums.sh; is_valid_horizon now && is_valid_horizon next && is_valid_horizon later && ! is_valid_horizon past' >/dev/null 2>&1`
### 2026-06-01T10:47:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
