---
id: T-1950
name: "G-066 deliverable #2 — reviewer auto-tick Agent ACs from machine-verifiable
  evidence"
description: >
  T-1442/T-1443 GO scope half: reviewer agent should auto-tick Agent AC checkboxes
  when evidence is machine-verifiable (file exists, command output matches). Current
  static_scan.py carries explicit guard 'NEVER modifies AC checkboxes'. Closes G-066
  prong 2 of 3.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T09:50:12Z
last_update: '2026-05-20T10:15:02Z'
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
cost_estimate_proposed:
  - ts: '2026-05-20T10:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1950: G-066 deliverable #2 — reviewer auto-tick Agent ACs from machine-verifiable evidence

## Context

Reclassified from `build` → `inception` (2026-05-21, S-2026-0521-resume).

**Initial reframing was wrong** — T-1443 inception (decisions 36, 113, 213) already
GO'd reviewer auto-tick of Agent ACs as a principle on 2026-04-25. The
"NEVER modifies AC checkboxes" guard in `static_scan.py` lines 7 + 1130 is
**leftover v1.0 scope-cut**, not a sovereignty boundary. The sovereignty boundary
is "reviewer NEVER ticks Human ACs". v1.3 already shipped per-AC granular
findings (`Finding.ac_index/ac_subhead/ac_text`) — the substrate for auto-tick
exists.

**Genuine inception scope** — implementation-specific questions T-1443 deferred:

1. **Trigger** — when does auto-tick fire? Reviewer scan? Completion gate? Manual `fw reviewer --tick`?
2. **Scope** — all Agent ACs, or only `[REVIEWER]`-prefixed (T-1811 post-dates T-1443)
3. **Evidence sufficiency rule** — what verdict + finding state counts as tick-worthy?
4. **Sovereignty rails** — idempotency on intent (don't re-tick what human un-ticked)

Research artifact: `docs/reports/T-1950-reviewer-auto-tick-inception.md`.

Inputs:
- T-1443 inception (sanctioning decision, 5 invariants, sovereignty 3-layer enforcement)
- T-1811 (`[REVIEWER]` AC prefix — post-dates T-1443, narrows scope candidate)
- T-1878 (author-time `[REVIEW]→[REVIEWER]` nudge — prefix convention)
- T-1947 (reviewer prose-quality guard — necessary-but-not-sufficient)
- `lib/reviewer/static_scan.py` v1.4 (substrate: per-AC findings shipped, mutation guard standing)

## Acceptance Criteria

### Agent
- [x] Research artifact `docs/reports/T-1950-reviewer-auto-tick-inception.md` exists with all four design questions answered (trigger / scope of auto-tickable ACs / evidence sufficiency rule / sovereignty rail for human-untick)
- [x] Artifact captures rejected alternatives in a Decisions Made block — at least one per design question
- [ ] Inception decision recorded via `fw inception decide T-1950 go|no-go|defer --rationale "..."` (human action; T-1950 reaches terminal state, not parked)
- [ ] If GO: at least one build child filed with real ACs (G-020-compliant) and arc/tags link back to T-1950 + G-066
- [ ] If GO: child task scope explicitly names the [REVIEWER]-only auto-tick decision (no scope creep into other AC classes without separate inception)

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

## Decisions

### 2026-05-21 — Reclassify build → inception (initial framing wrong)

- **Chose:** Reclassify T-1950 to `workflow_type: inception` before any source edit
- **Why:** Initial impulse was to treat T-1950 as a build (placeholder ACs notwithstanding) but the reviewer auto-tick capability requires 4 implementation decisions (trigger / scope / evidence / sovereignty rail) that T-1443 did not spell out. Building without those decisions would have surprised the sovereignty rail later (Q4 — digest-keyed feedback-stream design)
- **Rejected:** Build with "we'll figure out the rails as we go" — G-020 spirit + T-1443's own staged-rollout discipline (decision 14 in T-1443) say "design before build, even on a sanctioned principle"

### 2026-05-21 — Scope auto-tick to [REVIEWER]-prefixed Agent ACs at v1.0

- **Chose:** Auto-tick fires only for Agent ACs whose text starts with `[REVIEWER]` (T-1811 prefix)
- **Why:** T-1811 was filed precisely as the "reviewer-verifiable" prefix; auto-tick is the **dual** of [REVIEWER]. Conservative — easy to widen (v2: + Verification-bound; v3: all Agent), hard to narrow. T-1947's prose-quality guard already flags [REVIEWER] misfiles; that audit becomes auto-tick's safety net.
- **Rejected:** "All Agent ACs" (too broad — false-tick on misfiled prose-quality ACs) / "Agent ACs with matching Verification command" (heuristic mapping, conflicts with T-1831 C-4 progressive ticking)

### 2026-05-21 — Sovereignty rail: digest-keyed feedback-stream

- **Chose:** Auto-tick at most once per `(task_id, ac_index, evidence_digest)` tuple; human un-ticks observed via scan-time diff + feedback-stream `human_untick_observed`; never re-tick same tuple
- **Why:** Markdown `[ ]` has no state — initial-unticked vs human-unticked are indistinguishable in the body. Feedback-stream is the durable structured record (T-1443 decision 6). Digest-keying means evidence-changes re-evaluate naturally — human's stale revoke doesn't block updates after task content changes.
- **Rejected:** HTML comment marker (pollutes body, comment-blindness pattern) / Author opt-out via `[REVIEWER]:NO-AUTO` (friction-additive, violates 7 UX principles) / Side-file (duplicates feedback-stream, divergence risk)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO

**Rationale:** T-1443 already sanctioned reviewer auto-tick of Agent ACs as a principle
(decisions 36, 113, 213 in `docs/reports/T-1443-independent-reviewer-agent.md`); v1.3 shipped
the per-AC granular substrate (`Finding.ac_index/ac_subhead/ac_text`). G-066 prong 2 is
unfinished implementation, not unfinished design. The four implementation questions left
open by T-1443 are now answered conservatively in `docs/reports/T-1950-reviewer-auto-tick-inception.md`:
trigger fires in `static_scan.py` (one place covers manual + completion-gate callers);
scope is `[REVIEWER]`-prefixed Agent ACs only at v1.0 (T-1811 prefix dualism); evidence rule
is conjunctive (PASS + zero per-AC findings + untick + no suppress override + prefix match);
sovereignty rail is digest-keyed feedback-stream (one tick per `(task, ac, digest)` tuple,
human-untick observed but never re-ticked).

GO ships one build child (T-1950A): v1.0 reviewer auto-tick for `[REVIEWER]`-prefixed Agent
ACs. v2 (Verification-bound) and v3 (all Agent ACs) are filed as captured/horizon=later only
after v1.0 dogfood signal proves the rails hold.

**Evidence:**
- T-1443 GO decisions cited at `docs/reports/T-1443-independent-reviewer-agent.md:21, 36, 113, 213`
- v1.3 per-AC linkage shipped: `lib/reviewer/static_scan.py:49, 257, 703, 810, 906, 1083, 1115, 1263`
- Mutation guard standing as v1.0 scope-cut text: `lib/reviewer/static_scan.py:7, 1130` (T-1950A removes these)
- Feedback-stream substrate exists: `.context/working/feedback-stream.yaml` populated by `static_scan.py` since v1.0
- Override mechanism exists for safety-net: `lib/reviewer/overrides.py` (T-1443 v1.4)
- `[REVIEWER]` prefix substrate: T-1811 (CLAUDE.md §AC Classification Guidance) + T-1878 (author-time nudge) + T-1947 (prose-quality guard — auto-tick's safety net)
- Inception artefact: `docs/reports/T-1950-reviewer-auto-tick-inception.md`

**Confirm:** `fw inception decide T-1950 go --rationale "approved per T-1443 sanction + 4-question implementation design"` (via Watchtower at http://192.168.10.107:3000/inception/T-1950).

**Override:** NO-GO if the v1.0 [REVIEWER]-only scope is too narrow (you'd rather ship "all
Agent ACs" with a broader safety design first); DEFER if you'd rather close G-066 via prong 3
(T-1951 TermLink-dispatch) before prong 2.

## Updates

### 2026-05-21T20:30:00Z — inception-reframed [claude-code, S-2026-0521-resume]
- **Action:** Reclassified `workflow_type: build → inception`, status `captured → started-work`, horizon `next → now`. Wrote `docs/reports/T-1950-reviewer-auto-tick-inception.md` with 4 design questions + Decisions Made + Recommendation GO.
- **Output:** Research artefact + Recommendation block; tick Agent ACs #1 + #2.
- **Context:** Initial impulse to do a from-scratch inception was overcorrected after reading T-1443 (which already GO'd the principle on 2026-04-25); reframed to "implementation inception" answering the 4 questions T-1443 deferred.

### 2026-05-20T09:50:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1950-g-066-deliverable-2--reviewer-auto-tick-.md
- **Context:** Initial task creation
