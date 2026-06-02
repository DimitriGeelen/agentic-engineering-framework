---
id: T-1837
name: "Auto-tick '[REVIEW] Decide...' Human ACs on fw inception decide — pattern coverage gap (cluster Layer 1.5)"
description: >
  tick_inception_decide_acs PATTERNS only match '[REVIEW]...go/no-go decision' literal phrasing. Caught in S-2026-0514 cluster: T-1829/T-1830/T-1831 Human ACs read '[REVIEW] Decide go/no-go AND which approach', '[REVIEW] Decide GO/NO-GO/DEFER on the umbrella...', '[REVIEW] Decide on prevention pattern (Layer 1)' — wording diverged from regex. User decided all three via Watchtower; decisions recorded in task body as **Decision**: GO; but the AC checkboxes did NOT auto-tick → tasks stuck in partial-complete asking for re-review. Same antifragility class as T-1828/T-1832 (gate measures proxy diverged from reality). Fix: broaden regex to '\[REVIEW\].*\bdecide\b' (case-insensitive) — for inception tasks, '[REVIEW] Decide ...' canonically IS the go/no-go authorization. Add bats test pinning all three real-world wordings.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [fw-upgrade-incident-2026-05-14, gate-vs-content-drift, ac-discipline, bug]
components: [lib/inception.sh]
related_tasks: []
created: 2026-05-14T21:14:36Z
last_update: 2026-05-14T21:16:57Z
date_finished: 2026-05-14T21:16:57Z
---

# T-1837: Auto-tick '[REVIEW] Decide...' Human ACs on fw inception decide — pattern coverage gap (cluster Layer 1.5)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Extend `tick_inception_decide_acs` PATTERNS to match `[REVIEW]...decide` (case-insensitive, broader)
- [x] Bats test pins all three real-world wordings: "Decide go/no-go AND which approach", "Decide GO/NO-GO/DEFER on...", "Decide on prevention pattern"
- [x] Verification: bats test passes

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

bats tests/unit/tick_inception_decide_acs_review_decide_coverage.bats

## RCA

**Symptom:** User decided GO via Watchtower on T-1829/T-1830/T-1831 (decisions recorded in body as `**Decision**: GO`), but each task stayed in partial-complete with its Human AC unchecked. Surfaced when agent listed `/review/T-XXXX` URLs as "pending your action" — user replied "this does not make sense, you want me to accept/approve but ask me to review".

**Root cause:** `tick_inception_decide_acs` PATTERNS only matched the literal phrase "go/no-go decision" (`\[REVIEW\].*go/?no-go decision`). Real-world ACs use natural wording variants: "Decide go/no-go AND which approach", "Decide GO/NO-GO/DEFER on...", "Decide on prevention pattern". None matched. Auto-tick silently no-op'd; AC stayed `- [ ]`; framework rejected sweep completion; user-facing message asked for re-review of a decision already made.

**Why structurally allowed:** PATTERNS regex captured only one wording (the original template's exact phrasing). No structural enforcement that PATTERNS coverage matches the actual AC wording variants the agent writes. Same antifragility class as T-1828 (gate measures proxy diverged from reality) and T-1832 (anchor-dependent script silently no-ops when anchor variant unmet).

**Prevention:** PATTERNS broadened to `\[REVIEW\].*\bdecide\b` (case-insensitive). For inception tasks — the only context this function runs — '[REVIEW] Decide ...' is canonically the go/no-go authorization, so a broad match is safe. The non-decide test pin (`[REVIEW] Confirm UI ...`) ensures no false positive on review-class verbs that are NOT the decide AC. Three real-world wordings pinned in bats. Class shared with T-1832: keep regex coverage aligned to the wording it must match, not the wording the template uses.

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

### 2026-05-14T21:14:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1837-auto-tick-review-decide-human-acs-on-fw-.md
- **Context:** Initial task creation

### 2026-05-14T21:14:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-87b1576e
- **Timestamp:** 2026-06-02T14:59:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-14T21:16:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
