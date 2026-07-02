---
id: T-1835
name: "CLAUDE.md AC-tick discipline rule — tick checkboxes as content is written,
  not after-the-fact (T-1831 C-4 build)"
description: >
  T-1831 C-4 build sibling. Codify in CLAUDE.md §Verification Before Completion: agent
  must tick each Agent AC checkbox as soon as the corresponding content/work is in
  place, NOT after-the-fact. Origin: S-2026-0514 errors 1-3 — agent wrote AC content
  (RCA, candidates, recommendation) in task body but did not progressively tick boxes;
  gate measured [x] markers, not body content, blocked completion + decide with misleading
  error. Same antifragility class as T-1828: gate measures proxy that diverged from
  reality. Prevention pattern is documentation hygiene — costs nothing, reframes mental
  model.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-05-14T20:52:33Z
last_update: '2026-06-11T22:24:00Z'
date_finished: 2026-05-14T20:54:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1835: CLAUDE.md AC-tick discipline rule — tick checkboxes as content is written, not after-the-fact (T-1831 C-4 build)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Add "Progressive AC ticking" paragraph to CLAUDE.md §Verification Before Completion section
- [x] Paragraph references T-1831 C-4 origin and S-2026-0514 errors 1-3
- [x] Paragraph names the antifragility class (gate-measures-proxy) and cross-links T-1828
- [x] Verification command: `grep -q "Progressive AC ticking" CLAUDE.md`

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
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

grep -q "Progressive AC ticking" CLAUDE.md

## RCA

**Symptom:** S-2026-0514 errors 1-3 — agent wrote AC content (RCA, candidates, recommendation) in task body but did NOT progressively tick the `- [ ]` checkboxes. Completion gate (P-010) and inception-decide preflight (T-1503) refused with "Cannot complete — N/N agent AC unchecked", surfaced repeatedly to user before agent recognized the class.

**Root cause:** missing procedural rule in CLAUDE.md. The agent's workflow had no documented expectation about WHEN to tick AC boxes during work. The implicit assumption was "tick at the end before completion" — that expectation interacts badly with the gate, which counts `[x]` markers, not body content. After-the-fact ticking (only after the gate fires) is the exact pattern the gate exists to prevent.

**Why structurally allowed:**
- §Verification Before Completion told agent to *check* boxes before completion but did not specify WHEN ticks should happen during work.
- No structural reminder (hook, lint, audit) detects "AC content present, checkbox not ticked".
- Same antifragility class as T-1828: gate measures proxy (checkbox state) that diverged from reality (body content).
- T-1831 inception caught the pattern; this build task lands the documentation fix.

**Prevention:** CLAUDE.md §Verification Before Completion now includes a "Progressive AC ticking (T-1831 C-4)" paragraph explicit: tick each box as the content is in place, not after-the-fact. Cross-linked to T-1828 for the antifragility-class framing. Future agents reading CLAUDE.md before starting work get the rule directly. C-3 (gate diagnostic upgrade — surface body-content-vs-checkbox drift in the gate error message) is filed as a separate task; this one is the documentation half.

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

### 2026-05-14T20:52:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1835-claudemd-ac-tick-discipline-rule--tick-c.md
- **Context:** Initial task creation

### 2026-05-14T20:53:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c7b4325a
- **Timestamp:** 2026-06-02T14:59:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-14T20:54:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
