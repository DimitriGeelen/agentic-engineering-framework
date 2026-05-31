---
id: T-2147
name: "Reviewer detector — audience-mismatch in [REVIEW] ACs (T-2143 leg B): agent-as-subject
  phrasing in Human ACs"
description: >
  Reviewer detector — audience-mismatch in [REVIEW] ACs (T-2143 leg B): agent-as-subject
  phrasing in Human ACs

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [arc-008, reviewer, audience-mismatch, ac-routing]
components: [agents/audit/reviewer/static_scan.py]
related_tasks: [T-2143, T-2139, T-2142, T-2145, T-1947, T-1878, T-1811]
arc_id: inception-review-loop
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T17:26:30Z
last_update: '2026-05-31T17:30:03Z'
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
  - ts: '2026-05-31T17:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-31T17:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2147: Reviewer detector — audience-mismatch in [REVIEW] ACs (T-2143 leg B): agent-as-subject phrasing in Human ACs

## Context

Leg B of T-2143's Candidate D GO (recorded 2026-05-31T17:25:06Z). T-2143 RCA: agent reflexively routes prose-tone judgment to `[REVIEW]` (Human AC) even when audience disqualifies — when the AC subject is itself another agent's experience, asking the operator is structurally wrong. 4 rounds of the same failure in one session on T-2139's Human AC. Class fits alongside T-1947 (prose-mismatch detector, reads predicate) and T-1878 (default-bias rule); T-2147 reads **subject** — whose experience the AC is judging.

Full diagnosis + pattern hints: `docs/reports/T-2143-routing-recursion-rca.md`. Sibling of T-2145 (defer-as-hedge detector) — both extend `agents/audit/reviewer/static_scan.py` and could share catalogue infrastructure.

## Acceptance Criteria

### Agent
- [ ] `agents/audit/reviewer/static_scan.py` gains a new detector `audience-mismatch` that fires when ALL of these hold on a task body:
  - `### Human` section exists
  - At least one `- [ ] [REVIEW]` (or `[x] [REVIEW]`) AC under `### Human`
  - That AC's body text contains agent-as-subject phrasing: `agent who`, `agent reads`, `agent trips`, `agent files`, `agent sees`, `agent gets`, `agent handles`, `for an agent`, `the agent will`, or the singular noun form `agent` immediately followed by an indicative verb within 3 tokens
  - The AC's `**Expected:**` clause does NOT describe a human-experience question (presence of *human*, *operator*, *you*, *user* as subject)
- [ ] Detector emits CONCERN with message: "audience-mismatch: [REVIEW] AC asks about an *agent's* experience; agent-audience prose-tone judgment should be Agent self-eval, not Human review. Consider deleting the AC OR re-framing as governance question (does this match how YOU want framework gates to address agents?)."
- [ ] Detector entry added to reviewer catalogue alongside T-2145's `defer-as-hedge` entry, same default-on / TTL-overridable contract.
- [ ] Unit tests cover: (a) AC with "agent who trips" + REVIEW prefix triggers CONCERN, (b) AC with "you (operator)" + REVIEW does NOT trigger, (c) Agent-section AC with same phrasing does NOT trigger, (d) AC with framing question ("does this match how YOU want…") does NOT trigger, (e) AC describing rendered-content-for-human (e.g. UI/dashboard) with verb subject "user" does NOT trigger.
- [ ] Bats integration test pinning `fw reviewer T-XXX` end-to-end against a synthetic audience-mismatch fixture.
- [ ] Corpus walk: `grep -lE "agent (who|reads|trips|files|sees)" .tasks/{active,completed}/T-*.md` enumerated within `### Human` sections; each result classified as (a) genuine audience-mismatch (file override or rewrite), or (b) false positive (file TTL'd override with rationale). Walk size + result counts logged in `docs/reports/T-2147-corpus-walk.md`.
- [ ] False-positive guard: detector skips ACs whose body explicitly says "rewritten to ask <human>" or "audience: operator" — a documented opt-out marker the author can include.

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

### 2026-05-31T17:26:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2147-reviewer-detector--audience-mismatch-in-.md
- **Context:** Initial task creation

### 2026-05-31T17:28:02Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)
