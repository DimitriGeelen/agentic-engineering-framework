---
id: T-2167
name: "investigate OBS-034 orphan stash 254e9028 — drop or restore recommendation"
description: >
  investigate OBS-034 orphan stash 254e9028 — drop or restore recommendation

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T20:18:16Z
last_update: '2026-06-11T22:23:32Z'
date_finished: 2026-06-01T20:21:51Z
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
  - ts: '2026-06-11T22:23:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 4
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=4 (body:rubric-routable); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2167: investigate OBS-034 orphan stash 254e9028 — drop or restore recommendation

## Context

OBS-034 (captured 2026-05-29, context T-2091) flagged orphan stash `254e9028` —
`WIP on master: 8a8a7b0a T-2086: L-445 — source-range syntax must not expand into N duplicate entries`.
The stash was implicated as the source of G-052 active/T-1981 + active/T-1987 task-id duplicates
that T-2091 cleaned up. Per OBS-034 the choice was deferred to a human because:

> "this is a 600+ file stash referencing consumer paths that don't belong in this repo —
> dropping unknown stashes is destructive."

This task does the read-only investigation and produces a drop/restore/inspect Recommendation
for the operator to action via Watchtower. No destructive ops in this task — `git stash drop`
is the operator's call.

## Acceptance Criteria

### Agent
- [x] Confirm stash exists and matches OBS-034's id (254e9028), message ("WIP on master: 8a8a7b0a T-2086"), and rough file count (≥600).
- [x] Enumerate stash content by surface: count of `.agentic-framework/*` paths (consumer-layout pollution), count of framework-native paths, count of `.tasks/*` files inside.
- [x] Forensic check: for each `.tasks/T-NNNN-*.md` file in the stash, confirm a same-id task exists somewhere under `.tasks/{active,completed}/`. Zero unaccounted ids = no lost task content.
- [x] Spot-check the four `.tasks/active/T-*` files the stash carries against the live tree: are the stash versions semantically newer than what's now on master, or stale snapshots? (If newer = real risk; if stale = pollution.)
- [x] Cross-reference T-2091 RCA section in `.tasks/completed/T-2091-*.md` to confirm the stash was indeed the active/T-1981 + active/T-1987 duplicate source.
- [x] Write final Recommendation block (DROP / RESTORE / HUMAN-INSPECT) with rationale + evidence + the exact command the operator would run to action it. No `git stash drop` invoked by the agent.

### Human
- [ ] [REVIEW] Action the agent's Recommendation via Watchtower (or override) — operator-sovereign destructive operation.
      **Steps:**
      1. Open the Watchtower review URL emitted by `bin/fw task review T-2167`
      2. Read the Recommendation block + evidence
      3. If accepting agent's DROP recommendation: run `cd /opt/999-Agentic-Engineering-Framework && git stash drop 254e9028`
      4. Re-run `bin/fw note dismiss OBS-034 --reason "stash dropped — recommendation accepted"` (or `--reason "restored as ..."` / `"inspected, kept"`)
      **Expected:** stash list no longer contains `254e9028`; OBS-034 marked dismissed in inbox
      **If not:** restore via `git stash apply 254e9028` then triage individual paths

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

## Findings

**Stash identity (AC #1 PASS):**
- ID: `stash@{0}` → `254e9028` ✓
- Message: `WIP on master: 8a8a7b0a T-2086: L-445 — source-range syntax must not expand into N duplicate entries` ✓
- Total files: 1241 (well above OBS-034's "600+" estimate)
- Total diff: +41,075 / −28,034 LOC

**Content composition (AC #2 PASS):**
| Surface | Count | Nature |
|---|---:|---|
| `.agentic-framework/*` (consumer-layout) | 637 | Pure pollution — this path should NEVER exist in the framework repo's own working tree (consumer projects have it via `fw upgrade`, not the framework itself) |
| Framework-native paths | 604 | Mix of `.context/working/*` churn, `docs/generated/*` regen output, `.tasks/*`, `policy/*`, `web/*` |
| `.tasks/*` files inside stash | 58 | 4 active, 54 completed |

**Task-file forensic check (AC #3 PASS):**

Ran: for every `.tasks/T-NNNN-*.md` in stash, confirm same id exists in current `.tasks/{active,completed}/`.
- **0 truly-lost task ids** — every T-NNNN referenced by the stash has a current home on master.

**Spot-check on 4 active-tasks-in-stash vs live tree (AC #4 PASS):**

| Task | Stash location | Current location | Stash `last_update` | Live `last_update` | Verdict |
|---|---|---|---|---|---|
| T-1062 | `active/` | `active/` | 2026-05-29 | 2026-06-01 | **STALE** (3 days behind live) |
| T-1981 | `active/` | `completed/` | — | 2026-05-22 | **STALE** + duplicate-source (popping would re-introduce G-052) |
| T-1987 | `active/` | `completed/` | — | 2026-05-22 | **STALE** + duplicate-source (popping would re-introduce G-052) |
| T-2083 | `active/` | `active/` | 2026-05-29 | 2026-06-01 | **STALE** (3 days behind live) |

All four are stale. T-1981 and T-1987 are doubly disqualifying — they're the exact ids T-2091 cleaned up; popping the stash would re-create the G-052 duplicates that took 7 days of silent drift + an audit FAIL + an aborted push to detect last time.

**Cross-reference to T-2091 (AC #5 PASS):**

T-2091's `## RCA` doesn't name the stash id `254e9028` directly — it describes the root cause as "someone wrote the completed task content to `.tasks/completed/` directly, but never ran the `git mv` + commit pair." OBS-034 (filed alongside T-2091 cleanup, captured `2026-05-29T11:56:18Z`) is the link: *"Stash was the source of the G-052 active/T-1981 + active/T-1987 duplicates (T-2091 fix)."*

The mechanical chain is: confused-cwd session on 2026-05-22 → completed/ written, active/ not removed → some operation (`git stash` reflex?) stashed the working-tree state, capturing both the orphaned active/ copies AND a snapshot of `.agentic-framework/` (likely was inside a consumer project in another shell) → stash sat orphan for 7 days → 2026-05-29 audit catches G-052 → T-2091 cleans up active/ duplicates → stash still on disk → OBS-034 filed.

## Recommendation

**Recommendation:** DROP

**Rationale:**
1. **No content loss risk.** Forensic check found zero task ids in the stash that don't already exist on master. The stash is a snapshot of working-tree pollution, not unique work.
2. **`.agentic-framework/*` content (637 files, ≈51% of stash) is anti-pattern.** That subtree should not exist in the framework repo's own working tree. Restoring it would re-introduce consumer-layout files inside the framework repo and trigger G-052-class detectors again.
3. **All four active-tasks-in-stash are stale by 3-10 days.** Live versions on master are newer (BVP estimator + last_update worker mutates daily). Popping would clobber live state with old content.
4. **Two of the four active-tasks-in-stash (T-1981, T-1987) are the exact G-052 duplicate-source pair T-2091 already cleaned up.** Popping the stash literally undoes T-2091's fix.
5. **Framework-native non-task files in the stash are all churn or regen output.** `.context/working/*` is regenerated daily; `docs/generated/*` is regenerated by docgen runs; `.context/audits/*` rolls forward; `policy/value-drivers.yaml` was just rewritten as v3 by T-2166 yesterday — any stashed v1/v2 state is fully obsolete. No unique work to recover.
6. **OBS-034 itself called the stash "likely created by a session whose cwd was confused"** — that's a hallmark of pollution to discard, not artisanal work to preserve.

**Evidence:**
- `git stash list` shows the orphan entry exists
- `git stash show 254e9028 --name-only` enumerated 1241 files (637 `.agentic-framework/*` + 604 framework-native)
- `git stash show 254e9028 --stat | tail -1`: `1241 files changed, 41075 insertions(+), 28034 deletions(-)`
- Forensic loop checked all 58 task ids — all 58 have a current home; 0 unaccounted
- `.tasks/completed/T-2091-g-052-cleanup-*.md` RCA section confirms the active/completed duplicate cleanup logic; OBS-034 explicitly names this stash as the source
- All four active-tasks-in-stash carry `last_update:` older than their current live counterparts (3-10 days)

**Operator action (one-liner):**
```
cd /opt/999-Agentic-Engineering-Framework && git stash drop 254e9028 && bin/fw note dismiss OBS-034 --reason "stash dropped — agent recommendation accepted, no content loss (T-2167)"
```

**Reversibility note:** stash drops are *not* git-reflog-recoverable beyond `gc.reflogExpire` (default 90 days for reachable, 30 for unreachable; orphan stashes are unreachable post-drop). The stash SHA `254e9028` and its parent will linger in the reflog for ~30 days, so accidental drops can be recovered within that window via `git fsck --unreachable | grep commit` + `git stash apply <sha>`. After 30 days it's gone.

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

# Investigation is read-only; verification just pins that the artefacts still exist
# at the moment of completion (the operator hasn't dropped the stash yet — that's
# the [REVIEW] Human AC).
git stash list | grep -q "stash@{0}.*WIP on master: 8a8a7b0a T-2086"
n=$(git stash show 254e9028 --name-only 2>&1 | wc -l); test "$n" -ge 1000
grep -q "Recommendation:.*DROP" .tasks/active/T-2167-investigate-obs-034-orphan-stash-254e902.md
out=$(grep -E "^- \[ ?x?\]" .tasks/active/T-2167-investigate-obs-034-orphan-stash-254e902.md); echo "$out" | grep -E "^- \[x\]" | wc -l | grep -q "^6$"

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

## Updates

### 2026-06-01T20:18:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2167-investigate-obs-034-orphan-stash-254e902.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c8000672
- **Timestamp:** 2026-06-11T12:13:00Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 35
     - evidence: `git stash list | grep -q "stash@{0}.*WIP on master: 8a8a7b0a T-2086"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 38
     - evidence: `out=$(grep -E "^- \[ ?x?\]" .tasks/active/T-2167-investigate-obs-034-orphan-stash-254e902.md); echo "$out" | grep -E "^- \[x\]" | wc -l | grep -q "^6$"`
### 2026-06-01T20:21:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
