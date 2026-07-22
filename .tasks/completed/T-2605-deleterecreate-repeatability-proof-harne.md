---
id: T-2605
name: "Delete/recreate repeatability proof harness + first recreate of aef-dispatch-loop"
description: >
  T-2602 GO child 3/3, the operator's acceptance test: snapshot -> delete -> regenerate
  from spec -> canonical-identical check (IW-3 comparator). First recreate = aef-dispatch-loop
  with the correct back-handoff, superseding T-2601 fix options A/B/C.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, tools/corpus_lint.py, tools/corpus_spec.py]
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
created: 2026-07-22T10:49:57Z
last_update: 2026-07-22T19:21:04Z
date_finished: 2026-07-22T19:21:04Z
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
  - ts: '2026-07-22T11:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-22T11:00:09Z'
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
  - ts: '2026-07-22T18:58:10Z'
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

# T-2605: Delete/recreate repeatability proof harness + first recreate of aef-dispatch-loop

## Context

T-2602 GO child 3/3 — the operator's acceptance test verbatim: *"fine with deleting
it and then recreating, that would actually prove repeatable, consistent, correct and
reliable."* Substrate now in place: T-2603 (`fw corpus derive/generate/diff`, specs at
`.context/designer/specs/`, round-trip IDENTICAL proven on both source maps) and
T-2604 (`fw corpus lint`, live baseline = 4× legacy-ref + 1× emitterless-typed-event).
The first recreate target is `aef-dispatch-loop` (currently serving the intentionally
preserved T-2600 defective v3); regeneration from spec fixes its `legacy-ref` finding
automatically (generator emits `workflowRef` uuid form). 832 confirmed (rail offset
159) their pair-draft byte-pin is on frozen delivered bytes, not the live map — the
recreate trips nothing client-side.

**⚠ Load-bearing design constraint discovered at code-read (2026-07-22, designer_api.py
save/delete):** `/api/delete scope:map` removes `meta.json`, and `/api/save` mints the
uuid server-side via `meta.setdefault("uuid", uuid4())` — it does NOT read the XML's
workflowMeta uuid. So a map-scope delete + re-save mints a **fresh uuid**, orphaning
every referrer pinned to the old uuid (T-2573 immutable-identity broken by the
recreate itself; e.g. the regenerated task-lifecycle pins dispatch-loop's e32a518c…).
The prove harness must therefore default to **identity-preserving recreate**: delete
all *versions* (`scope:version` per version) while keeping `meta.json`/uuid, then
regenerate — `setdefault` no-ops and the uuid survives. Map-scope delete + `fw bpmn
claim <old-uuid> <id>` rebind is the separate disaster-recovery variant, exercised as
a distinct proof leg, not the default.

## Acceptance Criteria

### Agent
- [x] `fw corpus prove <map-id>` harness: snapshot served latest → identity-preserving delete (all versions, meta/uuid kept) → regenerate from spec via `/api/save` → fetch served → canonical diff vs snapshot; exits 0 only on IDENTICAL; reports uuid-before == uuid-after
- [x] First recreate executed on `aef-dispatch-loop`: prove run passes (canonical-identical, uuid e32a518c… preserved), and `fw corpus lint` afterwards no longer reports `legacy-ref` on aef-dispatch-loop (regeneration upgraded the ref form); `tests/unit/test_corpus_lint.py` live-corpus expectation pin updated deliberately in the same change
- [x] Registry invariant: ghost list before == after the recreate (only pre-existing 398f4752 fixture); no referrer of aef-dispatch-loop becomes a ghost
- [x] Designer surface re-verified live after recreate: `/designer/app?load=/api/version?id=aef-dispatch-loop&v=<new>` serves the regenerated map (nonce-mint 302 still fires) and `/api/list` shows it as latest
- [x] DR variant documented + exercised on a scratch map (NOT the live corpus): map-scope delete → recreate mints fresh uuid → old-uuid ref becomes registered ghost → `fw bpmn claim` rebinds it; each step's output recorded in the task
- [x] Recreate flow documented in `docs/reports/T-2602-spec-driven-corpus-authoring.md` follow-up section or a T-2605 report, including the identity-preservation constraint above

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

python3 -m pytest tests/unit/test_corpus_lint.py tests/web/test_designer_dr_recreate.py tests/web/test_s4_exemplar_intake.py -q
out=$(bin/fw corpus lint 2>&1); echo "$out" | grep -q "corpus lint: scanned"
out=$(bin/fw corpus lint 2>&1); ! echo "$out" | grep -q "legacy-ref] aef-dispatch-loop"
grep -q "T-2605 follow-up" docs/reports/T-2602-spec-driven-corpus-authoring.md

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

### 2026-07-22 — prove harness shipped, first recreate landed, DR variant + docs remain (session paused at budget-critical)

- **What changed:** `fw corpus prove <map-id>` implemented in `tools/corpus_spec.py`
  (no `bin/fw` dispatch change needed — the existing `corpus)` case already forwards
  `"$@"` to `corpus_spec.py`; the verb self-resolves the Watchtower URL via
  `FW_WATCHTOWER_URL`/`WATCHTOWER_URL` env or the `.context/working/watchtower.url`
  triple-file, falling back to `localhost:3000`). Dry-run proved on a hand-authored
  scratch map first (`t2605-scratch-prove`, cleaned up via `scope:map` delete after —
  zero corpus pollution, confirmed via `git status --porcelain .context/designer/`)
  before touching the live corpus. First real recreate executed on
  `aef-dispatch-loop`: PASS, canonical-identical, uuid `e32a518c-01de-4243-aafc-691cc99caf0d`
  preserved (verified `git diff` on `meta.json` — versions collapsed v1-v3 → single
  v1, uuid unchanged). `fw corpus lint` re-run post-recreate: aef-dispatch-loop's own
  `legacy-ref` finding is gone (5→4 findings); the 3 remaining legacy-refs are OTHER
  maps referencing aef-dispatch-loop/aef-task-lifecycle by slug — untouched by this
  recreate, each a future recreate's job. Registry (`registry.yaml`) diff-checked
  unchanged (only the pre-existing 398f4752 fixture ghost). Designer surface
  live-curl-verified: `/designer/app?load=...` still fires the nonce-mint 302,
  follow-redirect returns 200; `/api/list` reports `latest.v: 1`. Test pin in
  `tests/unit/test_corpus_lint.py::test_live_corpus_current_findings` updated
  deliberately (asserts absence of aef-dispatch-loop's own legacy-ref now, not
  presence) — 11/11 unit tests green.
- **Plan impact:** none — AC1-4 landed exactly as scoped. AC5 (DR variant on a
  scratch map) and AC6 (report doc) remain — session hit budget-critical
  mid-execution of the DR variant's first API call (before any live mutation;
  nothing left on the server to clean up).
- **Concurrent-session hazard observed (not part of this task, flagging for
  continuity):** mid-session, `.context/working/focus.yaml` was externally flipped
  to T-2608 by another process (reclaimed via `fw context focus T-2605`), and later
  the git index showed `.context/designer/specs/aef-dispatch-loop.yaml` +
  `aef-task-lifecycle.yaml` **staged for deletion** by a concurrent T-2608
  ("single stored representation for corpus") session, which had already moved to
  `.tasks/completed/`. This T-2605 commit deliberately used `git commit -- <scoped
  paths>` (not `git add -A` / plain `git commit`) to avoid co-committing that
  unrelated staged deletion — if T-2608's spec-file removal is intentional (folding
  spec+store into one representation), the next session should reconcile rather than
  silently resurrect `.context/designer/specs/` if it re-stages a T-2605 touch there.
- **Triggered:** continuation needed for AC5 (DR variant: create 2 scratch maps
  target+referrer, map-scope delete target, recreate under same id → fresh uuid,
  resave referrer to register the stale-uuid ghost, strip the auto-minted uuid key
  from target's meta.json (required — `claim_ghost` refuses to rebind over an
  existing different uuid per `tests/web/test_designer_registry_claim.py`), then
  `fw bpmn claim <old-uuid> t2605-dr-target`, verify referrer resolves, then clean up
  both scratch maps + confirm `registry.yaml` reverts to baseline) and AC6 (append a
  "T-2605 recreate" follow-up section to
  `docs/reports/T-2602-spec-driven-corpus-authoring.md` documenting the harness, the
  identity-preservation constraint, and the DR variant's manual-uuid-strip gotcha).

### 2026-07-22 — retrofit + DR leg + docs (session continuation, AC5/AC6 closed)

- **What changed:** `cmd_prove` retrofitted per T-2608 GO — the persisted-spec
  default path (`.context/designer/specs/<id>.yaml`, deleted under T-2608) is gone;
  prove now **derives the spec in-memory from the served snapshot** by default,
  `--spec` accepts a transient authoring file, and `--from <git-ref>` regenerates
  from the map's XML at a git ref (IW-3 survivability leg; proof target = that
  historical artifact). Live re-run on the recreated map: idempotent PASS
  ("uuid e32a518c… PRESERVED / canonical IDENTICAL") — the derive-in-memory
  default proven end-to-end against the live server. Designer surface re-verified
  in a real browser (Playwright): landing-card URL → nonce-mint 302 fires →
  regenerated v1 renders fully (pool header, both lanes, all 10 nodes incl. the
  single correct `agt_9_handoff` back-handoff and `agt_4_worker` bus catch).
- **AC5 (DR leg):** exercised **hermetically** in
  `tests/web/test_designer_dr_recreate.py` (tmp store, never the live corpus —
  ghost registration has registry side effects). Pinned sequence: map-scope
  delete destroys meta.json → recreate mints fresh uuid B≠A → referrer re-save
  registers A as ghost → `claim_ghost(A)` REFUSES while map owns B ("already
  owns uuid" — the manual-uuid-strip gotcha) → strip `uuid` key → claim rebinds
  A, ghost removed, claim recorded, `/api/list` reports A. 1/1 green.
- **AC6 (docs):** "T-2605 follow-up — recreate flow as executed" appended to
  `docs/reports/T-2602-spec-driven-corpus-authoring.md` (default leg steps,
  identity-preservation constraint, DR-leg gotcha).
- **Test state:** corpus_lint 11/11 + s4-exemplar 3/3 + DR 1/1; `fw corpus lint`
  = 4 findings, aef-dispatch-loop's own legacy-ref confirmed absent.

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

### 2026-07-22T10:49:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2605-deleterecreate-repeatability-proof-harne.md
- **Context:** Initial task creation

### 2026-07-22T18:58:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-af5d8b5f
- **Timestamp:** 2026-07-22T19:21:07Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 34
     - evidence: `out=$(bin/fw corpus lint 2>&1); ! echo "$out" | grep -q "legacy-ref] aef-dispatch-loop"`

### 2026-07-22T19:21:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
