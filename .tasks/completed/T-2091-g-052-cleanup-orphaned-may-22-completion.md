---
id: T-2091
name: "G-052 cleanup: orphaned May-22 completion work for T-1981 + T-1987 — duplicate
  task IDs"
description: >
  G-052 cleanup: orphaned May-22 completion work for T-1981 + T-1987 — duplicate task
  IDs

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [bug, cleanup, g-052]
components: [.tasks/active/, .tasks/completed/]
related_tasks: [T-1981, T-1987, T-077]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T11:43:37Z
last_update: 2026-05-29T11:51:47Z
date_finished: 2026-05-29T11:51:47Z
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
  - ts: '2026-05-29T11:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T11:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2091: G-052 cleanup: orphaned May-22 completion work for T-1981 + T-1987 — duplicate task IDs

## Context

Pre-push audit (handover S-2026-0529-1309) FAILED on G-052: T-1981 and T-1987 each
have a file in BOTH `.tasks/active/` AND `.tasks/completed/`. Investigation found:
the **active/** copies are TRACKED in git (`bc555371`, `529c2bad`, `ad9b76bd` for
T-1981; `77c81458`, `709b728c` for T-1987) but carry stale `status: captured /
started-work`. The **completed/** copies are UNTRACKED (mtime 2026-05-22, never
committed) and carry the canonical `status: work-completed` + filled Decision +
ticked ACs. May-22 completion work was orphaned (file written to `.tasks/completed/`
manually, the `git mv` and commit never happened). The metadata-refresh worker
has been bumping `last_update:` on the active/ copies ever since (latest:
2026-05-29T09:45:02Z), masking the divergence.

This blocks the pending handover commit `e1a6fd50` from reaching origin and will
block every subsequent pre-push audit until cleared.

## Acceptance Criteria

### Agent
- [x] May-22 canonical completion content (currently untracked in `.tasks/completed/T-1981-*.md` and `.tasks/completed/T-1987-*.md`) is staged and committed
- [x] Tracked stale active/ copies are removed via `git rm`
- [x] `bin/fw audit` STRUCTURE checks pass (no duplicate-task-IDs FAIL)
- [x] T-1981 and T-1987 inception decisions remain recorded (status `work-completed`, Decision section filled)
- [x] Pending handover commit `e1a6fd50` plus this cleanup commit land on origin/master

### Human
<!-- All ACs are agent-verifiable for this cleanup. No human review needed —
     the canonical content is what existed on May 22, no rendering surface touched.
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

# Verify: completed/ versions are now the canonical (only) copies — no active/ duplicates
out=$(ls .tasks/active/T-1981-* .tasks/active/T-1987-* 2>&1); echo "$out" | grep -qE "No such file"
test -f .tasks/completed/T-1981-inception-how-should-arc-scoped-drivers-.md
test -f .tasks/completed/T-1987-watchtower-redesign--apply-claude-design.md
# Verify: status is work-completed in both canonical files
out=$(grep -E "^status:" .tasks/completed/T-1981-inception-how-should-arc-scoped-drivers-.md 2>&1); echo "$out" | grep -qE "work-completed"
out=$(grep -E "^status:" .tasks/completed/T-1987-watchtower-redesign--apply-claude-design.md 2>&1); echo "$out" | grep -qE "work-completed"
# Verify: audit no longer flags G-052 (inverted grep — pass if pattern NOT found)
out=$(bin/fw audit 2>&1); ! echo "$out" | grep -qE "Duplicate task IDs detected"

## RCA

**Symptom:** `bin/fw audit` STRUCTURE check FAILed with G-052 ("Duplicate task IDs
detected") naming T-1981 and T-1987 — each present in BOTH `.tasks/active/` and
`.tasks/completed/`. The pre-push hook on handover S-2026-0529-1309 saw the FAIL
and refused to push, leaving commit `e1a6fd50` local-only.

**Root cause:** On 2026-05-22 someone (likely a session agent finalising the
inception decisions for the two arcs — T-1981 = BVP scoped-drivers, T-1987 =
watchtower-redesign) wrote the completed task content to `.tasks/completed/`
directly, but never ran the `git mv` + commit pair that would have removed the
old `.tasks/active/` file from the tree and recorded the transition. The active/
copies stayed tracked at their pre-completion state; the completed/ copies stayed
untracked. The metadata-refresh worker (BVP estimator + `last_update:` bumper)
treated the active/ tracked copies as live, mutating them daily — which (a)
masked the divergence (mtime looked fresh) and (b) wrote stale BVP proposals
against tasks that were already settled.

**Why structurally allowed:**
- No gate verifies "if a task ID exists in completed/, no copy may exist in
  active/" at WRITE time. The audit catches it at READ time (G-052) — useful
  but only fires when audit runs.
- The metadata-refresh worker iterates `.tasks/active/*.md` and doesn't
  cross-check `.tasks/completed/` for the same id before mutating. A stale
  duplicate looks identical to a fresh task to that worker.
- Whatever orchestrated the May-22 completion (manual edit? a half-completed
  `update-task.sh --status work-completed`?) didn't fail loudly — it left the
  tree in a partially-committed state that survived 7 days of churn.

**Prevention:**
- **Detect at write-time (CTL-NEW idea):** PreToolUse hook on `Write|Edit` to
  `.tasks/active/T-*.md` could check whether the same id exists in
  `.tasks/completed/` and refuse (or warn with cleanup hint). Surface in
  observation inbox: `obs-CTL-XXX-active-completed-collision`.
- **Detect in metadata worker:** before mutating any `.tasks/active/T-NNNN-*.md`,
  the BVP estimator + `last_update:` bumper should glob `.tasks/completed/T-NNNN-*.md`;
  if found, skip the active mutation and emit a concern. This stops the masking
  effect that hid this from 6+ daily audits.
- **One-shot doctor check:** `bin/fw doctor` could surface untracked task files
  in `.tasks/{active,completed}/` (currently doctor doesn't look here).

Filing the prevention work as a follow-up observation (see Updates) rather than
inline — one bug = one task. This task just clears the immediate G-052 instance.

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

**Recommendation:** GO (close on commit `d012f30d`)

**Rationale:** G-052 cleared on tracked-state evidence — `comm -12 <(active T-IDs)
<(completed T-IDs)` returns empty. The May-22 canonical completion content for
both inceptions is now committed to origin (e1a6fd50 + d012f30d landed). Status
fields are `work-completed` on both T-1981 and T-1987; their Decision sections
are filled (T-1981 GO Model B, T-1987 GO with arc-007 + 7 child slices).

**Evidence:**
- `git log --oneline origin/master..HEAD` → empty (origin caught up)
- `git ls-files .tasks/active/T-1981-* .tasks/active/T-1987-*` → empty
- `head -3 .tasks/completed/T-1981-*` → `status: work-completed`
- `head -3 .tasks/completed/T-1987-*` → `status: work-completed`
- Rename detection captured the transition: R074 (T-1981) + R089 (T-1987)

**Follow-up filed:** Prevention work (write-time hook + metadata-worker
cross-check + doctor untracked-task scan) belongs in a separate task — one
bug = one task. RCA section names the three prongs; recommend filing as
`fw context add-observation` with id `obs-CTL-active-completed-collision` so
the human can groom into a structural fix when it surfaces in the inbox.

## Decisions

<!-- No alternatives chosen here — the cleanup path was forced: untracked
     completed/ content was substantively newer than tracked active/ stubs. -->


## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-29T11:43:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2091-g-052-cleanup-orphaned-may-22-completion.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d25afc35
- **Timestamp:** 2026-05-29T11:51:48Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 40
     - evidence: `out=$(bin/fw audit 2>&1); ! echo "$out" | grep -qE "Duplicate task IDs detected"`

### 2026-05-29T11:51:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
